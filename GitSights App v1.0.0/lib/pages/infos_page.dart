import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfosPage extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onThemeToggle;

  const InfosPage({
    Key? key,
    required this.isDarkTheme,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GitBoard App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Developed by Nexas Studios'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Dark Mode: '),
                Switch(
                  value: isDarkTheme,
                  onChanged: (_) => onThemeToggle(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Links',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: () => _launchUrl(
                  'https://github.com/DaDevMikey/GitSights-app/tree/main'),
              child: const Text('Source Code'),
            ),
            ElevatedButton(
              onPressed: () => _launchUrl('https://githubinsights.vercel.app/'),
              child: const Text('Web Version'),
            ),
            ElevatedButton(
              onPressed: () =>
                  _launchUrl('https://nexas-development.vercel.app/'),
              child: const Text('Nexas Studios Website'),
            ),
            ElevatedButton(
              onPressed: () => _launchUrl('https://github.com/DaDevMikey'),
              child: const Text("Developer's GitHub"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }
}
