import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode) setThemeMode; // 1. إضافة المتغير

  const AuthGate({
    super.key,
    required this.setLocale,
    required this.setThemeMode, // 2. إضافته للمنشئ
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen(
            setLocale: setLocale,
            setThemeMode: setThemeMode, // 3. تمريره إلى HomeScreen
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
