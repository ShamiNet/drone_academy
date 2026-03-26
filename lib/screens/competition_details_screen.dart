import 'package:drone_academy/screens/competition_timer_screen.dart';
import 'package:drone_academy/screens/leaderboard_screen.dart';
import 'package:drone_academy/screens/select_trainee_for_test_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompetitionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> competition; // تم التغيير إلى Map
  final bool viewOnly; // إضافة parameter لتحديد وضع المشاهدة

  const CompetitionDetailsScreen({
    super.key,
    required this.competition,
    this.viewOnly = false, // افتراضياً false للحفاظ على السلوك الحالي
  });

  @override
  Widget build(BuildContext context) {
    final String title = competition['title'] ?? 'No Title';
    final String description = competition['description'] ?? 'No Description';

    // نحتاج لبيانات المتدرب الحالية لبدء المؤقت
    // للتبسيط سننشئ كائن بسيط، أو يمكن جلبه من البروفايل
    // في حالة الاستخدام الحقيقي يفضل تمرير بيانات المتدرب من الشاشة السابقة
    final currentUser = FirebaseAuth.instance.currentUser;
    final traineeDoc = {
      'id': currentUser?.uid ?? '',
      'displayName': currentUser?.displayName ?? 'Unknown',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Challenge Details & Rules',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const Spacer(),

            OutlinedButton.icon(
              icon: const Icon(Icons.leaderboard),
              label: const Text('View Leaderboard'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LeaderboardScreen(competition: competition),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),

            if (!viewOnly &&
                (ApiService.currentUser?['role'] == 'admin' ||
                    ApiService.currentUser?['role'] == 'owner'))
              OutlinedButton.icon(
                icon: const Icon(Icons.person_search),
                label: const Text('اختبار متدرب'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SelectTraineeForTestScreen(competition: competition),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            const SizedBox(height: 10),

            if (!viewOnly &&
                (ApiService.currentUser?['role'] == 'admin' ||
                    ApiService.currentUser?['role'] ==
                        'owner')) // إظهار زر البدء فقط للأدمن والأونر في وضع غير المشاهدة
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompetitionTimerScreen(
                        competition: competition,
                        traineeDoc: traineeDoc, // تمرير بيانات مبسطة
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  'Start Challenge!',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
