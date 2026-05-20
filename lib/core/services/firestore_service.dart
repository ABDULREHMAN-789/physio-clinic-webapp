import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/patient_model.dart';
import '../../models/session_model.dart';
import 'firebase_service.dart';

abstract class FirestoreService {
  // Patients CRUD
  Stream<List<PatientModel>> streamPatients();
  Future<void> addPatient(PatientModel patient);
  Future<void> updatePatient(PatientModel patient);
  Future<void> deletePatient(String patientId);

  // Sessions CRUD
  Stream<List<SessionModel>> streamSessions();
  Future<void> addSession(SessionModel session);
  Future<void> updateSession(SessionModel session);
  Future<void> deleteSession(String sessionId);
}

// ----------------------------------------------------
// PRODUCTION FIRESTORE IMPLEMENTATION
// ----------------------------------------------------
class RealFirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<PatientModel>> streamPatients() {
    return _firestore
        .collection('patients')
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Set patientId to the document ID if not present
        if (data['patientId'] == null || (data['patientId'] as String).isEmpty) {
          data['patientId'] = doc.id;
        }
        return PatientModel.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<void> addPatient(PatientModel patient) async {
    final docRef = _firestore.collection('patients').doc(patient.patientId);
    await docRef.set(patient.toMap());
  }

  @override
  Future<void> updatePatient(PatientModel patient) async {
    final docRef = _firestore.collection('patients').doc(patient.patientId);
    await docRef.update(patient.toMap());
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
    
    final batch = _firestore.batch();
    for (var doc in sessionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<List<SessionModel>> streamSessions() {
    return _firestore
        .collection('sessions')
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['sessionId'] == null || (data['sessionId'] as String).isEmpty) {
          data['sessionId'] = doc.id;
        }
        return SessionModel.fromMap(data);
      }).toList();
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
}

// ----------------------------------------------------
// HIGH-FIDELITY MOCK/DEMO SERVICE IMPLEMENTATION
// ----------------------------------------------------
class MockFirestoreServiceImpl implements FirestoreService {
  // In-Memory Database Lists
  final List<PatientModel> _mockPatients = [];
  final List<SessionModel> _mockSessions = [];

  // Streams Controllers for Real-Time Updates
  final StreamController<List<PatientModel>> _patientsController =
      StreamController<List<PatientModel>>.broadcast();
  final StreamController<List<SessionModel>> _sessionsController =
      StreamController<List<SessionModel>>.broadcast();

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
        paymentStatus: true,
        nextRecommendation: 'Next session in 3 days. Focus on core activation.',
      ),
      SessionModel(
        sessionId: 'SE-102',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 75)),
        treatmentNotes: 'Lumbar stabilization exercises introduced. Patient tolerated exercises well. Spasms reduced. Administered manual traction.',
        charges: 2000.0,
        paymentStatus: true,
        nextRecommendation: 'Continue core stabilization twice weekly.',
      ),
      SessionModel(
        sessionId: 'SE-103',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 12)),
        treatmentNotes: 'Lumbar stabilization exercises progressed to dynamic postures. Pain scale reported at 3/10 (down from 8/10 initially). Dry needling done on gluteus medius.',
        charges: 2500.0,
        paymentStatus: true,
        nextRecommendation: 'Next session in one week.',
      ),
      SessionModel(
        sessionId: 'SE-104',
        patientId: 'PT-001',
        sessionDate: now.subtract(const Duration(days: 2)),
        treatmentNotes: 'Patient complained of minor stiffness after traveling. Applied heat, myofascial release on lower back, and light stretches.',
        charges: 2000.0,
        paymentStatus: false, // Unpaid
        nextRecommendation: 'Avoid heavy sitting. Follow home exercise plan.',
      ),

      // PT-002 (Sarah Smith) - 3 sessions (2 paid, 1 unpaid)
      SessionModel(
        sessionId: 'SE-201',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 55)),
        treatmentNotes: 'Shoulder impingement tests positive. Administered cold pack, ultrasound therapy, and active-assisted range of motion.',
        charges: 2500.0,
        paymentStatus: true,
        nextRecommendation: 'Ice pack at home 3 times daily. Next session in 4 days.',
      ),
      SessionModel(
        sessionId: 'SE-202',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 48)),
        treatmentNotes: 'Active elevation improved from 110 to 135 degrees. Scapular mobilization performed. Light isometric rotator cuff exercises started.',
        charges: 2500.0,
        paymentStatus: true,
        nextRecommendation: 'Progress to light yellow Theraband exercises.',
      ),
      SessionModel(
        sessionId: 'SE-203',
        patientId: 'PT-002',
        sessionDate: now.subtract(const Duration(days: 5)),
        treatmentNotes: 'Rotator cuff strengthening with Theraband. Scapular stability exercises. Shoulder pain minimal during active movements.',
        charges: 3000.0,
        paymentStatus: false, // Unpaid
        nextRecommendation: 'Gradual return to light tennis drills. Reassess in 5 days.',
      ),

      // PT-003 (Michael Johnson) - 2 sessions (1 paid, 1 unpaid)
      SessionModel(
        sessionId: 'SE-301',
        patientId: 'PT-003',
        sessionDate: now.subtract(const Duration(days: 40)),
        treatmentNotes: 'Knee flexion at 90 degrees, extension at 5 degrees. Focus on patellar gliding and quadriceps sets with neuromuscular stimulation.',
        charges: 2000.0,
        paymentStatus: true,
        nextRecommendation: 'Next session in 2 days.',
      ),
      SessionModel(
        sessionId: 'SE-302',
        patientId: 'PT-003',
        sessionDate: now.subtract(const Duration(days: 35)),
        treatmentNotes: 'Knee flexion improved to 105 degrees, extension at 2 degrees. Introduced stationary cycling (no resistance) and mini-squats.',
        charges: 2000.0,
        paymentStatus: false, // Unpaid
        nextRecommendation: 'Continue home range of motion and cycling.',
      ),

      // PT-004 (Emily Davis) - 1 session (unpaid)
      SessionModel(
        sessionId: 'SE-401',
        patientId: 'PT-004',
        sessionDate: now.subtract(const Duration(days: 15)),
        treatmentNotes: 'Arthritic knee pain management. Applied moist heat, did gentle passive hamstring stretching, and quad-strengthening straight leg raises.',
        charges: 1500.0,
        paymentStatus: false, // Unpaid
        nextRecommendation: 'Walk 10 mins daily on flat surfaces. Next session in 1 week.',
      ),
    ]);

    // Publish initial values to controllers
    _publishPatients();
    _publishSessions();
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



  @override
  Stream<List<PatientModel>> streamPatients() {
    // Publish immediately on subscribe
    Future.microtask(() => _publishPatients());
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
    _publishPatients();
    _publishSessions();
  }

  @override
  Stream<List<SessionModel>> streamSessions() {
    Future.microtask(() => _publishSessions());
    return _sessionsController.stream;
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
