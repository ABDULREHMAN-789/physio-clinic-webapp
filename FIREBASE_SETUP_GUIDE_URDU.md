# 🔥 Firebase Firestore Setup Guide - اردو میں

## Step 1️⃣: Firebase سے Service Account Key حاصل کریں

### اپنا Firebase Project console کھولیں:
1. **https://console.firebase.google.com/** پر جائیں
2. اپنا project **`physioease-4fde7`** select کریں
3. Left sidebar میں **⚙️ Project Settings** پر کلک کریں

### Service Account Key download کریں:
1. **"Service Accounts"** tab پر جائیں
2. **"Generate New Private Key"** button دیکھیں
3. اس button کو click کریں
4. **JSON file download** ہوگی

### Downloaded File کو صحیح جگہ رکھیں:
```
D:\Physio Therapy Clinic Web App\
├── firebase_setup.js
├── serviceAccountKey.json  ← یہاں رکھیں (project root میں)
├── lib\
├── pubspec.yaml
└── ...
```

---

## Step 2️⃣: Node.js اور npm انسٹال کریں

اگر آپ کے پاس Node.js نہیں ہے:

### Windows میں:
1. **https://nodejs.org/** سے download کریں (LTS version)
2. Installer کو run کریں اور install کریں
3. PowerShell/Command Prompt میں یہ command چلائیں:
```bash
node --version
npm --version
```

---

## Step 3️⃣: Firebase Admin SDK انسٹال کریں

Project root میں PowerShell/Command Prompt کھولیں اور یہ command چلائیں:

```bash
npm init -y
npm install firebase-admin
```

یہ commands:
- **`package.json`** فائل بنائیں گے
- **`firebase-admin`** package install کریں گے

---

## Step 4️⃣: Setup Script Run کریں

اب اپنا Firebase setup شروع کریں! 🚀

**Project root میں PowerShell/Command Prompt کھولیں اور یہ command چلائیں:**

```bash
node firebase_setup.js
```

### Output کی مثال:

```
✅ Firebase initialized successfully!

🔄 Firebase Firestore setup شروع ہو رہی ہے...

📝 Patients collection میں data add کیا جا رہا ہے...
  ✓ Patient added: John Doe (PT-001)
  ✓ Patient added: Sarah Smith (PT-002)
  ✓ Patient added: Michael Johnson (PT-003)
  ✓ Patient added: Emily Davis (PT-004)

📅 Sessions collection میں data add کیا جا رہا ہے...
  ✓ Session added: SE-101 (Patient: PT-001)
  ✓ Session added: SE-102 (Patient: PT-001)
  ... (مزید sessions)

✅ Firebase Setup مکمل ہوگیا!

================================================
📊 Total Records Added:
   👥 Patients: 4
   📅 Sessions: 10
================================================

🎉 اب اپنے app میں Firebase کو enable کریں!
```

---

## Step 5️⃣: Firebase Console میں Verify کریں

Script کے بعد verify کریں کہ data صحیح طریقے سے add ہوا:

1. **https://console.firebase.google.com/** کھولیں
2. اپنا project select کریں
3. Left sidebar میں **🗄️ Firestore Database** پر کلک کریں
4. یہ collections دیکھیں:
   - **`patients`** collection - 4 patients
   - **`sessions`** collection - 10 sessions

---

## Step 6️⃣: اپنے Flutter App میں Use کریں

### اپنی app میں Firebase use کرنے کے لیے:

**`lib/core/services/firestore_service.dart`** میں یہ line check کریں:

```dart
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  if (FirebaseService.isFirebaseAvailable) {
    return RealFirestoreServiceImpl();  // یہ استعمال ہوگی
  } else {
    return MockFirestoreServiceImpl();  // نہیں تو یہ
  }
});
```

✅ اگر Firebase available ہے تو **`RealFirestoreServiceImpl`** استعمال ہوگی  
✅ اب آپ کا اصل patient data دیکھ سکتے ہو!

---

## 🎯 Data Structure - جو Firebase میں save ہوا

### 👥 Patients Collection:
```
patients/
├── PT-001 (John Doe)
│   ├── fullName: "John Doe"
│   ├── phone: "03001234567"
│   ├── age: 42
│   ├── gender: "Male"
│   ├── address: "DHA Phase 6, Karachi"
│   ├── medicalCondition: "Chronic Lower Back Pain"
│   ├── notes: "..."
│   └── registrationDate: (timestamp)
│
├── PT-002 (Sarah Smith)
├── PT-003 (Michael Johnson)
└── PT-004 (Emily Davis)
```

### 📅 Sessions Collection:
```
sessions/
├── SE-101 (Patient: PT-001)
│   ├── patientId: "PT-001"
│   ├── sessionDate: (timestamp)
│   ├── treatmentNotes: "..."
│   ├── charges: 2000
│   ├── paymentStatus: true
│   └── nextRecommendation: "..."
│
└── (مزید sessions...)
```

---

## ⚠️ Troubleshooting

### Error: "serviceAccountKey.json نہیں ملا"
✅ **Solution**: serviceAccountKey.json کو project root میں رکھیں

### Error: "firebase-admin not found"
✅ **Solution**: یہ command چلائیں:
```bash
npm install firebase-admin
```

### Error: "Permission Denied"
✅ **Solution**: 
- اپنے Firebase console میں جائیں
- Firestore Database → Rules میں یہ دیکھیں:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write;
    }
  }
}
```

### Error: Project ID غلط ہے
✅ **Solution**: 
- `firebase_setup.js` میں یہ line check کریں:
```javascript
projectId: 'physioease-4fde7'
```

---

## ✅ Done!

اب آپ کے پاس Firebase میں مکمل patient data ہے! 🎉

### اگلا قدم:
1. ✅ Flutter app run کریں
2. ✅ Patients screen پر جائیں
3. ✅ تمام 4 patients دیکھیں
4. ✅ ہر patient کے sessions دیکھیں

---

**کوئی سوال ہو تو پوچھیں!** 🤝
