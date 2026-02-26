import 'package:messaging/models/app_chat.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:another_telephony/telephony.dart' as tel;
import '../models/app_message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sms_messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        body TEXT NOT NULL,
        date INTEGER NOT NULL,
        type INTEGER NOT NULL,
        threadId TEXT,
        status INTEGER DEFAULT 0,
        read INTEGER NOT NULL DEFAULT 0,
        simId INTEGER NOT NULL,
        UNIQUE(address, body, date) ON CONFLICT IGNORE
      )
    ''');

    // 2. Chats table
    await db.execute('''
      CREATE TABLE chats (
        threadId TEXT PRIMARY KEY,
        address TEXT NOT NULL,
        normalizedAddress TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageDate INTEGER,
        isArchived INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        unreadCount INTEGER DEFAULT 0
      )
    ''');

    // Create indexes to optimize query performance as the DB grows
    await db
        .execute('CREATE INDEX idx_messages_threadId ON messages (threadId)');
  }

  // --- Optimized Batch Operations ---

  /// Handles bulk insertion of messages using a single transaction.
  /// This is crucial for the initial sync to prevent UI lag.
  Future<void> batchSyncMessages(List<tel.SmsMessage> messages) async {
    final db = await database;
    await db.transaction((txn) async {
      final Batch batch = txn.batch();

      for (var msg in messages) {
        final threadId = msg.threadId.toString();

        // Insert message (Ignore duplicates based on ID or timestamp if you add unique constraints)
        if (msg.address != null && msg.body != null && msg.date != null) {
          batch.insert(
              'messages',
              {
                'address': msg.address,
                'body': msg.body,
                'date': msg.date,
                'type': 1,
                'read': msg.read != null && msg.read! ? 1 : 0,
                'threadId': threadId,
                'simId': msg.subscriptionId ?? -1,
                'status': msg.status == tel.SmsStatus.STATUS_COMPLETE
                    ? MessageStatus.sent.value
                    : MessageStatus.unknown.value,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);

          // Update/Insert chat summary
          batch.insert(
              'chats',
              {
                'threadId': threadId,
                'address': msg.address,
                'normalizedAddress': AppChat.normalizeAddress(msg.address!),
                'lastMessage': msg.body,
                'lastMessageDate': msg.date,
                'unreadCount': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await batch.commit(noResult: true);
    });
  }

  // --- Standard Operations ---

  Future<int> insertMessage(AppSmsMessage message) async {
    final db = await database;
    return await db.insert('messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Advanced Upsert: Inserts a new chat or updates an existing one.
  /// If [incrementUnread] is true, it adds to the existing count in the DB.
  Future<void> upsertChat(AppChat chat, {bool incrementUnread = false}) async {
    final db = await database;

    if (incrementUnread) {
      await db.rawInsert('''
        INSERT INTO chats (threadId, address, normalizedAddress, lastMessage, lastMessageDate, unreadCount)
        VALUES (?, ?, ?, ?, ?, 1)
        ON CONFLICT(threadId) DO UPDATE SET
          lastMessage = excluded.lastMessage,
          lastMessageDate = excluded.lastMessageDate,
          unreadCount = unreadCount + 1
      ''', [
        chat.threadId,
        chat.address,
        chat.normalizedAddress,
        chat.lastMessage,
        chat.lastMessageDate
      ]);
    } else {
      await db.insert(
        'chats',
        chat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<AppSmsMessage>> getMessagesForThread(
    String threadId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => AppSmsMessage.fromMap(json)).toList();
  }

  Future<AppChat?> getChatByNormalizedAddress(String normalizedAddress) async {
    final db = await database;
    final result = await db.query(
      'chats',
      where: 'normalizedAddress = ?',
      whereArgs: [normalizedAddress],
    );
    if (result.isNotEmpty) {
      return AppChat.fromMap(result.first);
    }
    return null;
  }

  Future<List<AppChat>> getPaginatedChats({
    required int limit,
    required int offset,
  }) async {
    final db = await database;

    final result = await db.query(
      'chats',
      where: 'isArchived = ?',
      whereArgs: [0],
      // Primary sort: Pinned first. Secondary sort: Newest date first.
      orderBy: 'isPinned DESC, lastMessageDate DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((json) => AppChat.fromMap(json)).toList();
  }

  Future<List<AppChat>> getAllChats() async {
    final db = await database;

    final result = await db.query(
      'chats',
      where: 'isArchived = ?',
      whereArgs: [0],
      orderBy: 'isPinned DESC, lastMessageDate DESC',
    );

    return result.map((json) => AppChat.fromMap(json)).toList();
  }
  Future<List<AppChat>> getArchivedChats() async {
  final db = await database;
  final result = await db.query(
    'chats',
    where: 'isArchived = ?',
    whereArgs: [1], // 1 for archived
    orderBy: 'lastMessageDate DESC',
  );
  return result.map((json) => AppChat.fromMap(json)).toList();
}

Future<int> getArchivedCount() async {
  final db = await database;
  final count = Sqflite.firstIntValue(await db.rawQuery(
    'SELECT COUNT(*) FROM chats WHERE isArchived = 1'
  ));
  return count ?? 0;
}
Future<List<AppSmsMessage>> searchMessagesInThread(String threadId, String query) async {
  final db = await database;
  final String lowercaseQuery = query.toLowerCase();
  final result = await db.query(
    'messages',
    where: 'threadId = ? AND body LIKE ? COLLATE NOCASE',
    whereArgs: [threadId, '%$lowercaseQuery%'], 
    orderBy: 'date DESC',
  );
  return result.map((json) => AppSmsMessage.fromMap(json)).toList();
}

  // --- State Modification ---
  Future<void> markMessageAsSent(int messageId) async {
    final db = await database;
    await db.update('messages', {'status': MessageStatus.sent.value},
        where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> markMessageAsDelivered(int messageId) async {
    final db = await database;
    await db.update('messages', {'status': MessageStatus.delivered.value},
        where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> markMessageAsFailed(int messageId) async {
    final db = await database;
    await db.update('messages', {'status': MessageStatus.failed.value},
        where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> markThreadAsRead(String threadId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('messages', {'read': 1},
          where: 'threadId = ?', whereArgs: [threadId]);
      await txn.update('chats', {'unreadCount': 0},
          where: 'threadId = ?', whereArgs: [threadId]);
    });
  }

  Future<void> markThreadAsArchived(String threadId, bool isArchived) async {
    final db = await database;
    await db.update('chats', {'isArchived': isArchived ? 1 : 0},
        where: 'threadId = ?', whereArgs: [threadId]);
  }

  Future<void> markThreadAsPinned(String threadId, bool isPinned) async {
    final db = await database;
    await db.update('chats', {'isPinned': isPinned ? 1 : 0},
        where: 'threadId = ?', whereArgs: [threadId]);
  }

  Future<void> deleteThread(String threadId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .delete('messages', where: 'threadId = ?', whereArgs: [threadId]);
      await txn.delete('chats', where: 'threadId = ?', whereArgs: [threadId]);
    });
  }

  Future<void> deleteMessage(int id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMessages(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');

    await db.delete(
      'messages',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
