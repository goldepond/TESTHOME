import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/login_page.dart';
import 'screens/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      print('Firebase already initialized, using existing app');
    }
  } catch (e) {
    print('Firebase initialization error (handled): $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HouseMVP - 집 찾기', 
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF8b5cf6),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF8b5cf6),
          secondary: const Color(0xFF6366f1),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}


