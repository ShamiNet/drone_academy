import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; // نحتاجها فقط لدعم التوافق القديم مؤقتاً
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/models/pdf_report_data.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drone_academy/utils/pdf_generator.dart';
import 'package:drone_academy/screens/report_generation_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:drone_academy/screens/schedule_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drone_academy/services/ai_analyzer_service.dart';
import 'package:drone_academy/widgets/ai_summary_widget.dart';
import 'package:drone_academy/screens/competition_timer_screen.dart';
import 'package:drone_academy/screens/leaderboard_screen.dart';
import 'package:drone_academy/services/api_service.dart';

class TraineeProfileScreen extends StatefulWidget {
  final dynamic traineeData; // Map OR DocumentSnapshot
  const TraineeProfileScreen({super.key, required this.traineeData});

  @override
  State<TraineeProfileScreen> createState() => _TraineeProfileScreenState();
}

enum _SortOption { level, mastery, name }

class _TraineeProfileScreenState extends State<TraineeProfileScreen> {
  final ApiService _apiService = ApiService();
  late AppLocalizations l10n;

  List<dynamic>? _allTrainings;
  bool _isLoadingTrainings = true;
  double _progressPercentage = 0.0;
  int _completedTrainings = 0;
  int _totalTrainings = 0;
  double _averageMasteryPercentage = 0.0;
  bool _isLoadingStats = true;
  List<dynamic> _chartableTrainings = [];
  String? _selectedTrainingIdForChart;
  List<FlSpot> _chartData = [];
  String? _aiSummary;
  bool _isAnalyzing = false;
  bool _showOnlyWithResults = false;
  _SortOption _sortOption = _SortOption.level;
  bool _sortAscending = true;

  String get _traineeId {
    try {
      return widget.traineeData['id'] ?? widget.traineeData['uid'] ?? '';
    } catch (e) {
      return (widget.traineeData as dynamic).id;
    }
  }

  String get _traineeName {
    try {
      return widget.traineeData['displayName'] ?? 'No Name';
    } catch (e) {
      return (widget.traineeData as dynamic)['displayName'] ?? 'No Name';
    }
  }

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
    final trainings = await _apiService.fetchTrainings();
    if (mounted) {
      setState(() {
        _allTrainings = trainings;
        _isLoadingTrainings = false;
      });
    }
  }

  Future<void> _loadProgressData() async {
    if (_allTrainings == null) return;

    final traineeResults = await _apiService.fetchResults(
      traineeUid: _traineeId,
    );
    final totalCount = _allTrainings!.length;
    final uniqueCompletedIds = <String>{};

    for (var doc in traineeResults) {
      uniqueCompletedIds.add(doc['trainingId']);
    }

    double totalMastery = 0;
    if (traineeResults.isNotEmpty) {
      for (var doc in traineeResults) {
        totalMastery += (doc['masteryPercentage'] as num?) ?? 0;
      }
      _averageMasteryPercentage = totalMastery / traineeResults.length;
    }

    final Map<String, List<dynamic>> resultsGroupedByTraining = {};
    for (var result in traineeResults) {
      final trainingId = result['trainingId'] as String;
      if (resultsGroupedByTraining[trainingId] == null) {
        resultsGroupedByTraining[trainingId] = [];
      }
      resultsGroupedByTraining[trainingId]!.add(result);
    }

    final chartable = <dynamic>[];
    if (_allTrainings != null) {
      resultsGroupedByTraining.forEach((trainingId, resultsList) {
        if (resultsList.length > 1) {
          try {
            final trainingDoc = _allTrainings!.firstWhere(
              (doc) => doc['id'] == trainingId,
            );
            chartable.add(trainingDoc);
          } catch (e) {
            // Not found
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
    final allResults = await _apiService.fetchResults(traineeUid: _traineeId);
    final results = allResults
        .where((r) => r['trainingId'] == trainingId)
        .toList();

    results.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

    final spots = <FlSpot>[];
    for (var i = 0; i < results.length; i++) {
      final doc = results[i];
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
    final notes = await _apiService.fetchDailyNotes(traineeUid: _traineeId);
    final notesList = notes.map((doc) => doc['note'] as String).toList();
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

  Future<void> _generateSingleReport() async {
    final name = _traineeName;
    final currentUser = FirebaseAuth.instance.currentUser;
    final creatorName = currentUser?.displayName ?? 'Trainer';

    bool showWatermark = true;
    bool proceed = false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text(
          'خيارات التقرير',
          style: TextStyle(color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (c, st) => SwitchListTile(
            title: const Text(
              'إظهار العلامة المائية',
              style: TextStyle(color: Colors.white),
            ),
            value: showWatermark,
            activeColor: const Color(0xFF8FA1B4),
            onChanged: (val) => st(() => showWatermark = val),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              proceed = true;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8FA1B4),
              foregroundColor: Colors.black,
            ),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (!proceed) return;

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
      final results = await _apiService.fetchResults(traineeUid: _traineeId);
      final notes = await _apiService.fetchDailyNotes(traineeUid: _traineeId);

      String? aiSummary = _aiSummary;
      if (aiSummary == null && notes.isNotEmpty) {
        final notesList = notes.map((doc) => doc['note'] as String).toList();
        aiSummary = await AiAnalyzerService.summarizeTraineeNotes(notesList);
      }

      LevelProgress? levelProgress;
      if (_allTrainings != null) {
        final completedTrainingIds = results
            .map((doc) => doc['trainingId'] as String)
            .toSet();
        int highestLevel = 0;
        for (var training in _allTrainings!) {
          if (completedTrainingIds.contains(training['id'])) {
            final level = training['level'] as int? ?? 0;
            if (level > highestLevel) highestLevel = level;
          }
        }
        if (highestLevel > 0) {
          final trainingsInLevel = _allTrainings!
              .where((t) => (t['level'] as int? ?? 0) == highestLevel)
              .toList();
          int completedInLevel = trainingsInLevel
              .where((t) => completedTrainingIds.contains(t['id']))
              .length;
          levelProgress = LevelProgress(
            level: highestLevel,
            completedTrainings: completedInLevel,
            totalTrainingsInLevel: trainingsInLevel.length,
          );
        }
      }

      final pdfDoc = await createPdfDocument(
        traineeName: name,
        creatorName: creatorName,
        showWatermark: showWatermark,
        results: results,
        notes: notes,
        aiSummary: aiSummary,
        levelProgress: levelProgress,
        averageMastery: _averageMasteryPercentage,
      );

      if (mounted) {
        Navigator.pop(context);
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

  // --- الحوارات ---
  Future<void> _showAddResultDialog() async {
    final trainings = await _apiService.fetchTrainings();
    String? selectedId;
    String? selectedTitle;
    double mastery = 80;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(l10n.addTrainingResult),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(selectedTitle ?? l10n.selectTraining),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () async {
                  // --- التعديل هنا: استخدام dialogContext بدلاً من _ ---
                  final res = await showDialog<Map>(
                    context: context,
                    builder: (dialogContext) =>
                        _buildTrainingSelectionDialog(dialogContext, trainings),
                  );
                  if (res != null)
                    setSt(() {
                      selectedId = res['id'];
                      selectedTitle = res['title'];
                    });
                },
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Text('${l10n.mastery}: ${mastery.toInt()}%'),
              Slider(
                value: mastery,
                min: 0,
                max: 100,
                divisions: 100,
                label: mastery.toInt().toString(),
                onChanged: (v) => setSt(() => mastery = v),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      await _apiService.addResult({
                        'traineeUid': _traineeId,
                        'trainingId': selectedId,
                        'trainingTitle': selectedTitle,
                        'masteryPercentage': mastery.toInt(),
                        'date': DateTime.now().toIso8601String(),
                        'trainerUid': currentUser?.uid,
                        'trainerName': currentUser?.displayName ?? 'Unknown',
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadProgressData();
                      }
                    },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingSelectionDialog(
    BuildContext context,
    List<dynamic> allTrainings,
  ) {
    final searchController = TextEditingController();
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final filtered = allTrainings
            .where(
              (t) => t['title'].toString().toLowerCase().contains(
                searchController.text.toLowerCase(),
              ),
            )
            .toList();

        final Map<int, List<dynamic>> grouped = {};
        for (var t in filtered) {
          final lvl = t['level'] as int? ?? 1;
          if (grouped[lvl] == null) grouped[lvl] = [];
          grouped[lvl]!.add(t);
        }
        final sortedLevels = grouped.keys.toList()..sort();

        return AlertDialog(
          title: Text(l10n.selectTraining),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: sortedLevels.length,
                    itemBuilder: (ctx, idx) {
                      final lvl = sortedLevels[idx];
                      return ExpansionTile(
                        title: Text('${l10n.level} $lvl'),
                        children: grouped[lvl]!
                            .map(
                              (t) => ListTile(
                                title: Text(t['title']),
                                onTap: () => Navigator.pop(context, {
                                  'id': t['id'],
                                  'title': t['title'],
                                }),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSelectCompetitionDialog() async {
    final competitions = await _apiService.fetchCompetitions();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          _buildCompetitionSelectionDialog(context, competitions),
    );
  }

  Widget _buildCompetitionSelectionDialog(
    BuildContext context,
    List<dynamic> allCompetitions,
  ) {
    final searchController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setDialogState) {
        final filteredCompetitions = allCompetitions.where((competition) {
          final title = (competition['title'] as String? ?? '').toLowerCase();
          final query = searchController.text.toLowerCase();
          return title.contains(query);
        }).toList();

        return AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          title: Text(
            l10n.selectCompetitionToStart,
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l10n.searchCompetition,
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                  ),
                  onChanged: (value) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCompetitions.length,
                    itemBuilder: (context, index) {
                      final competition = filteredCompetitions[index];
                      return ListTile(
                        title: Text(
                          competition['title'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompetitionTimerScreen(
                                competition: competition,
                                traineeDoc: {
                                  'id': _traineeId,
                                  'displayName': _traineeName,
                                },
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddNoteDialog() async {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addDailyNote),
        content: TextField(controller: noteController, maxLines: 4),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                await _apiService.addDailyNote({
                  'traineeUid': _traineeId,
                  'trainerUid': FirebaseAuth.instance.currentUser?.uid,
                  'note': noteController.text,
                  'date': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNoteDialog(Map<String, dynamic> note) async {
    final noteController = TextEditingController(text: note['note']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editDailyNote),
        content: TextField(controller: noteController, maxLines: 4),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _apiService.updateDailyNote(note['id'], {
                'note': noteController.text,
                'date': DateTime.now().toIso8601String(),
              });
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(String id) async {
    await _apiService.deleteDailyNote(id);
    setState(() {});
  }

  Future<void> _showCompetitionsForLeaderboard() async {
    final competitions = await _apiService.fetchCompetitions();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_traineeName),
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
                        DropdownButton<String>(
                          hint: Text(l10n.selectTrainingToSeeProgress),
                          value: _selectedTrainingIdForChart,
                          isExpanded: true,
                          items: _chartableTrainings
                              .map(
                                (doc) => DropdownMenuItem<String>(
                                  value: doc['id'],
                                  child: Text(doc['title']),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            if (value != null) _generateChartData(value);
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
                            ScheduleScreen(traineeId: _traineeId),
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
          child: FutureBuilder<List<dynamic>>(
            future: _apiService.fetchResults(traineeUid: _traineeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final traineeResults = snapshot.data ?? [];

              final Map<String, List<dynamic>> resultsGroupedByTraining = {};
              for (var result in traineeResults) {
                final trainingId = result['trainingId'] as String;
                if (resultsGroupedByTraining[trainingId] == null)
                  resultsGroupedByTraining[trainingId] = [];
                resultsGroupedByTraining[trainingId]!.add(result);
              }

              var displayedTrainings = _showOnlyWithResults
                  ? _allTrainings!
                        .where(
                          (t) => resultsGroupedByTraining.containsKey(t['id']),
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
                        resultsGroupedByTraining[a['id']]
                                ?.first['masteryPercentage']
                            as int? ??
                        -1;
                    final scoreB =
                        resultsGroupedByTraining[b['id']]
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

              if (displayedTrainings.isEmpty)
                return EmptyStateWidget(
                  message: l10n.noTrainingsAvailable,
                  imagePath: 'assets/illustrations/no_data.svg',
                );

              return ListView.builder(
                itemCount: displayedTrainings.length,
                itemBuilder: (context, index) {
                  final training = displayedTrainings[index];
                  final resultsForThisTraining =
                      resultsGroupedByTraining[training['id']];

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
                          DateTime date = DateTime.now();
                          if (result['date'] != null)
                            date = DateTime.parse(result['date']);
                          final trainerName = result['trainerName'] ?? 'N/A';
                          return ListTile(
                            title: Text(
                              '${l10n.score}: ${result['masteryPercentage']}%',
                            ),
                            subtitle: Text(
                              'by $trainerName on ${DateFormat.yMMMd().add_jm().format(date)}',
                            ),
                            dense: true,
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
            alignment: WrapAlignment.center,
            children: [
              Tooltip(
                message: l10n.addTrainingResult,
                child: ElevatedButton.icon(
                  onPressed: _showAddResultDialog,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTrainingResult),
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
                  ),
                ),
              ),
              Tooltip(
                message: 'View Competition Leaderboards',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.leaderboard),
                  label: Text(l10n.leaderboard),
                  onPressed: _showCompetitionsForLeaderboard,
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
          child: FutureBuilder<List<dynamic>>(
            future: _apiService.fetchDailyNotes(traineeUid: _traineeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final notes = snapshot.data ?? [];
              if (notes.isEmpty)
                return EmptyStateWidget(
                  message: l10n.noNotesRecorded,
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  DateTime date = DateTime.now();
                  if (note['date'] != null) date = DateTime.parse(note['date']);

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
                            onPressed: () => _deleteNote(note['id']),
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
}
