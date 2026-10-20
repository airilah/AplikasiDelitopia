import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../services/auth_service.dart';

class PhoneAuthView extends ConsumerStatefulWidget {
  final PhoneAuthMode mode;
  final String? returnTo;

  const PhoneAuthView({
    super.key,
    required this.mode,
    this.returnTo,
  });

  @override
  ConsumerState<PhoneAuthView> createState() => _PhoneAuthViewState();
}

class _PhoneAuthViewState extends ConsumerState<PhoneAuthView> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  final String _channel = 'whatsapp';

  bool get _isValidPhone => _normalizedPhoneOrNull != null;

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
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _normalizedPhoneOrNull;
    if (phone == null) {
      setState(() =>
          _message = tr.get('phone_invalid', ref.read(appLanguageProvider)));
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await ref.read(authServiceProvider).requestPhoneOtp(
            phoneNumber: phone,
            mode: widget.mode,
            channel: _channel);

      if (!mounted) return;
      context.go(
        '${AppRouter.otpVerification}'
        '?mode=${widget.mode.name}'
        '&phone=${Uri.encodeComponent(result.phoneNumber)}'
        '&channel=$_channel'
        '${_returnToQuery()}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _returnToQuery() {
    final returnTo = widget.returnTo;
    if (returnTo == null || returnTo.isEmpty) return '';
    return '&returnTo=${Uri.encodeComponent(returnTo)}';
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.mode == PhoneAuthMode.register;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                          isRegister
                              ? tr.get('register_with_phone', lang)
                              : tr.get('login_with_phone_title', lang),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr.get('phone_otp_subtitle', lang),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          tr.get('phone', lang),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF202124),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
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
                                  hintText: '812 123 4567',
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade300),
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
                                      size: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              text: tr.get('send_code_via', lang),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 15,
                              ),
                              children: [
                                TextSpan(
                                  text: _channel == 'whatsapp' ? 'WhatsApp' : 'SMS',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isValidPhone ? null : _submit,
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
                                : Text(tr.get('next', lang)),
                          ),
                        ),
                      ],
                    ),
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
