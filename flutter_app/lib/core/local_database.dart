import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sets up the on-device database so the app keeps working with no
/// internet - the same file lives on phones and desktop computers, just
/// accessed through a different low-level driver depending on platform.
class LocalDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    // Desktop platforms (Windows/Linux/macOS) need the FFI driver instead
    // of the mobile-only native sqflite plugin.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'edulink_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_messages (
            client_message_id TEXT PRIMARY KEY,
            server_id INTEGER,
            sender_id INTEGER,
            receiver_id INTEGER,
            group_id INTEGER,
            reply_to_id INTEGER,
            message_type TEXT,
            body TEXT,
            reactions TEXT,
            is_edited INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            sync_status TEXT DEFAULT 'synced',
            created_at TEXT
          )
        ''');

        // Every message sent while offline (or that failed to send) sits
        // here until connectivity returns and it's retried automatically.
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT,
            payload TEXT,
            created_at TEXT,
            retry_count INTEGER DEFAULT 0
          )
        ''');

        // Generic cached-entity store for read-mostly data (classes,
        // lessons, assignments...) so the app has SOMETHING to show
        // immediately on launch, before/without a network round trip.
        await db.execute('''
          CREATE TABLE cache (
            cache_key TEXT PRIMARY KEY,
            json_value TEXT,
            updated_at TEXT
          )
        ''');
      },
    );
  }

  /// Generic helpers used by the caching layer (see cache_service.dart)
  static Future<void> putCache(String key, String jsonValue) async {
    final db = await instance;
    await db.insert(
      'cache',
      {'cache_key': key, 'json_value': jsonValue, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getCache(String key) async {
    final db = await instance;
    final rows = await db.query('cache', where: 'cache_key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['json_value'] as String;
  }
}
