import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode)? setThemeMode;
  const AuthGate({super.key, required this.setLocale, this.setThemeMode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // [DEBUG] طباعة حالة المراقب
        debugPrint(
          '🔐 [AUTH GATE] ConnectionState: ${snapshot.connectionState}',
        );

        // في حالة الانتظار (أول لحظة)، اعرض دائرة تحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          debugPrint(
            '🔐 [AUTH GATE] User Detected: ${snapshot.data!.uid} -> Going to Home',
          );
          return HomeScreen(setLocale: setLocale);
        } else {
          debugPrint('🔐 [AUTH GATE] No User -> Going to Login');
          return const LoginScreen();
        }

        // If the user is logged in, go to the home screen
        return HomeScreen(setLocale: setLocale);
      },
    );
  }
}
