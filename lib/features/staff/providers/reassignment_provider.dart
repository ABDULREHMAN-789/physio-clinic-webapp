import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../models/activity_log_model.dart';
import '../../../models/patient_model.dart';
import '../../../models/reassignment_log_model.dart';
import '../../../models/user_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Stream provider to get all reassignment logs (audit trail)
final reassignmentLogsStreamProvider = StreamProvider<List<ReassignmentLogModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamReassignmentLogs();
});

// State for reassignment operations
class ReassignmentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  ReassignmentState({
    required this.isLoading,
    this.error,
    required this.isSuccess,
  });

  factory ReassignmentState.initial() => ReassignmentState(isLoading: false, isSuccess: false);

  ReassignmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return ReassignmentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// StateNotifier to perform reassignment and reversion
class ReassignmentNotifier extends StateNotifier<ReassignmentState> {
  final FirestoreService _firestoreService;
  final ActivityLogService _logService;

  ReassignmentNotifier(this._firestoreService, this._logService) : super(ReassignmentState.initial());

  Future<void> reassignPatients({
    required List<PatientModel> patients,
    required UserModel originalTherapist,
    required UserModel temporaryTherapist,
    required UserModel adminUser,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
  }) async {
    state = ReassignmentState(isLoading: true, isSuccess: false);
    try {
      print('ReassignmentProvider: Checking Admin Authentication before Firestore writes...');
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        print('ReassignmentProvider: Auth User UID: ${authUser.uid}');
        print('ReassignmentProvider: Auth User Email: ${authUser.email}');
        try {
          final idTokenResult = await authUser.getIdTokenResult(true);
          print('ReassignmentProvider: Auth User Claims: ${idTokenResult.claims}');
        } catch (e) {
          print('ReassignmentProvider: Failed to get IdTokenResult: $e');
        }
      } else {
        print('ReassignmentProvider: WARNING - FirebaseAuth.instance.currentUser is NULL!');
      }
      print('ReassignmentProvider: adminUser model -> UID: ${adminUser.userId}, Email: ${adminUser.email}, Role: ${adminUser.role}');

      final now = DateTime.now();
      for (final patient in patients) {
        // 1. Create audit log
        final logId = 'RE-${now.millisecondsSinceEpoch}-${patient.patientId}';
        final log = ReassignmentLogModel(
          reassignmentId: logId,
          patientId: patient.patientId,
          patientName: patient.fullName,
          originalTherapistId: originalTherapist.userId,
          originalTherapistName: originalTherapist.fullName,
          temporaryTherapistId: temporaryTherapist.userId,
          temporaryTherapistName: temporaryTherapist.fullName,
          assignedById: adminUser.userId,
          assignedByName: adminUser.fullName,
          assignmentDate: now,
          startDate: startDate,
          endDate: endDate,
          reason: reason,
        );

        // 2. Update patient model
        final updatedPatient = patient.copyWith(
          isTemporarilyReassigned: true,
          tempTherapistId: temporaryTherapist.userId,
          tempTherapistName: temporaryTherapist.fullName,
          tempAssignmentDate: now,
          tempAssignmentStartDate: startDate,
          tempAssignmentEndDate: endDate,
          tempAssignmentReason: reason,
        );

        print('ReassignmentProvider: [STEP 1] Writing log document to path "/reassignment_logs/$logId" for patient: ${patient.fullName}...');
        try {
          await _firestoreService.addReassignmentLog(log);
          print('ReassignmentProvider: [STEP 1 SUCCESS] Written log to "/reassignment_logs/$logId".');
        } catch (e, stackTrace) {
          print('ReassignmentProvider: [STEP 1 FAILED] Failed writing to "/reassignment_logs/$logId": $e');
          print('ReassignmentProvider: Stack trace: $stackTrace');
          rethrow;
        }

        print('ReassignmentProvider: [STEP 2] Updating patient doc at path "/patients/${patient.patientId}" for: ${patient.fullName}...');
        try {
          await _firestoreService.updatePatient(updatedPatient);
          print('ReassignmentProvider: [STEP 2 SUCCESS] Updated patient document at "/patients/${patient.patientId}".');
        } catch (e, stackTrace) {
          print('ReassignmentProvider: [STEP 2 FAILED] Failed updating patient at "/patients/${patient.patientId}": $e');
          print('ReassignmentProvider: Stack trace: $stackTrace');
          rethrow;
        }
      }

      // 3. Log activity
      final activityLog = ActivityLogModel(
        logId: 'ACT-RE-${now.millisecondsSinceEpoch}',
        action: 'Patients Reassigned',
        userId: adminUser.userId,
        performedByName: adminUser.fullName,
        role: adminUser.role,
        timestamp: now,
        details: 'Temporarily reassigned ${patients.length} patients from ${originalTherapist.fullName} to ${temporaryTherapist.fullName}',
      );

      print('ReassignmentProvider: [STEP 3] Writing activity log document to path "/activity_logs/${activityLog.logId}"...');
      try {
        await _logService.logActivity(activityLog);
        print('ReassignmentProvider: [STEP 3 SUCCESS] Written log to "/activity_logs/${activityLog.logId}".');
      } catch (e, stackTrace) {
        print('ReassignmentProvider: [STEP 3 FAILED] Failed writing log to "/activity_logs/${activityLog.logId}": $e');
        print('ReassignmentProvider: Stack trace: $stackTrace');
        rethrow;
      }

      state = ReassignmentState(isLoading: false, isSuccess: true);
    } catch (e, stackTrace) {
      print('ReassignmentProvider: Overall reassignment process failed: $e');
      print('ReassignmentProvider: Stack trace: $stackTrace');
      state = ReassignmentState(isLoading: false, error: e.toString(), isSuccess: false);
    }
  }

  Future<void> revertReassignment({
    required PatientModel patient,
    required ReassignmentLogModel log,
    required UserModel adminUser,
  }) async {
    state = ReassignmentState(isLoading: true, isSuccess: false);
    try {
      print('ReassignmentProvider: Checking Admin Authentication before Firestore writes (Revert)...');
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        print('ReassignmentProvider: Auth User UID: ${authUser.uid}');
        print('ReassignmentProvider: Auth User Email: ${authUser.email}');
      } else {
        print('ReassignmentProvider: WARNING - FirebaseAuth.instance.currentUser is NULL!');
      }
      print('ReassignmentProvider: adminUser model -> UID: ${adminUser.userId}, Email: ${adminUser.email}, Role: ${adminUser.role}');

      final now = DateTime.now();

      // 1. Revert patient fields
      final revertedPatient = patient.revertAssignment();

      // 2. Update log with revert date
      final updatedLog = log.copyWith(revertDate: now);

      print('ReassignmentProvider: [REVERT STEP 1] Reverting patient fields in patients collection for: ${patient.fullName} at path "/patients/${patient.patientId}"...');
      try {
        await _firestoreService.updatePatient(revertedPatient);
        print('ReassignmentProvider: [REVERT STEP 1 SUCCESS] Reverted patient fields.');
      } catch (e, stackTrace) {
        print('ReassignmentProvider: [REVERT STEP 1 FAILED] Failed reverting patient: $e');
        print('ReassignmentProvider: Stack trace: $stackTrace');
        rethrow;
      }

      print('ReassignmentProvider: [REVERT STEP 2] Updating log in reassignment_logs with revert date at path "/reassignment_logs/${log.reassignmentId}"...');
      try {
        await _firestoreService.updateReassignmentLog(updatedLog);
        print('ReassignmentProvider: [REVERT STEP 2 SUCCESS] Updated log.');
      } catch (e, stackTrace) {
        print('ReassignmentProvider: [REVERT STEP 2 FAILED] Failed updating log: $e');
        print('ReassignmentProvider: Stack trace: $stackTrace');
        rethrow;
      }

      // 3. Log activity
      final activityLog = ActivityLogModel(
        logId: 'ACT-REV-${now.millisecondsSinceEpoch}',
        action: 'Reassignment Reverted',
        userId: adminUser.userId,
        performedByName: adminUser.fullName,
        role: adminUser.role,
        timestamp: now,
        details: 'Reverted temporary assignment for patient ${patient.fullName} back to ${log.originalTherapistName}',
      );

      print('ReassignmentProvider: [REVERT STEP 3] Writing revert log to activity_logs at path "/activity_logs/${activityLog.logId}"...');
      try {
        await _logService.logActivity(activityLog);
        print('ReassignmentProvider: [REVERT STEP 3 SUCCESS] Written log.');
      } catch (e, stackTrace) {
        print('ReassignmentProvider: [REVERT STEP 3 FAILED] Failed writing log: $e');
        print('ReassignmentProvider: Stack trace: $stackTrace');
        rethrow;
      }

      state = ReassignmentState(isLoading: false, isSuccess: true);
    } catch (e, stackTrace) {
      print('ReassignmentProvider: Overall revert process failed: $e');
      print('ReassignmentProvider: Stack trace: $stackTrace');
      state = ReassignmentState(isLoading: false, error: e.toString(), isSuccess: false);
    }
  }

  /// Automatically check and revert expired assignments
  Future<void> checkAndRevertExpired({
    required List<PatientModel> allPatients,
    required List<ReassignmentLogModel> allLogs,
    required UserModel adminUser,
  }) async {
    final now = DateTime.now();
    
    // Find all patients currently reassigned whose endDate is passed
    final expiredPatients = allPatients.where((p) {
      if (p.isTemporarilyReassigned == true && p.tempAssignmentEndDate != null) {
        return now.isAfter(p.tempAssignmentEndDate!);
      }
      return false;
    }).toList();

    if (expiredPatients.isEmpty) return;

    for (final patient in expiredPatients) {
      // Find the active reassignment log for this patient (the one without a revertDate)
      final activeLogIndex = allLogs.indexWhere(
        (l) => l.patientId == patient.patientId && l.revertDate == null
      );

      if (activeLogIndex != -1) {
        final log = allLogs[activeLogIndex];
        await revertReassignment(
          patient: patient,
          log: log,
          adminUser: adminUser,
        );
      }
    }
  }

  void resetState() {
    state = ReassignmentState.initial();
  }
}

// Riverpod provider for ReassignmentNotifier
final reassignmentOperationProvider = StateNotifierProvider<ReassignmentNotifier, ReassignmentState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logService = ref.watch(activityLogServiceProvider);
  return ReassignmentNotifier(firestoreService, logService);
});

// Auto-check provider that runs when patients and logs update, if the logged-in user is Admin
final autoReversionCheckerProvider = Provider.autoDispose<void>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.userModel == null || authState.role != 'Admin') return;

  final patientsAsync = ref.watch(allPatientsStreamProvider);
  final logsAsync = ref.watch(reassignmentLogsStreamProvider);

  patientsAsync.whenData((patients) {
    logsAsync.whenData((logs) {
      final notifier = ref.read(reassignmentOperationProvider.notifier);
      // Run the check asynchronously to avoid updating providers during build phase
      Future.microtask(() {
        notifier.checkAndRevertExpired(
          allPatients: patients,
          allLogs: logs,
          adminUser: authState.userModel!,
        );
      });
    });
  });
});
