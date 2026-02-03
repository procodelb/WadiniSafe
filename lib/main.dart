import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart'; // User needs to generate this

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // await Firebase.initializeApp(); // Fallback if options not generated yet
  } catch (e) {
    debugPrint("Firebase init failed (expected if not configured): $e");
  }

  runApp(const ProviderScope(child: WadiniSafeApp()));
}
