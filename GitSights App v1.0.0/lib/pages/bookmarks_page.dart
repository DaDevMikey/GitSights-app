import 'package:flutter/material.dart';

class BookmarksPage extends StatelessWidget {
  final List<Map<String, dynamic>> bookmarks;
  final Function(Map<String, dynamic>) onRemove;
  final Function(Map<String, dynamic>) onItemSelected;

  const BookmarksPage({
    Key? key,
    required this.bookmarks,
    required this.onRemove,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: bookmarks.isEmpty
          ? const Center(
              child: Text('No bookmarks yet.'),
            )
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final item = bookmarks[index];
                return Dismissible(
                  key: ValueKey(item['id']),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    onRemove(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${item['name'] ?? item['login']} removed from bookmarks'),
                      ),
                    );
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    title: Text(item['name'] ?? item['login'] ?? 'Unknown'),
                    subtitle: Text(item['description'] ?? 'No description'),
                    onTap: () => onItemSelected(item),
                  ),
                );
              },
            ),
    );
  }
}
