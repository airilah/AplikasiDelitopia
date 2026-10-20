import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/services/service_providers.dart';
import '../services/auth_service.dart';
import '../utils/auth_flow_utils.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class EmailVerificationView extends ConsumerStatefulWidget {
  final String? returnTo;

  const EmailVerificationView({super.key, this.returnTo});

  @override
  ConsumerState<EmailVerificationView> createState() =>
      _EmailVerificationViewState();
}

class _EmailVerificationViewState extends ConsumerState<EmailVerificationView> {
  final _otpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isChangingEmail = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).sendEmailVerificationOtp();
      if (!mounted) return;
      final isIndo = ref.read(appLanguageProvider) == AppLanguage.indonesia;
      setState(() {
        _message = isIndo
            ? 'Kode verifikasi telah dikirim ke email kamu.'
            : 'Verification code has been sent to your email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _verify() async {
    final lang = ref.read(appLanguageProvider);
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _message = tr.get('enter_6_digit_code', lang));
      return;
    }

    setState(() {
      _isVerifying = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).verifyEmailOtp(otp);
      if (!mounted) return;
      refreshAuthScopedProviders(ref);
      ref.invalidate(currentUserProvider);
      Helpers.showSnackbar(context, tr.get('email_verified_success', lang));
      _goNext();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isVerifying = false;
      });
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final lang = ref.read(appLanguageProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    final emailController = TextEditingController(text: user?.email ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded,
                              color: Color(0xFFDD2222), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            tr.get('change_email', lang),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr.get('change_email_desc', lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'email@domain.com',
                          labelText: tr.get('new_email_address', lang),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDD2222),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return tr.get('email_empty', lang);
                          }
                          final emailRegex =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return tr.get('email_format_invalid', lang);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isChangingEmail
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final newEmail = emailController.text.trim();
                                  if (user == null) return;

                                  setDialogState(() => _isChangingEmail = true);

                                  try {
                                    await ref
                                        .read(authServiceProvider)
                                        .updateProfile(
                                          userId: user.id,
                                          email: newEmail);

                                    ref.invalidate(currentUserProvider);
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }

                                    if (mounted) {
                                      Helpers.showSnackbar(
                                        context,
                                        tr.get('email_changed_to', lang).replaceAll('{email}', newEmail),
                                      );
                                      await _sendCode();
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      Helpers.showSnackbar(dialogContext, e.toString().replaceAll('Exception: ', ''), backgroundColor: Colors.red);
                                    }
                                  } finally {
                                    setDialogState(
                                        () => _isChangingEmail = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDD2222),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isChangingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  tr.get('save_send_code', lang),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: _isChangingEmail
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                          ),
                          child: Text(
                            tr.get('cancel', lang),
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _goNext() {
    final destination = widget.returnTo;
    context.go(
      destination != null && destination.isNotEmpty
          ? destination
          : AppRouter.navigation);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final emailTarget = user?.email ?? tr.get('your_email', lang);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF202124),
        title: Text(tr.get('email_verification_title', lang)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.get('email_unverified', lang),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr
                    .get('email_verification_message', lang)
                    .replaceAll('{email}', emailTarget),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showChangeEmailDialog,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(tr.get('change_email', lang)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDD2222),
                  side: const BorderSide(color: Color(0xFFDD2222)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('berhasil') ||
                            _message!.contains('dikirim') ||
                            _message!.contains('sent') ||
                            _message!.contains('success')
                        ? Colors.green.shade700
                        : const Color(0xFFDD2222),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isSending ? null : _sendCode,
                    child: Text(_isSending ? tr.get('sending', lang) : tr.get('resend_code', lang)),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr.get('email_verification_title', lang),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isVerifying ? null : _goNext,
                  child: Text(tr.get('skip_for_now', lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
