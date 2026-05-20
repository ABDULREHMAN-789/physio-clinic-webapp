import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final String email;
  final String? error;
  final bool isLoading;

  AuthState({
    required this.isAuthenticated,
    required this.email,
    this.error,
    required this.isLoading,
  });

  factory AuthState.initial(bool authenticated, String email) {
    return AuthState(
      isAuthenticated: authenticated,
      email: email,
      error: null,
      isLoading: false,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      error: error, // Clears error if set to null
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _subscription;

  AuthNotifier(this._authRepository)
      : super(AuthState.initial(
          _authRepository.getCurrentUser() != null,
          _authRepository.getCurrentUser()?.email ?? '',
        )) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _subscription = _authRepository.authStateChanges().listen((user) {
      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          email: user.email,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          email: '',
          isLoading: false,
        );
      }
    });
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _authRepository.signIn(email, password);
      return success;
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('user-not-found') ||
          errMsg.contains('wrong-password') ||
          errMsg.contains('invalid-credential') ||
          errMsg.contains('Invalid credentials')) {
        errMsg = 'Invalid email or password. Hint: admin@physioclinic.com / admin123';
      } else if (errMsg.contains('invalid-email')) {
        errMsg = 'The email address is badly formatted.';
      } else if (errMsg.contains('network-request-failed')) {
        errMsg = 'A network error occurred. Please check your internet connection.';
      } else {
        errMsg = 'Authentication failed. Please check your credentials and try again.';
      }
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: errMsg,
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authRepository.signOut();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
