import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/trainee_profile_screen.dart';
// -------------------------------------------
import 'package:drone_academy/services/api_service.dart';
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
  final ApiService _apiService = ApiService();
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.searchTrainee,
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
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
                  dropdownColor: const Color(0xFF1E2230),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.language, color: Colors.white),
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
          child: StreamBuilder<List<dynamic>>(
            stream: _apiService.streamUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data ?? [];

              // تصفية المتدربين فقط + البحث
              final trainees = users.where((u) {
                final role = u['role'];
                if (role != 'trainee') return false;

                final name = (u['displayName'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

              if (trainees.isEmpty) {
                return EmptyStateWidget(
                  message: l10n.noTrainees,
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              }

              return ListView.builder(
                itemCount: trainees.length,
                itemBuilder: (context, index) {
                  final trainee = trainees[index]; // Map<String, dynamic>
                  final name = trainee['displayName'] ?? 'Unknown';
                  final email = trainee['email'] ?? 'No Email';
                  final photoUrl = trainee['photoUrl'];

                  return Card(
                    color: const Color(0xFF1E2230),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage:
                            (photoUrl != null && photoUrl.toString().isNotEmpty)
                            ? CachedNetworkImageProvider(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.toString().isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        email,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TraineeProfileScreen(
                              traineeData: trainee,
                            ), // تمرير الـ Map مباشرة
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
