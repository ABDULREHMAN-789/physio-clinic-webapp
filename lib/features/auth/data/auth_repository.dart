import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/local_storage.dart';
import '../../../models/user_model.dart';

/// Clean model representing authenticated user profile.
class AuthUser {
  final String uid;
  final String email;
  final String role;
  final UserModel? userModel;

  AuthUser({required this.uid, required this.email, this.role = 'Therapist', this.userModel});
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<bool> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (cred.user != null) {
        final uid = cred.user!.uid;
        final userEmail = email.trim().toLowerCase();

        // Check if user document exists in Firestore
        final doc = await _firestore.collection('users').doc(uid).get();

        if (doc.exists) {
          // User document found — verify account is active
          final userModel = UserModel.fromMap(doc.data()!);
          if (userModel.status != 'Active') {
            await _auth.signOut();
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: 'This account has been deactivated. Contact your administrator.',
            );
          }
        } else {
          // No Firestore document yet — auto-create one based on email heuristic.
          // Admin email patterns get the Admin role; everyone else gets Therapist.
          final isAdmin = userEmail.contains('admin');
          final newUser = UserModel(
            userId: uid,
            fullName: isAdmin ? 'Clinic Admin' : 'Therapist',
            email: userEmail,
            phone: '',
            role: isAdmin ? 'Admin' : 'Therapist',
            status: 'Active',
            createdAt: DateTime.now(),
            revenuePercentage: isAdmin ? 0.0 : 30.0,
          );
          debugPrint('RealAuthRepository: No Firestore doc found for $userEmail — auto-creating with role ${newUser.role}.');
          await _firestore.collection('users').doc(uid).set(newUser.toMap());
        }
      }
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
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final userModel = UserModel.fromMap(doc.data()!);
          return AuthUser(uid: user.uid, email: user.email ?? '', role: userModel.role, userModel: userModel);
        } else {
          if (user.email == 'admin@physioclinic.com' || user.email == 'admin@clinic.com') {
             return AuthUser(uid: user.uid, email: user.email ?? '', role: 'Admin');
          }
          return AuthUser(uid: user.uid, email: user.email ?? '');
        }
      } catch (e) {
        debugPrint('RealAuthRepository: Error fetching user doc: $e');
        return AuthUser(uid: user.uid, email: user.email ?? '');
      }
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
    final savedEmail = getLocalStorageItem('mock_auth_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      final role = savedEmail.contains('admin') ? 'Admin' : 'Therapist';
      final mockModel = UserModel(
        userId: 'mock-${role.toLowerCase()}',
        fullName: 'Mock $role',
        email: savedEmail,
        phone: '',
        role: role,
        status: 'Active',
        createdAt: DateTime.now(),
        revenuePercentage: role == 'Therapist' ? 30.0 : 0.0,
      );
      _currentUser = AuthUser(uid: mockModel.userId, email: savedEmail, role: role, userModel: mockModel);
      debugPrint('MockAuthRepository: Restored session for $savedEmail');
    }
    Future.microtask(() => _controller.add(_currentUser));
  }

  @override
  Future<bool> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.trim() == 'admin@physioclinic.com' && password.trim() == 'admin123') {
      final mockAdmin = UserModel(
        userId: 'mock-admin',
        fullName: 'Clinic Admin',
        email: email.trim(),
        phone: '',
        role: 'Admin',
        status: 'Active',
        createdAt: DateTime.now(),
        revenuePercentage: 0.0,
      );
      _currentUser = AuthUser(uid: 'mock-admin', email: email.trim(), role: 'Admin', userModel: mockAdmin);
      setLocalStorageItem('mock_auth_email', email.trim());
      _controller.add(_currentUser);
      return true;
    } else if (email.trim() == 'therapist@physioclinic.com' && password.trim() == 'therapist123') {
      final mockTherapist = UserModel(
        userId: 'mock-therapist',
        fullName: 'John Therapist',
        email: email.trim(),
        phone: '',
        role: 'Therapist',
        status: 'Active',
        createdAt: DateTime.now(),
        revenuePercentage: 30.0,
      );
      _currentUser = AuthUser(uid: 'mock-therapist', email: email.trim(), role: 'Therapist', userModel: mockTherapist);
      setLocalStorageItem('mock_auth_email', email.trim());
      _controller.add(_currentUser);
      return true;
    } else {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Invalid credentials. Try admin@physioclinic.com/admin123 or therapist@physioclinic.com/therapist123.',
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
