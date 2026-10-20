import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_language.dart';
import '../services/storage_service.dart';

class AuthGuard {
  AuthGuard._();

  static bool isAuthenticated(WidgetRef ref) {
    final token = ref.read(storageServiceProvider).getAuthToken();
    return token != null && token.isNotEmpty;
  }

  static String loginLocation(String redirectTo) {
    return '/login?returnTo=${Uri.encodeComponent(redirectTo)}';
  }

  static bool requireLogin(
    BuildContext context,
    WidgetRef ref, {
    String? redirectTo,
  }) {
    if (isAuthenticated(ref)) return true;

    final target = redirectTo ?? GoRouterState.of(context).uri.toString();
    showLoginRequiredDialog(
      context,
      redirectTo: target,
      lang: ref.read(appLanguageProvider),
    );
    return false;
  }

  static Future<void> showLoginRequiredDialog(
    BuildContext context, {
    String? redirectTo,
    AppLanguage lang = AppLanguage.indonesia,
  }) async {
    final target = redirectTo ?? GoRouterState.of(context).uri.toString();

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Color(0xFFDD2222),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                tr.get('login_required_title', lang),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                tr.get('login_required_message', lang),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151), // Teks normal & tegas, tidak redup
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.go(
                          '/register?returnTo=${Uri.encodeComponent(target)}');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDD2222),
                        side: const BorderSide(color: Color(0xFFDD2222), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr.get('register', lang),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.go(loginLocation(target));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD2222),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr.get('login', lang),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Dismiss
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  tr.get('later', lang),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
  }

  static Future<void> guardedAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    String? redirectTo,
  }) async {
    if (!requireLogin(context, ref, redirectTo: redirectTo)) return;
    await action();
  }
}
