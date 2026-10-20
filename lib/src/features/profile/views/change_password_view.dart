import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../auth/services/auth_service.dart';
import '../../../shared/services/service_providers.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key});

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool get _hasPassword =>
      ref.read(currentUserProvider).valueOrNull?.hasPassword ?? true;
  AppLanguage get _lang => ref.read(appLanguageProvider);

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      if (mounted) {
        Helpers.showSnackbar(context, tr.get('user_not_found_relogin', _lang), backgroundColor: Colors.red);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.setPassword(
        currentPassword: _hasPassword ? _oldPasswordController.text : null,
        password: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text);

      if (mounted) {
        ref.invalidate(currentUserProvider);
        Helpers.showSnackbar(context, _hasPassword
                ? (_lang == AppLanguage.indonesia ? 'Password berhasil diubah' : 'Password changed successfully')
                : (_lang == AppLanguage.indonesia ? 'Password berhasil dibuat' : 'Password created successfully'), backgroundColor: Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackbar(
          context,
          '${tr.get('something_went_wrong', _lang)}: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    return BackButtonWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/settings',
            color: Colors.white,
          ),
          title: Text(lang == AppLanguage.indonesia ? 'UBAH PASSWORD' : 'CHANGE PASSWORD'),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Old Password
                if (_hasPassword) ...[
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOldPassword,
                    decoration: InputDecoration(
                      labelText: lang == AppLanguage.indonesia ? 'Password Saat Ini' : 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOldPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscureOldPassword = !_obscureOldPassword);
                        },
                      ),
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
                      if (value == null || value.isEmpty) {
                        return lang == AppLanguage.indonesia ? 'Silakan masukkan password saat ini' : 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: lang == AppLanguage.indonesia ? 'Password Baru' : 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscureNewPassword = !_obscureNewPassword);
                      },
                    ),
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
                    if (value == null || value.isEmpty) {
                      return lang == AppLanguage.indonesia ? 'Silakan masukkan password baru' : 'Please enter a new password';
                    }
                    if (value.length < 8) {
                      return lang == AppLanguage.indonesia ? 'Password minimal harus 8 karakter' : 'Password must be at least 8 characters';
                    }
                    if (_hasPassword && value == _oldPasswordController.text) {
                      return lang == AppLanguage.indonesia ? 'Password baru harus berbeda dengan password lama' : 'New password must be different from old password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: lang == AppLanguage.indonesia ? 'Konfirmasi Password Baru' : 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
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
                    if (value == null || value.isEmpty) {
                      return lang == AppLanguage.indonesia ? 'Silakan konfirmasi password baru Anda' : 'Please confirm your new password';
                    }
                    if (value != _newPasswordController.text) {
                      return lang == AppLanguage.indonesia ? 'Password tidak cocok' : 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Requirement Info Text (Plain text with smaller font)
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lang == AppLanguage.indonesia
                            ? 'Password minimal harus terdiri dari 8 karakter'
                            : 'Password must be at least 8 characters long',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          lang == AppLanguage.indonesia ? 'Simpan Password' : 'Save Password',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ));
  }
}
