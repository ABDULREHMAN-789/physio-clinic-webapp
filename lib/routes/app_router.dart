import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/sidebar_widget.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/splash_screen.dart';
import '../features/patients/screens/add_patient_screen.dart';
import '../features/patients/screens/patient_details_screen.dart';
import '../features/patients/screens/patients_screen.dart';
import '../features/sessions/screens/add_session_screen.dart';
import '../features/sessions/screens/sessions_screen.dart';
import '../features/billing/screens/billing_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../models/patient_model.dart';
import '../models/session_model.dart';

// Key for Navigator
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges()),
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const AddPatientScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final patientId = state.pathParameters['id']!;
                  final patient = state.extra as PatientModel?;
                  return AddPatientScreen(patientId: patientId, patient: patient);
                },
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final patientId = state.pathParameters['id']!;
                  return PatientDetailsScreen(patientId: patientId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/sessions',
            builder: (context, state) => const SessionsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final initialPatientId = state.uri.queryParameters['patientId'];
                  return AddSessionScreen(initialPatientId: initialPatientId);
                },
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final sessionId = state.pathParameters['id']!;
                  final session = state.extra as SessionModel?;
                  return AddSessionScreen(sessionId: sessionId, session: session);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const BillingScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login';
      final isSplash = state.uri.path == '/splash';

      if (!authState.isAuthenticated && !isLoggingIn && !isSplash) {
        return '/login';
      }
      if (authState.isAuthenticated && (isLoggingIn || isSplash)) {
        return '/dashboard';
      }
      return null;
    },
  );
});

/// A custom Listenable class that triggers notifications when a stream emits events.
/// This enables GoRouter to automatically re-run its redirect logic on auth state updates.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
