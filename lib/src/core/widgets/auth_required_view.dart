import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_language.dart';
import '../utils/auth_guard.dart';

class AuthRequiredView extends ConsumerStatefulWidget {
  final Widget child;
  final String redirectTo;

  const AuthRequiredView({
    super.key,
    required this.child,
    required this.redirectTo,
  });

  @override
  ConsumerState<AuthRequiredView> createState() => _AuthRequiredViewState();
}

class _AuthRequiredViewState extends ConsumerState<AuthRequiredView> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    if (AuthGuard.isAuthenticated(ref)) {
      return widget.child;
    }

    if (!_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          AuthGuard.showLoginRequiredDialog(
            context,
            redirectTo: widget.redirectTo,
            lang: ref.read(appLanguageProvider),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFDD2222),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr.get('login_required_message', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => AuthGuard.showLoginRequiredDialog(
                  context,
                  redirectTo: widget.redirectTo,
                  lang: ref.read(appLanguageProvider),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                ),
                child: Text(tr.get('login_or_register', lang)),
              ),
            ],
          ),
        ),
      ));
  }
}
