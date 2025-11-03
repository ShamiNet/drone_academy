import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainingDetailsScreen extends StatefulWidget {
  final QueryDocumentSnapshot training;
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
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Show an error snackbar if the URL can't be launched
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  // --- دالة جديدة: لتحديث حالة إتمام الخطوة ---
  void _onStepCompleted(bool isCompleted, String stepId) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final progressCollection = FirebaseFirestore.instance.collection(
      'step_progress',
    );
    final query = progressCollection
        .where('userId', isEqualTo: userId)
        .where('trainingId', isEqualTo: widget.training.id)
        .where('stepId', isEqualTo: stepId);

    if (isCompleted) {
      // إذا تم تحديد المربع، أضف سجل التقدم
      progressCollection.add({
        'userId': userId,
        'trainingId': widget.training.id,
        'stepId': stepId,
        'completedAt': Timestamp.now(),
      });
    } else {
      // إذا تم إلغاء التحديد، احذف سجل التقدم
      query.get().then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.training['title'] ?? 'No Title';
    final String description =
        widget.training['description'] ?? 'No Description';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          Hero(
            tag: 'training_image_${widget.training.id}',
            // --- This is the corrected section ---
            child: (widget.imageUrl.isNotEmpty)
                // If we have a URL, use Image.network
                ? CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        Image.asset('assets/images/drone_training_1.jpg'),
                  )
                // Otherwise, fall back to the local placeholder asset
                : Image.asset(
                    'assets/images/drone_training_1.jpg',
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
            // --- End of correction ---
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
              "Training Steps", // Needs translation key: 'trainingSteps'
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // --- بداية التعديل الكبير: استخدام StreamBuilder متداخل ---
          // StreamBuilder الأول: لجلب كل خطوات التدريب
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trainings')
                .doc(widget.training.id)
                .collection('steps')
                .orderBy('order')
                .snapshots(),
            builder: (context, stepsSnapshot) {
              final l10n = AppLocalizations.of(context)!;
              if (!stepsSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (stepsSnapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(l10n.noStepsAdded),
                );
              }

              // StreamBuilder الثاني: ليستمع لتقدم المتدرب في هذه الخطوات
              return StreamBuilder<QuerySnapshot>(
                stream: (userId != null)
                    ? FirebaseFirestore.instance
                          .collection('step_progress')
                          .where('userId', isEqualTo: userId)
                          .where('trainingId', isEqualTo: widget.training.id)
                          .snapshots()
                    : const Stream.empty(),
                builder: (context, progressSnapshot) {
                  // إنشاء مجموعة "Set" بالخطوات المكتملة لسهولة البحث
                  final completedStepIds = <String>{};
                  if (progressSnapshot.hasData) {
                    for (var doc in progressSnapshot.data!.docs) {
                      completedStepIds.add(doc['stepId']);
                    }
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stepsSnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final step = stepsSnapshot.data!.docs[index];
                      final stepType = step['type'];
                      final stepTitle = step['title'];

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

                      final isCompleted = completedStepIds.contains(step.id);

                      return Card(
                        child: CheckboxListTile(
                          title: Text(stepTitle),
                          value: isCompleted,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _onStepCompleted(value, step.id);
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
