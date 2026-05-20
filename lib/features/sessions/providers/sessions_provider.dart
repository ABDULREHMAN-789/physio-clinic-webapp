import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/session_model.dart';

// Stream provider to get real-time sessions list
final sessionsStreamProvider = StreamProvider<List<SessionModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamSessions();
});

// State class to track session operations
class SessionOperationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  SessionOperationState({
    required this.isLoading,
    this.error,
    required this.isSuccess,
  });

  factory SessionOperationState.initial() => SessionOperationState(isLoading: false, isSuccess: false);

  SessionOperationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return SessionOperationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class SessionOperationNotifier extends StateNotifier<SessionOperationState> {
  final FirestoreService _firestoreService;

  SessionOperationNotifier(this._firestoreService) : super(SessionOperationState.initial());

  Future<void> addSession(SessionModel session) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.addSession(session);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateSession(SessionModel session) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.updateSession(session);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteSession(String sessionId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.deleteSession(sessionId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void resetState() {
    state = SessionOperationState.initial();
  }
}

final sessionOperationProvider = StateNotifierProvider<SessionOperationNotifier, SessionOperationState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return SessionOperationNotifier(firestoreService);
});

// Selected Patient filter for sessions screen
final selectedPatientFilterProvider = StateProvider<String?>((ref) => null);
// Paid status filter for sessions screen (null = All, true = Paid, false = Unpaid)
final paymentStatusFilterProvider = StateProvider<bool?>((ref) => null);

final filteredSessionsProvider = Provider<AsyncValue<List<SessionModel>>>((ref) {
  final sessionsAsync = ref.watch(sessionsStreamProvider);
  final patientId = ref.watch(selectedPatientFilterProvider);
  final paymentStatus = ref.watch(paymentStatusFilterProvider);

  return sessionsAsync.whenData((sessions) {
    List<SessionModel> results = sessions;
    if (patientId != null && patientId.isNotEmpty) {
      results = results.where((s) => s.patientId == patientId).toList();
    }
    if (paymentStatus != null) {
      results = results.where((s) => s.paymentStatus == paymentStatus).toList();
    }
    return results;
  });
});
