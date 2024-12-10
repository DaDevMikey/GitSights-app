import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'pages/infos_page.dart';
import 'pages/detail_page.dart';
import 'pages/bookmarks_page.dart';

void main() {
  runApp(const GitBoardApp());
}

class GitBoardApp extends StatefulWidget {
  const GitBoardApp({Key? key}) : super(key: key);

  @override
  State<GitBoardApp> createState() => _GitBoardAppState();
}

class _GitBoardAppState extends State<GitBoardApp> {
  bool _isDarkTheme = false;

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: GitBoardHome(
        isDarkTheme: _isDarkTheme,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

class GitBoardHome extends StatefulWidget {
  final bool isDarkTheme;
  final VoidCallback onThemeToggle;

  const GitBoardHome({
    Key? key,
    required this.isDarkTheme,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  State<GitBoardHome> createState() => _GitBoardHomeState();
}

class _GitBoardHomeState extends State<GitBoardHome> {
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'Repositories';
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;
  double _progress = 0.0;
  bool _canSearch = true;

  final String githubBaseUrl = 'https://api.github.com';

  void _performSearch(String query) async {
    if (!_canSearch) return;
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a search term.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String endpoint;
    switch (_searchType) {
      case 'Users':
        endpoint = '/search/users?q=$query';
        break;
      case 'Repositories':
        endpoint = '/search/repositories?q=$query';
        break;
      case 'Gists':
        endpoint = '/gists/public';
        break;
      default:
        endpoint = '/search/repositories?q=$query';
    }

    final url = Uri.parse('$githubBaseUrl$endpoint');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _searchResults = _searchType == 'Gists'
              ? List<Map<String, dynamic>>.from(data)
              : List<Map<String, dynamic>>.from(data['items']);
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch results. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please check your connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _startSearchCooldown();
    }
  }

  void _startSearchCooldown() {
    setState(() {
      _canSearch = false;
      _progress = 1.0;
    });

    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_progress <= 0.0) {
        timer.cancel();
        setState(() {
          _canSearch = true;
        });
      } else {
        setState(() {
          _progress -= 0.01;
        });
      }
    });
  }

  void _addBookmark(Map<String, dynamic> item) {
    if (!_bookmarks.any((bookmark) => bookmark['id'] == item['id'])) {
      setState(() {
        _bookmarks.add(item);
      });
    }
  }

  void _removeBookmark(Map<String, dynamic> item) {
    setState(() {
      _bookmarks.removeWhere((bookmark) => bookmark['id'] == item['id']);
    });
  }

  void _navigateToInfosPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfosPage(
          isDarkTheme: widget.isDarkTheme,
          onThemeToggle: widget.onThemeToggle,
        ),
      ),
    );
  }

  void _navigateToDetailPage(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(item: item, type: _searchType),
      ),
    );
  }

  void _navigateToBookmarksPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookmarksPage(
          bookmarks: _bookmarks,
          onRemove: _removeBookmark,
          onItemSelected: _navigateToDetailPage,
        ),
      ),
    );
  }

  Widget _buildItemList(Map<String, dynamic> item) {
    final isBookmarked =
        _bookmarks.any((bookmark) => bookmark['id'] == item['id']);
    return ListTile(
      title: Text(item['login'] ?? item['name'] ?? 'Unknown'),
      subtitle: Text(item['description'] ?? 'No description'),
      trailing: IconButton(
        icon: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
          color: isBookmarked ? Colors.blue.shade700 : null,
        ),
        onPressed: () {
          if (isBookmarked) {
            _removeBookmark(item);
          } else {
            _addBookmark(item);
          }
        },
      ),
      onTap: () => _navigateToDetailPage(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitBoard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: _navigateToBookmarksPage,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _navigateToInfosPage,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search $_searchType',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _performSearch(_searchController.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                DropdownButton<String>(
                  value: _searchType,
                  onChanged: (value) {
                    setState(() {
                      _searchType = value!;
                    });
                  },
                  items: ['Users', 'Repositories', 'Gists']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                ),
              ],
            ),
            if (_progress < 1.0)
              LinearProgressIndicator(
                value: _progress,
                color: Colors.red,
                backgroundColor: Colors.grey.shade200,
              ),
            const SizedBox(height: 8.0),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(child: Text(_errorMessage!))
            else if (_searchResults.isEmpty)
              const Center(
                  child: Text('No results found. Start typing to search!'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return _buildItemList(item);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
