import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketplace UA',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primaryColor: const Color(0xFFAF0303),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFAF0303)),
      ),
      // Evaluamos la sesión solo una vez al arrancar la app
      home: FirebaseAuth.instance.currentUser != null && FirebaseAuth.instance.currentUser!.emailVerified
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}