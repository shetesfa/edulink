import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';

class StudyRoomChatScreen extends StatefulWidget {
  final int roomId;
  final String roomName;
  const StudyRoomChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<StudyRoomChatScreen> createState() => _StudyRoomChatScreenState();
}

class _StudyRoomChatScreenState extends State<StudyRoomChatScreen> {
  final _api = ApiClient();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final result = await _api.safeCall(() => _api.dio.get('/study-rooms/${widget.roomId}/messages'));
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          final payload = result.data!['data'];
          final rows = payload is Map<String, dynamic> ? payload['data'] : payload;
          _messages = rows is List ? List<Map<String, dynamic>>.from(rows) : [];
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageCtrl.text.trim();
    if (body.isEmpty || _isSending) return;

    _messageCtrl.clear();
    setState(() => _isSending = true);

    final result = await _api.safeCall(() => _api.dio.post('/study-rooms/${widget.roomId}/messages', data: {'body': body}));

    if (mounted) {
      setState(() => _isSending = false);
      if (result.success && result.data != null) {
        final payload = result.data!['data'];
        final newMessages = <Map<String, dynamic>>[];
        if (payload is Map<String, dynamic>) {
          final message = payload['message'];
          final aiResponse = payload['ai_response'];
          if (message is Map<String, dynamic>) newMessages.add(message);
          if (aiResponse is Map<String, dynamic>) newMessages.add(aiResponse);
        }
        if (newMessages.isNotEmpty) {
          setState(() => _messages.addAll(newMessages));
        }
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Study Room', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
          // @edulink hint banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF3E8FF),
            child: const Row(
              children: [
                Text('🤖', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Type @edulink followed by your question to get an AI answer',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 12),
                            const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Start the discussion or ask @edulink a question!', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _buildMessage(_messages[i], currentUser?.id),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, int? myId) {
    final isAI = msg['is_ai_response'] == true;
    final senderId = msg['user_id'] as int?;
    final isMe = !isAI && senderId == myId;
    final user = msg['user'];
    final senderName = isAI
        ? 'EduLink AI'
        : user is Map<String, dynamic>
            ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
            : 'Student';
    final body = msg['body'] as String? ?? '';
    final time = msg['created_at'] as String? ?? '';

    if (isAI) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3E8FF), Color(0xFFE0F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🤖 EduLink AI', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('AI', style: TextStyle(fontSize: 9, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              child: Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF7C3AED) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(body, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(time.length >= 16 ? time.substring(11, 16) : '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Message... or type @edulink to ask AI',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: _isSending
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
