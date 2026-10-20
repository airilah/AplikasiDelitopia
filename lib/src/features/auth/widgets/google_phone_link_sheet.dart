import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/models/user_model.dart';
import '../services/auth_service.dart';

class GooglePhoneLinkSheet extends ConsumerStatefulWidget {
  final GoogleLinkPendingData googleData;
  final ValueChanged<User> onSuccess;

  const GooglePhoneLinkSheet({
    super.key,
    required this.googleData,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required GoogleLinkPendingData googleData,
    required ValueChanged<User> onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GooglePhoneLinkSheet(
        googleData: googleData,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<GooglePhoneLinkSheet> createState() =>
      _GooglePhoneLinkSheetState();
}

class _GooglePhoneLinkSheetState extends ConsumerState<GooglePhoneLinkSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _step = 0; // 0: Input Phone, 1: Input OTP
  bool _isLoading = false;
  String? _errorMessage;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _cleanPhone() {
    var raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.startsWith('62')) {
      raw = '0${raw.substring(2)}';
    } else if (raw.startsWith('8')) {
      raw = '0$raw';
    }
    return raw;
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _cleanPhone();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.requestPhoneOtp(
        phoneNumber: phone,
        mode: PhoneAuthMode.login,
        channel: 'whatsapp',
      );

      if (!mounted) return;
      setState(() {
        _step = 1;
        _isLoading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyAndLink() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      final lang = ref.read(appLanguageProvider);
      setState(() => _errorMessage = lang == AppLanguage.indonesia
          ? 'Silakan masukkan kode OTP yang valid'
          : 'Please enter a valid OTP code');
      return;
    }

    final phone = _cleanPhone();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.linkGoogleWithPhoneOtp(
        phoneNumber: phone,
        otp: otp,
        googleData: widget.googleData,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Avatar & Icon
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: widget.googleData.photo != null &&
                              widget.googleData.photo!.isNotEmpty
                          ? ClipOval(
                              child: CachedImage(
                                imageUrl: widget.googleData.photo!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(
                                    Icons.account_circle,
                                    size: 32,
                                    color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.g_mobiledata_rounded,
                              size: 36, color: Color(0xFF4285F4)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.sync_alt_rounded,
                          color: Colors.grey.shade500, size: 24),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDD2222),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Center(
                child: Text(
                  isIndo ? 'Hubungkan Akun Google' : 'Link Google Account',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Center(
                child: Text(
                  isIndo
                      ? 'Akun Google (${widget.googleData.email}) belum terhubung. Masukkan nomor HP kamu untuk menautkan akun Delitopia.'
                      : 'Google account (${widget.googleData.email}) is not linked yet. Enter your phone number to link your Delitopia account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFC9C9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFB01C1C), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB01C1C),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_step == 0) ...[
                // Phone Input Field
                Text(
                  isIndo ? 'Nomor WhatsApp / HP' : 'Phone / WhatsApp Number',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4D4D4D),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: isIndo ? 'Contoh: 081234567890' : 'e.g. 081234567890',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFDD2222), width: 1.8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isIndo
                          ? 'Silakan masukkan nomor ponsel'
                          : 'Please enter phone number';
                    }
                    if (value.trim().length < 9) {
                      return isIndo
                          ? 'Nomor ponsel minimal 9 digit'
                          : 'Phone number too short';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Send OTP Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isIndo
                                ? 'Kirim Kode Verifikasi (OTP)'
                                : 'Send OTP Code',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // OTP Step
                Text(
                  isIndo ? 'Kode Verifikasi (OTP)' : 'Verification Code (OTP)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4D4D4D),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFDD2222), width: 1.8),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Resend OTP & Change Phone
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _step = 0;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        isIndo ? 'Ganti Nomor' : 'Change Phone',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _countdown > 0 || _isLoading
                          ? null
                          : _handleSendOtp,
                      child: Text(
                        _countdown > 0
                            ? (isIndo
                                ? 'Kirim Ulang (${_countdown}s)'
                                : 'Resend (${_countdown}s)')
                            : (isIndo ? 'Kirim Ulang OTP' : 'Resend OTP'),
                        style: TextStyle(
                          color: _countdown > 0
                              ? Colors.grey
                              : const Color(0xFFDD2222),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Verify and Link Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyAndLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isIndo ? 'Verifikasi & Masuk' : 'Verify & Sign In',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
