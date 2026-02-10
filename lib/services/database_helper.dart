import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:another_telephony/telephony.dart' as tel;
import '../models/sms_message.dart';

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
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Messages table with an index on threadId for faster chat loading
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        body TEXT NOT NULL,
        date INTEGER NOT NULL,
        type INTEGER NOT NULL,
        threadId TEXT,
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Chats table
    await db.execute('''
      CREATE TABLE chats (
        threadId TEXT PRIMARY KEY,
        address TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageDate INTEGER,
        unreadCount INTEGER DEFAULT 0
      )
    ''');

    // Create indexes to optimize query performance as the DB grows
    await db.execute('CREATE INDEX idx_messages_threadId ON messages (threadId)');
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
        batch.insert('messages', {
          'address': msg.address,
          'body': msg.body,
          'date': msg.date,
          'type': 1, // Inbox
          'threadId': threadId,
          'read': 1, // Historical are usually read
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Update/Insert chat summary
        batch.insert('chats', {
          'threadId': threadId,
          'address': msg.address,
          'lastMessage': msg.body,
          'lastMessageDate': msg.date,
          'unreadCount': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    });
  }

  // --- Standard Operations ---

  Future<int> insertMessage(AppSmsMessage message) async {
    final db = await database;
    return await db.insert(
      'messages', 
      message.toMap(), 
      conflictAlgorithm: ConflictAlgorithm.ignore
    );
  }

  /// Advanced Upsert: Inserts a new chat or updates an existing one.
  /// If [incrementUnread] is true, it adds to the existing count in the DB.
  Future<void> upsertChat(AppChat chat, {bool incrementUnread = false}) async {
    final db = await database;
    
    if (incrementUnread) {
      await db.rawInsert('''
        INSERT INTO chats (threadId, address, lastMessage, lastMessageDate, unreadCount)
        VALUES (?, ?, ?, ?, 1)
        ON CONFLICT(threadId) DO UPDATE SET
          lastMessage = excluded.lastMessage,
          lastMessageDate = excluded.lastMessageDate,
          unreadCount = unreadCount + 1
      ''', [chat.threadId, chat.address, chat.lastMessage, chat.lastMessageDate]);
    } else {
      await db.insert(
        'chats',
        chat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<AppSmsMessage>> getMessagesForThread(String threadId) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'date DESC',
    );
    return result.map((json) => AppSmsMessage.fromMap(json)).toList();
  }

  Future<List<AppChat>> getAllChats() async {
    final db = await database;
    final result = await db.query(
      'chats',
      orderBy: 'lastMessageDate DESC',
    );
    return result.map((json) => AppChat.fromMap(json)).toList();
  }

  // --- State Modification ---

  Future<void> markThreadAsRead(String threadId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('messages', {'read': 1}, where: 'threadId = ?', whereArgs: [threadId]);
      await txn.update('chats', {'unreadCount': 0}, where: 'threadId = ?', whereArgs: [threadId]);
    });
  }

  Future<void> deleteThread(String threadId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'threadId = ?', whereArgs: [threadId]);
      await txn.delete('chats', where: 'threadId = ?', whereArgs: [threadId]);
    });
  }

  Future<void> deleteMessage(int id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}