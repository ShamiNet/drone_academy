import 'package:cached_network_image/cached_network_image.dart'; // هام جداً
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_training_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class ManageTrainingsTab extends StatefulWidget {
  const ManageTrainingsTab({super.key});

  @override
  State<ManageTrainingsTab> createState() => _ManageTrainingsTabState();
}

class _ManageTrainingsTabState extends State<ManageTrainingsTab> {
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
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
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

          // القائمة
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: _apiService.streamTrainings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noTrainingsAvailable,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final filtered = docs
                    .where(
                      (d) => d['title'].toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                final Map<int, List<dynamic>> grouped = {};
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
                            // --- هنا التعديل لإظهار الصورة ---
                            final String? imageUrl = doc['imageUrl'];
                            final bool hasImage =
                                imageUrl != null && imageUrl.isNotEmpty;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              // عرض الصورة على اليمين (Leading)
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: hasImage
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade800,
                                          child: const Icon(
                                            Icons.flight,
                                            color: Colors.white54,
                                          ), // أيقونة بديلة
                                        ),
                                ),
                              ),

                              title: Text(
                                doc['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                        builder: (_) =>
                                            EditTrainingScreen(training: doc),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _apiService.deleteTraining(doc['id']),
                                  ),
                                ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditTrainingScreen()),
        ),
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
