import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static bool _isFirebaseAvailable = false;
  static bool get isFirebaseAvailable => _isFirebaseAvailable;

  static Future<void> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey == 'PLACEHOLDER_API_KEY') {
        debugPrint('Firebase is in MOCK/DEMO mode. Real Firebase credentials not found.');
        _isFirebaseAvailable = false;
        return;
      }
      
      await Firebase.initializeApp(
        options: options,
      );
      _isFirebaseAvailable = true;
      debugPrint('Firebase initialized successfully in PRODUCTION mode.');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e. Falling back to MOCK/DEMO mode.');
      _isFirebaseAvailable = false;
    }
  }
}
