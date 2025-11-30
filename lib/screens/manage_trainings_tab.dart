import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_training_screen.dart';
import 'package:flutter/material.dart';

class ManageTrainingsTab extends StatefulWidget {
  const ManageTrainingsTab({super.key});

  @override
  State<ManageTrainingsTab> createState() => _ManageTrainingsTabState();
}

class _ManageTrainingsTabState extends State<ManageTrainingsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // نفس لون الخلفية ليتطابق مع الواجهة الرئيسية
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white), // لون نص الكتابة
              decoration: InputDecoration(
                hintText: 'ابحث عن تدريب...',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trainings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noTrainingsAvailable,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final filtered = docs
                    .where(
                      (d) => d['title'].toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                final Map<int, List<DocumentSnapshot>> grouped = {};
                for (var d in filtered) {
                  final lvl = d['level'] as int? ?? 0;
                  grouped.putIfAbsent(lvl, () => []).add(d);
                }
                final sortedLevels = grouped.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedLevels.length,
                  itemBuilder: (context, index) {
                    final level = sortedLevels[index];
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
                          collapsedIconColor: Colors.grey,
                          iconColor: Colors.blue,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF3F51B5),
                            child: Text(
                              '$level',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            'المستوى $level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: grouped[level]!.map((doc) {
                            return ListTile(
                              title: Text(
                                doc['title'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditTrainingScreen(training: doc),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
      // --- هنا تمت إضافة الزر ليعمل ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditTrainingScreen()),
        ),
        backgroundColor: const Color(0xFFFF9800), // اللون البرتقالي
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // أقصى اليسار
    );
  }
}
