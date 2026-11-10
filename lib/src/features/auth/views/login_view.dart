import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/helpers.dart';
import '../services/auth_service.dart';
import '../utils/auth_flow_utils.dart';
import '../widgets/google_phone_link_sheet.dart';

class LoginView extends ConsumerStatefulWidget {
  final String? returnTo;

  const LoginView({super.key, this.returnTo});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordStep = false;
  bool _obscurePassword = true;
  // ignore: unused_field
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleNextStep() {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (email.isEmpty) {
      Helpers.showError(
        context,
        tr.get('email_required', ref.read(appLanguageProvider)),
      );
      return;
    }
    if (!valid) {
      Helpers.showError(
        context,
        tr.get('email_invalid', ref.read(appLanguageProvider)),
      );
      return;
    }
    setState(() {
      _isPasswordStep = true;
      _errorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _passwordFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authServiceProvider).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;

      refreshAuthScopedProviders(ref);
      _navigateAfterLogin();
    } on AccountPendingDeletionException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showRestoreAccountDialog(e);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
      });
      Helpers.showError(context, errorMsg);
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
                            email: _emailController.text.trim(),
                          );
                      if (!mounted) return;
                      refreshAuthScopedProviders(ref);
                      Helpers.showSnackbar(
                        context,
                        isIndo
                            ? 'Akun Anda berhasil dipulihkan. Selamat datang kembali!'
                            : 'Your account has been successfully restored. Welcome back!',
                      );
                      _navigateAfterLogin();
                    } catch (err) {
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      Helpers.showError(
                        context,
                        err.toString().replaceAll('Exception: ', '').trim(),
                      );
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;

      refreshAuthScopedProviders(ref);
      _navigateAfterLogin();
    } on GoogleRequiresPhoneLinkException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      GooglePhoneLinkSheet.show(
        context,
        googleData: e.data,
        onSuccess: (user) {
          refreshAuthScopedProviders(ref);
          _navigateAfterLogin();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _friendlyGoogleError(e);
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      if (errorMsg != null && errorMsg.isNotEmpty) {
        Helpers.showError(context, errorMsg);
      }
    }
  }

  String? _friendlyGoogleError(Object error) {
    final message = error.toString().replaceAll('Exception: ', '');
    if (message.contains('dibatalkan') ||
        message.contains('canceled') ||
        message.contains('cancelled') ||
        message.contains('sign_in_canceled')) {
      return null;
    }
    if (message.contains('belum terdaftar') ||
        message.contains('Nomor Ponsel')) {
      return message;
    }
    if (message.contains('ApiException: 10') ||
        message.contains('sign_in_failed') ||
        message.contains('ApiException:')) {
      return tr.get('google_login_not_ready', ref.read(appLanguageProvider));
    }
    return message;
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithApple();
      if (!mounted) return;

      refreshAuthScopedProviders(ref);
      _navigateAfterLogin();
    } on GoogleRequiresPhoneLinkException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      GooglePhoneLinkSheet.show(
        context,
        googleData: e.data,
        onSuccess: (user) {
          refreshAuthScopedProviders(ref);
          _navigateAfterLogin();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      Helpers.showError(context, errorMsg);
    }
  }

  void _navigateAfterLogin() {
    final destination = widget.returnTo;
    context.go(
      destination != null && destination.isNotEmpty
          ? destination
          : AppRouter.navigation,
    );
  }

  void _goToPhoneLogin() {
    context.go(
      '${AppRouter.phoneAuth}?mode=login'
      '${_returnToQuery()}',
    );
  }

  void _goToRegister() {
    context.go(
      '${AppRouter.register}'
      '${_returnToQuery(prefix: '?')}',
    );
  }

  String _returnToQuery({String prefix = '&'}) {
    final returnTo = widget.returnTo;
    if (returnTo == null || returnTo.isEmpty) return '';
    return '${prefix}returnTo=${Uri.encodeComponent(returnTo)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return PopScope(
      canPop: !_isPasswordStep,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isPasswordStep) {
          setState(() {
            _isPasswordStep = false;
            _errorMessage = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).top -
                    MediaQuery.paddingOf(context).bottom -
                    44,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        if (_isPasswordStep) {
                          setState(() {
                            _isPasswordStep = false;
                            _errorMessage = null;
                          });
                        } else {
                          context.go(AppRouter.navigation);
                        }
                      },
                      icon: Icon(_isPasswordStep ? Icons.arrow_back : Icons.close),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDD2222),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr.get('login_title', lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr.get('login_subtitle', lang),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildForm(lang),
                  const SizedBox(height: 28),
                  _buildDivider(lang),
                  const SizedBox(height: 20),
                  _buildQuickLoginOptions(lang),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr.get('dont_have_account', lang),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _goToRegister,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          tr.get('register', lang),
                          style: const TextStyle(
                            color: Color(0xFFDD2222),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppLanguage lang) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            readOnly: _isPasswordStep,
            keyboardType: TextInputType.emailAddress,
            textInputAction: _isPasswordStep ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) =>
                _isPasswordStep ? _passwordFocusNode.requestFocus() : _handleNextStep(),
            decoration: _inputDecoration(
              hint: 'Email',
              icon: Icons.email_outlined,
              suffix: _isPasswordStep
                  ? TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isPasswordStep = false;
                              });
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        lang == AppLanguage.indonesia ? 'Ubah' : 'Change',
                        style: const TextStyle(
                          color: Color(0xFFDD2222),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
              if (email.isEmpty) return tr.get('email_required', lang);
              if (!valid) return tr.get('email_invalid', lang);
              return null;
            },
          ),
          if (_isPasswordStep) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _isLoading ? null : _handleEmailLogin(),
              decoration: _inputDecoration(
                hint: 'Password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return tr.get('password_required', lang);
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : () => context.go(AppRouter.forgotPassword),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  tr.get('forgot_password', lang),
                  style: const TextStyle(
                    color: Color(0xFFDD2222),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!_isPasswordStep)
            _AuthButton(
              label: tr.get('continue', lang, fallback: 'Lanjut'),
              onPressed: _isLoading ? null : _handleNextStep,
              filled: true,
            )
          else
            _AuthButton(
              icon: Icons.login_rounded,
              label: tr.get('login', lang),
              onPressed: _isLoading ? null : _handleEmailLogin,
              filled: true,
              loading: _isLoading,
            ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppLanguage lang) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            tr.get('or_login_with', lang, fallback: 'atau masuk dengan'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }

  Widget _buildQuickLoginOptions(AppLanguage lang) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SocialQuickButton(
                iconWidget: Image.asset(
                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => const FaIcon(
                    FontAwesomeIcons.google,
                    color: Color(0xFFEA4335),
                    size: 18,
                  ),
                ),
                label: 'Google',
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                loading: _isLoading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialQuickButton(
                iconWidget: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
                label: 'WhatsApp',
                onPressed: _isLoading ? null : _goToPhoneLogin,
              ),
            ),
          ],
        ),
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) ...[
          const SizedBox(height: 12),
          _SocialQuickButton(
            iconWidget: const Icon(Icons.apple, size: 22, color: Colors.black),
            label: 'Apple',
            onPressed: _isLoading ? null : _handleAppleSignIn,
            loading: _isLoading,
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDD2222), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDD2222), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDD2222), width: 1.4),
      ),
    );
  }
}

class _SocialQuickButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _SocialQuickButton({
    required this.iconWidget,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF202124),
          backgroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: Colors.grey.shade300, width: 1.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDD2222)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool loading;

  const _AuthButton({
    this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, size: 22),
              if (icon != null) const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD2222),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF202124),
          backgroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: child,
      ),
    );
  }
}
