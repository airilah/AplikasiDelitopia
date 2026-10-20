import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../services/auth_service.dart';
import '../utils/auth_flow_utils.dart';

class CompleteProfileView extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? returnTo;

  const CompleteProfileView({
    super.key,
    required this.phoneNumber,
    this.returnTo,
  });

  @override
  ConsumerState<CompleteProfileView> createState() =>
      _CompleteProfileViewState();
}

class _CompleteProfileViewState extends ConsumerState<CompleteProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdayController = TextEditingController();
  String? _gender;
  DateTime? _birthday;
  bool _isLoading = false;
  String? _message;

  String get _formattedBirthday {
    final birthday = _birthday;
    if (birthday == null) return '';
    return '${birthday.year.toString().padLeft(4, '0')}-'
        '${birthday.month.toString().padLeft(2, '0')}-'
        '${birthday.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final lang = ref.read(appLanguageProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 5, now.month, now.day),
      helpText: tr.get('choose_birthday', lang),
      cancelText: tr.get('cancel', lang),
      confirmText: tr.get('choose', lang),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDD2222),
              onPrimary: Colors.white,
              onSurface: Color(0xFF202124),
            ),
          ),
          child: child!);
      });

    if (picked == null) return;
    setState(() {
      _birthday = picked;
      _birthdayController.text = '${picked.day.toString().padLeft(2, '0')} '
          '${_monthLabels(lang)[picked.month - 1]} '
          '${picked.year}';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).completePhoneProfile(
            phoneNumber: widget.phoneNumber,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            gender: _gender!,
            birthday: _formattedBirthday);

      if (!mounted) return;
      refreshAuthScopedProviders(ref);

      final destination = widget.returnTo;
      context.go(
        destination != null && destination.isNotEmpty
            ? destination
            : AppRouter.navigation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<bool> _showExitConfirmation(BuildContext context, AppLanguage lang) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFDD2222)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang == AppLanguage.indonesia
                    ? 'Lengkapi Data Akun'
                    : 'Complete Your Profile',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          lang == AppLanguage.indonesia
              ? 'Tinggal 1 langkah lagi! Lengkapi nama dan tanggal lahir Anda agar dapat menikmati promo, voucher ulang tahun, dan kemudahan pemesanan.'
              : 'Just 1 step left! Complete your name and birthday to enjoy member promos, birthday rewards, and seamless ordering.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              lang == AppLanguage.indonesia ? 'Nanti Saja' : 'Later',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              lang == AppLanguage.indonesia ? 'Lengkapi Sekarang' : 'Complete Now',
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showExitConfirmation(context, lang);
        if (shouldLeave && context.mounted) {
          final destination = widget.returnTo;
          context.go(
            destination != null && destination.isNotEmpty
                ? destination
                : AppRouter.navigation,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF202124),
          centerTitle: true,
          title: Text(tr.get('complete_profile_title', lang)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldLeave = await _showExitConfirmation(context, lang);
              if (shouldLeave && context.mounted) {
                final destination = widget.returnTo;
                context.go(
                  destination != null && destination.isNotEmpty
                      ? destination
                      : AppRouter.navigation,
                );
              }
            },
          ),
        ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            children: [
              Text(
                tr.get('customer_data', lang),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr
                    .get('phone_verified_profile_message', lang)
                    .replaceAll('{phone}', widget.phoneNumber),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              _TextFieldShell(
                child: TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr.get('full_name', lang),
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return tr.get('full_name_required', lang);
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              _TextFieldShell(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: tr.get('email', lang),
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    final valid =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                    if (!valid) return tr.get('email_invalid', lang);
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              _TextFieldShell(
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: InputDecoration(
                    labelText: tr.get('gender', lang),
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.transgender_outlined, color: Colors.grey.shade400),
                    border: InputBorder.none,
                  ),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
                  items: [
                    DropdownMenuItem(value: 'M', child: Text(tr.get('male', lang))),
                    DropdownMenuItem(value: 'F', child: Text(tr.get('female', lang))),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr.get('gender_required', lang);
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              _TextFieldShell(
                child: TextFormField(
                  controller: _birthdayController,
                  readOnly: true,
                  onTap: _pickBirthday,
                  decoration: InputDecoration(
                    labelText: tr.get('birthday', lang),
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.cake_outlined, color: Colors.grey.shade400),
                    suffixIcon: Icon(Icons.calendar_month_rounded, size: 20, color: Colors.grey.shade500),
                    border: InputBorder.none,
                  ),
                  validator: (_) {
                    if (_birthday == null) {
                      return tr.get('birthday_required', lang);
                    }
                    return null;
                  },
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 28),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE52B2B), Color(0xFFC31C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0.5,
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
                      : Text(tr.get('save_and_continue', lang)),
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

class _TextFieldShell extends StatelessWidget {
  final Widget child;

  const _TextFieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

List<String> _monthLabels(AppLanguage lang) {
  if (lang == AppLanguage.english) {
    return const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
  }

  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
}
