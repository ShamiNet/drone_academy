import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  final ApiService _apiService = ApiService();
  double _progressPercentage = 0.0;
  int _completedTrainings = 0;
  int _totalTrainings = 0;
  bool _isLoading = true;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    // 1. جلب كل التدريبات
    final trainings = await _apiService.fetchTrainings();

    // 2. جلب نتائج المستخدم الحالي (API يعرف المستخدم من الجلسة أو نمرره)
    // هنا سنفترض أننا نمرر ID المستخدم الحالي المخزن في ApiService.currentUser
    final currentUserId =
        ApiService.currentUser?['uid'] ?? ApiService.currentUser?['id'];

    if (currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await _apiService.fetchResults(traineeUid: currentUserId);

    final uniqueCompletedIds = <String>{};
    for (var r in results) {
      uniqueCompletedIds.add(r['trainingId']);
    }

    if (mounted) {
      setState(() {
        _totalTrainings = trainings.length;
        _completedTrainings = uniqueCompletedIds.length;
        _progressPercentage = _totalTrainings > 0
            ? (_completedTrainings / _totalTrainings)
            : 0.0;
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myProgress)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: CircularPercentIndicator(
                    radius: 100.0,
                    lineWidth: 15.0,
                    animation: true,
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
                        'Completed $_completedTrainings of $_totalTrainings',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17.0,
                        ),
                      ),
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: Colors.orange,
                  ),
                ),
                const Divider(thickness: 2),
                Expanded(
                  child: _results.isEmpty
                      ? EmptyStateWidget(
                          message: l10n.noResultsRecorded,
                          imagePath: 'assets/illustrations/no_data.svg',
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            // تأكد من تنسيق التاريخ
                            DateTime date = DateTime.now();
                            if (result['date'] != null)
                              date = DateTime.parse(result['date']);

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
                        ),
                ),
              ],
            ),
    );
  }
}
