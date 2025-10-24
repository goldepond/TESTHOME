import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/main_page.dart';

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
        primaryColor: AppColors.kPrimary,
        scaffoldBackgroundColor: AppColors.kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.kPrimary,
          primary: AppColors.kPrimary,
          secondary: AppColors.kSecondary,
          surface: AppColors.kSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.kPrimary,
            side: BorderSide(color: AppColors.kPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.kPrimary,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.kPrimary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      home: const MainPage(
        userId: '',
        userName: '',
      ),
    );
  }
}


