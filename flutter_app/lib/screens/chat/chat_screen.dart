import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/connectivity_service.dart';
import '../../core/realtime_service.dart';
import '../../models/message.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String title;
  final int? receiverId;
  final int? groupId;

  const ChatScreen({super.key, required this.title, this.receiverId, this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatProvider _chatProvider;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider(receiverId: widget.receiverId, groupId: widget.groupId);

    final auth = context.read<AuthProvider>();
    _chatProvider.loadHistory(auth.currentUser!.id).then((_) => _scrollToBottom());

    _subscribeRealtime();

    // Whenever the connection comes back, automatically retry anything
    // that was sent while offline - this is the "just works" offline part.
    context.read<ConnectivityService>().addListener(_onConnectivityChanged);
  }

  Future<void> _subscribeRealtime() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.currentUser?.id;
    try {
      await RealtimeService().connect();
      if (!mounted) return;
      if (widget.groupId != null) {
        await RealtimeService().subscribeToGroup(widget.groupId!, (data) {
          _chatProvider.receiveRealtimeMessage(data['message']);
          _scrollToBottom();
        });
      } else if (widget.receiverId != null && myId != null) {
        await RealtimeService().subscribeToPrivateChat(myId, (data) {
          _chatProvider.receiveRealtimeMessage(data['message']);
          _scrollToBottom();
        });
      }
    } catch (_) {
      // Realtime is a bonus, not a requirement - if it fails to connect
      // (e.g. Reverb isn't running yet), the app still works via sync.
    }
  }

  void _onConnectivityChanged() {
    if (context.read<ConnectivityService>().isOnline) {
      _chatProvider.retryPending();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendImage() async {
    final isOnline = context.read<ConnectivityService>().isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos need internet to send - text messages still work offline.')),
      );
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final result = await _chatProvider.sendImageMessage(picked.path);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    _messageController.clear();
    await _chatProvider.sendMessage(auth.currentUser!.id, auth.currentUser!.fullName, text);
    _scrollToBottom();
  }

  void _showMessageActions(BuildContext context, ChatMessage msg, bool isMine) {
    if (msg.serverId == null || msg.isDeleted) return; // pending/deleted messages have nothing to act on yet

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Text('👍', style: TextStyle(fontSize: 20)),
              title: const Text('React 👍'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chatProvider.react(msg.serverId!, '👍');
              },
            ),
            ListTile(
              leading: const Text('❤️', style: TextStyle(fontSize: 20)),
              title: const Text('React ❤️'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chatProvider.react(msg.serverId!, '❤️');
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(msg.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(sheetContext);
                _chatProvider.togglePin(msg.serverId!);
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditDialog(msg);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _chatProvider.delete(msg.serverId!);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage msg) {
    final controller = TextEditingController(text: msg.body);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _chatProvider.edit(msg.serverId!, controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    context.read<ConnectivityService>().removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser!.id;
    final isOnline = context.watch<ConnectivityService>().isOnline;

    return ChangeNotifierProvider.value(
      value: _chatProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (widget.groupId != null)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(groupId: widget.groupId!, groupName: widget.title),
                )),
              ),
          ],
          bottom: !isOnline
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Container(
                    color: Colors.orange,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: const Text('Offline - messages will send once reconnected',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  if (chat.isLoading) return const Center(child: CircularProgressIndicator());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chat.messages[index];
                      final isMine = msg.senderId == myId;

                      return GestureDetector(
                        onLongPress: () => _showMessageActions(context, msg, isMine),
                        child: Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMine ? Colors.deepPurple : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (msg.isPinned)
                                Icon(Icons.push_pin, size: 12, color: isMine ? Colors.white70 : Colors.black45),
                              Text(
                                msg.isDeleted
                                    ? 'Message deleted'
                                    : (msg.messageType == 'image' ? '📷 Photo' : (msg.body ?? '')),
                                style: TextStyle(
                                      color: isMine ? Colors.white : Colors.black87,
                                      fontStyle: msg.isDeleted ? FontStyle.italic : FontStyle.normal)),
                              if (msg.isEdited && !msg.isDeleted)
                                Text('edited', style: TextStyle(fontSize: 10, color: isMine ? Colors.white60 : Colors.black45)),
                              if (msg.reactions.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  children: msg.reactions.entries
                                      .map((e) => Chip(
                                            label: Text('${e.key} ${(e.value as List).length}', style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ))
                                      .toList(),
                                ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.syncStatus == 'pending')
                                    Icon(Icons.access_time, size: 12, color: isMine ? Colors.white70 : Colors.black45),
                                  if (msg.syncStatus == 'synced' && isMine)
                                    Icon(Icons.check, size: 12, color: isMine ? Colors.white70 : Colors.black45),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.image_outlined), onPressed: _sendImage),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(icon: const Icon(Icons.send), onPressed: _send),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
