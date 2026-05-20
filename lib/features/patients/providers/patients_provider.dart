import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/patient_model.dart';

// Stream provider to get real-time patients list
final patientsStreamProvider = StreamProvider<List<PatientModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamPatients();
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

  PatientOperationNotifier(this._firestoreService) : super(PatientOperationState.initial());

  Future<void> addPatient(PatientModel patient) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.addPatient(patient);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePatient(PatientModel patient) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.updatePatient(patient);
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
  return PatientOperationNotifier(firestoreService);
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
