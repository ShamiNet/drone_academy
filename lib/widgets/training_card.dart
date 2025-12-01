import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/screens/training_details_screen.dart';
import 'package:flutter/material.dart';

class TrainingCard extends StatelessWidget {
  // تم التغيير لقبول Map<String, dynamic>
  final Map<String, dynamic> training;

  const TrainingCard({super.key, required this.training});

  @override
  Widget build(BuildContext context) {
    final title = training['title'] ?? 'No Title';
    final imageUrl = training['imageUrl'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: (imageUrl != null && imageUrl.toString().isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 50,
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      Image.asset('assets/images/drone_training_1.jpg'),
                )
              : Image.asset(
                  'assets/images/drone_training_1.jpg',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrainingDetailsScreen(
                training: training,
                imageUrl: imageUrl ?? 'assets/images/drone_training_1.jpg',
              ),
            ),
          );
        },
      ),
    );
  }
}
