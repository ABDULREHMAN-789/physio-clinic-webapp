import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../models/activity_log_model.dart';
import '../../../models/patient_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Stream provider to get real-time patients list
final patientsStreamProvider = StreamProvider<List<PatientModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final authState = ref.watch(authProvider);
  final isAdmin = authState.role == 'Admin';
  final therapistId = isAdmin ? null : authState.userModel?.userId;
  final stream = firestoreService.streamPatients(therapistId: therapistId);
  
  // Under unified profile, therapists can see all patients (including massage chair)
  return stream;
});

// Stream provider to get ALL patients in the clinic (without therapist filtering) for duplicate checks
final allPatientsStreamProvider = StreamProvider<List<PatientModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamPatients(therapistId: null);
});


// State class to track patient operations (adding/editing/deleting)
class PatientOperationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  PatientOperationState({
    required this.isLoading,
    this.error,
    required this.isSuccess,
  });

  factory PatientOperationState.initial() => PatientOperationState(isLoading: false, isSuccess: false);

  PatientOperationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return PatientOperationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class PatientOperationNotifier extends StateNotifier<PatientOperationState> {
  final FirestoreService _firestoreService;
  final ActivityLogService _logService;
  final UserModel? _currentUser;

  PatientOperationNotifier(this._firestoreService, this._logService, this._currentUser) : super(PatientOperationState.initial());

  Future<void> addPatient(PatientModel patient) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.addPatient(patient);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Patient Registered',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Registered new patient: ${patient.fullName}',
        ));
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePatient(PatientModel patient) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.updatePatient(patient);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Patient Updated',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Updated profile for patient: ${patient.fullName}',
        ));
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deletePatient(String patientId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.deletePatient(patientId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void resetState() {
    state = PatientOperationState.initial();
  }
}

final patientOperationProvider = StateNotifierProvider<PatientOperationNotifier, PatientOperationState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logService = ref.watch(activityLogServiceProvider);
  final currentUser = ref.watch(authProvider).userModel;
  return PatientOperationNotifier(firestoreService, logService, currentUser);
});

// Helper provider to search/filter patients list
final searchFilterProvider = StateProvider<String>((ref) => '');

final filteredPatientsProvider = Provider<AsyncValue<List<PatientModel>>>((ref) {
  final patientsAsync = ref.watch(patientsStreamProvider);
  final searchQuery = ref.watch(searchFilterProvider).toLowerCase().trim();

  return patientsAsync.whenData((patients) {
    if (searchQuery.isEmpty) return patients;
    return patients.where((patient) {
      return patient.fullName.toLowerCase().contains(searchQuery) ||
          patient.phone.contains(searchQuery) ||
          patient.medicalCondition.toLowerCase().contains(searchQuery);
    }).toList();
  });
});
