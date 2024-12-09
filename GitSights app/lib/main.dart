import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(GitSightApp(prefs: prefs));
}

class GitSightApp extends StatefulWidget {
  final SharedPreferences prefs;

  const GitSightApp({Key? key, required this.prefs}) : super(key: key);

  @override
  _GitSightAppState createState() => _GitSightAppState();
}

class _GitSightAppState extends State<GitSightApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.prefs.getBool('darkMode') ?? false;
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      widget.prefs.setBool('darkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitSight',
      theme: _isDarkMode ? _darkTheme : _lightTheme,
      home: HomeScreen(toggleTheme: _toggleTheme),
    );
  }

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blueGrey,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const HomeScreen({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _selectedType = 'repositories';
  final List<String> _searchTypes = ['repositories', 'users', 'gists'];
  List<dynamic> _bookmarks = [];
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchGitHub(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/search/$_selectedType?q=$query&per_page=30'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['items'];
          _animationController.forward(from: 0.0);
        });
      } else {
        _handleApiError(response);
      }
    } on TimeoutException {
      _showErrorDialog(
        'Request timed out',
        allowRetry: true,
        retryAction: () => _searchGitHub(query),
      );
    } catch (e) {
      _showErrorDialog(
        'Error searching GitHub: ${e.toString()}',
        allowRetry: true,
        retryAction: () => _searchGitHub(query),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleApiError(http.Response response) {
    switch (response.statusCode) {
      case 403:
        _showErrorDialog('Rate limit exceeded. Please try again later.');
        break;
      case 422:
        _showErrorDialog('Invalid search query.');
        break;
      default:
        _showErrorDialog('GitHub API error: ${response.statusCode}');
    }
  }

  void _showErrorDialog(
    String message, {
    bool allowRetry = false,
    VoidCallback? retryAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          if (allowRetry && retryAction != null)
            TextButton(
              child: Text('Retry'),
              onPressed: () {
                Navigator.of(ctx).pop();
                retryAction();
              },
            ),
          TextButton(
            child: Text('Report Issue'),
            onPressed: () {
              _launchURL(
                  'https://github.com/DaDevMikey/Github-Insights/issues/new');
            },
          ),
          TextButton(
            child: Text('Okay'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        _showErrorDialog('Could not launch $url');
      }
    } catch (e) {
      _showErrorDialog('Error launching URL: $e');
    }
  }

  void _showInfoScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InfoScreen(launchURL: _launchURL),
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    bool isExpanded = false;
    List<dynamic> userRepos = [];

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            ListTile(
              title: Text(_getItemTitle(item)),
              subtitle: Text(_getItemSubtitle(item)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBookmarkButton(item),
                  _buildAdditionalInfo(item),
                ],
              ),
              onTap: _selectedType == 'users'
                  ? () async {
                      if (!isExpanded) {
                        try {
                          final response = await http.get(
                            Uri.parse('${item['repos_url']}'),
                          );
                          if (response.statusCode == 200) {
                            setState(() {
                              userRepos = json.decode(response.body);
                              isExpanded = true;
                            });
                          }
                        } catch (e) {
                          _showErrorDialog('Error fetching user repositories');
                        }
                      } else {
                        setState(() {
                          isExpanded = false;
                        });
                      }
                    }
                  : () => _showDetailsDialog(item),
            ),
            if (_selectedType == 'users' && isExpanded)
              ...userRepos.map((repo) => ListTile(
                    title: Text(repo['full_name']),
                    subtitle: Text(repo['description'] ?? 'No description'),
                    trailing: Text('★ ${repo['stargazers_count']}'),
                    onTap: () => _launchURL(repo['html_url']),
                  )),
          ],
        );
      },
    );
  }

  String _getItemTitle(dynamic item) {
    switch (_selectedType) {
      case 'repositories':
        return item['full_name'];
      case 'users':
        return item['login'];
      case 'gists':
        return item['owner']['login'];
      default:
        return 'Unknown';
    }
  }

  String _getItemSubtitle(dynamic item) {
    switch (_selectedType) {
      case 'repositories':
        return item['description'] ?? 'No description';
      case 'users':
        return item['bio'] ?? 'No bio';
      case 'gists':
        return item['description'] ?? 'Unnamed Gist';
      default:
        return 'Unknown';
    }
  }

  Widget _buildBookmarkButton(dynamic item) {
    final isBookmarked = _bookmarks.any(
      (bookmark) => bookmark['id'] == item['id'],
    );

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: isBookmarked ? Colors.blue : null,
      ),
      onPressed: () => setState(() {
        isBookmarked
            ? _bookmarks.removeWhere((bookmark) => bookmark['id'] == item['id'])
            : _bookmarks.add(item);
      }),
    );
  }

  Widget _buildAdditionalInfo(dynamic item) {
    switch (_selectedType) {
      case 'repositories':
        return Text('★ ${item['stargazers_count']}');
      case 'users':
        return Text('Followers: ${item['followers'] ?? 0}');
      default:
        return SizedBox.shrink();
    }
  }

  void _showDetailsDialog(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_getItemTitle(item)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${_getItemSubtitle(item)}'),
              if (_selectedType == 'repositories') ...[
                Text('Stars: ${item['stargazers_count']}'),
                Text('Forks: ${item['forks_count']}'),
                Text('Watchers: ${item['watchers_count']}'),
                Text('Language: ${item['language'] ?? 'N/A'}'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _launchURL(item['owner']['html_url']),
                      child: Text('View Profile'),
                    ),
                    SizedBox(width: 10),
                    if (item['homepage'] != null)
                      ElevatedButton(
                        onPressed: () => _launchURL(item['homepage']),
                        child: Text('Website'),
                      ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _launchURL(item['html_url']),
                      child: Text('Source Code'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GitSight'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_4),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showInfoScreen,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedType,
                  items: _searchTypes.map((String type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.capitalize()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedType = newValue!;
                    });
                  },
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search GitHub...',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () => _searchGitHub(_searchController.text),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _searchGitHub,
                  ),
                ),
              ],
            ),
          ),
          _isLoading
              ? FadeTransition(
                  opacity: _animation,
                  child: CircularProgressIndicator(),
                )
              : Expanded(
                  child: FadeTransition(
                    opacity: _animation,
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, index) {
                        return _buildSearchResultItem(_searchResults[index]);
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  final Function(String) launchURL;

  const InfoScreen({Key? key, required this.launchURL}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About GitSight'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GitSight',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 16),
            Text(
              'A comprehensive GitHub search and exploration app.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            _buildLinkTile(
              context,
              'Creator: DaDevMikey',
              'https://github.com/DaDevMikey',
            ),
            _buildLinkTile(
              context,
              'Official Website',
              'https://GitSights.vercel.app/',
            ),
            _buildLinkTile(
              context,
              'Personal Website',
              'https://nexas-development.vercel.app/',
            ),
            _buildLinkTile(
              context,
              'GitHub Repository',
              'https://github.com/DaDevMikey/Github-Insights',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(BuildContext context, String title, String url) {
    return ListTile(
      title: Text(title),
      trailing: Icon(Icons.open_in_new),
      onTap: () => launchURL(url),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
