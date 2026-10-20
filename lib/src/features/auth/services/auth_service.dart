import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/user_model.dart';

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthService(apiClient, storageService);
});

enum PhoneAuthMode { login, register }

class PhoneAuthStartResult {
  final String phoneNumber;
  final bool otpSent;
  final bool? isRegistered;
  final String message;

  const PhoneAuthStartResult({
    required this.phoneNumber,
    required this.otpSent,
    required this.message,
    this.isRegistered,
  });
}

class PhoneAuthVerifyResult {
  final String phoneNumber;
  final bool authenticated;
  final bool requiresProfile;
  final String message;

  const PhoneAuthVerifyResult({
    required this.phoneNumber,
    required this.authenticated,
    required this.requiresProfile,
    required this.message,
  });
}

class GoogleLinkPendingData {
  final String email;
  final String name;
  final String? googleId;
  final String? photo;

  const GoogleLinkPendingData({
    required this.email,
    required this.name,
    this.googleId,
    this.photo,
  });
}

class GoogleRequiresPhoneLinkException implements Exception {
  final GoogleLinkPendingData data;
  final String message;

  GoogleRequiresPhoneLinkException({required this.data, required this.message});

  @override
  String toString() => message;
}

class AccountPendingDeletionException implements Exception {
  final int? userId;
  final int? daysRemaining;
  final String? deletionEffectiveAt;
  final String message;

  AccountPendingDeletionException({
    this.userId,
    this.daysRemaining,
    this.deletionEffectiveAt,
    required this.message,
  });

  @override
  String toString() => message;
}

class AuthService {
  final ApiClient _apiClient;
  final StorageService _storageService;
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthService(this._apiClient, this._storageService);

  Future<Map<String, dynamic>> _postWithFallback(
    String path, {
    required Map<String, dynamic> data,
    String? fallbackPath,
  }) async {
    try {
      return await _apiClient.post(path, data: data);
    } catch (e) {
      final message = e.toString().toLowerCase();
      final statusCode = e is ApiException ? e.statusCode : null;
      final canFallback = fallbackPath != null &&
          (statusCode == 404 ||
              statusCode == 500 ||
              statusCode == 502 ||
              statusCode == 503 ||
              statusCode == 504 ||
              message.contains('route') ||
              message.contains('not found') ||
              message.contains('404') ||
              message.contains('500') ||
              message.contains('server error') ||
              message.contains('internal server error') ||
              message.contains('bad gateway'));
      if (!canFallback) rethrow;

      return _apiClient.post(fallbackPath, data: data);
    }
  }

  String? _normalizeIndonesianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    var local = digits;
    if (local.startsWith('62')) {
      local = local.substring(2);
    }
    if (local.startsWith('0')) {
      local = local.substring(1);
    }
    if (!local.startsWith('8')) return null;
    if (local.length < 9 || local.length > 13) return null;
    return '62$local';
  }

  Future<PhoneAuthStartResult> requestPhoneOtp({
    required String phoneNumber,
    required PhoneAuthMode mode,
    String channel = 'whatsapp',
  }) async {
    final normalizedPhone = _normalizeIndonesianPhone(phoneNumber);
    if (normalizedPhone == null) {
      throw Exception('Nomor ponsel tidak valid.');
    }

    final response = await _postWithFallback(ApiConstants.requestPhoneOtp,
        data: {
          'phone_number': normalizedPhone,
          'channel': channel,
          'purpose': mode.name,
        },
        fallbackPath: ApiConstants.legacyRequestPhoneOtp);

    if (!_isSuccessResponse(response)) {
      throw Exception(response['message'] ?? 'Gagal mengirim kode OTP.');
    }

    final data = response['data'];
    final registered = data is Map<String, dynamic>
        ? data['is_registered'] ?? data['registered']
        : null;
    final serverPhone =
        data is Map<String, dynamic> ? data['phone_number']?.toString() : null;

    return PhoneAuthStartResult(
        phoneNumber:
            serverPhone?.isNotEmpty == true ? serverPhone! : normalizedPhone,
        otpSent: true,
        isRegistered: registered is bool
            ? registered
            : registered == null
                ? null
                : registered.toString() == '1' ||
                    registered.toString().toLowerCase() == 'true',
        message: response['message']?.toString() ??
            'Kode verifikasi sudah dikirim melalui ${channel == 'whatsapp' ? 'WhatsApp' : 'SMS'}.');
  }

  Future<PhoneAuthVerifyResult> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
    required PhoneAuthMode mode,
  }) async {
    final normalizedPhone = _normalizeIndonesianPhone(phoneNumber);
    if (normalizedPhone == null) {
      throw Exception('Nomor ponsel tidak valid.');
    }

    try {
      final response = await _postWithFallback(ApiConstants.verifyOtp,
          data: {
            'phone_number': normalizedPhone,
            'otp': otp,
            'purpose': mode.name,
          },
          fallbackPath: ApiConstants.legacyVerifyOtp);

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Kode verifikasi salah.');
      }

      final data = response['data'];
      final token = _extractToken(data) ?? response['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _storageService.saveAuthToken(token);

        final user = await _extractOrFetchUser(data);
        if (user != null) {
          await _storageService.saveUserId(user.id);
        }

        return PhoneAuthVerifyResult(
            phoneNumber: normalizedPhone,
            authenticated: true,
            requiresProfile: _requiresProfile(data, user),
            message: response['message']?.toString() ?? 'Berhasil masuk.');
      }

      return PhoneAuthVerifyResult(
          phoneNumber: normalizedPhone,
          authenticated: false,
          requiresProfile: mode == PhoneAuthMode.register ||
              (data is Map<String, dynamic> &&
                  (data['requires_profile'] == true ||
                      data['profile_required'] == true)),
          message: response['message']?.toString() ??
              'Nomor berhasil diverifikasi. Lengkapi profil untuk melanjutkan.');
    } on ApiException catch (e) {
      if (e.statusCode == 403 &&
          (e.data?['status'] == 'account_pending_deletion' ||
              e.data?['code'] == 'account_pending_deletion')) {
        final data = e.data?['data'] as Map<String, dynamic>?;
        throw AccountPendingDeletionException(
          userId: data?['user_id'] is int
              ? data!['user_id']
              : int.tryParse(data?['user_id']?.toString() ?? ''),
          daysRemaining: data?['days_remaining'] is int
              ? data!['days_remaining']
              : int.tryParse(data?['days_remaining']?.toString() ?? ''),
          deletionEffectiveAt: data?['deletion_effective_at']?.toString(),
          message: e.data?['message']?.toString() ?? e.message,
        );
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is AccountPendingDeletionException) rethrow;
      throw Exception('Kode verifikasi salah atau sudah kedaluwarsa.');
    }
  }

  Future<User> completePhoneProfile({
    required String phoneNumber,
    required String name,
    required String email,
    required String gender,
    required String birthday,
  }) async {
    try {
      final response =
          await _apiClient.post(ApiConstants.completePhoneProfile, data: {
        'phone_number': phoneNumber,
        'name': name,
        'email': email,
        'gender': _mapGenderForBackend(gender),
        'birthday': birthday,
      });

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Gagal menyimpan profil.');
      }

      final data = response['data'];
      final token = _extractToken(data) ?? response['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _storageService.saveAuthToken(token);
      }

      final user = await _extractOrFetchUser(data);
      if (user == null) {
        throw Exception('Profil tersimpan, tetapi data user tidak ditemukan.');
      }

      await _storageService.saveUserId(user.id);
      return user;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Gagal melengkapi profil: $e');
    }
  }

  Future<void> sendEmailVerificationOtp() async {
    try {
      final response =
          await _apiClient.post(ApiConstants.sendEmailVerification);

      if (!_isSuccessResponse(response)) {
        throw Exception(
            response['message'] ?? 'Gagal mengirim kode verifikasi email.');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<User> verifyEmailOtp(String otp) async {
    try {
      final response =
          await _apiClient.post(ApiConstants.verifyEmail, data: {'otp': otp});

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Kode verifikasi email salah.');
      }

      final user = await _extractOrFetchUser(response['data']);
      if (user == null) {
        throw Exception(
            'Email terverifikasi, tetapi data user tidak ditemukan.');
      }

      await _storageService.saveUserId(user.id);
      return user;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<String> requestProfilePhoneOtp({
    required String phoneNumber,
    String channel = 'whatsapp',
  }) async {
    final normalizedPhone = _normalizeIndonesianPhone(phoneNumber);
    if (normalizedPhone == null) {
      throw Exception('Nomor ponsel tidak valid.');
    }

    final response =
        await _apiClient.post(ApiConstants.requestProfilePhoneOtp, data: {
      'phone_number': normalizedPhone,
      'channel': channel,
    });

    if (!_isSuccessResponse(response)) {
      throw Exception(response['message'] ?? 'Gagal mengirim kode OTP.');
    }

    final data = response['data'];
    final serverPhone =
        data is Map<String, dynamic> ? data['phone_number']?.toString() : null;
    return serverPhone?.isNotEmpty == true ? serverPhone! : normalizedPhone;
  }

  Future<User> verifyProfilePhone({
    required String phoneNumber,
    required String otp,
  }) async {
    final normalizedPhone = _normalizeIndonesianPhone(phoneNumber);
    if (normalizedPhone == null) {
      throw Exception('Nomor ponsel tidak valid.');
    }

    try {
      final response =
          await _apiClient.post(ApiConstants.verifyProfilePhone, data: {
        'phone_number': normalizedPhone,
        'otp': otp,
      });

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Kode verifikasi salah.');
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return User.fromJson(data);
      }

      final user = await getCurrentUserWithPoints();
      if (user == null) {
        throw Exception(
            'Nomor terverifikasi, tetapi data user tidak ditemukan.');
      }
      return user;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> setPassword({
    String? currentPassword,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiClient.post(ApiConstants.setPassword, data: {
        if (currentPassword != null && currentPassword.isNotEmpty)
          'current_password': currentPassword,
        'password': password,
        'password_confirmation': confirmPassword,
      });

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Gagal menyimpan password.');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  String? _extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    return data['access_token']?.toString() ??
        data['token']?.toString() ??
        (data['auth'] is Map<String, dynamic>
            ? (data['auth'] as Map<String, dynamic>)['access_token']?.toString()
            : null);
  }

  bool _isSuccessResponse(Map<String, dynamic> response) {
    return response['status'] == 'success' || response['success'] == true;
  }

  Future<User?> _extractOrFetchUser(dynamic data) async {
    if (data is Map<String, dynamic>) {
      final userData = data['user'];
      if (userData is Map<String, dynamic>) {
        return User.fromJson(userData);
      }
      if (data['id'] != null) {
        return User.fromJson(data);
      }
    }
    return getCurrentUserWithPoints();
  }

  bool _requiresProfile(dynamic data, User? user) {
    if (data is Map<String, dynamic> &&
        (data['requires_profile'] == true ||
            data['profile_required'] == true)) {
      return true;
    }
    if (user == null) return false;
    return user.name.trim().isEmpty ||
        user.email.trim().isEmpty ||
        user.email.contains('@phone.local');
  }

  String _mapGenderForBackend(String gender) {
    if (gender == 'M') return 'L';
    if (gender == 'F') return 'P';
    return gender;
  }

  // Login with email/password
  Future<User> login(String email, String password) async {
    try {
      final response = await _postWithFallback(ApiConstants.login,
          data: {
            'email': email,
            'password': password,
          },
          fallbackPath: ApiConstants.legacyLogin);

      if (_isSuccessResponse(response)) {
        final data = response['data'];
        final token =
            _extractToken(data) ?? response['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Token login tidak ditemukan.');
        }
        await _storageService.saveAuthToken(token);

        final user = await _extractOrFetchUser(data);
        if (user == null) {
          throw Exception('Gagal memuat data user.');
        }

        await _storageService.saveUserId(user.id);
        return user;
      }

      throw Exception(response['message'] ?? 'Email atau password salah.');
    } on ApiException catch (e) {
      if (e.statusCode == 403 &&
          (e.data?['status'] == 'account_pending_deletion' ||
              e.data?['code'] == 'account_pending_deletion')) {
        final data = e.data?['data'] as Map<String, dynamic>?;
        throw AccountPendingDeletionException(
          userId: data?['user_id'] is int
              ? data!['user_id']
              : int.tryParse(data?['user_id']?.toString() ?? ''),
          daysRemaining: data?['days_remaining'] is int
              ? data!['days_remaining']
              : int.tryParse(data?['days_remaining']?.toString() ?? ''),
          deletionEffectiveAt: data?['deletion_effective_at']?.toString(),
          message: e.data?['message']?.toString() ?? e.message,
        );
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is AccountPendingDeletionException) rethrow;
      final message = e.toString().replaceAll('Exception: ', '').trim();
      if (message.isNotEmpty &&
          !message.toLowerCase().contains('gagal masuk')) {
        throw Exception(message);
      }
      throw Exception('Gagal masuk. Periksa email dan password kamu.');
    }
  }

  // Register new user
  Future<void> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String birthday,
    String? gender,
  }) async {
    try {
      final response = await _apiClient.post(ApiConstants.register, data: {
        'name': name,
        'email': email,
        'phone_number': phoneNumber,
        'password': password,
        'birthday': birthday,
        if (gender != null) 'gender': gender,
      });

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Forgot password - send OTP
  Future<bool> forgotPassword(String email) async {
    try {
      final response =
          await _apiClient.post('/password/forgot', data: {'email': email});

      return response['status'] == 'success';
    } catch (e) {
      throw Exception('Failed to send reset code: $e');
    }
  }

  // Verify OTP
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await _apiClient.post('/password/otp', data: {
        'email': email,
        'otp': int.parse(otp),
      });

      return response['status'] == 'success';
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  // Reset password
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiClient.post('/password/reset', data: {
        'email': email,
        'otp': int.parse(otp),
        'password': password,
        'password_confirmation': confirmPassword,
      });

      return response['status'] == 'success';
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Change password (for logged in users)
  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await setPassword(
          currentPassword: oldPassword,
          password: newPassword,
          confirmPassword: confirmPassword);
      return true;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Detach this device before revoking the session so old users no longer receive pushes.
      try {
        final userId = await _storageService.getUserId();
        if (userId != null) {
          await updateFcmToken(userId, '');
        }
      } catch (e) {
        debugPrint('FCM token cleanup error (ignored): $e');
      }

      // Call API logout
      try {
        await _apiClient.post('/auth/logout');
      } catch (e) {
        // Ignore API errors during logout
        debugPrint('Logout API error (ignored): $e');
      }

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Clear all local data
      await _storageService.clearAll();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // Google Sign-In
  Future<User> signInWithGoogle() async {
    // On Web, Google Sign-In requires the domain to be registered in Google Cloud Console.
    // Since this is a local development environment, we skip the popup flow on web.
    if (kIsWeb) {
      throw Exception(
          'Login Google tidak tersedia saat pengujian di browser lokal.\n\n'
          'Untuk menggunakan fitur ini, jalankan aplikasi di emulator Android atau perangkat fisik.\n\n'
          'Gunakan Email & Password untuk login di browser.');
    }

    GoogleSignInAccount? googleUser;
    try {
      // Trigger the Google Sign-In flow
      googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In dibatalkan');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      // Sign in to Firebase with the Google credential
      final firebase_auth.UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Get the Firebase ID token
      final idToken = await userCredential.user?.getIdToken();

      final payload = {
        'id_token': googleAuth.idToken ?? idToken,
        'email': googleUser.email,
        'name': googleUser.displayName ?? userCredential.user?.displayName,
        'google_id': googleUser.id,
        'photo': googleUser.photoUrl,
      };

      Map<String, dynamic> response;
      try {
        response =
            await _apiClient.post('/v2/auth/login/google', data: payload);
      } on ApiException catch (apiErr) {
        if (apiErr.data?['requires_phone_link'] == true ||
            apiErr.statusCode == 404 ||
            apiErr.message.contains('belum terdaftar')) {
          final pendingData = GoogleLinkPendingData(
            email: googleUser.email,
            name: googleUser.displayName ??
                userCredential.user?.displayName ??
                '',
            googleId: googleUser.id,
            photo: googleUser.photoUrl,
          );
          throw GoogleRequiresPhoneLinkException(
            data: pendingData,
            message: apiErr.message,
          );
        }
        rethrow;
      }

      if (_isSuccessResponse(response)) {
        // Save token
        final token = _extractToken(response['data']) ??
            response['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Token login Google tidak ditemukan.');
        }
        await _storageService.saveAuthToken(token);

        // Get user profile with points
        final user = await getCurrentUserWithPoints();
        if (user == null) {
          throw Exception('Failed to load user data');
        }

        await _storageService.saveUserId(user.id);
        return user;
      }

      if (response['requires_phone_link'] == true) {
        final pendingData = GoogleLinkPendingData(
          email: googleUser.email,
          name:
              googleUser.displayName ?? userCredential.user?.displayName ?? '',
          googleId: googleUser.id,
          photo: googleUser.photoUrl,
        );
        throw GoogleRequiresPhoneLinkException(
          data: pendingData,
          message: response['message'] ??
              'Nomor ponsel diperlukan untuk menautkan akun Google.',
        );
      }

      throw Exception(response['message'] ?? 'Google Sign-In failed');
    } on GoogleRequiresPhoneLinkException {
      rethrow;
    } catch (e) {
      if (googleUser != null) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      if (e is GoogleRequiresPhoneLinkException) {
        rethrow;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Apple Sign-In
  Future<User> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final email = appleCredential.email;
      final givenName = appleCredential.givenName ?? '';
      final familyName = appleCredential.familyName ?? '';
      final fullName = '$givenName $familyName'.trim();
      final displayName = fullName.isNotEmpty ? fullName : 'Apple User';
      final appleId = appleCredential.userIdentifier ?? '';

      // Try Firebase Auth link if configured
      try {
        final oauthProvider = firebase_auth.OAuthProvider('apple.com');
        final credential = oauthProvider.credential(
          idToken: appleCredential.identityToken,
          rawNonce: null,
        );
        await _firebaseAuth.signInWithCredential(credential);
      } catch (_) {}

      final payload = {
        'id_token': appleCredential.identityToken,
        'email': email,
        'name': displayName,
        'google_id': 'apple_$appleId',
      };

      Map<String, dynamic> response;
      try {
        response =
            await _apiClient.post('/v2/auth/login/google', data: payload);
      } on ApiException catch (apiErr) {
        if (apiErr.data?['requires_phone_link'] == true ||
            apiErr.statusCode == 404 ||
            apiErr.message.contains('belum terdaftar')) {
          final pendingData = GoogleLinkPendingData(
            email: email ?? '',
            name: displayName,
            googleId: 'apple_$appleId',
            photo: null,
          );
          throw GoogleRequiresPhoneLinkException(
            data: pendingData,
            message: apiErr.message,
          );
        }
        rethrow;
      }

      if (_isSuccessResponse(response)) {
        final token = _extractToken(response['data']) ??
            response['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Token login Apple tidak ditemukan.');
        }
        await _storageService.saveAuthToken(token);

        final user = await getCurrentUserWithPoints();
        if (user == null) {
          throw Exception('Gagal memuat profil pengguna.');
        }

        await _storageService.saveUserId(user.id);
        return user;
      }

      if (response['requires_phone_link'] == true) {
        final pendingData = GoogleLinkPendingData(
          email: email ?? '',
          name: displayName,
          googleId: 'apple_$appleId',
          photo: null,
        );
        throw GoogleRequiresPhoneLinkException(
          data: pendingData,
          message: response['message'] ??
              'Nomor ponsel diperlukan untuk menautkan akun Apple.',
        );
      }

      throw Exception(response['message'] ?? 'Apple Sign-In failed');
    } on GoogleRequiresPhoneLinkException {
      rethrow;
    } catch (e) {
      if (e is GoogleRequiresPhoneLinkException) {
        rethrow;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Link Google Account with Phone Number and OTP
  Future<User> linkGoogleWithPhoneOtp({
    required String phoneNumber,
    required String otp,
    required GoogleLinkPendingData googleData,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v2/auth/google/link-phone',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
          'email': googleData.email,
          'name': googleData.name,
          'google_id': googleData.googleId,
          'photo': googleData.photo,
        },
      );

      if (_isSuccessResponse(response)) {
        final token = _extractToken(response['data']) ??
            response['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Token login tidak ditemukan.');
        }
        await _storageService.saveAuthToken(token);

        final user = await getCurrentUserWithPoints();
        if (user == null) {
          throw Exception('Gagal memuat profil pengguna.');
        }

        await _storageService.saveUserId(user.id);
        return user;
      }

      throw Exception(response['message'] ?? 'Gagal menautkan akun Google.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Link Google Account for authenticated user
  Future<User> linkGoogleAccountForCurrentProfile({
    required String email,
    String? idToken,
    String? googleId,
    String? photo,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v2/users/google/link',
        data: {
          'email': email,
          'id_token': idToken,
          'google_id': googleId,
          'photo': photo,
        },
      );

      if (_isSuccessResponse(response)) {
        final user = await getCurrentUserWithPoints();
        if (user == null) {
          throw Exception('Gagal memuat profil pengguna.');
        }
        return user;
      }

      throw Exception(
          response['message'] ?? 'Gagal menghubungkan akun Google.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/v2/users/profile');

      if (_isSuccessResponse(response)) {
        return User.fromJson(response['data']);
      }

      return null;
    } catch (e) {
      try {
        final response = await _apiClient.get('/auth/me');
        if (_isSuccessResponse(response)) {
          return User.fromJson(response['data']);
        }
      } catch (_) {}
      return null;
    }
  }

  // Get current user with points - fetch from /auth/me and /getData/points separately
  Future<User?> getCurrentUserWithPoints() async {
    try {
      debugPrint('🔵 Getting user with points - fetching user data...');

      // Get user from /auth/me
      final userResponse = await _apiClient.get('/v2/users/profile');
      debugPrint('📦 User response: $userResponse');

      if (!_isSuccessResponse(userResponse)) {
        debugPrint('⚠️ Failed to get user data');
        return null;
      }

      final user = User.fromJson(userResponse['data']);
      debugPrint('✅ User loaded: ${user.name}');

      // Get points separately from /getData/points
      try {
        debugPrint('🔵 Fetching points balance...');
        final pointsResponse = await _apiClient.get('/getData/points');
        debugPrint('📦 Points response: $pointsResponse');

        if (pointsResponse['status'] == 'success' &&
            pointsResponse['data'] != null) {
          final dataMap = pointsResponse['data'] as Map<String, dynamic>;
          final points = (dataMap['point_balance'] as num?)?.toInt() ?? 0;
          debugPrint('✅ Points fetched: $points');

          // Create new user object with points
          final userWithPoints = User(
              id: user.id,
              name: user.name,
              email: user.email,
              phoneNumber: user.phoneNumber,
              photo: user.photo,
              birthday: user.birthday,
              gender: user.gender,
              point: points,
              fcmToken: user.fcmToken,
              isActive: user.isActive,
              emailVerified: user.emailVerified,
              phoneVerified: user.phoneVerified,
              hasPassword: user.hasPassword,
              profileCompleted: user.profileCompleted,
              createdAt: user.createdAt,
              updatedAt: user.updatedAt);

          debugPrint(
              '✅ Final user with points: ${userWithPoints.name}, Points: ${userWithPoints.point}');
          return userWithPoints;
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching points (using 0 as fallback): $e');
      }

      // Return user with 0 points if points fetch failed
      return user;
    } catch (e) {
      debugPrint('❌ Error getting user with points: $e');
      return null;
    }
  }

  // Update profile
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? name,
    String? gender,
    String? email,
    String? phoneNumber,
    String? birthday,
    dynamic photo, // File or null
  }) async {
    try {
      final formData = <String, dynamic>{};
      if (name != null) formData['name'] = name;
      if (gender != null) formData['gender'] = gender;
      if (email != null) formData['email'] = email;
      if (phoneNumber != null) formData['phone_number'] = phoneNumber;
      if (birthday != null) formData['birthday'] = birthday;
      if (photo != null) formData['photo'] = photo;

      final response = await _apiClient.post('/auth/edit-profile/$userId',
          data: formData, isMultipart: photo != null);

      return response;
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update FCM Token
  Future<void> updateFcmToken(int userId, String fcmToken) async {
    try {
      await _apiClient
          .post('/auth/fcm_token/$userId', data: {'fcm_token': fcmToken});
    } catch (e) {
      throw Exception('Failed to update FCM token: $e');
    }
  }

  // Refresh token
  Future<String> refreshToken() async {
    try {
      final response = await _apiClient.post('/auth/refresh');

      if (response['status'] == 'success') {
        final token = response['data']['access_token'];
        await _storageService.saveAuthToken(token);
        return token;
      }

      throw Exception(response['message'] ?? 'Token refresh failed');
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }

  // Validate token
  Future<bool> validateToken() async {
    try {
      final response = await _apiClient.get('/auth/token-validation');
      return response['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // Check if email/password combination is valid
  Future<bool> validateUser(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/user-validation', data: {
        'email': email,
        'password': password,
      });
      return response['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // Get deletion summary
  Future<Map<String, dynamic>> getDeletionSummary() async {
    try {
      final response = await _apiClient.get('/auth/deletion-summary');
      if (_isSuccessResponse(response) && response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // Delete account (30-day grace period)
  Future<void> deleteAccount(int userId, {String? reason}) async {
    try {
      final response = await _apiClient.post(
        '/auth/delete-profile/$userId',
        data: reason != null ? {'reason': reason} : null,
      );

      if (_isSuccessResponse(response)) {
        await logout();
      } else {
        throw Exception(response['message'] ?? 'Gagal memproses permohonan penghapusan akun');
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      throw Exception(msg.isNotEmpty ? msg : 'Gagal memproses permohonan penghapusan akun');
    }
  }

  // Restore account within 30-day grace period
  Future<User> restoreAccount({
    int? userId,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final response = await _apiClient.post('/auth/restore-account', data: {
        if (userId != null) 'user_id': userId,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      });

      if (_isSuccessResponse(response)) {
        final data = response['data'];
        final token =
            _extractToken(data) ?? response['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Token login tidak ditemukan.');
        }
        await _storageService.saveAuthToken(token);

        final user = await _extractOrFetchUser(data);
        if (user == null) {
          throw Exception('Gagal memuat data user.');
        }

        await _storageService.saveUserId(user.id);
        return user;
      }

      throw Exception(response['message'] ?? 'Gagal memulihkan akun.');
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      throw Exception(msg.isNotEmpty ? msg : 'Gagal memulihkan akun.');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = _storageService.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Get auth token
  Future<String?> getAuthToken() async {
    return _storageService.getAuthToken();
  }
}
