import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_competition_screen.dart';
import 'package:drone_academy/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';

// --- تبويب إدارة المسابقات ---
class ManageCompetitionsTab extends StatefulWidget {
  const ManageCompetitionsTab({super.key});

  @override
  State<ManageCompetitionsTab> createState() => _ManageCompetitionsTabState();
}

class _ManageCompetitionsTabState extends State<ManageCompetitionsTab> {
  final _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
    });
  }

  Future<void> _showCompetitionsForLeaderboard(BuildContext context) async {
    final competitionsSnapshot = await FirebaseFirestore.instance
        .collection('competitions')
        .get();

    if (!context.mounted) return;

    final competitions = competitionsSnapshot.docs;
    final l10n = AppLocalizations.of(context)!;

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (context, value, child) {
                return ElevatedButton.icon(
                  onPressed: () => _showCompetitionsForLeaderboard(context),
                  icon: const Icon(Icons.leaderboard),
                  label: Text(l10n.leaderboard),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.searchCompetition,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (context, value, child) {
                    if (value.isNotEmpty) {
                      return IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('competitions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(l10n.noActiveCompetitions));
                }

                final allCompetitions = snapshot.data!.docs;
                final filteredCompetitions = allCompetitions.where((doc) {
                  if (_searchQuery.value.isEmpty) {
                    return true;
                  }
                  final title =
                      (doc.data() as Map<String, dynamic>)['title']
                          ?.toString()
                          .toLowerCase() ??
                      '';
                  return title.contains(_searchQuery.value.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: filteredCompetitions.length,
                  itemBuilder: (context, index) {
                    final competition = filteredCompetitions[index];
                    return Card(
                      child: ListTile(
                        title: Text(competition['title']),
                        subtitle: Text(
                          competition['isActive'] ? l10n.active : l10n.inactive,
                          style: TextStyle(
                            color: competition['isActive']
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditCompetitionScreen(
                                    competition: competition,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showDialog(
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
                                            .collection('competitions')
                                            .doc(competition.id)
                                            .delete();
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        l10n.delete,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EditCompetitionScreen(),
          ),
        ),
        child: const Icon(Icons.add),
        tooltip: l10n.addCompetition,
        backgroundColor: Colors.amber,
      ),
    );
  }
}
