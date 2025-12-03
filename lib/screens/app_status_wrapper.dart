import 'package:drone_academy/screens/home_screen.dart';
import 'package:drone_academy/screens/maintenance_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/loading_view.dart'; // استيراد الشاشة الجديدة
import 'package:flutter/material.dart';

class AppStatusWrapper extends StatelessWidget {
  final void Function(Locale) setLocale;
  final void Function(ThemeMode) setThemeMode;

  const AppStatusWrapper({
    super.key,
    required this.setLocale,
    required this.setThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();

    return StreamBuilder<Map<String, dynamic>>(
      stream: apiService.streamAppConfig(),
      builder: (context, appSnapshot) {
        // [تعديل] استخدام LoadingView بدلاً من Scaffold فارغ
        if (!appSnapshot.hasData) {
          return const LoadingView(message: "جاري التحقق من النظام...");
        }

        final appConfig = appSnapshot.data!;
        final isEnabled = appConfig['isEnabled'] ?? true;
        final forceUpdate = appConfig['forceUpdate'] ?? false;
        final maintenanceMessage =
            appConfig['maintenanceMessage'] ?? 'التطبيق في وضع الصيانة.';
        final updateUrl = appConfig['updateUrl'] ?? '';
        final updateMessage =
            appConfig['updateMessage'] ?? 'يرجى تحديث التطبيق للمتابعة.';

        if (forceUpdate) {
          return MaintenanceScreen(
            title: 'تحديث مطلوب',
            message: updateMessage,
            buttonText: 'تحديث الآن',
            url: updateUrl,
          );
        }

        if (!isEnabled) {
          return MaintenanceScreen(
            title: 'الصيانة',
            message: maintenanceMessage,
          );
        }

        return HomeScreen(setLocale: setLocale, setThemeMode: setThemeMode);
      },
    );
  }
}
