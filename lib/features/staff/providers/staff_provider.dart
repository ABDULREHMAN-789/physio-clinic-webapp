import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/activity_log_model.dart';
import '../../../core/services/firebase_service.dart';

final staffProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  if (!FirebaseService.isFirebaseAvailable) {
    return Stream.value([
      UserModel(
        userId: 'mock-therapist',
        fullName: 'John Therapist',
        email: 'therapist@physioclinic.com',
        phone: '+1234567890',
        role: 'Therapist',
        specialization: 'Orthopedic Spine',
        qualification: 'DPT, CMPT',
        status: 'Active',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        revenuePercentage: 30.0,
      ),
      UserModel(
        userId: 'mock-therapist-b',
        fullName: 'Sarah Therapist',
        email: 'sarah@physioclinic.com',
        phone: '+1987654321',
        role: 'Therapist',
        specialization: 'Pediatric Rehabilitation',
        qualification: 'DPT, MS-Sports',
        status: 'Active',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        revenuePercentage: 40.0,
      ),
      UserModel(
        userId: 'mock-therapist-c',
        fullName: 'Michael Therapist',
        email: 'michael@physioclinic.com',
        phone: '+1122334455',
        role: 'Therapist',
        specialization: 'Neurological rehab',
        qualification: 'DPT',
        status: 'Active',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        revenuePercentage: 35.0,
      ),
    ]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'Therapist')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((u) => u.status != 'Deleted')
          .toList());
});

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addStaff(UserModel staff, String password, UserModel adminUser) async {
    if (!FirebaseService.isFirebaseAvailable) return;

    try {
      // Create user using a secondary Firebase app to avoid signing out the Admin
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: staff.email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final newStaff = staff.copyWith(userId: uid);

      // Save to Firestore
      if (kDebugMode) {
        print('====== FIRESTORE WRITE DEBUG (addStaff) ======');
        print('Active Auth User UID: ${FirebaseAuth.instance.currentUser?.uid}');
        print('Active Auth User Email: ${FirebaseAuth.instance.currentUser?.email}');
        print('Admin User parameter UID: ${adminUser.userId}');
        print('Admin User parameter Role: ${adminUser.role}');
        print('Target Write Path: users/$uid');
        print('Target Data: ${newStaff.toMap()}');
        print('=============================================');
      }
      await _firestore.collection('users').doc(uid).set(newStaff.toMap());

      // Log activity
      final log = ActivityLogModel(
        logId: _firestore.collection('activity_logs').doc().id,
        action: 'Staff Created',
        userId: adminUser.userId,
        performedByName: adminUser.fullName,
        role: adminUser.role,
        timestamp: DateTime.now(),
        details: 'Added new therapist: ${staff.fullName} (${staff.email})',
      );
      await _firestore.collection('activity_logs').doc(log.logId).set(log.toMap());

      // Sign out the secondary app instance
      await secondaryAuth.signOut();
    } catch (e) {
      debugPrint('Error adding staff: $e');
      rethrow;
    }
  }

  /// Soft-deletes a staff member.
  /// Sets status = 'Deleted' and isDeleted = true so all historical session,
  /// billing, and salary records remain intact while the account is deactivated.
  Future<void> deleteStaff(UserModel staff, UserModel adminUser) async {
    if (!FirebaseService.isFirebaseAvailable) return;

    try {
      if (kDebugMode) {
        print('====== FIRESTORE SOFT-DELETE DEBUG (deleteStaff) ======');
        print('Active Auth User UID: ${FirebaseAuth.instance.currentUser?.uid}');
        print('Target Staff UID: ${staff.userId}');
        print('Target Staff Name: ${staff.fullName}');
        print('=======================================================');
      }

      // Soft-delete: mark the document as deleted
      await _firestore.collection('users').doc(staff.userId).update({
        'status': 'Deleted',
        'isDeleted': true,
      });

      // Log the activity
      final log = ActivityLogModel(
        logId: _firestore.collection('activity_logs').doc().id,
        action: 'Staff Deleted',
        userId: adminUser.userId,
        performedByName: adminUser.fullName,
        role: adminUser.role,
        timestamp: DateTime.now(),
        details: 'Soft-deleted staff account: ${staff.fullName} (${staff.email})',
      );
      await _firestore.collection('activity_logs').doc(log.logId).set(log.toMap());
    } catch (e) {
      debugPrint('Error deleting staff: $e');
      rethrow;
    }
  }

  Future<void> updateStaff(UserModel staff, UserModel adminUser) async {
    if (!FirebaseService.isFirebaseAvailable) return;

    try {
      if (kDebugMode) {
        print('====== FIRESTORE WRITE DEBUG (updateStaff) ======');
        print('Active Auth User UID: ${FirebaseAuth.instance.currentUser?.uid}');
        print('Active Auth User Email: ${FirebaseAuth.instance.currentUser?.email}');
        print('Admin User parameter UID: ${adminUser.userId}');
        print('Admin User parameter Role: ${adminUser.role}');
        print('Target Update Path: users/${staff.userId}');
        print('Target Data: ${staff.toMap()}');
        print('================================================');
      }
      await _firestore.collection('users').doc(staff.userId).update(staff.toMap());

      // Log activity
      final log = ActivityLogModel(
        logId: _firestore.collection('activity_logs').doc().id,
        action: 'Staff Updated',
        userId: adminUser.userId,
        performedByName: adminUser.fullName,
        role: adminUser.role,
        timestamp: DateTime.now(),
        details: 'Updated details for therapist: ${staff.fullName}',
      );
      await _firestore.collection('activity_logs').doc(log.logId).set(log.toMap());
    } catch (e) {
      debugPrint('Error updating staff: $e');
      rethrow;
    }
  }
}

final staffServiceProvider = Provider<StaffService>((ref) => StaffService());
