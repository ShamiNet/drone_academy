import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/maintenance_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppStatusWrapper extends StatelessWidget {
  final void Function(Locale) setLocale;
  const AppStatusWrapper({super.key, required this.setLocale});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final ApiService apiService = ApiService();

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("Error: User not logged in.")),
      );
    }

    // استخدام ApiService بدلاً من Firestore
    return StreamBuilder<Map<String, dynamic>>(
      stream: apiService.streamAppConfig(),
      builder: (context, appSnapshot) {
        if (!appSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final appConfig = appSnapshot.data!;
        final isEnabled = appConfig['isEnabled'] ?? true;
        final forceUpdate = appConfig['forceUpdate'] ?? false;
        final maintenanceMessage =
            appConfig['maintenanceMessage'] ??
            'The app is currently under maintenance.';
        final updateUrl = appConfig['updateUrl'] ?? '';
        final updateMessage =
            appConfig['updateMessage'] ?? 'A new version is available.';

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

        return HomeScreen(setLocale: setLocale);
      },
    );
  }
}
