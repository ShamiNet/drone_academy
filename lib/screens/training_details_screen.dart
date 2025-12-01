import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TrainingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> training;
  final String imageUrl;

  const TrainingDetailsScreen({
    super.key,
    required this.training,
    required this.imageUrl,
  });

  @override
  State<TrainingDetailsScreen> createState() => _TrainingDetailsScreenState();
}

class _TrainingDetailsScreenState extends State<TrainingDetailsScreen> {
  final ApiService _apiService = ApiService();

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  void _onStepCompleted(bool isCompleted, String stepId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _apiService.setStepProgress(
      userId,
      widget.training['id'],
      stepId,
      isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String title = widget.training['title'] ?? 'No Title';
    final String description =
        widget.training['description'] ?? 'No Description';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          Hero(
            tag: 'training_image_${widget.training['id']}',
            child: (widget.imageUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        Image.asset('assets/images/drone_training_1.jpg'),
                  )
                : Image.asset(
                    'assets/images/drone_training_1.jpg',
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              l10n.trainingSteps,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // جلب الخطوات من السيرفر
          FutureBuilder<List<dynamic>>(
            future: _apiService.fetchSteps(widget.training['id']),
            builder: (context, stepsSnapshot) {
              if (stepsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final steps = stepsSnapshot.data ?? [];
              if (steps.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(l10n.noStepsAdded),
                );
              }

              // الاستماع للتقدم من السيرفر
              return StreamBuilder<List<dynamic>>(
                stream: (userId != null)
                    ? _apiService.streamStepProgress(
                        userId,
                        widget.training['id'],
                      )
                    : const Stream.empty(),
                builder: (context, progressSnapshot) {
                  final completedStepIds = <String>{};
                  if (progressSnapshot.hasData) {
                    for (var doc in progressSnapshot.data!) {
                      completedStepIds.add(doc['stepId']);
                    }
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final stepType = step['type'];
                      final stepTitle = step['title'];
                      final stepId = step['id']; // تأكد أن السيرفر يرسل id

                      if (stepType == 'video') {
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.videocam,
                              color: Colors.red,
                            ),
                            title: Text(stepTitle),
                            onTap: () => _launchURL(step['videoUrl']),
                          ),
                        );
                      }

                      final isCompleted = completedStepIds.contains(stepId);
                      return Card(
                        child: CheckboxListTile(
                          title: Text(stepTitle),
                          value: isCompleted,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _onStepCompleted(value, stepId);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
