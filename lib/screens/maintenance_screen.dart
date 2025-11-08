import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final String? url;

  const MaintenanceScreen({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.url,
  });

  Future<void> _launchUrl() async {
    if (url != null && await canLaunchUrl(Uri.parse(url!))) {
      await launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication);
    } else {
      // Handle error
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              if (buttonText != null && url != null)
                ElevatedButton(onPressed: _launchUrl, child: Text(buttonText!)),
            ],
          ),
        ),
      ),
    );
  }
}
