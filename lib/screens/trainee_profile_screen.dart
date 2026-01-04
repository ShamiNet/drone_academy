import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // للتوافق فقط
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

  // متغيرات التحكم
  bool _showOnlyWithResults = false;
  _SortOption _sortOption = _SortOption.level;
  bool _sortAscending = true;

  // --- دوال مساعدة لاستخراج البيانات بأمان ---
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
            // تحديد أول تدريب للشارت تلقائياً
            if (_selectedTrainingIdForChart == null) {
              _selectedTrainingIdForChart = trainingId;
              _generateChartData(trainingId);
            }
          } catch (e) {}
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
    final filtered = allResults
        .where((r) => r['trainingId'] == trainingId)
        .toList();

    filtered.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

    final spots = <FlSpot>[];
    for (var i = 0; i < filtered.length; i++) {
      final doc = filtered[i];
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
    String selectedLanguage = 'ar';
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
          builder: (c, st) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اختيار اللغة
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8FA1B4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لغة التقرير',
                      style: TextStyle(color: Color(0xFF8FA1B4), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedLanguage,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E2230),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(
                          value: 'ar',
                          child: Row(
                            children: [
                              Text('🇸🇦', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('العربية'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(
                            children: [
                              Text('🇬🇧', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('English'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ru',
                          child: Row(
                            children: [
                              Text('🇷🇺', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('Русский'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) => st(() => selectedLanguage = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'إظهار العلامة المائية',
                  style: TextStyle(color: Colors.white),
                ),
                value: showWatermark,
                activeColor: const Color(0xFF8FA1B4),
                onChanged: (val) => st(() => showWatermark = val),
              ),
            ],
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
        language: selectedLanguage,
      );

      if (mounted) {
        Navigator.pop(context);
        // تأخير صغير للسماح للـ Navigator بإغلاق النافذة السابقة بشكل كامل
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          showReportReadyDialog(context, pdfDoc);
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _traineeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              l10n.trainees,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
              ),
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFF9800)),
              onPressed: _generateSingleReport,
            ),
          ),
        ],
      ),
      body: _isLoadingStats || _isLoadingTrainings
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. الإحصائيات
                  Row(
                    children: [
                      _buildGradientStatCard(
                        title: l10n.trainingsCompleted,
                        value: '$_completedTrainings',
                        subtitle: '/ $_totalTrainings Total',
                        colors: [
                          const Color(0xFF2196F3),
                          const Color(0xFF1976D2),
                        ],
                        icon: Icons.check_circle_outline,
                        percent: _progressPercentage,
                      ),
                      const SizedBox(width: 16),
                      _buildGradientStatCard(
                        title: l10n.mastery,
                        value:
                            '${_averageMasteryPercentage.toStringAsFixed(0)}%',
                        subtitle: 'Average Score',
                        colors: [
                          const Color(0xFFFF9800),
                          const Color(0xFFF57C00),
                        ],
                        icon: Icons.star_border,
                        percent: _averageMasteryPercentage / 100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. الشارت
                  if (_chartableTrainings.isNotEmpty) ...[
                    Text(
                      l10n.scoreEvolution,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedTrainingIdForChart,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.show_chart,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              filled: false,
                            ),
                            dropdownColor: const Color(0xFF1E293B),
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
                          const Divider(color: Colors.white10),
                          if (_chartData.isNotEmpty)
                            SizedBox(
                              height: 200,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 20.0,
                                  right: 10,
                                ),
                                child: LineChart(
                                  LineChartData(
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _chartData,
                                        isCurved: true,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF9800),
                                            Color(0xFFFFD54F),
                                          ],
                                        ),
                                        barWidth: 4,
                                        isStrokeCapRound: true,
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFFFF9800,
                                              ).withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                    titlesData: const FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                        ),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: true),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 3. الذكاء الاصطناعي
                  _buildAiSummaryCard(), // الدالة المصححة موجودة الآن في الأسفل
                  const SizedBox(height: 24),

                  // 4. التبويبات
                  DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey,
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(
                                text: l10n.results,
                                icon: const Icon(Icons.emoji_events_outlined),
                              ),
                              Tab(
                                text: l10n.dailyNotes,
                                icon: const Icon(Icons.note_alt_outlined),
                              ),
                              Tab(
                                text: l10n.schedule,
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 550,
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildResultsTab(), // التبويب المحدث مع الأزرار
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
            ),
    );
  }

  // --- الدالة المفقودة سابقاً: _buildAiSummaryCard ---
  Widget _buildAiSummaryCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: const Color(0xFF1E293B), // لون داكن للبطاقة
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF3F51B5)),
                  const SizedBox(width: 10),
                  Text(
                    l10n.aiPerformanceAnalysis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isAnalyzing)
                const Center(child: CircularProgressIndicator())
              else if (_aiSummary != null)
                AiSummaryWidget(summary: _aiSummary!)
              else
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.analytics),
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

  // --- تبويب النتائج المحدث (التصميم الحديث + أزرار التحكم القديمة) ---
  Widget _buildResultsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.fetchResults(traineeUid: _traineeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final traineeResults = snapshot.data ?? [];

        // منطق التجميع
        final Map<String, List<dynamic>> resultsGroupedByTraining = {};
        for (var result in traineeResults) {
          final tId = result['trainingId'] as String;
          if (resultsGroupedByTraining[tId] == null)
            resultsGroupedByTraining[tId] = [];
          resultsGroupedByTraining[tId]!.add(result);
        }

        // منطق الفلترة والترتيب
        var displayedTrainings = _showOnlyWithResults
            ? _allTrainings!
                  .where((t) => resultsGroupedByTraining.containsKey(t['id']))
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
              final sA =
                  resultsGroupedByTraining[a['id']]?.first['masteryPercentage']
                      as int? ??
                  -1;
              final sB =
                  resultsGroupedByTraining[b['id']]?.first['masteryPercentage']
                      as int? ??
                  -1;
              comparison = sA.compareTo(sB);
              break;
            case _SortOption.name:
              comparison = (a['title'] as String? ?? '').compareTo(
                b['title'] as String? ?? '',
              );
              break;
          }
          return _sortAscending ? comparison : -comparison;
        });

        return Column(
          children: [
            // 1. شريط أدوات التحكم (الفرز والفلترة)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sort, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_SortOption>(
                            value: _sortOption,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
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
                            onChanged: (v) => setState(() => _sortOption = v!),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: const Color(0xFFFF9800),
                        ),
                        onPressed: () =>
                            setState(() => _sortAscending = !_sortAscending),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      l10n.showOnlyWithResults,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    value: _showOnlyWithResults,
                    activeColor: const Color(0xFFFF9800),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _showOnlyWithResults = v),
                  ),
                ],
              ),
            ),

            // 2. القائمة
            Expanded(
              child: displayedTrainings.isEmpty
                  ? EmptyStateWidget(
                      message: l10n.noTrainingsAvailable,
                      imagePath: 'assets/illustrations/no_data.svg',
                    )
                  : ListView.builder(
                      itemCount: displayedTrainings.length,
                      itemBuilder: (context, index) {
                        final training = displayedTrainings[index];
                        final results =
                            resultsGroupedByTraining[training['id']];
                        final hasResults =
                            results != null && results.isNotEmpty;
                        final latest = hasResults ? results.first : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasResults
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.white10,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (hasResults ? Colors.green : Colors.grey)
                                          .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasResults
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: hasResults
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              title: Text(
                                training['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                hasResults
                                    ? "Latest: ${latest['masteryPercentage']}%"
                                    : l10n.noResultsYet,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: hasResults
                                  ? Text(
                                      "${latest['masteryPercentage']}%",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green,
                                      ),
                                    )
                                  : const Text(
                                      "0%",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),

                              children: hasResults
                                  ? results.map((r) {
                                      final date = DateTime.parse(r['date']);
                                      return ListTile(
                                        title: Text(
                                          "${l10n.score}: ${r['masteryPercentage']}%",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        subtitle: Text(
                                          DateFormat.yMMMd().add_jm().format(
                                            date,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        leading: const Icon(
                                          Icons.history,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        dense: true,
                                      );
                                    }).toList()
                                  : [],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // 3. الأزرار الثلاثة
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton(
                  icon: Icons.add,
                  label: l10n.addTrainingResult,
                  color: const Color(0xFFFF9800),
                  onPressed: _showAddResultDialog,
                ),
                _buildActionButton(
                  icon: Icons.timer,
                  label: l10n.startCompetitionTest,
                  color: Colors.green,
                  onPressed: _showSelectCompetitionDialog,
                ),
                _buildActionButton(
                  icon: Icons.leaderboard,
                  label: l10n.leaderboard,
                  color: Colors.purpleAccent,
                  onPressed: _showCompetitionsForLeaderboard,
                  isOutlined: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.transparent : color,
        foregroundColor: isOutlined ? color : Colors.black,
        elevation: isOutlined ? 0 : 4,
        side: isOutlined ? BorderSide(color: color) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGradientStatCard({
    required String title,
    required String value,
    required String subtitle,
    required List<Color> colors,
    required IconData icon,
    required double percent,
  }) {
    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 28),
                CircularPercentIndicator(
                  radius: 20.0,
                  lineWidth: 4.0,
                  percent: percent.clamp(0.0, 1.0),
                  center: Text(
                    "${(percent * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  progressColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- باقي الدوال (Dialogs) ---
  Future<void> _showAddResultDialog() async {
    final trainings = await _apiService.fetchTrainings();
    String? selectedId;
    String? selectedTitle;
    double mastery = 80;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1E2230), // Dark Dialog
          title: Text(
            l10n.addTrainingResult,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  selectedTitle ?? l10n.selectTraining,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                onTap: () async {
                  final res = await showDialog<Map>(
                    context: context,
                    builder: (ctx2) =>
                        _buildTrainingSelectionDialog(ctx2, trainings),
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
              Text(
                '${l10n.mastery}: ${mastery.toInt()}%',
                style: const TextStyle(color: Colors.white),
              ),
              Slider(
                value: mastery,
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: const Color(0xFFFF9800),
                label: mastery.toInt().toString(),
                onChanged: (v) => setSt(() => mastery = v),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
              ),
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
          backgroundColor: const Color(0xFF1E2230),
          title: Text(
            l10n.selectTraining,
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    labelStyle: TextStyle(color: Colors.grey),
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
                        title: Text(
                          '${l10n.level} $lvl',
                          style: const TextStyle(color: Colors.white),
                        ),
                        collapsedIconColor: Colors.grey,
                        iconColor: const Color(0xFFFF9800),
                        children: grouped[lvl]!
                            .map(
                              (t) => ListTile(
                                title: Text(
                                  t['title'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2230),
      title: Text(
        l10n.selectCompetitionToStart,
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allCompetitions.length,
          itemBuilder: (ctx, idx) {
            final comp = allCompetitions[idx];
            return ListTile(
              title: Text(
                comp['title'],
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompetitionTimerScreen(
                      competition: comp,
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
    );
  }

  Future<void> _showCompetitionsForLeaderboard() async {
    final comps = await _apiService.fetchCompetitions();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.selectCompetitionToViewLeaderboard,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: comps.length,
            itemBuilder: (ctx, idx) {
              return ListTile(
                title: Text(
                  comps[idx]['title'],
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LeaderboardScreen(competition: comps[idx]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
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
                  final date = DateTime.parse(note['date']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat.yMMMd().format(date),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 16,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteNote(note['id']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          note['note'],
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ],
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
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddNoteDialog() async {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.addDailyNote,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                await _apiService.addDailyNote({
                  'traineeUid': _traineeId,
                  'note': noteController.text,
                  'date': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
            ),
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
}
