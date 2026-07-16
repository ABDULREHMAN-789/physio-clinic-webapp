import 'package:cloud_firestore/cloud_firestore.dart';

class ReassignmentLogModel {
  final String reassignmentId;
  final String patientId;
  final String patientName;
  final String originalTherapistId;
  final String originalTherapistName;
  final String temporaryTherapistId;
  final String temporaryTherapistName;
  final String assignedById;
  final String assignedByName;
  final DateTime assignmentDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? revertDate;
  final String? reason;

  ReassignmentLogModel({
    required this.reassignmentId,
    required this.patientId,
    required this.patientName,
    required this.originalTherapistId,
    required this.originalTherapistName,
    required this.temporaryTherapistId,
    required this.temporaryTherapistName,
    required this.assignedById,
    required this.assignedByName,
    required this.assignmentDate,
    this.startDate,
    this.endDate,
    this.revertDate,
    this.reason,
  });

  ReassignmentLogModel copyWith({
    String? reassignmentId,
    String? patientId,
    String? patientName,
    String? originalTherapistId,
    String? originalTherapistName,
    String? temporaryTherapistId,
    String? temporaryTherapistName,
    String? assignedById,
    String? assignedByName,
    DateTime? assignmentDate,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? revertDate,
    String? reason,
  }) {
    return ReassignmentLogModel(
      reassignmentId: reassignmentId ?? this.reassignmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      originalTherapistId: originalTherapistId ?? this.originalTherapistId,
      originalTherapistName: originalTherapistName ?? this.originalTherapistName,
      temporaryTherapistId: temporaryTherapistId ?? this.temporaryTherapistId,
      temporaryTherapistName: temporaryTherapistName ?? this.temporaryTherapistName,
      assignedById: assignedById ?? this.assignedById,
      assignedByName: assignedByName ?? this.assignedByName,
      assignmentDate: assignmentDate ?? this.assignmentDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      revertDate: revertDate ?? this.revertDate,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reassignmentId': reassignmentId,
      'patientId': patientId,
      'patientName': patientName,
      'originalTherapistId': originalTherapistId,
      'originalTherapistName': originalTherapistName,
      'temporaryTherapistId': temporaryTherapistId,
      'temporaryTherapistName': temporaryTherapistName,
      'assignedById': assignedById,
      'assignedByName': assignedByName,
      'assignmentDate': assignmentDate,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (revertDate != null) 'revertDate': revertDate,
      if (reason != null) 'reason': reason,
    };
  }

  factory ReassignmentLogModel.fromMap(Map<String, dynamic> map, [String? docId]) {
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

    DateTime? parseNullableDate(dynamic dateField) {
      if (dateField == null) return null;
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        return DateTime.tryParse(dateField);
      } else if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      }
      return null;
    }

    return ReassignmentLogModel(
      reassignmentId: map['reassignmentId'] ?? docId ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      originalTherapistId: map['originalTherapistId'] ?? '',
      originalTherapistName: map['originalTherapistName'] ?? '',
      temporaryTherapistId: map['temporaryTherapistId'] ?? '',
      temporaryTherapistName: map['temporaryTherapistName'] ?? '',
      assignedById: map['assignedById'] ?? '',
      assignedByName: map['assignedByName'] ?? '',
      assignmentDate: parseDate(map['assignmentDate']),
      startDate: parseNullableDate(map['startDate']),
      endDate: parseNullableDate(map['endDate']),
      revertDate: parseNullableDate(map['revertDate']),
      reason: map['reason'],
    );
  }
}
