import 'package:cloud_firestore/cloud_firestore.dart';

class MassageChairBillModel {
  final String billId;
  final String customerId; // References patientId
  final String customerName;
  final DateTime sessionDate;
  final String duration; // Optional, e.g., "30 minutes"
  final double fee;
  final bool paymentStatus; // true = Paid, false = Unpaid
  final DateTime createdAt;

  MassageChairBillModel({
    required this.billId,
    required this.customerId,
    required this.customerName,
    required this.sessionDate,
    this.duration = '',
    required this.fee,
    required this.paymentStatus,
    required this.createdAt,
  });

  MassageChairBillModel copyWith({
    String? billId,
    String? customerId,
    String? customerName,
    DateTime? sessionDate,
    String? duration,
    double? fee,
    bool? paymentStatus,
    DateTime? createdAt,
  }) {
    return MassageChairBillModel(
      billId: billId ?? this.billId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      sessionDate: sessionDate ?? this.sessionDate,
      duration: duration ?? this.duration,
      fee: fee ?? this.fee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'customerId': customerId,
      'customerName': customerName,
      'sessionDate': sessionDate,
      'duration': duration,
      'fee': fee,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt,
    };
  }

  factory MassageChairBillModel.fromMap(Map<String, dynamic> map) {
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

    return MassageChairBillModel(
      billId: map['billId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      sessionDate: parseDate(map['sessionDate']),
      duration: map['duration'] ?? '',
      fee: map['fee'] is num ? (map['fee'] as num).toDouble() : 0.0,
      paymentStatus: map['paymentStatus'] ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
