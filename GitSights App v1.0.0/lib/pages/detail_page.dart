import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;

  const DetailPage({Key? key, required this.item, required this.type})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(type == 'Users' ? item['login'] : item['name']),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: type == 'Users' ? _buildUserDetails() : _buildRepoDetails(),
      ),
    );
  }

  Widget _buildRepoDetails() {
    final repoUrl = item['html_url'];
    final creatorUrl = item['owner']?['html_url'];
    final website = item['homepage'];
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          item['name'] ?? 'Unknown Repository',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(item['description'] ?? 'No description available.'),
        const SizedBox(height: 16),
        _buildStatRow('Stars', item['stargazers_count']),
        _buildStatRow('Forks', item['forks_count']),
        _buildStatRow('Watchers', item['watchers_count']),
        _buildStatRow('Primary Language', item['language']),
        const SizedBox(height: 16),
        if (repoUrl != null)
          ElevatedButton(
            onPressed: () async => await _launchUrl(repoUrl),
            child: const Text('View on GitHub'),
          ),
        if (creatorUrl != null)
          ElevatedButton(
            onPressed: () async => await _launchUrl(creatorUrl),
            child: const Text('View Creator Profile'),
          ),
        if (website != null && website.isNotEmpty)
          ElevatedButton(
            onPressed: () async => await _launchUrl(website),
            child: const Text('Visit Website'),
          ),
      ],
    );
  }

  Widget _buildUserDetails() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (item['avatar_url'] != null)
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(item['avatar_url']),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          item['login'] ?? 'Unknown User',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStatRow('Repositories', item['public_repos']),
        _buildStatRow('Followers', item['followers']),
        _buildStatRow('Following', item['following']),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async => await _launchUrl(item['html_url']),
          child: const Text('View Profile on GitHub'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value?.toString() ?? 'N/A'),
        ],
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
