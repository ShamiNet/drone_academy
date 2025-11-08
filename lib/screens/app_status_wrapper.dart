import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/maintenance_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppStatusWrapper extends StatelessWidget {
  final void Function(Locale) setLocale;
  const AppStatusWrapper({super.key, required this.setLocale});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      // Should not happen if the user is logged in, but as a safeguard
      return const Scaffold(
        body: Center(child: Text("Error: User not logged in.")),
      );
    }

    // Stream for global app configuration
    final appStatusStream = FirebaseFirestore.instance
        .collection('app_status')
        .doc('config')
        .snapshots();

    // Stream for the current user's status
    final userStatusStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: appStatusStream,
      builder: (context, appSnapshot) {
        if (!appSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final appConfig =
            appSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final isEnabled = appConfig['isEnabled'] ?? true;
        final forceUpdate = appConfig['forceUpdate'] ?? false;
        final maintenanceMessage =
            appConfig['maintenanceMessage'] ??
            'The app is currently under maintenance. Please try again later.';
        final updateUrl = appConfig['updateUrl'] ?? '';
        final updateMessage =
            appConfig['updateMessage'] ??
            'A new version of the app is available. Please update to continue.';

        if (forceUpdate) {
          return MaintenanceScreen(
            title: 'Update Required',
            message: updateMessage,
            buttonText: 'Update Now',
            url: updateUrl,
          );
        }

        if (!isEnabled) {
          return MaintenanceScreen(
            title: 'Maintenance',
            message: maintenanceMessage,
          );
        }

        // If app is enabled, check user status
        return StreamBuilder<DocumentSnapshot>(
          stream: userStatusStream,
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final isBlocked = userData['isBlocked'] ?? false;

            if (isBlocked) {
              return const MaintenanceScreen(
                title: 'Account Disabled',
                message:
                    'Your account has been disabled. Please contact support for assistance.',
              );
            }

            // If everything is fine, show the HomeScreen
            return HomeScreen(setLocale: setLocale);
          },
        );
      },
    );
  }
}
