import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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

    await db.execute('''
      CREATE TABLE conversations (
        threadId TEXT PRIMARY KEY,
        address TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageDate INTEGER,
        unreadCount INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertMessage(AppSmsMessage message) async {
    final db = await database;
    return await db.insert('messages', message.toMap(),conflictAlgorithm: ConflictAlgorithm.ignore);
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

  Future<List<AppConversation>> getAllConversations() async {
    final db = await database;
    final result = await db.query(
      'conversations',
      orderBy: 'lastMessageDate DESC',
    );

    return result.map((json) => AppConversation.fromMap(json)).toList();
  }

  Future<void> updateConversation(AppConversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markMessageAsRead(int messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'read': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markThreadAsRead(String threadId) async {
    final db = await database;
    await db.update(
      'messages',
      {'read': 1},
      where: 'threadId = ?',
      whereArgs: [threadId],
    );
    
    await db.update(
      'conversations',
      {'unreadCount': 0},
      where: 'threadId = ?',
      whereArgs: [threadId],
    );
  }

  Future<void> deleteMessage(int id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteThread(String threadId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
    );
    await db.delete(
      'conversations',
      where: 'threadId = ?',
      whereArgs: [threadId],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
