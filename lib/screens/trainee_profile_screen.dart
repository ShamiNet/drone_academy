import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/competition_timer_screen.dart';
import 'package:drone_academy/screens/leaderboard_screen.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drone_academy/utils/pdf_generator.dart'; // تأكد من وجود ملف PDF المحدث
import 'package:drone_academy/screens/report_generation_dialogs.dart'; // لاستخدام showReportReadyDialog
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:drone_academy/screens/schedule_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/widgets/ai_summary_widget.dart';

class TraineeProfileScreen extends StatefulWidget {
  final DocumentSnapshot traineeData;
  const TraineeProfileScreen({super.key, required this.traineeData});

  @override
  State<TraineeProfileScreen> createState() => _TraineeProfileScreenState();
}

enum _SortOption { level, mastery, name }

class _TraineeProfileScreenState extends State<TraineeProfileScreen> {
  late AppLocalizations l10n;
  List<DocumentSnapshot>? _allTrainings;
  bool _isLoadingTrainings = true;
  double _progressPercentage = 0.0;
  int _completedTrainings = 0;
  int _totalTrainings = 0;
  double _averageMasteryPercentage = 0.0;
  bool _isLoadingStats = true;
  List<DocumentSnapshot> _chartableTrainings = [];
  String? _selectedTrainingIdForChart;
  List<FlSpot> _chartData = [];
  String? _aiSummary;
  bool _isAnalyzing = false;

  // متغيرات الفلترة والترتيب
  bool _showOnlyWithResults = false;
  _SortOption _sortOption = _SortOption.level;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAllTrainings();
    await _loadProgressData();
  }

  Future<void> _loadAllTrainings() async {
    final trainingsSnapshot = await FirebaseFirestore.instance
        .collection('trainings')
        .orderBy('level')
        .get();
    if (mounted) {
      setState(() {
        _allTrainings = trainingsSnapshot.docs;
        _isLoadingTrainings = false;
      });
    }
  }

  Future<void> _loadProgressData() async {
    if (_allTrainings == null) return;
    final traineeId = widget.traineeData.id;
    final totalTrainingsFuture = FirebaseFirestore.instance
        .collection('trainings')
        .count()
        .get();
    final traineeResultsFuture = FirebaseFirestore.instance
        .collection('results')
        .where('traineeUid', isEqualTo: traineeId)
        .get();

    final results = await Future.wait([
      totalTrainingsFuture,
      traineeResultsFuture,
    ]);

    final totalCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final traineeResultsDocs = (results[1] as QuerySnapshot).docs;

    final uniqueCompletedIds = <String>{};
    for (var doc in traineeResultsDocs) {
      uniqueCompletedIds.add(doc['trainingId']);
    }

    double totalMastery = 0;
    if (traineeResultsDocs.isNotEmpty) {
      for (var doc in traineeResultsDocs) {
        totalMastery += (doc['masteryPercentage'] as num?) ?? 0;
      }
      _averageMasteryPercentage = totalMastery / traineeResultsDocs.length;
    }

    final Map<String, List<DocumentSnapshot>> resultsGroupedByTraining = {};
    for (var result in traineeResultsDocs) {
      final trainingId = result['trainingId'] as String;
      if (resultsGroupedByTraining[trainingId] == null) {
        resultsGroupedByTraining[trainingId] = [];
      }
      resultsGroupedByTraining[trainingId]!.add(result);
    }

    final chartable = <DocumentSnapshot>[];
    if (_allTrainings != null) {
      resultsGroupedByTraining.forEach((trainingId, resultsList) {
        if (resultsList.length > 1) {
          try {
            final trainingDoc = _allTrainings!.firstWhere(
              (doc) => doc.id == trainingId,
            );
            chartable.add(trainingDoc);
          } catch (e) {
            print('Training doc not found for id: $trainingId');
          }
        }
      });
    }

    if (mounted) {
      setState(() {
        _totalTrainings = totalCount;
        _completedTrainings = uniqueCompletedIds.length;
        _progressPercentage = (totalCount > 0)
            ? (uniqueCompletedIds.length / totalCount).clamp(0.0, 1.0)
            : 0.0;
        _isLoadingStats = false;
        _chartableTrainings = chartable;
      });
    }
  }

  void _generateChartData(String trainingId) async {
    final resultsSnapshot = await FirebaseFirestore.instance
        .collection('results')
        .where('traineeUid', isEqualTo: widget.traineeData.id)
        .where('trainingId', isEqualTo: trainingId)
        .orderBy('date', descending: false)
        .get();

    final spots = <FlSpot>[];
    for (var i = 0; i < resultsSnapshot.docs.length; i++) {
      final doc = resultsSnapshot.docs[i];
      final y = (doc['masteryPercentage'] as int).toDouble();
      spots.add(FlSpot(i.toDouble(), y));
    }

    setState(() {
      _selectedTrainingIdForChart = trainingId;
      _chartData = spots;
    });
  }

  Future<void> _analyzeNotes() async {
    setState(() => _isAnalyzing = true);
    final notesSnapshot = await FirebaseFirestore.instance
        .collection('daily_notes')
        .where('traineeUid', isEqualTo: widget.traineeData.id)
        .get();

    final notesList = notesSnapshot.docs
        .map((doc) => doc['note'] as String)
        .toList();
    final summary = await AiAnalyzerService.summarizeTraineeNotes(notesList);

    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _isAnalyzing = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  // --- دالة توليد التقرير الفردي (المنطق الجديد) ---
  Future<void> _generateSingleReport() async {
    final name = widget.traineeData['displayName'] ?? 'No Name';

    // 1. إظهار نافذة التحميل مباشرة
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2230),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const CircularProgressIndicator(color: Color(0xFF8FA1B4)),
        ),
      ),
    );

    try {
      // 2. جلب البيانات
      final resultsSnapshot = await FirebaseFirestore.instance
          .collection('results')
          .where('traineeUid', isEqualTo: widget.traineeData.id)
          .orderBy('date', descending: true)
          .get();

      final notesSnapshot = await FirebaseFirestore.instance
          .collection('daily_notes')
          .where('traineeUid', isEqualTo: widget.traineeData.id)
          .orderBy('date', descending: true)
          .get();

      // 3. تحليل الذكاء الاصطناعي (إذا لم يكن موجوداً)
      String? aiSummary = _aiSummary;
      if (aiSummary == null && notesSnapshot.docs.isNotEmpty) {
        final notesList = notesSnapshot.docs
            .map((doc) => doc['note'] as String)
            .toList();
        aiSummary = await AiAnalyzerService.summarizeTraineeNotes(notesList);
      }

      // 4. حساب تقدم المستوى
      LevelProgress? levelProgress;
      if (_allTrainings != null) {
        final completedTrainingIds = resultsSnapshot.docs
            .map((doc) => doc['trainingId'] as String)
            .toSet();
        int highestLevel = 0;
        for (var training in _allTrainings!) {
          if (completedTrainingIds.contains(training.id)) {
            final level = training['level'] as int? ?? 0;
            if (level > highestLevel) highestLevel = level;
          }
        }
        if (highestLevel > 0) {
          final trainingsInLevel = _allTrainings!
              .where((t) => (t['level'] as int? ?? 0) == highestLevel)
              .toList();
          int completedInLevel = trainingsInLevel
              .where((t) => completedTrainingIds.contains(t.id))
              .length;
          levelProgress = LevelProgress(
            level: highestLevel,
            completedTrainings: completedInLevel,
            totalTrainingsInLevel: trainingsInLevel.length,
          );
        }
      }

      // 5. إنشاء PDF (بالنسخة المستقرة بدون علامة مائية)
      final pdfDoc = await createPdfDocument(
        traineeName: name,
        results: resultsSnapshot.docs,
        notes: notesSnapshot.docs,
        aiSummary: aiSummary,
        levelProgress: levelProgress,
        averageMastery: _averageMasteryPercentage,
      );

      if (mounted) {
        Navigator.pop(context); // إخفاء التحميل
        // 6. عرض نافذة "التقرير جاهز"
        showReportReadyDialog(context, pdfDoc);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- واجهة المستخدم ---
  @override
  Widget build(BuildContext context) {
    final String name = widget.traineeData['displayName'] ?? 'No Name';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateSingleReport,
          ),
        ],
      ),
      body: _isLoadingStats || _isLoadingTrainings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatIndicator(
                        percent: _progressPercentage,
                        label:
                            '${(_progressPercentage * 100).toStringAsFixed(0)}%',
                        footer:
                            '$_completedTrainings / $_totalTrainings\n${l10n.trainingsCompleted}',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      _buildStatIndicator(
                        percent: _averageMasteryPercentage / 100,
                        label:
                            '${_averageMasteryPercentage.toStringAsFixed(0)}%',
                        footer: l10n.mastery,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),

                if (_chartableTrainings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scoreEvolution,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 1),
                        DropdownButton<String>(
                          hint: Text(l10n.selectTrainingToSeeProgress),
                          value: _selectedTrainingIdForChart,
                          isExpanded: true,
                          items: _chartableTrainings.map((doc) {
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(doc['title']),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              _generateChartData(value);
                            }
                          },
                        ),
                        if (_chartData.isNotEmpty)
                          SizedBox(
                            height: 170,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: LineChart(
                                LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _chartData,
                                      isCurved: true,
                                      barWidth: 4,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                  ],
                                  titlesData: const FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: true),
                                    ),
                                  ),
                                  gridData: const FlGridData(show: true),
                                  borderData: FlBorderData(show: true),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(thickness: 3),
                _buildAiSummaryCard(),
                const Divider(thickness: 2),
                DefaultTabController(
                  length: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                            text: l10n.results,
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                          Tab(
                            text: l10n.dailyNotes,
                            icon: const Icon(Icons.note_alt_outlined),
                          ),
                          Tab(
                            text: l10n.schedule,
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildResultsTab(),
                            _buildNotesTab(),
                            ScheduleScreen(traineeId: widget.traineeData.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAiSummaryCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiPerformanceAnalysis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_isAnalyzing)
                const Center(child: CircularProgressIndicator())
              else if (_aiSummary != null)
                AiSummaryWidget(summary: _aiSummary!)
              else
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.analyzeNotesNow),
                    onPressed: _analyzeNotes,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<_SortOption>(
                  value: _sortOption,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: _SortOption.level,
                      child: Text(l10n.sortByLevel),
                    ),
                    DropdownMenuItem(
                      value: _SortOption.mastery,
                      child: Text(l10n.sortByMastery),
                    ),
                    DropdownMenuItem(
                      value: _SortOption.name,
                      child: Text(l10n.sortByName),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortOption = value);
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () =>
                    setState(() => _sortAscending = !_sortAscending),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: Text(l10n.showOnlyWithResults),
          value: _showOnlyWithResults,
          onChanged: (value) => setState(() => _showOnlyWithResults = value),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('results')
                .where('traineeUid', isEqualTo: widget.traineeData.id)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return const Center(child: Text('Error loading data.'));

              final traineeResults = snapshot.data?.docs ?? [];
              final Map<String, List<DocumentSnapshot>>
              resultsGroupedByTraining = {};
              for (var result in traineeResults) {
                final trainingId = result['trainingId'] as String;
                if (resultsGroupedByTraining[trainingId] == null) {
                  resultsGroupedByTraining[trainingId] = [];
                }
                resultsGroupedByTraining[trainingId]!.add(result);
              }

              var displayedTrainings = _showOnlyWithResults
                  ? _allTrainings!
                        .where(
                          (t) => resultsGroupedByTraining.containsKey(t.id),
                        )
                        .toList()
                  : _allTrainings!.toList();

              displayedTrainings.sort((a, b) {
                int comparison;
                switch (_sortOption) {
                  case _SortOption.level:
                    comparison = (a['level'] as int? ?? 0).compareTo(
                      b['level'] as int? ?? 0,
                    );
                    break;
                  case _SortOption.mastery:
                    final scoreA =
                        resultsGroupedByTraining[a.id]
                                ?.first['masteryPercentage']
                            as int? ??
                        -1;
                    final scoreB =
                        resultsGroupedByTraining[b.id]
                                ?.first['masteryPercentage']
                            as int? ??
                        -1;
                    comparison = scoreA.compareTo(scoreB);
                    break;
                  case _SortOption.name:
                    comparison = (a['title'] as String? ?? '').compareTo(
                      b['title'] as String? ?? '',
                    );
                    break;
                }
                return _sortAscending ? comparison : -comparison;
              });

              if (displayedTrainings.isEmpty) {
                return EmptyStateWidget(
                  message: l10n.noTrainingsAvailable,
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              }

              return ListView.builder(
                itemCount: displayedTrainings.length,
                itemBuilder: (context, index) {
                  final training = displayedTrainings[index];
                  final resultsForThisTraining =
                      resultsGroupedByTraining[training.id];

                  if (resultsForThisTraining != null &&
                      resultsForThisTraining.isNotEmpty) {
                    final latestResult = resultsForThisTraining.first;
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          training['title'] ?? l10n.training,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${l10n.latestScore}: ${latestResult['masteryPercentage']}%',
                        ),
                        leading: const Icon(Icons.history, color: Colors.green),
                        trailing: Text(
                          '${latestResult['masteryPercentage']}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                        children: resultsForThisTraining.map((result) {
                          final date = (result['date'] as Timestamp).toDate();
                          final trainerName = result['trainerName'] ?? 'N/A';
                          return Dismissible(
                            key: Key(result.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              FirebaseFirestore.instance
                                  .collection('results')
                                  .doc(result.id)
                                  .delete();
                            },
                            background: Container(
                              color: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              alignment: Alignment.centerRight,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                '${l10n.score}: ${result['masteryPercentage']}%',
                              ),
                              subtitle: Text(
                                'by $trainerName on ${DateFormat.yMMMd().add_jm().format(date)}',
                              ),
                              dense: true,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  } else {
                    return Card(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withOpacity(0.5),
                      child: ListTile(
                        title: Text(training['title'] ?? l10n.training),
                        subtitle: Text(
                          l10n.noResultsYet,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        trailing: const Text(
                          '0%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              Tooltip(
                message: l10n.addTrainingResult,
                child: ElevatedButton.icon(
                  onPressed: _showAddResultDialog,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTrainingResult),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: l10n.startCompetitionTest,
                child: ElevatedButton.icon(
                  onPressed: _showSelectCompetitionDialog,
                  icon: const Icon(Icons.timer),
                  label: Text(l10n.startCompetitionTest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'View Competition Leaderboards',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.leaderboard),
                  label: Text(l10n.leaderboard),
                  onPressed: _showCompetitionsForLeaderboard,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('daily_notes')
                .where('traineeUid', isEqualTo: widget.traineeData.id)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return EmptyStateWidget(
                  message: l10n.noNotesRecorded,
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              final notes = snapshot.data!.docs;
              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final date = (note['date'] as Timestamp).toDate();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(note['note'] ?? ''),
                      subtitle: Text(DateFormat.yMMMd().add_jm().format(date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditNoteDialog(note),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteNote(note.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showAddNoteDialog,
            icon: const Icon(Icons.note_add),
            label: Text(l10n.addDailyNote),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatIndicator({
    required double percent,
    required String label,
    required String footer,
    required Color color,
  }) {
    return CircularPercentIndicator(
      radius: 50.0,
      lineWidth: 10.0,
      animation: true,
      percent: percent.clamp(0.0, 1.0),
      center: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          footer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
      ),
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: color,
    );
  }

  // --- الحوارات والدوال المساعدة ---

  Future<void> _showAddResultDialog() async {
    final trainingsSnapshot = await FirebaseFirestore.instance
        .collection('trainings')
        .get();
    final trainings = trainingsSnapshot.docs;
    String? selectedTrainingId;
    String? selectedTrainingTitle;
    double masteryPercentage = 80.0;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> openTrainingSelectionDialog() async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (dialogContext) =>
                    _buildTrainingSelectionDialog(dialogContext, trainings),
              );
              if (result != null) {
                setState(() {
                  selectedTrainingId = result['id'];
                  selectedTrainingTitle = result['title'];
                });
              }
            }

            return AlertDialog(
              title: Text(l10n.addTrainingResult),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: openTrainingSelectionDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedTrainingTitle ?? l10n.selectTraining,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selectedTrainingTitle == null
                                      ? Colors.grey.shade600
                                      : null,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('${l10n.mastery}: ${masteryPercentage.toInt()}%'),
                  Slider(
                    value: masteryPercentage,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: masteryPercentage.round().toString(),
                    onChanged: (value) =>
                        setState(() => masteryPercentage = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: selectedTrainingId != null
                      ? () async {
                          final trainerAuth = FirebaseAuth.instance.currentUser;
                          if (trainerAuth == null) return;
                          final trainerDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(trainerAuth.uid)
                              .get();
                          final trainerName =
                              trainerDoc.data()?['displayName'] ?? 'Unknown';

                          await FirebaseFirestore.instance
                              .collection('results')
                              .add({
                                'traineeUid': widget.traineeData.id,
                                'trainingId': selectedTrainingId,
                                'trainingTitle': selectedTrainingTitle,
                                'masteryPercentage': masteryPercentage.toInt(),
                                'date': Timestamp.now(),
                                'trainerUid': trainerAuth.uid,
                                'trainerName': trainerName,
                              });
                          if (mounted) {
                            Navigator.of(context).pop();
                            _loadProgressData();
                          }
                        }
                      : null,
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSelectCompetitionDialog() async {
    final competitionsSnapshot = await FirebaseFirestore.instance
        .collection('competitions')
        .where('isActive', isEqualTo: true)
        .get();
    showDialog(
      context: context,
      builder: (context) =>
          _buildCompetitionSelectionDialog(context, competitionsSnapshot.docs),
    );
  }

  Widget _buildCompetitionSelectionDialog(
    BuildContext context,
    List<DocumentSnapshot> allCompetitions,
  ) {
    final searchController = TextEditingController();
    final currentTrainerId = FirebaseAuth.instance.currentUser?.uid;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        final filteredCompetitions = allCompetitions.where((competition) {
          final title = (competition['title'] as String? ?? '').toLowerCase();
          final query = searchController.text.toLowerCase();
          return title.contains(query);
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: currentTrainerId != null
              ? FirebaseFirestore.instance
                    .collection('user_favorite_competitions')
                    .where('trainerId', isEqualTo: currentTrainerId)
                    .snapshots()
              : const Stream.empty(),
          builder: (context, favoriteSnapshot) {
            final favoriteCompetitionIds = <String>{};
            if (favoriteSnapshot.hasData) {
              for (var doc in favoriteSnapshot.data!.docs) {
                favoriteCompetitionIds.add(doc['competitionId']);
              }
            }

            final favoriteCompetitions = filteredCompetitions
                .where((c) => favoriteCompetitionIds.contains(c.id))
                .toList();
            final otherCompetitions = filteredCompetitions
                .where((c) => !favoriteCompetitionIds.contains(c.id))
                .toList();

            return AlertDialog(
              title: Text(l10n.selectCompetitionToStart),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: l10n.searchCompetition,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (favoriteCompetitions.isNotEmpty)
                            ExpansionTile(
                              title: Text(
                                l10n.favorites,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              leading: Icon(
                                Icons.star,
                                color: Theme.of(context).primaryColor,
                              ),
                              initiallyExpanded: true,
                              children: favoriteCompetitions.map((competition) {
                                return ListTile(
                                  title: Text(competition['title']),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CompetitionTimerScreen(
                                              competition: competition,
                                              traineeDoc: widget.traineeData,
                                            ),
                                      ),
                                    );
                                  },
                                  trailing: _buildCompetitionFavoriteButton(
                                    favoriteCompetitionIds.contains(
                                      competition.id,
                                    ),
                                    competition.id,
                                  ),
                                );
                              }).toList(),
                            ),
                          ...otherCompetitions.map((competition) {
                            return ListTile(
                              title: Text(competition['title']),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CompetitionTimerScreen(
                                          competition: competition,
                                          traineeDoc: widget.traineeData,
                                        ),
                                  ),
                                );
                              },
                              trailing: _buildCompetitionFavoriteButton(
                                favoriteCompetitionIds.contains(competition.id),
                                competition.id,
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTrainingSelectionDialog(
    BuildContext context,
    List<DocumentSnapshot> allTrainings,
  ) {
    final searchController = TextEditingController();
    final currentTrainerId = FirebaseAuth.instance.currentUser?.uid;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        final filteredTrainings = allTrainings.where((training) {
          final title = (training['title'] as String? ?? '').toLowerCase();
          final query = searchController.text.toLowerCase();
          return title.contains(query);
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: currentTrainerId != null
              ? FirebaseFirestore.instance
                    .collection('user_favorites')
                    .where('trainerId', isEqualTo: currentTrainerId)
                    .snapshots()
              : const Stream.empty(),
          builder: (context, favoriteSnapshot) {
            final favoriteTrainingIds = <String>{};
            if (favoriteSnapshot.hasData) {
              for (var doc in favoriteSnapshot.data!.docs) {
                favoriteTrainingIds.add(doc['trainingId']);
              }
            }

            final favoriteTrainings = filteredTrainings
                .where((t) => favoriteTrainingIds.contains(t.id))
                .toList();
            final otherTrainings = filteredTrainings
                .where((t) => !favoriteTrainingIds.contains(t.id))
                .toList();

            final Map<int, List<DocumentSnapshot>> trainingsByLevel = {};
            for (var training in otherTrainings) {
              final level = training['level'] as int? ?? 1;
              if (trainingsByLevel[level] == null) trainingsByLevel[level] = [];
              trainingsByLevel[level]!.add(training);
            }
            final sortedLevels = trainingsByLevel.keys.toList()..sort();

            return AlertDialog(
              title: Text(l10n.selectTraining),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: l10n.searchTraining,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: 1 + sortedLevels.length,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            if (favoriteTrainings.isEmpty)
                              return const SizedBox.shrink();
                            return ExpansionTile(
                              title: Text(
                                l10n.favorites,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              leading: Icon(
                                Icons.star,
                                color: Theme.of(context).primaryColor,
                              ),
                              initiallyExpanded: true,
                              children: favoriteTrainings.map((training) {
                                return ListTile(
                                  title: Text(training['title']),
                                  onTap: () => Navigator.of(context).pop({
                                    'id': training.id,
                                    'title': training['title'],
                                  }),
                                  trailing: _buildTrainingFavoriteButton(
                                    favoriteTrainingIds.contains(training.id),
                                    training.id,
                                  ),
                                );
                              }).toList(),
                            );
                          }

                          final level = sortedLevels[index - 1];
                          final levelTrainings = trainingsByLevel[level]!;
                          if (levelTrainings.isEmpty)
                            return const SizedBox.shrink();

                          return ExpansionTile(
                            title: Text(
                              '${l10n.level} $level',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            initiallyExpanded: searchController.text.isNotEmpty,
                            children: levelTrainings.map((training) {
                              return ListTile(
                                title: Text(training['title']),
                                onTap: () => Navigator.of(context).pop({
                                  'id': training.id,
                                  'title': training['title'],
                                }),
                                trailing: _buildTrainingFavoriteButton(
                                  favoriteTrainingIds.contains(training.id),
                                  training.id,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompetitionFavoriteButton(
    bool isFavorite,
    String competitionId,
  ) {
    final currentTrainerId = FirebaseAuth.instance.currentUser?.uid;
    if (currentTrainerId == null) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite ? Colors.amber : Colors.grey,
      ),
      onPressed: () async {
        final favoritesCollection = FirebaseFirestore.instance.collection(
          'user_favorite_competitions',
        );
        if (isFavorite) {
          final querySnapshot = await favoritesCollection
              .where('trainerId', isEqualTo: currentTrainerId)
              .where('competitionId', isEqualTo: competitionId)
              .limit(1)
              .get();
          if (querySnapshot.docs.isNotEmpty)
            await querySnapshot.docs.first.reference.delete();
        } else {
          await favoritesCollection.add({
            'trainerId': currentTrainerId,
            'competitionId': competitionId,
          });
        }
      },
    );
  }

  Widget _buildTrainingFavoriteButton(bool isFavorite, String trainingId) {
    final currentTrainerId = FirebaseAuth.instance.currentUser?.uid;
    if (currentTrainerId == null) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite ? Colors.amber : Colors.grey,
      ),
      onPressed: () async {
        final favoritesCollection = FirebaseFirestore.instance.collection(
          'user_favorites',
        );
        if (isFavorite) {
          final querySnapshot = await favoritesCollection
              .where('trainerId', isEqualTo: currentTrainerId)
              .where('trainingId', isEqualTo: trainingId)
              .limit(1)
              .get();
          if (querySnapshot.docs.isNotEmpty)
            await querySnapshot.docs.first.reference.delete();
        } else {
          await favoritesCollection.add({
            'trainerId': currentTrainerId,
            'trainingId': trainingId,
          });
        }
      },
    );
  }

  Future<void> _showAddNoteDialog() async {
    final noteController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addDailyNote),
          content: TextField(
            controller: noteController,
            decoration: InputDecoration(hintText: l10n.enterNoteHere),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (noteController.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('daily_notes')
                      .add({
                        'traineeUid': widget.traineeData.id,
                        'trainerUid': FirebaseAuth.instance.currentUser?.uid,
                        'note': noteController.text,
                        'date': Timestamp.now(),
                      });
                  if (mounted) Navigator.of(context).pop();
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditNoteDialog(DocumentSnapshot note) async {
    final noteController = TextEditingController(text: note['note']);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.editDailyNote),
          content: TextField(
            controller: noteController,
            decoration: InputDecoration(hintText: l10n.enterNoteHere),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (noteController.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('daily_notes')
                      .doc(note.id)
                      .update({
                        'note': noteController.text,
                        'date': Timestamp.now(),
                      });
                  if (mounted) Navigator.of(context).pop();
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNote(String noteId) async {
    await FirebaseFirestore.instance
        .collection('daily_notes')
        .doc(noteId)
        .delete();
  }

  Future<void> _showCompetitionsForLeaderboard() async {
    final competitionsSnapshot = await FirebaseFirestore.instance
        .collection('competitions')
        .get();
    final competitions = competitionsSnapshot.docs;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectCompetitionToViewLeaderboard),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: competitions.length,
              itemBuilder: (context, index) {
                final competition = competitions[index];
                return ListTile(
                  title: Text(competition['title']),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LeaderboardScreen(competition: competition),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }
}
