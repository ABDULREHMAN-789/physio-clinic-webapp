import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../models/activity_log_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Stream provider to get real-time massage chair bills list (admin only)
final massageChairBillsStreamProvider = StreamProvider<List<MassageChairBillModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamMassageChairBills();
});

// State class to track massage chair bill operations
class MassageChairBillOperationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  MassageChairBillOperationState({
    required this.isLoading,
    this.error,
    required this.isSuccess,
  });

  factory MassageChairBillOperationState.initial() =>
      MassageChairBillOperationState(isLoading: false, isSuccess: false);

  MassageChairBillOperationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return MassageChairBillOperationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class MassageChairBillOperationNotifier extends StateNotifier<MassageChairBillOperationState> {
  final FirestoreService _firestoreService;
  final ActivityLogService _logService;
  final UserModel? _currentUser;

  MassageChairBillOperationNotifier(this._firestoreService, this._logService, this._currentUser)
      : super(MassageChairBillOperationState.initial());

  Future<void> addBill(MassageChairBillModel bill) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.addMassageChairBill(bill);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Massage Chair Bill Created',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Created massage chair bill for ${bill.customerName}. Fee: Rs. ${bill.fee}',
        ));
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateBill(MassageChairBillModel bill) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.updateMassageChairBill(bill);
      if (_currentUser != null) {
        await _logService.logActivity(ActivityLogModel(
          logId: FirebaseFirestore.instance.collection('activity_logs').doc().id,
          action: 'Massage Chair Bill Updated',
          userId: _currentUser.userId,
          performedByName: _currentUser.fullName,
          role: _currentUser.role,
          timestamp: DateTime.now(),
          details: 'Updated massage chair bill for ${bill.customerName}. Payment: ${bill.paymentStatus}',
        ));
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteBill(String billId) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _firestoreService.deleteMassageChairBill(billId);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void resetState() {
    state = MassageChairBillOperationState.initial();
  }
}

final massageChairBillOperationProvider =
    StateNotifierProvider<MassageChairBillOperationNotifier, MassageChairBillOperationState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logService = ref.watch(activityLogServiceProvider);
  final currentUser = ref.watch(authProvider).userModel;
  return MassageChairBillOperationNotifier(firestoreService, logService, currentUser);
});
