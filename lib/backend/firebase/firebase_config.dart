import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyAwsGmHtSWW9LdaO8R0I6wftQPkHtnUy94",
            authDomain: "mgpfunctions.firebaseapp.com",
            projectId: "mgpfunctions",
            storageBucket: "mgpfunctions.firebasestorage.app",
            messagingSenderId: "224974438083",
            appId: "1:224974438083:web:bc9f7aa83a1a9a28fcec76",
            measurementId: "G-FL3NDR09LN"));
  } else {
    await Firebase.initializeApp();
  }
}
