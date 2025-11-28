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
        // If the user is not logged in, go to the login screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // If the user is logged in, go to the home screen
        return HomeScreen(setLocale: setLocale, setThemeMode: setThemeMode);
      },
    );
  }
}
