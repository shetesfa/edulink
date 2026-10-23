import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';
import 'secure_storage.dart';

/// Minimal Pusher-protocol client for Laravel Reverb.  This talks directly to
/// the configured Reverb host, so it works with self-hosted Reverb rather than
/// only with Pusher's hosted clusters.
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final Dio _authDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final Map<String, void Function(Map<String, dynamic>)> _messageHandlers = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _connectionCompleter;
  String? _socketId;
  bool _connected = false;

  Future<void> connect() async {
    if (_connected) return;
    if (ApiConfig.reverbKey.isEmpty) {
      throw StateError('Realtime chat is not configured. Set REVERB_APP_KEY in .env.');
    }

    await disconnect();
    _connectionCompleter = Completer<void>();
    final scheme = ApiConfig.reverbUseTLS ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$scheme://${ApiConfig.reverbHost}:${ApiConfig.reverbPort}/app/${ApiConfig.reverbKey}'
      '?protocol=7&client=edulink_flutter&version=1.0&flash=false',
    );

    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        _connected = false;
        if (!(_connectionCompleter?.isCompleted ?? true)) {
          _connectionCompleter!.completeError(error, stackTrace);
        }
      },
      onDone: () {
        _connected = false;
        if (!(_connectionCompleter?.isCompleted ?? true)) {
          _connectionCompleter!.completeError(const SocketException('Realtime connection closed before it was established.'));
        }
      },
    );

    await _connectionCompleter!.future.timeout(const Duration(seconds: 12));
  }

  Future<void> subscribeToPrivateChat(int userId, void Function(Map<String, dynamic>) onMessage) {
    return _subscribe('private-chat.$userId', onMessage);
  }

  Future<void> subscribeToGroup(int groupId, void Function(Map<String, dynamic>) onMessage) {
    return _subscribe('private-group.$groupId', onMessage);
  }

  Future<void> _subscribe(String channelName, void Function(Map<String, dynamic>) onMessage) async {
    if (!_connected || _socketId == null) {
      throw StateError('Realtime connection is not ready.');
    }

    final token = await SecureStorageService.getToken();
    if (token == null) throw StateError('Sign in before connecting to realtime chat.');
    final response = await _authDio.post(
      '/broadcasting/auth',
      data: {'channel_name': channelName, 'socket_id': _socketId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final auth = Map<String, dynamic>.from(response.data as Map);
    _messageHandlers[channelName] = onMessage;
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName, 'auth': auth['auth']},
    });
  }

  Future<void> disconnect() async {
    _messageHandlers.clear();
    _socketId = null;
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _handleEvent(dynamic rawEvent) {
    final event = Map<String, dynamic>.from(jsonDecode(rawEvent as String) as Map);
    final eventName = event['event'] as String?;
    final data = _decodeData(event['data']);

    if (eventName == 'pusher:connection_established') {
      _socketId = data['socket_id'] as String?;
      if (_socketId == null) {
        _connectionCompleter?.completeError(const FormatException('Realtime server did not provide a socket ID.'));
        return;
      }
      _connected = true;
      _connectionCompleter?.complete();
      return;
    }
    if (eventName == 'pusher:ping') {
      _send({'event': 'pusher:pong', 'data': {}});
      return;
    }
    if (eventName == 'message.sent') {
      final channelName = event['channel'] as String?;
      final handler = channelName == null ? null : _messageHandlers[channelName];
      if (handler != null) handler(data);
    }
  }

  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is String) return Map<String, dynamic>.from(jsonDecode(data) as Map);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}

class SocketException implements Exception {
  final String message;
  const SocketException(this.message);
  @override
  String toString() => message;
}
