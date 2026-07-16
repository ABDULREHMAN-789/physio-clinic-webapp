import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String logId;
  final String action;
  final String userId;
  final String performedByName;
  final String role;
  final DateTime timestamp;
  final String details;
  final Map<String, dynamic>? metadata;

  ActivityLogModel({
    required this.logId,
    required this.action,
    required this.userId,
    required this.performedByName,
    required this.role,
    required this.timestamp,
    required this.details,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'action': action,
      'userId': userId,
      'performedByName': performedByName,
      'role': role,
      'timestamp': timestamp,
      'details': details,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic dateField) {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        return DateTime.tryParse(dateField) ?? DateTime.now();
      } else if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      }
      return DateTime.now();
    }

    return ActivityLogModel(
      logId: map['logId'] ?? docId ?? '',
      action: map['action'] ?? '',
      userId: map['userId'] ?? '',
      performedByName: map['performedByName'] ?? map['userName'] ?? '',
      role: map['role'] ?? '',
      timestamp: parseDate(map['timestamp']),
      details: map['details'] ?? '',
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
