import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  Map<String, dynamic>? _results;
  bool _isLoading = false;

  Future<void> _search() async {
    if (_controller.text.trim().length < 2) return;
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/search', queryParameters: {'query': _controller.text.trim()}));
    if (result.success && result.data != null) {
      setState(() => _results = result.data!['data']);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search classes, lessons, people...', border: InputBorder.none),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onSubmitted: (_) => _search(),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: _search)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results == null
              ? const Center(child: Text('Search across your classes, lessons, assignments, quizzes, and people.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _section('Classes', _results!['classes'], Icons.class_),
                    _section('Lessons', _results!['lessons'], Icons.menu_book, titleKey: 'title'),
                    _section('Assignments', _results!['assignments'], Icons.assignment, titleKey: 'title'),
                    _section('Quizzes', _results!['quizzes'], Icons.quiz, titleKey: 'title'),
                    _peopleSection(_results!['people']),
                  ],
                ),
    );
  }

  Widget _section(String label, List<dynamic>? items, IconData icon, {String titleKey = 'name'}) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        ...items.map((i) => ListTile(leading: Icon(icon), title: Text(i[titleKey] ?? ''))),
      ],
    );
  }

  Widget _peopleSection(List<dynamic>? people) {
    if (people == null || people.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('People', style: Theme.of(context).textTheme.titleMedium)),
        ...people.map((p) {
          final username = p['username'];
          final hasPhoto = p['profile_photo'] != null && (p['profile_photo'] as String).isNotEmpty;
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: hasPhoto ? NetworkImage(p['profile_photo']) : null,
              child: hasPhoto ? null : Text(
                '${p['first_name']?[0] ?? '?'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text('${p['first_name']} ${p['last_name']}'),
            subtitle: Text(username != null ? '@$username' : (p['email'] ?? '')),
          );
        }),
      ],
    );
  }
}
