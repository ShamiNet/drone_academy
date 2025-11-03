import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // 1. استيراد الحزمة الجديدة

// 2. تحويل الشاشة إلى StatefulWidget
class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  // 3. متغيرات لتخزين بيانات التقدم
  double _progressPercentage = 0.0;
  int _completedTrainings = 0;
  int _totalTrainings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  // 4. دالة لجلب البيانات وحساب النسبة المئوية
  Future<void> _loadProgressData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // جلب عدد التدريبات الكلي
    final totalTrainingsFuture = FirebaseFirestore.instance
        .collection('trainings')
        .count()
        .get();

    // جلب كل نتائج المتدرب
    final traineeResultsFuture = FirebaseFirestore.instance
        .collection('results')
        .where('traineeUid', isEqualTo: currentUser.uid)
        .get();

    final results = await Future.wait([
      totalTrainingsFuture,
      traineeResultsFuture,
    ]);

    final totalCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final traineeResultsDocs = (results[1] as QuerySnapshot).docs;

    // استخدام Set لضمان حساب كل تدريب مرة واحدة فقط
    final uniqueCompletedIds = <String>{};
    for (var doc in traineeResultsDocs) {
      uniqueCompletedIds.add(doc['trainingId']);
    }

    final completedCount = uniqueCompletedIds.length;

    if (mounted) {
      setState(() {
        _totalTrainings = totalCount;
        _completedTrainings = completedCount;
        _progressPercentage = (totalCount > 0)
            ? (completedCount / totalCount)
            : 0.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myProgress)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 5. قسم دائرة التقدم الجديد
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: CircularPercentIndicator(
                    radius: 100.0,
                    lineWidth: 15.0,
                    animation: true,
                    animationDuration: 1200,
                    percent: _progressPercentage,
                    center: Text(
                      '${(_progressPercentage * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 32.0,
                      ),
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'You have completed $_completedTrainings of $_totalTrainings trainings',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17.0,
                        ),
                      ),
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const Divider(thickness: 2),

                // 6. قائمة النتائج السابقة (تبقى كما هي)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('results')
                        .where('traineeUid', isEqualTo: currentUser!.uid)
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return EmptyStateWidget(
                          message: l10n.noResultsRecorded,
                          imagePath: 'assets/illustrations/no_data.svg',
                        );
                      }
                      final results = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          final date = (result['date'] as Timestamp).toDate();
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              title: Text(result['trainingTitle'] ?? ''),
                              subtitle: Text(
                                DateFormat.yMMMd().add_jm().format(date),
                              ),
                              trailing: Text(
                                '${result['masteryPercentage']}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
