import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';

typedef LocaleChangeCallback = void Function(Locale locale);

class TrainerDashboard extends StatefulWidget {
  final LocaleChangeCallback? onLocaleChange;
  const TrainerDashboard({super.key, this.onLocaleChange});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- بداية التعديل: بناء الاستعلام بشكل ديناميكي ---
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'trainee');

    // أضف شرط البحث فقط إذا كان هناك نص
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('displayName', isGreaterThanOrEqualTo: _searchQuery)
          .where('displayName', isLessThan: '${_searchQuery}z');
    }
    // --- نهاية التعديل ---

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.searchTrainee,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<Locale>(
                  value: Localizations.localeOf(context),
                  icon: const Icon(Icons.language),
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null && widget.onLocaleChange != null) {
                      widget.onLocaleChange!(newLocale);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: Locale('en'), child: Text('EN')),
                    DropdownMenuItem(value: Locale('ar'), child: Text('AR')),
                    DropdownMenuItem(value: Locale('ru'), child: Text('RU')),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // استخدام الاستعلام الذي أنشأناه
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return EmptyStateWidget(
                  message: AppLocalizations.of(context)!.noTrainees,
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              }

              final trainees = snapshot.data!.docs;

              return ListView.builder(
                itemCount: trainees.length,
                itemBuilder: (context, index) {
                  final trainee = trainees[index];
                  final name =
                      trainee['displayName'] ??
                      AppLocalizations.of(context)!.addTrainingResult;
                  final email = trainee['email'] ?? 'No Email';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TraineeProfileScreen(traineeData: trainee),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
