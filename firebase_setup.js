/**
 * Firebase Firestore Setup Script
 * یہ script Firebase میں تمام patient اور session records create کرے گا
 * 
 * استعمال: node firebase_setup.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Firebase initialize کریں
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'physioease-4fde7'
  });
  console.log('✅ Firebase initialized successfully!');
} catch (error) {
  console.error('❌ Error: serviceAccountKey.json نہیں ملا!');
  console.error('Firebase Console سے serviceAccountKey.json download کریں اور اسے project root میں رکھیں۔');
  process.exit(1);
}

const db = admin.firestore();

// ============================================
// PATIENT DATA
// ============================================
const patientsData = [
  {
    patientId: 'PT-001',
    fullName: 'John Doe',
    phone: '03001234567',
    age: 42,
    gender: 'Male',
    address: 'DHA Phase 6, Karachi',
    medicalCondition: 'Chronic Lower Back Pain',
    notes: 'Suffered injury during gym squatting. Requires lumbar stabilization exercises and manual traction twice weekly.',
    registrationDate: new Date(new Date().getTime() - 90 * 24 * 60 * 60 * 1000)
  },
  {
    patientId: 'PT-002',
    fullName: 'Sarah Smith',
    phone: '03217654321',
    age: 28,
    gender: 'Female',
    address: 'Clifton Block 5, Karachi',
    medicalCondition: 'Rotator Cuff Tendonitis',
    notes: 'Professional tennis player. Impingement on right shoulder. Needs active range of motion rehabilitation, ultrasound therapy, and rotator strengthening.',
    registrationDate: new Date(new Date().getTime() - 60 * 24 * 60 * 60 * 1000)
  },
  {
    patientId: 'PT-003',
    fullName: 'Michael Johnson',
    phone: '03339988776',
    age: 35,
    gender: 'Male',
    address: 'Gulshan-e-Iqbal, Karachi',
    medicalCondition: 'Post-op ACL Reconstruction',
    notes: 'Left knee ACL hamstring graft, 6 weeks post-surgery. Focusing on extension range of motion, patellar mobility, and quadriceps reactivation.',
    registrationDate: new Date(new Date().getTime() - 45 * 24 * 60 * 60 * 1000)
  },
  {
    patientId: 'PT-004',
    fullName: 'Emily Davis',
    phone: '03454433221',
    age: 65,
    gender: 'Female',
    address: 'PECHS Block 2, Karachi',
    medicalCondition: 'Knee Osteoarthritis',
    notes: 'Bilateral mild osteoarthritis. Pain management via heat therapy, gentle hamstring stretching, quadriceps strengthening, and balance training.',
    registrationDate: new Date(new Date().getTime() - 30 * 24 * 60 * 60 * 1000)
  }
];

// ============================================
// SESSION DATA
// ============================================
const sessionsData = [
  // PT-001 (John Doe) - 4 sessions
  {
    sessionId: 'SE-101',
    patientId: 'PT-001',
    sessionDate: new Date(new Date().getTime() - 80 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Initial Assessment. Lumbar spine range of motion restricted. Muscle spasm in erector spinae. Administered deep tissue release and moist heat.',
    charges: 2000.0,
    paymentStatus: true,
    nextRecommendation: 'Next session in 3 days. Focus on core activation.'
  },
  {
    sessionId: 'SE-102',
    patientId: 'PT-001',
    sessionDate: new Date(new Date().getTime() - 75 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Lumbar stabilization exercises introduced. Patient tolerated exercises well. Spasms reduced. Administered manual traction.',
    charges: 2000.0,
    paymentStatus: true,
    nextRecommendation: 'Continue core stabilization twice weekly.'
  },
  {
    sessionId: 'SE-103',
    patientId: 'PT-001',
    sessionDate: new Date(new Date().getTime() - 12 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Lumbar stabilization exercises progressed to dynamic postures. Pain scale reported at 3/10 (down from 8/10 initially). Dry needling done on gluteus medius.',
    charges: 2500.0,
    paymentStatus: true,
    nextRecommendation: 'Next session in one week.'
  },
  {
    sessionId: 'SE-104',
    patientId: 'PT-001',
    sessionDate: new Date(new Date().getTime() - 2 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Patient complained of minor stiffness after traveling. Applied heat, myofascial release on lower back, and light stretches.',
    charges: 2000.0,
    paymentStatus: false,
    nextRecommendation: 'Avoid heavy sitting. Follow home exercise plan.'
  },

  // PT-002 (Sarah Smith) - 3 sessions
  {
    sessionId: 'SE-201',
    patientId: 'PT-002',
    sessionDate: new Date(new Date().getTime() - 55 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Shoulder impingement tests positive. Administered cold pack, ultrasound therapy, and active-assisted range of motion.',
    charges: 2500.0,
    paymentStatus: true,
    nextRecommendation: 'Ice pack at home 3 times daily. Next session in 4 days.'
  },
  {
    sessionId: 'SE-202',
    patientId: 'PT-002',
    sessionDate: new Date(new Date().getTime() - 48 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Active elevation improved from 110 to 135 degrees. Scapular mobilization performed. Light isometric rotator cuff exercises started.',
    charges: 2500.0,
    paymentStatus: true,
    nextRecommendation: 'Progress to light yellow Theraband exercises.'
  },
  {
    sessionId: 'SE-203',
    patientId: 'PT-002',
    sessionDate: new Date(new Date().getTime() - 5 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Rotator cuff strengthening with Theraband. Scapular stability exercises. Shoulder pain minimal during active movements.',
    charges: 3000.0,
    paymentStatus: false,
    nextRecommendation: 'Gradual return to light tennis drills. Reassess in 5 days.'
  },

  // PT-003 (Michael Johnson) - 2 sessions
  {
    sessionId: 'SE-301',
    patientId: 'PT-003',
    sessionDate: new Date(new Date().getTime() - 40 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Knee flexion at 90 degrees, extension at 5 degrees. Focus on patellar gliding and quadriceps sets with neuromuscular stimulation.',
    charges: 2000.0,
    paymentStatus: true,
    nextRecommendation: 'Next session in 2 days.'
  },
  {
    sessionId: 'SE-302',
    patientId: 'PT-003',
    sessionDate: new Date(new Date().getTime() - 35 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Knee flexion improved to 105 degrees, extension at 2 degrees. Introduced stationary cycling (no resistance) and mini-squats.',
    charges: 2000.0,
    paymentStatus: false,
    nextRecommendation: 'Continue home range of motion and cycling.'
  },

  // PT-004 (Emily Davis) - 1 session
  {
    sessionId: 'SE-401',
    patientId: 'PT-004',
    sessionDate: new Date(new Date().getTime() - 15 * 24 * 60 * 60 * 1000),
    treatmentNotes: 'Arthritic knee pain management. Applied moist heat, did gentle passive hamstring stretching, and quad-strengthening straight leg raises.',
    charges: 1500.0,
    paymentStatus: false,
    nextRecommendation: 'Walk 10 mins daily on flat surfaces. Next session in 1 week.'
  }
];

// ============================================
// DATABASE SETUP FUNCTION
// ============================================
async function setupFirebase() {
  console.log('\n🔄 Firebase Firestore setup شروع ہو رہی ہے...\n');

  try {
    // Step 1: Patients Collection میں ڈیٹا add کریں
    console.log('📝 Patients collection میں data add کیا جا رہا ہے...');
    let patientCount = 0;
    for (const patient of patientsData) {
      await db.collection('patients').doc(patient.patientId).set(patient);
      patientCount++;
      console.log(`  ✓ Patient added: ${patient.fullName} (${patient.patientId})`);
    }

    // Step 2: Sessions Collection میں ڈیٹا add کریں
    console.log('\n📅 Sessions collection میں data add کیا جا رہا ہے...');
    let sessionCount = 0;
    for (const session of sessionsData) {
      await db.collection('sessions').doc(session.sessionId).set(session);
      sessionCount++;
      console.log(`  ✓ Session added: ${session.sessionId} (Patient: ${session.patientId})`);
    }

    // Success message
    console.log('\n✅ Firebase Setup مکمل ہوگیا!\n');
    console.log('=' .repeat(50));
    console.log(`📊 Total Records Added:`);
    console.log(`   👥 Patients: ${patientCount}`);
    console.log(`   📅 Sessions: ${sessionCount}`);
    console.log('=' .repeat(50));
    console.log('\n🎉 اب اپنے app میں Firebase کو enable کریں اور patient data دیکھ سکتے ہو!\n');

  } catch (error) {
    console.error('\n❌ Error occurred:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run setup
setupFirebase();
