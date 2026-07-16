import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../models/activity_log_model.dart';

final activityLogsStreamProvider = StreamProvider<List<ActivityLogModel>>((ref) {
  final service = ref.watch(activityLogServiceProvider);
  return service.streamLogs();
});
