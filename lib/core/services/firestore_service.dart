import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/patient_model.dart';
import '../../models/session_model.dart';
import '../../models/massage_chair_bill_model.dart';
import '../../models/reassignment_log_model.dart';
import 'firebase_service.dart';

abstract class FirestoreService {
  // Patients CRUD
  Stream<List<PatientModel>> streamPatients({String? therapistId});
  Future<void> addPatient(PatientModel patient);
  Future<void> updatePatient(PatientModel patient);
  Future<void> deletePatient(String patientId);

  // Sessions CRUD
  Stream<List<SessionModel>> streamSessions({String? therapistId});
  Stream<List<SessionModel>> streamSessionsForPatient(String patientId);
  Future<void> addSession(SessionModel session);
  Future<void> updateSession(SessionModel session);
  Future<void> deleteSession(String sessionId);

  // Massage Chair Bills CRUD
  Stream<List<MassageChairBillModel>> streamMassageChairBills();
  Future<void> addMassageChairBill(MassageChairBillModel bill);
  Future<void> updateMassageChairBill(MassageChairBillModel bill);
  Future<void> deleteMassageChairBill(String billId);

  // Reassignment Logs CRUD
  Stream<List<ReassignmentLogModel>> streamReassignmentLogs();
  Future<void> addReassignmentLog(ReassignmentLogModel log);
  Future<void> updateReassignmentLog(ReassignmentLogModel log);
}

// ----------------------------------------------------
// PRODUCTION FIRESTORE IMPLEMENTATION
// ----------------------------------------------------
class RealFirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<PatientModel>> streamPatients({String? therapistId}) {
    if (therapistId != null) {
      final controller = StreamController<List<PatientModel>>.broadcast();
      List<PatientModel> list1 = [];
      List<PatientModel> list2 = [];

      void emitMerged() {
        if (controller.isClosed) return;
        final mergedMap = <String, PatientModel>{};
        for (final p in list1) {
          mergedMap[p.patientId] = p;
        }
        for (final p in list2) {
          mergedMap[p.patientId] = p;
        }

        final filteredList = mergedMap.values.where((p) {
          final isAssigned = p.assignedTherapistId == therapistId;
          final isTemp = p.tempTherapistId == therapistId;
          final isReassigned = p.isTemporarilyReassigned ?? false;
          return isReassigned ? isTemp : isAssigned;
        }).toList();

        filteredList.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
        controller.add(filteredList);
      }

      final sub1 = _firestore
          .collection('patients')
          .where('assignedTherapistId', isEqualTo: therapistId)
          .snapshots()
          .listen((snapshot) {
        list1 = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          if (data['patientId'] == null || (data['patientId'] as String).isEmpty) {
            data['patientId'] = doc.id;
          }
          return PatientModel.fromMap(data);
        }).toList();
        emitMerged();
      }, onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      });

      final sub2 = _firestore
          .collection('patients')
          .where('tempTherapistId', isEqualTo: therapistId)
          .snapshots()
          .listen((snapshot) {
        list2 = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          if (data['patientId'] == null || (data['patientId'] as String).isEmpty) {
            data['patientId'] = doc.id;
          }
          return PatientModel.fromMap(data);
        }).toList();
        emitMerged();
      }, onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      });

      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
        controller.close();
      };

      return controller.stream;
    } else {
      return _firestore
          .collection('patients')
          .orderBy('registrationDate', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          if (data['patientId'] == null || (data['patientId'] as String).isEmpty) {
            data['patientId'] = doc.id;
          }
          return PatientModel.fromMap(data);
        }).toList();
      });
    }
  }

  @override
  Future<void> addPatient(PatientModel patient) async {
    final docRef = _firestore.collection('patients').doc(patient.patientId);
    await docRef.set(patient.toMap());
  }

  @override
  Future<void> updatePatient(PatientModel patient) async {
    print('FirestoreService: updatePatient called for patient: ${patient.fullName} (ID: ${patient.patientId}) in "patients"');
    try {
      final docRef = _firestore.collection('patients').doc(patient.patientId);
      await docRef.update(patient.toMap());
      print('FirestoreService: updatePatient SUCCESS for patient: ${patient.fullName}');
    } catch (e, stackTrace) {
      print('FirestoreService: updatePatient FAILED for patient: ${patient.fullName} - Error: $e');
      print('FirestoreService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deletePatient(String patientId) async {
    // 1. Delete patient document
    await _firestore.collection('patients').doc(patientId).delete();
    
    // 2. Delete all sessions belonging to this patient
    final sessionsSnapshot = await _firestore
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .get();
    
    // 3. Delete all massage chair bills belonging to this patient
    final mcBillsSnapshot = await _firestore
        .collection('massage_chair_bills')
        .where('customerId', isEqualTo: patientId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in sessionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    for (var doc in mcBillsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<List<SessionModel>> streamSessions({String? therapistId}) {
    Query query = _firestore.collection('sessions');
    if (therapistId != null) {
      query = query.where('therapistId', isEqualTo: therapistId);
    }
    return query
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        if (data['sessionId'] == null || (data['sessionId'] as String).isEmpty) {
          data['sessionId'] = doc.id;
        }
        return SessionModel.fromMap(data);
      }).toList();
    });
  }

  @override
  Stream<List<SessionModel>> streamSessionsForPatient(String patientId) {
    return _firestore
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['sessionId'] == null || (data['sessionId'] as String).isEmpty) {
          data['sessionId'] = doc.id;
        }
        return SessionModel.fromMap(data);
      }).toList();
      list.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      return list;
    });
  }

  @override
  Future<void> addSession(SessionModel session) async {
    final docRef = _firestore.collection('sessions').doc(session.sessionId);
    await docRef.set(session.toMap());
  }

  @override
  Future<void> updateSession(SessionModel session) async {
    final docRef = _firestore.collection('sessions').doc(session.sessionId);
    await docRef.update(session.toMap());
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  @override
  Stream<List<MassageChairBillModel>> streamMassageChairBills() {
    return _firestore
        .collection('massage_chair_bills')
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['billId'] == null || (data['billId'] as String).isEmpty) {
          data['billId'] = doc.id;
        }
        return MassageChairBillModel.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<void> addMassageChairBill(MassageChairBillModel bill) async {
    final docRef = _firestore.collection('massage_chair_bills').doc(bill.billId);
    await docRef.set(bill.toMap());
  }

  @override
  Future<void> updateMassageChairBill(MassageChairBillModel bill) async {
    final docRef = _firestore.collection('massage_chair_bills').doc(bill.billId);
    await docRef.update(bill.toMap());
  }

  @override
  Future<void> deleteMassageChairBill(String billId) async {
    await _firestore.collection('massage_chair_bills').doc(billId).delete();
  }

  @override
  Stream<List<ReassignmentLogModel>> streamReassignmentLogs() {
    print('FirestoreService: streamReassignmentLogs called for collection "reassignment_logs"');
    return _firestore
        .collection('reassignment_logs')
        .orderBy('assignmentDate', descending: true)
        .snapshots()
        .map((snapshot) {
          print('FirestoreService: streamReassignmentLogs success, returned ${snapshot.docs.length} documents.');
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['reassignmentId'] == null || (data['reassignmentId'] as String).isEmpty) {
              data['reassignmentId'] = doc.id;
            }
            return ReassignmentLogModel.fromMap(data);
          }).toList();
        })
        .handleError((error, stackTrace) {
          print('FirestoreService: streamReassignmentLogs error in snapshots stream: $error');
          print('FirestoreService: Stack trace: $stackTrace');
          throw error;
        });
  }

  @override
  Future<void> addReassignmentLog(ReassignmentLogModel log) async {
    print('FirestoreService: addReassignmentLog called for ID: ${log.reassignmentId} in "reassignment_logs"');
    try {
      final docRef = _firestore.collection('reassignment_logs').doc(log.reassignmentId);
      await docRef.set(log.toMap());
      print('FirestoreService: addReassignmentLog SUCCESS for ID: ${log.reassignmentId}');
    } catch (e, stackTrace) {
      print('FirestoreService: addReassignmentLog FAILED for ID: ${log.reassignmentId} - Error: $e');
      print('FirestoreService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateReassignmentLog(ReassignmentLogModel log) async {
    print('FirestoreService: updateReassignmentLog called for ID: ${log.reassignmentId} in "reassignment_logs"');
    try {
      final docRef = _firestore.collection('reassignment_logs').doc(log.reassignmentId);
      await docRef.update(log.toMap());
      print('FirestoreService: updateReassignmentLog SUCCESS for ID: ${log.reassignmentId}');
    } catch (e, stackTrace) {
      print('FirestoreService: updateReassignmentLog FAILED for ID: ${log.reassignmentId} - Error: $e');
      print('FirestoreService: Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// ----------------------------------------------------
// HIGH-FIDELITY MOCK/DEMO SERVICE IMPLEMENTATION
// ----------------------------------------------------
class MockFirestoreServiceImpl implements FirestoreService {
  // In-Memory Database Lists
  final List<PatientModel> _mockPatients = [];
  final List<SessionModel> _mockSessions = [];
  final List<MassageChairBillModel> _mockMassageChairBills = [];
  final List<ReassignmentLogModel> _mockReassignmentLogs = [];

  // Streams Controllers for Real-Time Updates
  final StreamController<List<PatientModel>> _patientsController =
      StreamController<List<PatientModel>>.broadcast();
  final StreamController<List<SessionModel>> _sessionsController =
      StreamController<List<SessionModel>>.broadcast();
  final StreamController<List<MassageChairBillModel>> _massageChairBillsController =
      StreamController<List<MassageChairBillModel>>.broadcast();
  final StreamController<List<ReassignmentLogModel>> _reassignmentLogsController =
      StreamController<List<ReassignmentLogModel>>.broadcast();

  MockFirestoreServiceImpl() {
    _seedMockData();
  }

  void _seedMockData() {
    final now = DateTime.now();

    // 1. Seed Patients
    _mockPatients.addAll([
      PatientModel(
        patientId: 'PT-001',
        fullName: 'John Doe',
        phone: '03001234567',
        age: 42,
        gender: 'Male',
        address: 'DHA Phase 6, Karachi',
        medicalCondition: 'Chronic Lower Back Pain',
        notes: 'Suffered injury during gym squatting. Requires lumbar stabilization exercises and manual traction twice weekly.',
        registrationDate: now.subtract(const Duration(days: 90)),
        assignedTherapistId: 'mock-therapist',
        assignedTherapistName: 'John Therapist',
      ),
      PatientModel(
        patientId: 'PT-002',
        fullName: 'Sarah Smith',
        phone: '03217654321',
        age: 28,
        gender: 'Female',
        address: 'Clifton Block 5, Karachi',
        medicalCondition: 'Rotator Cuff Tendonitis',
        notes: 'Professional tennis player. Impingement on right shoulder. Needs active range of motion rehabilitation, ultrasound therapy, and rotator strengthening.',
        registrationDate: now.subtract(const Duration(days: 60)),
        assignedTherapistId: 'mock-therapist',
        assignedTherapistName: 'John Therapist',
      ),
      PatientModel(
        patientId: 'PT-003',
        fullName: 'Michael Johnson',
        phone: '03339988776',
        age: 35,
        gender: 'Male',
        address: 'Gulshan-e-Iqbal, Karachi',
        medicalCondition: 'Post-op ACL Reconstruction',
        notes: 'Left knee ACL hamstring graft, 6 weeks post-surgery. Focusing on extension range of motion, patellar mobility, and quadriceps reactivation.',
        registrationDate: now.subtract(const Duration(days: 45)),
        assignedTherapistId: 'mock-therapist-b',
        assignedTherapistName: 'Sarah Therapist',
      ),
      PatientModel(
        patientId: 'PT-004',
        fullName: 'Emily Davis',
        phone: '03454433221',
        age: 65,
        gender: 'Female',
        address: 'PECHS Block 2, Karachi',
        medicalCondition: 'Knee Osteoarthritis',
        notes: 'Bilateral mild osteoarthritis. Pain management via heat therapy, gentle hamstring stretching, quadriceps strengthening, and balance training.',
        registrationDate: now.subtract(const Duration(days: 30)),
        assignedTherapistId: 'mock-therapist-b',
        assignedTherapistName: 'Sarah Therapist',
      ),
    ]);

    // 2. Seed Sessions (some paid, some unpaid)
    _mockSessions.addAll([
      // PT-001 (John Doe) - 4 sessions (3 paid, 1 unpaid)
      SessionModel(
        sessionId: 'SE-101',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 80)),
        treatmentNotes: 'Initial Assessment. Lumbar spine range of motion restricted. Muscle spasm in erector spinae. Administered deep tissue release and moist heat.',
        charges: 2000.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Next session in 3 days. Focus on core activation.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),
      SessionModel(
        sessionId: 'SE-102',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 75)),
        treatmentNotes: 'Lumbar stabilization exercises introduced. Patient tolerated exercises well. Spasms reduced. Administered manual traction.',
        charges: 2000.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Continue core stabilization twice weekly.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),
      SessionModel(
        sessionId: 'SE-103',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 12)),
        treatmentNotes: 'Lumbar stabilization exercises progressed to dynamic postures. Pain scale reported at 3/10 (down from 8/10 initially). Dry needling done on gluteus medius.',
        charges: 2500.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Next session in one week.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),
      SessionModel(
        sessionId: 'SE-104',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 2)),
        treatmentNotes: 'Patient complained of minor stiffness after traveling. Applied heat, myofascial release on lower back, and light stretches.',
        charges: 2000.0,
        paymentStatus: 'Unpaid', // Unpaid
        nextRecommendation: 'Avoid heavy sitting. Follow home exercise plan.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),

      // PT-002 (Sarah Smith) - 3 sessions (2 paid, 1 unpaid)
      SessionModel(
        sessionId: 'SE-201',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 55)),
        treatmentNotes: 'Shoulder impingement tests positive. Administered cold pack, ultrasound therapy, and active-assisted range of motion.',
        charges: 2500.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Ice pack at home 3 times daily. Next session in 4 days.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),
      SessionModel(
        sessionId: 'SE-202',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 48)),
        treatmentNotes: 'Active elevation improved from 110 to 135 degrees. Scapular mobilization performed. Light isometric rotator cuff exercises started.',
        charges: 2500.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Progress to light yellow Theraband exercises.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),
      SessionModel(
        sessionId: 'SE-203',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 5)),
        treatmentNotes: 'Rotator cuff strengthening with Theraband. Scapular stability exercises. Shoulder pain minimal during active movements.',
        charges: 3000.0,
        paymentStatus: 'Unpaid', // Unpaid
        nextRecommendation: 'Gradual return to light tennis drills. Reassess in 5 days.',
        therapistId: 'mock-therapist',
        therapistName: 'John Therapist',
      ),

      // PT-003 (Michael Johnson) - 2 sessions (1 paid, 1 unpaid)
      SessionModel(
        sessionId: 'SE-301',
        patientId: 'PT-003',
        sessionDate: now.subtract(const Duration(days: 40)),
        treatmentNotes: 'Knee flexion at 90 degrees, extension at 5 degrees. Focus on patellar gliding and quadriceps sets with neuromuscular stimulation.',
        charges: 2000.0,
        paymentStatus: 'Paid',
        nextRecommendation: 'Next session in 2 days.',
        therapistId: 'mock-therapist-b',
        therapistName: 'Sarah Therapist',
      ),
      SessionModel(
        sessionId: 'SE-302',
        patientId: 'PT-003',
        sessionDate: now.subtract(const Duration(days: 35)),
        treatmentNotes: 'Knee flexion improved to 105 degrees, extension at 2 degrees. Introduced stationary cycling (no resistance) and mini-squats.',
        charges: 2000.0,
        paymentStatus: 'Unpaid', // Unpaid
        nextRecommendation: 'Continue home range of motion and cycling.',
        therapistId: 'mock-therapist-b',
        therapistName: 'Sarah Therapist',
      ),

      // PT-004 (Emily Davis) - 1 session (unpaid)
      SessionModel(
        sessionId: 'SE-401',
        patientId: 'PT-004',
        sessionDate: now.subtract(const Duration(days: 15)),
        treatmentNotes: 'Arthritic knee pain management. Applied moist heat, did gentle passive hamstring stretching, and quad-strengthening straight leg raises.',
        charges: 1500.0,
        paymentStatus: 'Unpaid', // Unpaid
        nextRecommendation: 'Walk 10 mins daily on flat surfaces. Next session in 1 week.',
        therapistId: 'mock-therapist-b',
        therapistName: 'Sarah Therapist',
      ),
    ]);

    // 3. Seed Massage Chair Customers
    _mockPatients.addAll([
      PatientModel(
        patientId: 'MC-001',
        fullName: 'Ali Hassan',
        phone: '03111222333',
        age: 50,
        gender: 'Male',
        address: 'Nazimabad Block 3, Karachi',
        medicalCondition: '',
        notes: '',
        registrationDate: now.subtract(const Duration(days: 20)),
        customerType: 'massage_chair',
      ),
      PatientModel(
        patientId: 'MC-002',
        fullName: 'Fatima Noor',
        phone: '03229988771',
        age: 38,
        gender: 'Female',
        address: 'Bahria Town Phase 4, Karachi',
        medicalCondition: '',
        notes: '',
        registrationDate: now.subtract(const Duration(days: 10)),
        customerType: 'massage_chair',
      ),
    ]);

    // 4. Seed Massage Chair Bills
    _mockMassageChairBills.addAll([
      MassageChairBillModel(
        billId: 'MCB-001',
        customerId: 'MC-001',
        customerName: 'Ali Hassan',
        sessionDate: now.subtract(const Duration(days: 20)),
        duration: '30 minutes',
        fee: 500.0,
        paymentStatus: 'Paid',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      MassageChairBillModel(
        billId: 'MCB-002',
        customerId: 'MC-001',
        customerName: 'Ali Hassan',
        sessionDate: now.subtract(const Duration(days: 7)),
        duration: '45 minutes',
        fee: 700.0,
        paymentStatus: 'Unpaid',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      MassageChairBillModel(
        billId: 'MCB-003',
        customerId: 'MC-002',
        customerName: 'Fatima Noor',
        sessionDate: now.subtract(const Duration(days: 10)),
        duration: '30 minutes',
        fee: 500.0,
        paymentStatus: 'Paid',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ]);

    // Publish initial values to controllers
    _publishPatients();
    _publishSessions();
    _publishMassageChairBills();
    _publishReassignmentLogs();
  }

  void _publishPatients() {
    // Sort descending by registrationDate
    final sorted = List<PatientModel>.from(_mockPatients)
      ..sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
    _patientsController.add(sorted);
  }

  void _publishSessions() {
    // Sort descending by sessionDate
    final sorted = List<SessionModel>.from(_mockSessions)
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    _sessionsController.add(sorted);
  }

  void _publishMassageChairBills() {
    final sorted = List<MassageChairBillModel>.from(_mockMassageChairBills)
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    _massageChairBillsController.add(sorted);
  }

  void _publishReassignmentLogs() {
    final sorted = List<ReassignmentLogModel>.from(_mockReassignmentLogs)
      ..sort((a, b) => b.assignmentDate.compareTo(a.assignmentDate));
    _reassignmentLogsController.add(sorted);
  }

  @override
  Stream<List<PatientModel>> streamPatients({String? therapistId}) {
    Future.microtask(() => _publishPatients());
    if (therapistId != null) {
      return _patientsController.stream.map((list) {
        return list.where((p) {
          final isAssigned = p.assignedTherapistId == therapistId;
          final isTemp = p.tempTherapistId == therapistId;
          final isReassigned = p.isTemporarilyReassigned ?? false;
          return isReassigned ? isTemp : isAssigned;
        }).toList();
      });
    }
    return _patientsController.stream;
  }

  @override
  Future<void> addPatient(PatientModel patient) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockPatients.add(patient);
    _publishPatients();
  }

  @override
  Future<void> updatePatient(PatientModel patient) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockPatients.indexWhere((p) => p.patientId == patient.patientId);
    if (index != -1) {
      _mockPatients[index] = patient;
      _publishPatients();
    }
  }

  @override
  Future<void> deletePatient(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Remove patient
    _mockPatients.removeWhere((p) => p.patientId == patientId);
    // Cascade delete sessions
    _mockSessions.removeWhere((s) => s.patientId == patientId);
    // Cascade delete massage bills
    _mockMassageChairBills.removeWhere((b) => b.customerId == patientId);
    _publishPatients();
    _publishSessions();
    _publishMassageChairBills();
  }

  @override
  Stream<List<SessionModel>> streamSessions({String? therapistId}) {
    Future.microtask(() => _publishSessions());
    if (therapistId != null) {
      return _sessionsController.stream.map((list) => list.where((s) => s.therapistId == therapistId).toList());
    }
    return _sessionsController.stream;
  }

  @override
  Stream<List<SessionModel>> streamSessionsForPatient(String patientId) {
    Future.microtask(() => _publishSessions());
    return _sessionsController.stream.map((list) {
      final filtered = list.where((s) => s.patientId == patientId).toList();
      filtered.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      return filtered;
    });
  }

  @override
  Future<void> addSession(SessionModel session) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockSessions.add(session);
    _publishSessions();
  }

  @override
  Future<void> updateSession(SessionModel session) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockSessions.indexWhere((s) => s.sessionId == session.sessionId);
    if (index != -1) {
      _mockSessions[index] = session;
      _publishSessions();
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockSessions.removeWhere((s) => s.sessionId == sessionId);
    _publishSessions();
  }

  @override
  Stream<List<MassageChairBillModel>> streamMassageChairBills() {
    Future.microtask(() => _publishMassageChairBills());
    return _massageChairBillsController.stream;
  }

  @override
  Future<void> addMassageChairBill(MassageChairBillModel bill) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockMassageChairBills.add(bill);
    _publishMassageChairBills();
  }

  @override
  Future<void> updateMassageChairBill(MassageChairBillModel bill) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockMassageChairBills.indexWhere((b) => b.billId == bill.billId);
    if (index != -1) {
      _mockMassageChairBills[index] = bill;
      _publishMassageChairBills();
    }
  }

  @override
  Future<void> deleteMassageChairBill(String billId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockMassageChairBills.removeWhere((b) => b.billId == billId);
    _publishMassageChairBills();
  }

  @override
  Stream<List<ReassignmentLogModel>> streamReassignmentLogs() {
    Future.microtask(() => _publishReassignmentLogs());
    return _reassignmentLogsController.stream;
  }

  @override
  Future<void> addReassignmentLog(ReassignmentLogModel log) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockReassignmentLogs.add(log);
    _publishReassignmentLogs();
  }

  @override
  Future<void> updateReassignmentLog(ReassignmentLogModel log) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockReassignmentLogs.indexWhere((l) => l.reassignmentId == log.reassignmentId);
    if (index != -1) {
      _mockReassignmentLogs[index] = log;
      _publishReassignmentLogs();
    }
  }
}

// ----------------------------------------------------
// RIVERPOD SERVICE PROVIDERS
// ----------------------------------------------------

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  if (FirebaseService.isFirebaseAvailable) {
    return RealFirestoreServiceImpl();
  } else {
    // Fall back to Mock mode
    return MockFirestoreServiceImpl();
  }
});
