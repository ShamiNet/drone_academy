import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_training_screen.dart';
import 'package:flutter/material.dart';

// --- تبويب إدارة التدريبات ---
class ManageTrainingsTab extends StatefulWidget {
  const ManageTrainingsTab({super.key});

  @override
  State<ManageTrainingsTab> createState() => _ManageTrainingsTabState();
}

class _ManageTrainingsTabState extends State<ManageTrainingsTab> {
  final _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  Future<void> _reorderTraining(
    QueryDocumentSnapshot trainingToMove,
    String action,
    List<QueryDocumentSnapshot> currentLevelTrainings,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    List<QueryDocumentSnapshot> mutableLevelTrainings = List.from(
      currentLevelTrainings,
    );

    final currentIndex = mutableLevelTrainings.indexOf(trainingToMove);
    if (currentIndex == -1) return;

    mutableLevelTrainings.removeAt(currentIndex);

    int newIndex;
    switch (action) {
      case 'top':
        newIndex = 0;
        break;
      case 'up':
        newIndex = (currentIndex - 1).clamp(0, mutableLevelTrainings.length);
        break;
      case 'down':
        newIndex = (currentIndex + 1).clamp(0, mutableLevelTrainings.length);
        break;
      case 'bottom':
        newIndex = mutableLevelTrainings.length;
        break;
      default:
        return;
    }

    mutableLevelTrainings.insert(newIndex, trainingToMove);

    for (int i = 0; i < mutableLevelTrainings.length; i++) {
      batch.update(mutableLevelTrainings[i].reference, {'order': i});
    }
    await batch.commit();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trainings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(l10n.noTrainingsAvailable));
                }

                final allTrainings = snapshot.data!.docs;
                allTrainings.sort((a, b) {
                  final levelA =
                      (a.data() as Map<String, dynamic>)['level'] as int? ?? 1;
                  final levelB =
                      (b.data() as Map<String, dynamic>)['level'] as int? ?? 1;
                  final orderA =
                      (a.data() as Map<String, dynamic>)['order'] as int? ??
                      999999;
                  final orderB =
                      (b.data() as Map<String, dynamic>)['order'] as int? ??
                      999999;

                  if (levelA != levelB) {
                    return levelA.compareTo(levelB);
                  }
                  return orderA.compareTo(orderB);
                });

                final filteredTrainings = allTrainings.where((doc) {
                  final title = doc['title'].toString().toLowerCase();
                  return title.contains(_searchQuery.value.toLowerCase());
                }).toList();

                if (filteredTrainings.isEmpty &&
                    _searchQuery.value.isNotEmpty) {
                  return Column(
                    children: [
                      _buildSearchField(l10n, _searchController, _searchQuery),
                      Center(child: Text(l10n.noResultsFound)),
                    ],
                  );
                }
                final Map<int, List<QueryDocumentSnapshot>> trainingsByLevel =
                    {};
                for (var training in filteredTrainings) {
                  final level = training['level'] as int? ?? 1;
                  if (trainingsByLevel[level] == null) {
                    trainingsByLevel[level] = [];
                  }
                  trainingsByLevel[level]!.add(training);
                }
                final sortedLevels = trainingsByLevel.keys.toList()..sort();

                return Column(
                  children: [
                    _buildSearchField(l10n, _searchController, _searchQuery),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: sortedLevels.length,
                        itemBuilder: (context, index) {
                          final level = sortedLevels[index];
                          final levelTrainings = trainingsByLevel[level]!;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 8.0,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              title: Text(
                                '${l10n.level} $level',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              leading: CircleAvatar(child: Text('$level')),
                              initiallyExpanded: false,
                              children: levelTrainings.map((training) {
                                final data =
                                    training.data() as Map<String, dynamic>;
                                final imageUrl = data.containsKey('imageUrl')
                                    ? data['imageUrl'] as String?
                                    : null;
                                final title = training['title'] ?? 'No Title';

                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child:
                                        (imageUrl != null &&
                                            imageUrl.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => Image.asset(
                                                  'assets/images/drone_training_1.jpg',
                                                ),
                                          )
                                        : Image.asset(
                                            'assets/images/drone_training_1.jpg',
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  title: Text(title),
                                  subtitle: Text(
                                    '${l10n.level} ${training['level']}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditTrainingScreen(
                                                  training: training,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _showDeleteDialog(
                                          context,
                                          training,
                                          l10n,
                                        ),
                                      ),
                                      // --- بداية إضافة قائمة الترتيب ---
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) {
                                          _reorderTraining(
                                            training,
                                            value,
                                            levelTrainings,
                                          );
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'top',
                                            child: Text(l10n.moveToTop),
                                          ),
                                          PopupMenuItem(
                                            value: 'up',
                                            child: Text(l10n.moveUp),
                                          ),
                                          PopupMenuItem(
                                            value: 'down',
                                            child: Text(l10n.moveDown),
                                          ),
                                          PopupMenuItem(
                                            value: 'bottom',
                                            child: Text(l10n.moveToBottom),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditTrainingScreen()),
        ),
        child: const Icon(Icons.add),
        tooltip: l10n.addTraining,
      ),
    );
  }

  Padding _buildSearchField(
    AppLocalizations l10n,
    TextEditingController controller,
    ValueNotifier<String> query,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ValueListenableBuilder<String>(
        valueListenable: query,
        builder: (context, value, child) {
          return TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.searchTraining,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => controller.clear(),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

void _showDeleteDialog(
  BuildContext context,
  DocumentSnapshot training,
  AppLocalizations l10n,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.confirmDeletion),
      content: Text(l10n.areYouSureDelete),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            FirebaseFirestore.instance
                .collection('trainings')
                .doc(training.id)
                .delete();
            Navigator.pop(context);
          },
          child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
