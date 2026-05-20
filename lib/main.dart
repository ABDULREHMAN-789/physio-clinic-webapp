import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase (will fall back to mock database gracefully if credentials are missing)
  await FirebaseService.initialize();

  runApp(
    const ProviderScope(
      child: PhysioClinicApp(),
    ),
  );
}

class PhysioClinicApp extends ConsumerWidget {
  const PhysioClinicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
