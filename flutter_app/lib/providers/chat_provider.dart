import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/local_database.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final _uuid = const Uuid();

  final int? receiverId;
  final int? groupId;
  int? _currentUserId;

  List<ChatMessage> messages = [];
  bool isLoading = true;

  ChatProvider({this.receiverId, this.groupId});

  String get _endpoint => groupId != null ? '/chat/groups/$groupId/messages' : '/chat/private/$receiverId';

  /// 1. Show whatever is already saved on the device INSTANTLY (works with
  ///    zero internet). 2. Quietly ask the server for anything newer using
  ///    `?since=` so we only fetch what changed, not the whole history again.
  Future<void> loadHistory(int currentUserId) async {
    _currentUserId = currentUserId;
    isLoading = true;
    notifyListeners();

    await _loadFromLocalDb(currentUserId);
    isLoading = false;
    notifyListeners();

    await _syncFromServer(currentUserId);
  }

  Future<void> _loadFromLocalDb([int? currentUserId]) async {
    final db = await LocalDatabase.instance;
    final hasPrivateParticipants = groupId == null && currentUserId != null && receiverId != null;
    final where = groupId != null
        ? 'group_id = ?'
        : hasPrivateParticipants
            ? '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))'
            : '(sender_id = ? OR receiver_id = ?)';
    final whereArgs = groupId != null
        ? [groupId]
        : hasPrivateParticipants
            ? [currentUserId, receiverId, receiverId, currentUserId]
            : [receiverId, receiverId];

    final rows = await db.query('local_messages', where: where, whereArgs: whereArgs, orderBy: 'created_at ASC');
    messages = rows.map((r) => ChatMessage.fromLocalRow(r)).toList();
  }

  Future<void> _syncFromServer([int? currentUserId]) async {
    final lastLocal = messages.where((m) => m.syncStatus == 'synced').toList();
    final since = lastLocal.isNotEmpty ? lastLocal.last.createdAt.toIso8601String() : null;

    final result = await _api.safeCall(
      () => _api.dio.get(_endpoint, queryParameters: since != null ? {'since': since} : null),
    );

    if (!result.success || result.data == null) return; // offline - what we loaded locally is all we show, and that's fine

    final messagesPayload = result.data!['messages'] ?? result.data!['data']?['messages'];
    final msgsList = messagesPayload is Map<String, dynamic> ? messagesPayload['data'] : messagesPayload;
    if (msgsList is! List) return;

    final serverMessages = msgsList
        .map((m) => ChatMessage.fromServerJson(m))
        .toList();

    final db = await LocalDatabase.instance;
    for (final msg in serverMessages) {
      await db.insert('local_messages', msg.toLocalRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await _loadFromLocalDb(currentUserId);
    notifyListeners();
  }

  /// Send a message that works the same way whether you're online or not:
  /// it appears in the chat immediately (optimistic, saved to SQLite first),
  /// then quietly tries to reach the server. If that fails because there's
  /// no internet, it just stays marked "pending" - nothing is lost, and it
  /// will go out automatically next time `retryPending()` runs (e.g. when
  /// ConnectivityService notices the connection came back).
  /// Sends an image attachment. Unlike sendMessage() (fully offline-safe),
  /// this needs connectivity at send time - queuing large binary files for
  /// later offline upload is a bigger undertaking than queuing small text
  /// rows, so this is a deliberate scope simplification: text chat works
  /// fully offline, image attachments require being online when sent.
  Future<ApiResult<Map<String, dynamic>>> sendImageMessage(String filePath) async {
    final clientId = _uuid.v4();
    final formData = FormData.fromMap({
      'client_message_id': clientId,
      'message_type': 'image',
      'attachments': [await MultipartFile.fromFile(filePath)],
    });

    final result = await _api.safeCall(() => _api.dio.post(_endpoint, data: formData));
    if (result.success) {
      final messageJson = result.data!['message'] ?? result.data!['data']?['message'];
      if (messageJson != null) {
        final message = ChatMessage.fromServerJson(messageJson);
        final db = await LocalDatabase.instance;
        await db.insert('local_messages', message.toLocalRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        await _loadFromLocalDb(_currentUserId);
        notifyListeners();
      }
    }
    return result;
  }

  Future<void> sendMessage(int senderId, String senderName, String body) async {
    final clientId = _uuid.v4();
    final message = ChatMessage(
      clientMessageId: clientId,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      groupId: groupId,
      messageType: 'text',
      body: body,
      syncStatus: 'pending',
      createdAt: DateTime.now(),
    );

    final db = await LocalDatabase.instance;
    await db.insert('local_messages', message.toLocalRow());

    messages.add(message);
    notifyListeners();

    await _trySend(message);
  }

  Future<void> _trySend(ChatMessage message) async {
    final result = await _api.safeCall(() => _api.dio.post(_endpoint, data: {
          'client_message_id': message.clientMessageId,
          'body': message.body,
          'message_type': message.messageType,
        }));

    final db = await LocalDatabase.instance;

    if (result.success) {
      final serverJson = result.data!['message'] ?? result.data!['data']?['message'];
      if (serverJson != null) {
        await db.update(
          'local_messages',
          {'server_id': serverJson['id'], 'sync_status': 'synced'},
          where: 'client_message_id = ?',
          whereArgs: [message.clientMessageId],
        );
      }
    } else {
      // Stays 'pending' in SQLite - retryPending() will pick it up later.
      await db.update('local_messages', {'sync_status': 'pending'},
          where: 'client_message_id = ?', whereArgs: [message.clientMessageId]);
    }

    await _loadFromLocalDb(_currentUserId);
    notifyListeners();
  }

  /// Call this when connectivity comes back online - resends every message
  /// still sitting in "pending" state. Safe to call as often as you like:
  /// the server recognizes client_message_id and never creates duplicates.
  Future<void> retryPending() async {
    final pending = messages.where((m) => m.syncStatus == 'pending').toList();
    for (final message in pending) {
      await _trySend(message);
    }
  }

  /// Called by the realtime listener when a message arrives over Reverb
  /// from someone else, so it shows up instantly without waiting for the
  /// next poll/sync.
  Future<void> receiveRealtimeMessage(Map<String, dynamic> json) async {
    final message = ChatMessage.fromServerJson(json);
    final db = await LocalDatabase.instance;
    await db.insert('local_messages', message.toLocalRow());
    await _loadFromLocalDb(_currentUserId);
    notifyListeners();
  }

  Future<void> react(int serverId, String emoji) async {
    await _api.safeCall(() => _api.dio.post('/chat/messages/$serverId/react', data: {'emoji': emoji}));
    await _syncFromServer(_currentUserId);
  }

  Future<void> edit(int serverId, String newBody) async {
    final result = await _api.safeCall(() => _api.dio.put('/chat/messages/$serverId', data: {'body': newBody}));
    if (result.success) {
      final db = await LocalDatabase.instance;
      await db.update('local_messages', {'body': newBody, 'is_edited': 1},
          where: 'server_id = ?', whereArgs: [serverId]);
      await _loadFromLocalDb(_currentUserId);
      notifyListeners();
    }
  }

  Future<void> delete(int serverId) async {
    final result = await _api.safeCall(() => _api.dio.delete('/chat/messages/$serverId'));
    if (result.success) {
      final db = await LocalDatabase.instance;
      await db.update('local_messages', {'is_deleted': 1, 'body': null},
          where: 'server_id = ?', whereArgs: [serverId]);
      await _loadFromLocalDb(_currentUserId);
      notifyListeners();
    }
  }

  Future<void> togglePin(int serverId) async {
    await _api.safeCall(() => _api.dio.post('/chat/messages/$serverId/pin'));
    await _syncFromServer(_currentUserId);
  }

  Future<ApiResult<Map<String, dynamic>>> forward(int serverId, {int? toReceiverId, int? toGroupId}) {
    return _api.safeCall(() => _api.dio.post('/chat/messages/$serverId/forward', data: {
          'receiver_id': toReceiverId,
          'group_id': toGroupId,
          'client_message_id': _uuid.v4(),
        }));
  }
}
