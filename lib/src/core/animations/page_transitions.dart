import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for smooth navigation
class PageTransitions {
  /// Fade transition
  static CustomTransitionPage fadeTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child);
      },
      transitionDuration: duration);
  }

  /// Slide from right transition
  static CustomTransitionPage slideFromRight<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: Curves.easeOutCubic));
        
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: CurveTween(curve: Curves.easeIn).animate(animation),
            child: child,
          ));
      },
      transitionDuration: duration);
  }

  /// Slide from bottom transition (for modals)
  static CustomTransitionPage slideFromBottom<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: Curves.easeOutCubic));
        
        return SlideTransition(
          position: animation.drive(tween),
          child: child);
      },
      transitionDuration: duration);
  }

  /// Scale transition
  static CustomTransitionPage scaleTransition<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween<double>(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack));
        
        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: CurveTween(curve: Curves.easeIn).animate(animation),
            child: child,
          ));
      },
      transitionDuration: duration);
  }

  /// Shared axis transition (Material Design)
  static CustomTransitionPage sharedAxis<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.3, 0.0);
        const end = Offset.zero;
        final slideTween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: Curves.easeOutCubic));
        
        final fadeTween = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: ConstantTween<double>(1.0),
            weight: 50,
          ),
        ]);
        
        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ));
      },
      transitionDuration: duration);
  }
}
