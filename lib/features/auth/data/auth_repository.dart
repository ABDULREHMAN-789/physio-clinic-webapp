import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/local_storage.dart';

/// Clean model representing authenticated user profile.
class AuthUser {
  final String uid;
  final String email;

  AuthUser({required this.uid, required this.email});
}

/// Abstract definition for the Authentication layer.
abstract class AuthRepository {
  Future<bool> signIn(String email, String password);
  Future<void> signOut();
  AuthUser? getCurrentUser();
  Stream<AuthUser?> authStateChanges();
}

// ----------------------------------------------------
// PRODUCTION FIREBASE AUTH IMPLEMENTATION
// ----------------------------------------------------
class RealAuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('RealAuthRepository: FirebaseAuthException [${e.code}] - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('RealAuthRepository: Unexpected sign-in error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('RealAuthRepository: Sign-out error: $e');
    }
  }

  @override
  AuthUser? getCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return AuthUser(uid: user.uid, email: user.email ?? '');
    });
  }
}

// ----------------------------------------------------
// HIGH-FIDELITY MOCK AUTH IMPLEMENTATION
// ----------------------------------------------------
class MockAuthRepositoryImpl implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  MockAuthRepositoryImpl() {
    // Attempt to restore persistent login state from local storage
    final savedEmail = getLocalStorageItem('mock_auth_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _currentUser = AuthUser(uid: 'mock-admin', email: savedEmail);
      debugPrint('MockAuthRepository: Restored session for $savedEmail');
    }
    // Delay slightly to allow listeners to subscribe
    Future.microtask(() => _controller.add(_currentUser));
  }

  @override
  Future<bool> signIn(String email, String password) async {
    // Artificial delay to simulate network latency
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.trim() == 'admin@physioclinic.com' && password.trim() == 'admin123') {
      _currentUser = AuthUser(uid: 'mock-admin', email: email.trim());
      setLocalStorageItem('mock_auth_email', email.trim());
      _controller.add(_currentUser);
      return true;
    } else {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Invalid credentials. Use admin@physioclinic.com / admin123 for demo.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    removeLocalStorageItem('mock_auth_email');
    _controller.add(null);
  }

  @override
  AuthUser? getCurrentUser() {
    return _currentUser;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _controller.stream;
  }
}

// ----------------------------------------------------
// RIVERPOD SERVICE PROVIDERS
// ----------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (FirebaseService.isFirebaseAvailable) {
    debugPrint('AuthRepository: Initializing PRODUCTION RealAuthRepository.');
    return RealAuthRepositoryImpl();
  } else {
    debugPrint('AuthRepository: Initializing OFFLINE MockAuthRepository.');
    return MockAuthRepositoryImpl();
  }
});
