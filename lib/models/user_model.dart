import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String role; // 'Admin' or 'Therapist'
  final String specialization;
  final String qualification;
  final String status; // 'Active' or 'Inactive'
  final DateTime createdAt;
  final double revenuePercentage;

  UserModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.specialization = '',
    this.qualification = '',
    required this.status,
    required this.createdAt,
    this.revenuePercentage = 0.0,
  });

  UserModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? specialization,
    String? qualification,
    String? status,
    DateTime? createdAt,
    double? revenuePercentage,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      qualification: qualification ?? this.qualification,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      revenuePercentage: revenuePercentage ?? this.revenuePercentage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'specialization': specialization,
      'qualification': qualification,
      'status': status,
      'createdAt': createdAt,
      'revenuePercentage': revenuePercentage,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
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

    return UserModel(
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'Therapist',
      specialization: map['specialization'] ?? '',
      qualification: map['qualification'] ?? '',
      status: map['status'] ?? 'Active',
      createdAt: parseDate(map['createdAt']),
      revenuePercentage: map['revenuePercentage'] is num ? (map['revenuePercentage'] as num).toDouble() : 0.0,
    );
  }
}
