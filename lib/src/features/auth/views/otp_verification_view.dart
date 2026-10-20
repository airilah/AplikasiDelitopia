import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../services/auth_service.dart';
import '../utils/auth_flow_utils.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class OtpVerificationView extends ConsumerStatefulWidget {
  final String phoneNumber;
  final PhoneAuthMode mode;
  final String channel;
  final String? returnTo;

  const OtpVerificationView({
    super.key,
    required this.phoneNumber,
    required this.mode,
    this.channel = 'whatsapp',
    this.returnTo,
  });

  @override
  ConsumerState<OtpVerificationView> createState() =>
      _OtpVerificationViewState();
}

class _OtpVerificationViewState extends ConsumerState<OtpVerificationView> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  late String _activeChannel;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.channel;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    final isIndo = ref.read(appLanguageProvider) == AppLanguage.indonesia;
    if (otp.length < 4) {
      setState(() => _message = isIndo ? 'Kode verifikasi salah' : 'Invalid verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await ref.read(authServiceProvider).verifyPhoneOtp(
            phoneNumber: widget.phoneNumber,
            otp: otp,
            mode: widget.mode);

      if (!mounted) return;

      if (result.authenticated && !result.requiresProfile) {
        refreshAuthScopedProviders(ref);
        _goAfterAuth();
        return;
      }

      context.go(
        '${AppRouter.completeProfile}'
        '?phone=${Uri.encodeComponent(widget.phoneNumber)}'
        '${_returnToQuery()}');
    } on AccountPendingDeletionException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showRestoreAccountDialog(e);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showRestoreAccountDialog(AccountPendingDeletionException pending) {
    final lang = ref.read(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restore_rounded,
                color: Color(0xFFE65100),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isIndo ? 'Pulihkan Akun?' : 'Restore Account?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF242424),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          pending.message,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isIndo ? 'Batal' : 'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    setState(() => _isLoading = true);
                    try {
                      await ref.read(authServiceProvider).restoreAccount(
                            userId: pending.userId,
                            phoneNumber: widget.phoneNumber,
                          );
                      if (!mounted) return;
                      refreshAuthScopedProviders(ref);
                      Helpers.showSnackbar(
                        context,
                        isIndo
                            ? 'Akun Anda berhasil dipulihkan. Selamat datang kembali!'
                            : 'Your account has been successfully restored. Welcome back!',
                      );
                      _goAfterAuth();
                    } catch (err) {
                      if (!mounted) return;
                      setState(() {
                        _isLoading = false;
                        _message =
                            err.toString().replaceAll('Exception: ', '').trim();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isIndo ? 'Pulihkan Akun' : 'Restore Account',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).requestPhoneOtp(
            phoneNumber: widget.phoneNumber,
            mode: widget.mode,
            channel: _activeChannel);
      if (!mounted) return;

      _startTimer();
      setState(() => _isLoading = false);

      final isIndo = ref.read(appLanguageProvider) == AppLanguage.indonesia;
      Helpers.showSnackbar(
        context,
        isIndo
            ? 'Kode verifikasi dikirim ulang via ${_activeChannel == 'whatsapp' ? 'WhatsApp' : 'SMS'}'
            : 'Verification code resent via ${_activeChannel == 'whatsapp' ? 'WhatsApp' : 'SMS'}',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _goAfterAuth() {
    final destination = widget.returnTo;
    context.go(
      destination != null && destination.isNotEmpty
          ? destination
          : AppRouter.navigation);
  }

  String _returnToQuery() {
    final returnTo = widget.returnTo;
    if (returnTo == null || returnTo.isEmpty) return '';
    return '&returnTo=${Uri.encodeComponent(returnTo)}';
  }

  String _displayPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) return '+$digits';
    if (digits.startsWith('8')) return '+62$digits';
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final channelLabel = _activeChannel == 'whatsapp' ? 'WhatsApp' : 'SMS';
    final phoneMessage = tr
        .get('code_sent_via_phone', lang)
        .replaceAll('{channel}', channelLabel)
        .replaceAll('{phone}', _displayPhone(widget.phoneNumber));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 52 ? constraints.maxHeight - 52 : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRouter.login);
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF202124),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        tr.get('enter_verification_code', lang),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phoneMessage,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _otpController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (_) => setState(() => _message = null),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDD2222),
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                        ),
                      ),
                      if (_message != null && _message!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFDD2222).withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDD2222).withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFDD2222),
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _message!,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => setState(() => _message = null),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Resend & Channel Switcher
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            if (_secondsRemaining > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr
                                        .get('resend_code_in', lang)
                                        .replaceAll('{time}', '00:${_secondsRemaining.toString().padLeft(2, '0')}'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: _isLoading ? null : _resend,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: Text(
                                    tr.get('resend_otp_whatsapp', lang),
                                    style: const TextStyle(fontWeight: FontWeight.normal),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDD2222),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDD2222),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(tr.get('verify', lang)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
