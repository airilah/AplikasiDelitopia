import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../shared/services/service_providers.dart';
import '../../auth/services/auth_service.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class AddPhoneNumberView extends ConsumerStatefulWidget {
  final String? returnTo;

  const AddPhoneNumberView({super.key, this.returnTo});

  @override
  ConsumerState<AddPhoneNumberView> createState() => _AddPhoneNumberViewState();
}

class _AddPhoneNumberViewState extends ConsumerState<AddPhoneNumberView> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  final String _channel = 'whatsapp';
  String? _message;
  String? _verifiedPhone;
  int _secondsRemaining = 60;
  Timer? _timer;
  AppLanguage get _lang => ref.read(appLanguageProvider);

  String? get _normalizedPhoneOrNull {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    var local = digits;
    if (local.startsWith('62')) {
      local = local.substring(2);
    }
    if (local.startsWith('0')) {
      local = local.substring(1);
    }
    if (!local.startsWith('8')) return null;
    if (local.length < 9 || local.length > 13) return null;

    return '+62$local';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
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

  String _displayPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) return '+$digits';
    if (digits.startsWith('8')) return '+62$digits';
    return phone;
  }

  Future<void> _requestOtp() async {
    final phone = _normalizedPhoneOrNull;
    if (phone == null) {
      setState(() => _message = _lang == AppLanguage.indonesia ? 'Nomor ponsel tidak valid' : 'Invalid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final sentPhone =
          await ref.read(authServiceProvider).requestProfilePhoneOtp(
                phoneNumber: phone,
                channel: _channel);

      if (!mounted) return;
      setState(() {
        _verifiedPhone = sentPhone;
        _otpSent = true;
        _isLoading = false;
      });

      _startTimer();

      Helpers.showSnackbar(context, 
            _lang == AppLanguage.indonesia
                ? 'Kode verifikasi dikirim melalui ${_channel == 'whatsapp' ? 'WhatsApp' : 'SMS'}'
                : 'Verification code sent via ${_channel == 'whatsapp' ? 'WhatsApp' : 'SMS'}', backgroundColor: Colors.green);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _verifiedPhone ?? _normalizedPhoneOrNull;
    final otp = _otpController.text.trim();
    if (phone == null) {
      setState(() => _message = _lang == AppLanguage.indonesia ? 'Nomor ponsel tidak valid' : 'Invalid phone number');
      return;
    }
    if (otp.length != 6) {
      setState(() => _message = _lang == AppLanguage.indonesia ? 'Masukkan 6 digit kode OTP' : 'Enter 6-digit OTP code');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).verifyProfilePhone(
            phoneNumber: phone,
            otp: otp);

      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Nomor ponsel berhasil diverifikasi' : 'Phone number verified successfully');

      final returnTo = widget.returnTo;
      if (returnTo != null && returnTo.isNotEmpty) {
        context.go(returnTo);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('${AppRouter.navigation}?index=4');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    return BackButtonWrapper(
      backRoute: '${AppRouter.navigation}?index=4',
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '${AppRouter.navigation}?index=4',
            color: Colors.white,
          ),
          title: Text(lang == AppLanguage.indonesia ? 'Verifikasi Nomor Ponsel' : 'Verify Phone Number'),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otpSent
                      ? (lang == AppLanguage.indonesia ? 'Masukkan kode OTP' : 'Enter OTP code')
                      : (lang == AppLanguage.indonesia ? 'Tambahkan nomor ponsel' : 'Add phone number'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent
                      ? (lang == AppLanguage.indonesia
                          ? 'Kode dikirim via '
                              '${_channel == 'whatsapp' ? 'WhatsApp' : 'SMS'} '
                              'ke ${_displayPhone(_verifiedPhone ?? _normalizedPhoneOrNull ?? 'nomor kamu')}.'
                          : 'Code sent via '
                              '${_channel == 'whatsapp' ? 'WhatsApp' : 'SMS'} '
                              'to ${_displayPhone(_verifiedPhone ?? _normalizedPhoneOrNull ?? 'your number')}.')
                      : (lang == AppLanguage.indonesia
                          ? 'Nomor ponsel wajib unik dan diperlukan untuk checkout serta login terbaru.'
                          : 'Phone number must be unique and is required for checkout and recent logins.'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 28),
                if (!_otpSent) ...[
                  Text(
                    lang == AppLanguage.indonesia ? 'Nomor Ponsel' : 'Phone Number',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4D4D4D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '+62',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          onChanged: (_) => setState(() => _message = null),
                          decoration: InputDecoration(
                            hintText: '838 1234 4323',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFFDD2222),
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
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
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Timer & Resend Container
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
                                lang == AppLanguage.indonesia
                                    ? 'Kirim ulang kode dalam 00:${_secondsRemaining.toString().padLeft(2, '0')}'
                                    : 'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
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
                              onPressed: _isLoading ? null : _requestOtp,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(
                                lang == AppLanguage.indonesia
                                    ? 'Kirim Ulang Kode OTP via WhatsApp'
                                    : 'Resend OTP Code via WhatsApp',
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
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFDD2222), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              color: Color(0xFFDD2222),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _otpSent
                            ? _verifyOtp
                            : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      disabledBackgroundColor: const Color(0xFFFFB6B6),
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
                        : Text(_otpSent
                            ? (lang == AppLanguage.indonesia ? 'Verifikasi' : 'Verify')
                            : (lang == AppLanguage.indonesia ? 'Kirim OTP' : 'Send OTP')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
