import 'dart:convert';

class ChatMessage {
  final String clientMessageId;
  final int? serverId;
  final int senderId;
  final String senderName;
  final int? receiverId;
  final int? groupId;
  final String messageType;
  final String? body;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final Map<String, dynamic> reactions;
  final String syncStatus; // synced | pending | failed
  final DateTime createdAt;

  ChatMessage({
    required this.clientMessageId,
    this.serverId,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    this.groupId,
    required this.messageType,
    this.body,
    this.isEdited = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.reactions = const {},
    this.syncStatus = 'synced',
    required this.createdAt,
  });

  factory ChatMessage.fromServerJson(Map<String, dynamic> json) {
    return ChatMessage(
      clientMessageId: json['client_message_id'] ?? json['id'].toString(),
      serverId: json['id'],
      senderId: json['sender_id'],
      senderName: json['sender'] != null ? '${json['sender']['first_name']} ${json['sender']['last_name']}' : '',
      receiverId: json['receiver_id'],
      groupId: json['group_id'],
      messageType: json['message_type'] ?? 'text',
      body: json['body'],
      isEdited: json['is_edited'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      isPinned: json['is_pinned'] ?? false,
      reactions: Map<String, dynamic>.from(json['reactions'] ?? {}),
      syncStatus: 'synced',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  factory ChatMessage.fromLocalRow(Map<String, dynamic> row) {
    return ChatMessage(
      clientMessageId: row['client_message_id'],
      serverId: row['server_id'],
      senderId: row['sender_id'],
      senderName: '',
      receiverId: row['receiver_id'],
      groupId: row['group_id'],
      messageType: row['message_type'] ?? 'text',
      body: row['body'],
      isEdited: row['is_edited'] == 1,
      isDeleted: row['is_deleted'] == 1,
      isPinned: row['is_pinned'] == 1,
      reactions: row['reactions'] != null && row['reactions'] != ''
          ? Map<String, dynamic>.from(jsonDecode(row['reactions']))
          : {},
      syncStatus: row['sync_status'] ?? 'synced',
      createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toLocalRow() => {
        'client_message_id': clientMessageId,
        'server_id': serverId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'group_id': groupId,
        'reply_to_id': null,
        'message_type': messageType,
        'body': body,
        'reactions': jsonEncode(reactions),
        'is_edited': isEdited ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
        'is_pinned': isPinned ? 1 : 0,
        'sync_status': syncStatus,
        'created_at': createdAt.toIso8601String(),
      };
}
