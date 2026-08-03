import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String patientId;
  final DateTime sessionDate;
  final String treatmentNotes;
  final double charges;
  final String paymentStatus; // 'Paid', 'Unpaid', 'Fee Waiver'
  final String nextRecommendation;
  final String? therapistId;
  final String? therapistName;

  SessionModel({
    required this.sessionId,
    required this.patientId,
    required this.sessionDate,
    required this.treatmentNotes,
    required this.charges,
    required this.paymentStatus,
    required this.nextRecommendation,
    this.therapistId,
    this.therapistName,
  });

  SessionModel copyWith({
    String? sessionId,
    String? patientId,
    DateTime? sessionDate,
    String? treatmentNotes,
    double? charges,
    String? paymentStatus,
    String? nextRecommendation,
    String? therapistId,
    String? therapistName,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      patientId: patientId ?? this.patientId,
      sessionDate: sessionDate ?? this.sessionDate,
      treatmentNotes: treatmentNotes ?? this.treatmentNotes,
      charges: charges ?? this.charges,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      nextRecommendation: nextRecommendation ?? this.nextRecommendation,
      therapistId: therapistId ?? this.therapistId,
      therapistName: therapistName ?? this.therapistName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'patientId': patientId,
      'sessionDate': sessionDate,
      'treatmentNotes': treatmentNotes,
      'charges': charges,
      'paymentStatus': paymentStatus,
      'nextRecommendation': nextRecommendation,
      'therapistId': therapistId,
      'therapistName': therapistName,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
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

    String parsePaymentStatus(dynamic status) {
      if (status is bool) return status ? 'Paid' : 'Unpaid';
      if (status is String && status.isNotEmpty) return status;
      return 'Unpaid';
    }

    return SessionModel(
      sessionId: map['sessionId'] ?? '',
      patientId: map['patientId'] ?? '',
      sessionDate: parseDate(map['sessionDate']),
      treatmentNotes: map['treatmentNotes'] ?? '',
      charges: map['charges'] is num ? (map['charges'] as num).toDouble() : 0.0,
      paymentStatus: parsePaymentStatus(map['paymentStatus']),
      nextRecommendation: map['nextRecommendation'] ?? '',
      therapistId: map['therapistId'],
      therapistName: map['therapistName'],
    );
  }
}
