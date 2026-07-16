import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_log_model.dart';
import 'firebase_service.dart';

abstract class ActivityLogService {
  Future<void> logActivity(ActivityLogModel log);
  Stream<List<ActivityLogModel>> streamLogs();
}

class RealActivityLogServiceImpl implements ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> logActivity(ActivityLogModel log) async {
    print('ActivityLogService: logActivity called for ID: ${log.logId} in collection "activity_logs"');
    try {
      final docRef = _firestore.collection('activity_logs').doc(log.logId);
      await docRef.set(log.toMap());
      print('ActivityLogService: logActivity SUCCESS for ID: ${log.logId}');
    } catch (e, stackTrace) {
      print('ActivityLogService: logActivity FAILED for ID: ${log.logId} - Error: $e');
      print('ActivityLogService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Stream<List<ActivityLogModel>> streamLogs() {
    print('ActivityLogService: streamLogs called for collection "activity_logs"');
    return _firestore
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          print('ActivityLogService: streamLogs success, returned ${snapshot.docs.length} documents.');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ActivityLogModel.fromMap(data, doc.id);
          }).toList();
        })
        .handleError((error, stackTrace) {
          print('ActivityLogService: streamLogs error in snapshots stream: $error');
          print('ActivityLogService: Stack trace: $stackTrace');
          throw error;
        });
  }
}

class MockActivityLogServiceImpl implements ActivityLogService {
  final List<ActivityLogModel> _mockLogs = [];
  final StreamController<List<ActivityLogModel>> _logsController = StreamController.broadcast();

  @override
  Future<void> logActivity(ActivityLogModel log) async {
    _mockLogs.insert(0, log); // Add to beginning to simulate descending order
    _publishLogs();
  }

  @override
  Stream<List<ActivityLogModel>> streamLogs() {
    Future.microtask(() => _publishLogs());
    return _logsController.stream;
  }

  void _publishLogs() {
    _logsController.add(List.unmodifiable(_mockLogs));
  }
}

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  if (FirebaseService.isFirebaseAvailable) {
    return RealActivityLogServiceImpl();
  } else {
    return MockActivityLogServiceImpl();
  }
});
