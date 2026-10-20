import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../auth/services/auth_service.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/models/user_model.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import 'change_password_view.dart';

class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _selectedBirthday;
  String? _selectedGender;
  bool _isLoading = false;
  AppLanguage get _lang => ref.read(appLanguageProvider);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userAsync = ref.read(currentUserProvider);
    userAsync.whenData((user) {
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email;
          _phoneController.text = _displayPhoneNumber(user);
          if (user.gender != null && user.gender!.trim().isNotEmpty) {
            final g = user.gender!.trim().toUpperCase();
            if (g == 'L' || g == 'M' || g == 'LAKI-LAKI' || g == 'MALE') {
              _selectedGender = 'L';
            } else if (g == 'P' || g == 'F' || g == 'PEREMPUAN' || g == 'FEMALE') {
              _selectedGender = 'P';
            }
          }
          if (user.birthday != null && user.birthday!.trim().isNotEmpty) {
            try {
              final raw = user.birthday!.trim();
              DateTime parsed;
              if (raw.contains('T')) {
                // ISO timestamp with potential UTC offset -> convert to local time
                parsed = DateTime.parse(raw).toLocal();
              } else if (raw.contains('-')) {
                final parts = raw.split(' ')[0].split('-');
                if (parts.length == 3) {
                  parsed = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                } else {
                  parsed = DateTime.parse(raw);
                }
              } else {
                parsed = DateTime.parse(raw);
              }
              _selectedBirthday = parsed;
              _birthdayController.text = _formatBirthdayDisplay(parsed);
            } catch (_) {
              _birthdayController.text = user.birthday!.trim();
            }
          }
        });
      }
    });
  }

  String _formatBirthdayDisplay(DateTime date) {
    const monthsId = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final mList = _lang == AppLanguage.indonesia ? monthsId : monthsEn;
    return '${date.day} ${mList[date.month - 1]} ${date.year}';
  }

  Future<void> _pickBirthday(BuildContext context) async {
    final now = DateTime.now();
    final initial = _selectedBirthday ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime(now.year - 5)) ? DateTime(now.year - 20) : initial,
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 5, now.month, now.day),
      helpText: _lang == AppLanguage.indonesia ? 'PILIH TANGGAL LAHIR' : 'SELECT DATE OF BIRTH',
      cancelText: _lang == AppLanguage.indonesia ? 'BATAL' : 'CANCEL',
      confirmText: _lang == AppLanguage.indonesia ? 'PILIH' : 'SELECT',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDD2222),
              onPrimary: Colors.white,
              onSurface: Color(0xFF202124),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = _formatBirthdayDisplay(picked);
      });
    }
  }

  String _displayPhoneNumber(User user) {
    final phone = user.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) return '';
    return _maskVerifiedPhoneNumber(phone);
  }

  String _maskVerifiedPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;

    final localNumber = digits.startsWith('62')
        ? '0${digits.substring(2)}'
        : (digits.startsWith('0') ? digits : '0$digits');

    if (localNumber.length <= 7) return localNumber;

    const visibleStart = 4;
    const visibleEnd = 3;
    final maskCount = localNumber.length - (visibleStart + visibleEnd);
    final stars = '*' * (maskCount > 0 ? maskCount : 4);
    return '${localNumber.substring(0, visibleStart)}$stars${localNumber.substring(localNumber.length - visibleEnd)}';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      String? birthdayToSend;
      if (_selectedBirthday != null) {
        birthdayToSend = '${_selectedBirthday!.year.toString().padLeft(4, '0')}-'
            '${_selectedBirthday!.month.toString().padLeft(2, '0')}-'
            '${_selectedBirthday!.day.toString().padLeft(2, '0')}';
      }

      await authService.updateProfile(
        userId: user.id,
        name: _nameController.text.trim(),
        gender: _selectedGender,
        birthday: birthdayToSend,
      );

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        Helpers.showSnackbar(context, tr.get('profile_updated_success', _lang), backgroundColor: Colors.green);
        BackButtonWrapper.handleBack(context, backRoute: '/navigation?index=4');
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

  Widget _buildEmailStatusBadge(User user) {
    if (user.emailVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 4),
          Text(
            _lang == AppLanguage.indonesia ? 'Verifikasi' : 'Verify',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSuffix(User user) {
    if (user.emailVerified) {
      return const Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
      );
    }
    return const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22);
  }

  Widget _buildPhoneStatusBadge(User user) {
    final hasPhone = user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty;
    if (!hasPhone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              _lang == AppLanguage.indonesia ? 'Tambah' : 'Add',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (user.phoneVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 4),
          Text(
            _lang == AppLanguage.indonesia ? 'Verifikasi' : 'Verify',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSuffix(User user) {
    final hasPhone = user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty;
    if (hasPhone && user.phoneVerified) {
      return const Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
      );
    }
    return const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(lang == AppLanguage.indonesia ? 'EDIT PROFIL' : 'EDIT PROFILE'),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: userAsync.when(
          data: (user) {
            if (user == null) {
              return Center(
                child: Text(tr.get('user_not_found_relogin', lang)),
              );
            }

            // Sync controller values
            if (_nameController.text.isEmpty && user.name.isNotEmpty) {
              _nameController.text = user.name;
            }
            _emailController.text = user.email;
            _phoneController.text = _displayPhoneNumber(user);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 1. Full Name Field (Editable)
                  Text(
                    lang == AppLanguage.indonesia ? 'Nama Lengkap' : 'Full Name',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4D4D4D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: lang == AppLanguage.indonesia ? 'Masukkan nama lengkap Anda' : 'Enter your full name',
                      prefixIcon:
                          const Icon(Icons.person_outline, size: 20),
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
                        return lang == AppLanguage.indonesia ? 'Silakan masukkan nama Anda' : 'Please enter your name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 2. Gender Field (Editable anytime)
                  Text(
                    lang == AppLanguage.indonesia ? 'Jenis Kelamin' : 'Gender',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4D4D4D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Laki-laki
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGender = 'L';
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _selectedGender == 'L'
                                  ? const Color(0xFFFFF1F1)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedGender == 'L'
                                    ? const Color(0xFFDD2222)
                                    : Colors.grey.shade300,
                                width: _selectedGender == 'L' ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.male_rounded,
                                  size: 20,
                                  color: _selectedGender == 'L'
                                      ? const Color(0xFFDD2222)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang == AppLanguage.indonesia
                                      ? 'Laki-laki'
                                      : 'Male',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: _selectedGender == 'L'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedGender == 'L'
                                        ? const Color(0xFFDD2222)
                                        : const Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Perempuan
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGender = 'P';
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _selectedGender == 'P'
                                  ? const Color(0xFFFFF1F1)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedGender == 'P'
                                    ? const Color(0xFFDD2222)
                                    : Colors.grey.shade300,
                                width: _selectedGender == 'P' ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.female_rounded,
                                  size: 20,
                                  color: _selectedGender == 'P'
                                      ? const Color(0xFFDD2222)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang == AppLanguage.indonesia
                                      ? 'Perempuan'
                                      : 'Female',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: _selectedGender == 'P'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedGender == 'P'
                                        ? const Color(0xFFDD2222)
                                        : const Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3. Tanggal Lahir Field
                  Text(
                    lang == AppLanguage.indonesia ? 'Tanggal Lahir' : 'Date of Birth',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4D4D4D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: (user.birthday != null && user.birthday!.trim().isNotEmpty)
                        ? () {
                            Helpers.showSnackbar(
                              context,
                              lang == AppLanguage.indonesia
                                  ? 'Tanggal lahir tidak bisa diubah. Salah? Silakan hubungi customer service.'
                                  : 'Date of birth cannot be changed. Need help? Please contact customer service.',
                              backgroundColor: const Color(0xFF333333),
                            );
                          }
                        : () => _pickBirthday(context),
                    child: AbsorbPointer(
                      absorbing: true,
                      child: TextFormField(
                        controller: _birthdayController,
                        readOnly: true,
                        style: const TextStyle(
                          color: Color(0xFF202124),
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: lang == AppLanguage.indonesia ? 'Pilih tanggal lahir Anda' : 'Select your date of birth',
                          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                          suffixIcon: (user.birthday != null && user.birthday!.trim().isNotEmpty)
                              ? const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                )
                              : const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
                          filled: true,
                          fillColor: (user.birthday != null && user.birthday!.trim().isNotEmpty)
                              ? const Color(0xFFF2F4F7)
                              : const Color(0xFFF8F9FA),
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
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Email Field (Disabled / Read-only with Suffix Status)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4D4D4D),
                        ),
                      ),
                      _buildEmailStatusBadge(user),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: user.emailVerified
                        ? null
                        : () {
                            context.push(AppRouter.emailVerification);
                          },
                    child: AbsorbPointer(
                      absorbing: true,
                      child: TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        style: const TextStyle(
                          color: Color(0xFF202124),
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: lang == AppLanguage.indonesia ? 'Alamat Email' : 'Email address',
                          prefixIcon:
                              const Icon(Icons.email_outlined, size: 20),
                          suffixIcon: _buildEmailSuffix(user),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F7),
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
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Password Field (Row 4, before Phone Number)
                  Text(
                    'Password',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4D4D4D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordView(),
                        ),
                      );
                    },
                    child: AbsorbPointer(
                      absorbing: true,
                      child: TextFormField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: user.hasPassword
                              ? '••••••••••••'
                              : (lang == AppLanguage.indonesia ? 'Belum dibuat' : 'Not set'),
                        ),
                        style: TextStyle(
                          color: user.hasPassword ? const Color(0xFF202124) : Colors.grey.shade600,
                          letterSpacing: user.hasPassword ? 3.0 : 0,
                          fontWeight: user.hasPassword ? FontWeight.bold : FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F7),
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
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Phone Field (Disabled / Read-only with Suffix Status)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang == AppLanguage.indonesia ? 'Nomor Telepon' : 'Phone Number',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4D4D4D),
                        ),
                      ),
                      _buildPhoneStatusBadge(user),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: user.phoneVerified
                        ? null
                        : () {
                            context.push('/add-phone-number');
                          },
                    child: AbsorbPointer(
                      absorbing: true,
                      child: TextFormField(
                        controller: _phoneController,
                        readOnly: true,
                        style: const TextStyle(
                          color: Color(0xFF202124),
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: lang == AppLanguage.indonesia ? 'Nomor telepon' : 'Phone number',
                          prefixIcon:
                              const Icon(Icons.phone_outlined, size: 20),
                          suffixIcon: _buildPhoneSuffix(user),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F7),
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
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              lang == AppLanguage.indonesia ? 'Simpan Perubahan' : 'Save Changes',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFDD2222)),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('${tr.get('something_went_wrong', ref.read(appLanguageProvider))}: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(currentUserProvider);
                  },
                  child: Text(tr.get('retry', ref.read(appLanguageProvider))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
