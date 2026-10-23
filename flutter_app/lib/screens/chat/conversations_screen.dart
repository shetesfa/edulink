import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'chat_screen.dart';
import 'create_group_dialog.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _api = ApiClient();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/chat/conversations'));
    if (result.success && result.data != null) {
      final conversationsList = result.data!['conversations'] ?? result.data!['data']?['conversations'];
      if (conversationsList is List) {
        setState(() => _conversations = conversationsList);
      }
    }
    setState(() => _isLoading = false);
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Group via Code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Group Join Code (e.g. GRP-XXXXXX)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                final result = await _api.safeCall(() => _api.dio.post('/chat/groups/join', data: {
                  'join_code': codeController.text.trim(),
                }));
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
                if (result.success) _load();
              }
            },
            child: const Text('Join Group'),
          ),
        ],
      ),
    );
  }

  void _showSearchUserDialog() {
    final queryController = TextEditingController();
    List<dynamic> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Search Users'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: queryController,
                decoration: InputDecoration(
                  labelText: 'Name or Username',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      if (queryController.text.trim().length >= 2) {
                        setDialogState(() => isSearching = true);
                        final result = await _api.safeCall(() => _api.dio.get('/search', queryParameters: {'query': queryController.text.trim()}));
                        if (result.success && result.data != null) {
                          setDialogState(() {
                            searchResults = result.data!['users'] ?? result.data!['data']?['users'] ?? [];
                          });
                        }
                        setDialogState(() => isSearching = false);
                      }
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (isSearching) const CircularProgressIndicator(),
              if (!isSearching && searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final u = searchResults[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('${u['first_name']} ${u['last_name']}'),
                        subtitle: Text(u['email'] ?? ''),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                title: '${u['first_name']} ${u['last_name']}',
                                receiverId: u['id'],
                              ),
                            ),
                          ).then((_) => _load());
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directMessages = _conversations.where((c) => c['type'] == 'private').toList();
    final groupChats = _conversations.where((c) => c['type'] == 'group').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages & Groups'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_search_outlined),
              tooltip: 'Find Users',
              onPressed: _showSearchUserDialog,
            ),
            IconButton(
              icon: const Icon(Icons.vpn_key_outlined),
              tooltip: 'Join Group via Code',
              onPressed: _showJoinGroupDialog,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'Direct Messages'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Groups'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('New Chat / Group'),
          onPressed: () async {
            showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('Search & Chat User'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSearchUserDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.group_add),
                      title: const Text('Create New Group'),
                      onTap: () async {
                        Navigator.pop(context);
                        final created = await showDialog<bool>(context: context, builder: (_) => const CreateGroupDialog());
                        if (created == true) _load();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.vpn_key),
                      title: const Text('Join Group via Code'),
                      onTap: () {
                        Navigator.pop(context);
                        _showJoinGroupDialog();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Direct Messages Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: directMessages.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: [
                              const Center(child: Text('No direct messages yet. Search users to start chatting!')),
                              const SizedBox(height: 16),
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: _showSearchUserDialog,
                                  icon: const Icon(Icons.person_search),
                                  label: const Text('Find People'),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: directMessages.length,
                            itemBuilder: (context, index) {
                              final c = directMessages[index];
                              final name = '${c['user']['first_name']} ${c['user']['last_name']}';
                              final lastBody = c['last_message']?['body'] ?? '';
                              final unread = c['unread_count'] ?? 0;

                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(name),
                                subtitle: Text(lastBody, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: unread > 0
                                    ? CircleAvatar(radius: 12, backgroundColor: Colors.deepPurple, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)))
                                    : null,
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        title: name,
                                        receiverId: c['user']['id'],
                                      ),
                                    ))
                                    .then((_) => _load()),
                              );
                            },
                          ),
                  ),
                  // Group Chats Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: groupChats.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: [
                              const Center(child: Text('No group chats yet. Join or create a group!')),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _showJoinGroupDialog,
                                    icon: const Icon(Icons.vpn_key),
                                    label: const Text('Join Code'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final created = await showDialog<bool>(context: context, builder: (_) => const CreateGroupDialog());
                                      if (created == true) _load();
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('New Group'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: groupChats.length,
                            itemBuilder: (context, index) {
                              final c = groupChats[index];
                              final name = c['group']['name'];
                              final lastBody = c['last_message']?['body'] ?? '';
                              final unread = c['unread_count'] ?? 0;

                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.groups)),
                                title: Text(name),
                                subtitle: Text(lastBody, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: unread > 0
                                    ? CircleAvatar(radius: 12, backgroundColor: Colors.deepPurple, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)))
                                    : null,
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        title: name,
                                        groupId: c['group']['id'],
                                      ),
                                    ))
                                    .then((_) => _load()),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
