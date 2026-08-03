import 'package:cloud_firestore/cloud_firestore.dart';

class PatientModel {
  final String patientId;
  final String fullName;
  final String phone;
  final int age;
  final String gender;
  final String address;
  final String medicalCondition;
  final String notes;
  final DateTime registrationDate;
  final String? assignedTherapistId;
  final String? assignedTherapistName;
  final bool? isTemporarilyReassigned;
  final String? tempTherapistId;
  final String? tempTherapistName;
  final DateTime? tempAssignmentDate;
  final DateTime? tempAssignmentStartDate;
  final DateTime? tempAssignmentEndDate;
  final String? tempAssignmentReason;
  final String customerType; // 'therapy' or 'massage_chair'
  final double? consultationFee;
  final String? consultationPaymentStatus;
  final DateTime? consultationPaymentDate;
  final String? consultationNotes;
  final String? paymentType; // 'feeWaiver' or 'regular'
  final bool? isFeeWaiver;

  PatientModel({
    required this.patientId,
    required this.fullName,
    required this.phone,
    required this.age,
    required this.gender,
    required this.address,
    required this.medicalCondition,
    required this.notes,
    required this.registrationDate,
    this.assignedTherapistId,
    this.assignedTherapistName,
    this.isTemporarilyReassigned,
    this.tempTherapistId,
    this.tempTherapistName,
    this.tempAssignmentDate,
    this.tempAssignmentStartDate,
    this.tempAssignmentEndDate,
    this.tempAssignmentReason,
    this.customerType = 'therapy',
    this.consultationFee,
    this.consultationPaymentStatus,
    this.consultationPaymentDate,
    this.consultationNotes,
    this.paymentType,
    this.isFeeWaiver,
  });

  bool get isFeeWaiverPatient =>
      isFeeWaiver == true ||
      paymentType == 'feeWaiver' ||
      consultationPaymentStatus == 'Fee Waiver';

  PatientModel copyWith({
    String? patientId,
    String? fullName,
    String? phone,
    int? age,
    String? gender,
    String? address,
    String? medicalCondition,
    String? notes,
    DateTime? registrationDate,
    String? assignedTherapistId,
    String? assignedTherapistName,
    bool? isTemporarilyReassigned,
    String? tempTherapistId,
    String? tempTherapistName,
    DateTime? tempAssignmentDate,
    DateTime? tempAssignmentStartDate,
    DateTime? tempAssignmentEndDate,
    String? tempAssignmentReason,
    String? customerType,
    double? consultationFee,
    String? consultationPaymentStatus,
    DateTime? consultationPaymentDate,
    String? consultationNotes,
    String? paymentType,
    bool? isFeeWaiver,
  }) {
    return PatientModel(
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      medicalCondition: medicalCondition ?? this.medicalCondition,
      notes: notes ?? this.notes,
      registrationDate: registrationDate ?? this.registrationDate,
      assignedTherapistId: assignedTherapistId ?? this.assignedTherapistId,
      assignedTherapistName: assignedTherapistName ?? this.assignedTherapistName,
      isTemporarilyReassigned: isTemporarilyReassigned ?? this.isTemporarilyReassigned,
      tempTherapistId: tempTherapistId ?? this.tempTherapistId,
      tempTherapistName: tempTherapistName ?? this.tempTherapistName,
      tempAssignmentDate: tempAssignmentDate ?? this.tempAssignmentDate,
      tempAssignmentStartDate: tempAssignmentStartDate ?? this.tempAssignmentStartDate,
      tempAssignmentEndDate: tempAssignmentEndDate ?? this.tempAssignmentEndDate,
      tempAssignmentReason: tempAssignmentReason ?? this.tempAssignmentReason,
      customerType: customerType ?? this.customerType,
      consultationFee: consultationFee ?? this.consultationFee,
      consultationPaymentStatus: consultationPaymentStatus ?? this.consultationPaymentStatus,
      consultationPaymentDate: consultationPaymentDate ?? this.consultationPaymentDate,
      consultationNotes: consultationNotes ?? this.consultationNotes,
      paymentType: paymentType ?? this.paymentType,
      isFeeWaiver: isFeeWaiver ?? this.isFeeWaiver,
    );
  }

  Map<String, dynamic> toMap() {
    final computedFeeWaiver = isFeeWaiver == true || consultationPaymentStatus == 'Fee Waiver' || paymentType == 'feeWaiver';
    return {
      'patientId': patientId,
      'fullName': fullName,
      'phone': phone,
      'age': age,
      'gender': gender,
      'address': address,
      'medicalCondition': medicalCondition,
      'notes': notes,
      'registrationDate': registrationDate, // Firestore parses DateTime as Timestamp automatically
      'assignedTherapistId': assignedTherapistId,
      'assignedTherapistName': assignedTherapistName,
      'isTemporarilyReassigned': isTemporarilyReassigned,
      'tempTherapistId': tempTherapistId,
      'tempTherapistName': tempTherapistName,
      'tempAssignmentDate': tempAssignmentDate,
      'tempAssignmentStartDate': tempAssignmentStartDate,
      'tempAssignmentEndDate': tempAssignmentEndDate,
      'tempAssignmentReason': tempAssignmentReason,
      'customerType': customerType,
      'consultationFee': consultationFee,
      'consultationPaymentStatus': consultationPaymentStatus,
      'consultationPaymentDate': consultationPaymentDate,
      'consultationNotes': consultationNotes,
      'paymentType': paymentType ?? (computedFeeWaiver ? 'feeWaiver' : 'regular'),
      'isFeeWaiver': computedFeeWaiver,
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
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

    String? parsePaymentStatus(dynamic status) {
      if (status == null) return null;
      if (status is bool) return status ? 'Paid' : 'Unpaid';
      return status.toString();
    }

    return PatientModel(
      patientId: map['patientId'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      age: map['age'] is num ? (map['age'] as num).toInt() : 0,
      gender: map['gender'] ?? '',
      address: map['address'] ?? '',
      medicalCondition: map['medicalCondition'] ?? '',
      notes: map['notes'] ?? '',
      registrationDate: parseDate(map['registrationDate']),
      assignedTherapistId: map['assignedTherapistId'],
      assignedTherapistName: map['assignedTherapistName'],
      isTemporarilyReassigned: map['isTemporarilyReassigned'] as bool?,
      tempTherapistId: map['tempTherapistId'],
      tempTherapistName: map['tempTherapistName'],
      tempAssignmentDate: parseNullableDate(map['tempAssignmentDate']),
      tempAssignmentStartDate: parseNullableDate(map['tempAssignmentStartDate']),
      tempAssignmentEndDate: parseNullableDate(map['tempAssignmentEndDate']),
      tempAssignmentReason: map['tempAssignmentReason'],
      customerType: map['customerType'] ?? 'therapy',
      consultationFee: map['consultationFee'] != null ? (map['consultationFee'] as num).toDouble() : 0.0,
      consultationPaymentStatus: parsePaymentStatus(map['consultationPaymentStatus']),
      consultationPaymentDate: parseNullableDate(map['consultationPaymentDate']),
      consultationNotes: map['consultationNotes'] as String?,
      paymentType: map['paymentType'] as String?,
      isFeeWaiver: map['isFeeWaiver'] as bool?,
    );
  }

  PatientModel revertAssignment() {
    return PatientModel(
      patientId: patientId,
      fullName: fullName,
      phone: phone,
      age: age,
      gender: gender,
      address: address,
      medicalCondition: medicalCondition,
      notes: notes,
      registrationDate: registrationDate,
      assignedTherapistId: assignedTherapistId,
      assignedTherapistName: assignedTherapistName,
      isTemporarilyReassigned: false,
      tempTherapistId: null,
      tempTherapistName: null,
      tempAssignmentDate: null,
      tempAssignmentStartDate: null,
      tempAssignmentEndDate: null,
      tempAssignmentReason: null,
      customerType: customerType,
      consultationFee: consultationFee,
      consultationPaymentStatus: consultationPaymentStatus,
      consultationPaymentDate: consultationPaymentDate,
      consultationNotes: consultationNotes,
      paymentType: paymentType,
      isFeeWaiver: isFeeWaiver,
    );
  }
}
