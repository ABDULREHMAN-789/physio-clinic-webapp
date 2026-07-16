import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../models/activity_log_model.dart';
import '../../../models/session_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Stream provider to get real-time sessions list
final sessionsStreamProvider = StreamProvider<List<SessionModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final authState = ref.watch(authProvider);
  final therapistId = authState.role == 'Admin' ? null : authState.userModel?.userId;
  return firestoreService.streamSessions(therapistId: therapistId);
});

// Stream provider to get real-time sessions for a specific patient
final patientSessionsStreamProvider = StreamProvider.family<List<SessionModel>, String>((ref, patientId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamSessionsForPatient(patientId);
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
  final ActivityLogService _logService;
  final UserModel? _currentUser;

  SessionOperationNotifier(this._firestoreService, this._logService, this._currentUser) : super(SessionOperationState.initial());

  Future<void> addSession(SessionModel session) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.addSession(session);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Session Logged',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Recorded session for patient ID: ${session.patientId}. Charges: ${session.charges}',
        ));
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateSession(SessionModel session) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.updateSession(session);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Session Updated',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Updated session record for patient ID: ${session.patientId}. Payment Status: ${session.paymentStatus ? 'Paid' : 'Unpaid'}',
        ));
      }
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
  final logService = ref.watch(activityLogServiceProvider);
  final currentUser = ref.watch(authProvider).userModel;
  return SessionOperationNotifier(firestoreService, logService, currentUser);
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
