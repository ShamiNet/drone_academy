import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_training_screen.dart';
import 'package:drone_academy/screens/training_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class ManageTrainingsTab extends StatefulWidget {
  const ManageTrainingsTab({super.key});

  @override
  State<ManageTrainingsTab> createState() => _ManageTrainingsTabState();
}

class _ManageTrainingsTabState extends State<ManageTrainingsTab> {
  final ApiService _apiService = ApiService();

  List<dynamic> _trainings = [];
  final Set<int> _expandedLevels = <int>{};
  final Set<int> _savingLevels = <int>{};
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  int _trainingLevel(dynamic training) {
    if (training['level'] is int) return training['level'] as int;
    return int.tryParse(training['level']?.toString() ?? '') ?? 0;
  }

  int _trainingOrder(dynamic training) {
    if (training['order'] is int) return training['order'] as int;
    return int.tryParse(training['order']?.toString() ?? '') ?? 999999;
  }

  String _describeLevelTrainings(List<dynamic> trainings) {
    return trainings
        .map(
          (training) =>
              '${training['title'] ?? training['id']}[${_trainingOrder(training)}]',
        )
        .join(' | ');
  }

  Future<void> _loadTrainings({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final trainings = await _apiService.getTrainings(
        forceRefresh: forceRefresh,
      );
      debugPrint(
        '[TRAINING_REORDER][LOAD] forceRefresh=$forceRefresh count=${trainings.length}',
      );
      if (!mounted) return;

      setState(() {
        _trainings = trainings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadTrainings(forceRefresh: true);
  }

  Future<void> _openEditTraining([Map<String, dynamic>? training]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTrainingScreen(training: training)),
    );

    if (!mounted) return;
    await _loadTrainings(forceRefresh: true);
  }

  Future<void> _openTrainingDetails(Map<String, dynamic> training) async {
    final imageUrl = (training['imageUrl'] ?? '').toString();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TrainingDetailsScreen(training: training, imageUrl: imageUrl),
      ),
    );
  }

  Future<void> _deleteTraining(Map<String, dynamic> training) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التدريب'),
        content: Text('هل تريد حذف "${training['title'] ?? ''}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _apiService.deleteTraining(training['id']);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف التدريب بنجاح')));
      await _loadTrainings(forceRefresh: true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حذف التدريب، حاول مرة أخرى')),
    );
  }

  Map<int, List<dynamic>> _groupTrainings(List<dynamic> trainings) {
    final grouped = <int, List<dynamic>>{};

    for (final training in trainings) {
      final level = _trainingLevel(training);
      grouped.putIfAbsent(level, () => []).add(training);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final orderComparison = _trainingOrder(a).compareTo(_trainingOrder(b));
        if (orderComparison != 0) return orderComparison;
        return (a['title'] ?? '').toString().compareTo(
          (b['title'] ?? '').toString(),
        );
      });
    }

    return grouped;
  }

  Future<void> _reorderLevel(int level, int oldIndex, int newIndex) async {
    if (_savingLevels.contains(level)) return;

    final originalTrainings = _trainings
        .map((training) => Map<String, dynamic>.from(training as Map))
        .toList();

    final levelTrainings =
        originalTrainings
            .where((training) => _trainingLevel(training) == level)
            .toList()
          ..sort((a, b) {
            final orderComparison = _trainingOrder(
              a,
            ).compareTo(_trainingOrder(b));
            if (orderComparison != 0) return orderComparison;
            return (a['title'] ?? '').toString().compareTo(
              (b['title'] ?? '').toString(),
            );
          });

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    debugPrint(
      '[TRAINING_REORDER][UI] level=$level oldIndex=$oldIndex newIndex=$newIndex before=${_describeLevelTrainings(levelTrainings)}',
    );

    final movedTraining = levelTrainings.removeAt(oldIndex);
    levelTrainings.insert(newIndex, movedTraining);

    for (var index = 0; index < levelTrainings.length; index++) {
      levelTrainings[index]['order'] = index;
    }

    debugPrint(
      '[TRAINING_REORDER][UI] level=$level afterLocal=${_describeLevelTrainings(levelTrainings)}',
    );

    final updatedById = {
      for (final training in levelTrainings) training['id']: training,
    };

    final nextTrainings = originalTrainings
        .map((training) => updatedById[training['id']] ?? training)
        .toList();

    setState(() {
      _savingLevels.add(level);
      _trainings = nextTrainings;
    });

    final success = await _apiService.updateTrainingOrders(levelTrainings);
    if (!mounted) return;

    if (success) {
      final refreshedTrainings = await _apiService.getTrainings(
        forceRefresh: true,
      );
      final refreshedLevelTrainings =
          refreshedTrainings
              .where((training) => _trainingLevel(training) == level)
              .toList()
            ..sort((a, b) {
              final orderComparison = _trainingOrder(
                a,
              ).compareTo(_trainingOrder(b));
              if (orderComparison != 0) return orderComparison;
              return (a['title'] ?? '').toString().compareTo(
                (b['title'] ?? '').toString(),
              );
            });

      debugPrint(
        '[TRAINING_REORDER][VERIFY] level=$level persisted=${_describeLevelTrainings(refreshedLevelTrainings)}',
      );

      setState(() {
        _savingLevels.remove(level);
        _trainings = refreshedTrainings;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث ترتيب تدريبات المستوى $level')),
      );
      return;
    }

    setState(() {
      _savingLevels.remove(level);
      _trainings = originalTrainings;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('فشل حفظ الترتيب الجديد، تمت إعادة الوضع السابق'),
      ),
    );
  }

  Widget _buildTrainingTile(Map<String, dynamic> training) {
    final String? imageUrl = training['imageUrl'];
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final orderValue = _trainingOrder(training);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openTrainingDetails(training),
        leading: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flight, color: Colors.white54),
              ),
        title: Text(
          training['title'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          training['description']?.toString().trim().isNotEmpty == true
              ? training['description']
              : 'بدون وصف',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              orderValue == 999999 ? '#-' : '#${orderValue + 1}',
              style: const TextStyle(color: Colors.white54),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _openEditTraining(training),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteTraining(training),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableTile(Map<String, dynamic> training, int index) {
    return Container(
      key: ValueKey(training['id']),
      child: Row(
        children: [
          Expanded(child: _buildTrainingTile(training)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    final filteredTrainings = _trainings
        .where(
          (training) => (training['title'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()),
        )
        .toList();

    final groupedTrainings = _groupTrainings(filteredTrainings);
    final sortedLevels = groupedTrainings.keys.toList()..sort();
    final canReorder = _searchQuery.trim().isEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن تدريب...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => setState(() => _searchQuery = ''),
                      ),
                filled: true,
                fillColor: const Color(0xFF1E2230),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                canReorder
                    ? 'اسحب من أيقونة الترتيب لتغيير ترتيب التدريبات داخل نفس المستوى.'
                    : 'إعادة الترتيب تتوقف مؤقتاً أثناء البحث. امسح البحث لتفعيل السحب والإفلات.',
                style: TextStyle(
                  color: canReorder ? Colors.white60 : Colors.amber,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_errorMessage != null) {
                    return Center(
                      child: Text(
                        'خطأ: $_errorMessage',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (_trainings.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noTrainingsAvailable,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (filteredTrainings.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد نتائج مطابقة للبحث.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedLevels.length,
                    itemBuilder: (context, index) {
                      final level = sortedLevels[index];
                      final trainingsInLevel = groupedTrainings[level]!;
                      final isSavingLevel = _savingLevels.contains(level);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2230),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: _expandedLevels.contains(level),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedLevels.add(level);
                                } else {
                                  _expandedLevels.remove(level);
                                }
                              });
                            },
                            collapsedIconColor: Colors.grey,
                            iconColor: Colors.blue,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF3F51B5),
                              child: Text(
                                '$level',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المستوى $level',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${trainingsInLevel.length} تدريب',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              if (isSavingLevel)
                                const LinearProgressIndicator(minHeight: 2),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: canReorder
                                    ? ReorderableListView.builder(
                                        shrinkWrap: true,
                                        buildDefaultDragHandles: false,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: trainingsInLevel.length,
                                        onReorder: (oldIndex, newIndex) =>
                                            _reorderLevel(
                                              level,
                                              oldIndex,
                                              newIndex,
                                            ),
                                        itemBuilder: (context, itemIndex) {
                                          final training =
                                              trainingsInLevel[itemIndex]
                                                  as Map<String, dynamic>;
                                          return _buildReorderableTile(
                                            training,
                                            itemIndex,
                                          );
                                        },
                                      )
                                    : Column(
                                        children: trainingsInLevel
                                            .map(
                                              (training) => _buildTrainingTile(
                                                training
                                                    as Map<String, dynamic>,
                                              ),
                                            )
                                            .toList(),
                                      ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditTraining(),
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
