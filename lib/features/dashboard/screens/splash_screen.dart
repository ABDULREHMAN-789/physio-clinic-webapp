import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  StreamSubscription<AuthUser?>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Show the splash for at least 1.5 seconds for brand impression.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (!FirebaseService.isFirebaseAvailable) {
      // In Mock mode, auth state is synchronous — read directly.
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
      return;
    }

    // In Firebase mode, auth restoration is ASYNC on web.
    // Listen to the authStateChanges() stream and navigate on
    // the first event. A 4-second safety timeout prevents infinite loading.
    final authRepository = ref.read(authRepositoryProvider);
    bool navigated = false;

    // Safety timeout: if Firebase takes > 4 seconds, go to login.
    Future.delayed(const Duration(seconds: 4), () {
      if (!navigated && mounted) {
        navigated = true;
        _authSub?.cancel();
        context.go('/login');
      }
    });

    _authSub = authRepository.authStateChanges().listen((user) {
      if (!navigated && mounted) {
        navigated = true;
        _authSub?.cancel();
        if (user != null) {
          context.go('/dashboard');
        } else {
          context.go('/login');
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, AppColors.primaryLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/clinic_logo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              AppSizes.h24,
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
                child: Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              AppSizes.h8,
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
                child: Text(
                  AppStrings.appSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                ),
              ),
              AppSizes.h32,
              // Loading Indicator
              const SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
