import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_competition_screen.dart';
import 'package:drone_academy/screens/leaderboard_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class ManageCompetitionsTab extends StatefulWidget {
  const ManageCompetitionsTab({super.key});

  @override
  State<ManageCompetitionsTab> createState() => _ManageCompetitionsTabState();
}

class _ManageCompetitionsTabState extends State<ManageCompetitionsTab> {
  final ApiService _apiService = ApiService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchCompetition,
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E2230),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: _apiService.streamCompetitions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data ?? [];

                final filtered = docs
                    .where(
                      (d) => d['title'].toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty)
                  return Center(
                    child: Text(
                      l10n.noResultsFound,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final comp = filtered[index];
                    return Card(
                      color: const Color(0xFF1E2230),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          comp['title'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          comp['isActive'] == true
                              ? l10n.active
                              : l10n.inactive,
                          style: TextStyle(
                            color: comp['isActive'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _apiService.deleteCompetition(comp['id']),
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
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
