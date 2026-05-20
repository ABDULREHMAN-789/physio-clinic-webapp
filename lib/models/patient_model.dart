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
  });

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
    );
  }

  Map<String, dynamic> toMap() {
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
    );
  }
}
