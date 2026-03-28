import 'dart:math';

import 'package:flutter/material.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/mchango_campaign.dart';
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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS campaigns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        threadId TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER,
        targetAmount REAL,
        isActive INTEGER DEFAULT 1,
        openingBalance REAL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        campaignId INTEGER NOT NULL,
        senderName TEXT,
        senderPhone TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        messageId INTEGER,
        FOREIGN KEY (campaignId) REFERENCES campaigns(id)
      )
    ''');
  }

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
        status INTEGER DEFAULT 0,
        read INTEGER NOT NULL DEFAULT 0,
        simId INTEGER NOT NULL,
        UNIQUE(address, body, date) ON CONFLICT IGNORE
      )
    ''');
        // Create indexes to optimize query performance as the DB grows
    await db
        .execute('CREATE INDEX idx_messages_threadId ON messages (threadId)');

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
    await db.execute('''
    CREATE TABLE campaigns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      threadId TEXT NOT NULL,
      startDate INTEGER NOT NULL,
      endDate INTEGER,
      targetAmount REAL,
      isActive INTEGER DEFAULT 1,
      openingBalance REAL DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE contributions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      campaignId INTEGER NOT NULL,
      senderName TEXT,
      senderPhone TEXT NOT NULL,
      amount REAL NOT NULL,
      date INTEGER NOT NULL,
      messageId INTEGER,
      FOREIGN KEY (campaignId) REFERENCES campaigns(id)
    )
  ''');
    
  }

  // --- Optimized Batch Operations ---

  /// Handles bulk insertion of messages using a single transaction.
  /// This is crucial for the initial sync to prevent UI lag.
Future<void> batchSyncMessages(List<tel.SmsMessage> messages) async {
  final db = await database;

  // 3. Ensure unique constraint exists on your messages table:
  // CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_unique
  // ON messages(address, date, body) — or use `id` from SMS provider if available
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_unique
    ON messages(address, date, body)
  ''');

  await db.transaction((txn) async {
    final Batch batch = txn.batch();

    // Track per-thread unread counts instead of hardcoding 0
    final Map<String, int> threadUnreadCount = {};
    final Map<String, Map<String, dynamic>> threadLatest = {};

    for (var msg in messages) {
      if (msg.address == null || msg.body == null || msg.date == null) continue;

      final threadId = msg.threadId.toString();

      // 4. Derive correct type: sent = 2, inbox = 1
      final int msgType = (msg.type == tel.SmsType.MESSAGE_TYPE_SENT) ? 2 : 1;

      // 5. Accumulate real unread count
      if (msgType == 1 && (msg.read == null || !msg.read!)) {
        threadUnreadCount[threadId] = (threadUnreadCount[threadId] ?? 0) + 1;
      }

      batch.insert(
        'messages',
        {
          'address': msg.address,
          'body': msg.body,
          'date': msg.date,
          'type': msgType, // fixed: not hardcoded
          'read': (msg.read == true) ? 1 : 0,
          'threadId': threadId,
          'simId': msg.subscriptionId ?? -1,
          'status': msg.status == tel.SmsStatus.STATUS_COMPLETE
              ? MessageStatus.sent.value
              : MessageStatus.unknown.value,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Track latest message per thread for chat summary
      final existing = threadLatest[threadId];
      if (existing == null || (msg.date! > existing['lastMessageDate'])) {
        threadLatest[threadId] = {
          'threadId': threadId,
          'address': msg.address,
          'normalizedAddress': AppChat.normalizeAddress(msg.address!),
          'lastMessage': msg.body,
          'lastMessageDate': msg.date,
        };
      }
    }

    // 6. Insert chat summaries once per thread with correct unread count
    for (final entry in threadLatest.entries) {
      final threadId = entry.key;
      batch.insert(
        'chats',
        {
          ...entry.value,
          'unreadCount': threadUnreadCount[threadId] ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  });
}
Future<int> getLatestMessageDate() async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT MAX(date) as maxDate FROM messages'
  );
  return (result.firstOrNull?['maxDate'] as int?) ?? 0;
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
  int? targetTimestamp,
}) async {
  final db = await database;

  if (targetTimestamp != null) {
    const window = anchorWindow;

    final before = await db.query(
      'messages',
      where: 'threadId = ? AND date <= ?',
      whereArgs: [threadId, targetTimestamp],
      orderBy: 'date DESC',
      limit: window,
    );

    final after = await db.query(
      'messages',
      where: 'threadId = ? AND date > ?',
      whereArgs: [threadId, targetTimestamp],
      orderBy: 'date ASC', // newest in 'after' window last
      limit: window,
    );

    // after reversed = DESC, before already DESC
    // Combined: newest first, consistent with non-search queries
    final merged = [
      ...after.reversed.map(AppSmsMessage.fromMap), // DESC (newest after target first)
      ...before.map(AppSmsMessage.fromMap),          // DESC (target + older)
    ];

    return merged; 
  }

  // Normal paginated fetch
  final maps = await db.query(
    'messages',
    where: 'threadId = ?',
    whereArgs: [threadId],
    orderBy: 'date DESC',
    limit: limit,
    offset: offset,
  );
  return maps.map(AppSmsMessage.fromMap).toList();
}
  Future<List<AppSmsMessage>> getMessagesBeforeTimestamp(
    String threadId, {
    required int beforeDate,
    int limit = 20,
  }) async {
    print("Getting messages before timestamp: ${formatMessageDate(beforeDate)}");
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'threadId = ? AND date < ?',
      whereArgs: [threadId, beforeDate],
      orderBy: 'date ASC',
      limit: limit,
    );
    return maps.map(AppSmsMessage.fromMap).toList();
  }
  Future<List<AppSmsMessage>> getMessagesAfterTimestamp(
    String threadId, {
    required int afterDate,
    int limit = 20,
  }) async {
    
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'threadId = ? AND date > ?',
      whereArgs: [threadId, afterDate],
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map(AppSmsMessage.fromMap).toList();
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
  required bool isDefaultApp,
}) async {
  final db = await database;

  final List<String> financialSenders = [
    'MPESA', 
    'M-PESA', 
    'AirtelMoney', 
    'AIRTELMONEY',
    'Safaricom' // Optional: Safaricom often sends account/data alerts
  ];
  String whereClause = 'isArchived = ?';
  List<Object?> whereArgs = [0];

  if (!isDefaultApp) {
    final placeholders = List.generate(financialSenders.length, (index) => '?').join(', ');
    whereClause += ' AND UPPER(address) IN ($placeholders)';
    whereArgs.addAll(financialSenders);
  }

  final chatMaps = await db.query(
    'chats',
    where: whereClause,
    whereArgs: whereArgs,
    orderBy: 'isPinned DESC, lastMessageDate DESC',
    limit: limit,
    offset: offset,
  );

  List<AppChat> chats = [];

  for (var map in chatMaps) {
    List<String> recentMsgs = [];
    
    // 2. Fetch last 5 messages ONLY if not default app (Limited Mode)
    if (!isDefaultApp) {
      final msgMaps = await db.query(
        'messages',
        where: 'threadId = ?',
        whereArgs: [map['threadId']],
        orderBy: 'date DESC',
        limit: 1,
      );
      recentMsgs = msgMaps.map((m) => m['body'] as String).toList();
    }

    chats.add(AppChat.fromMap(map, recent: recentMsgs));
  }

  return chats;
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
Future<List<AppSmsMessage>> searchGlobal(String query, bool isDefault) async {
  final db = await database;
  final lowercaseQuery = '%${query.toLowerCase()}%';

  final String addressFilter = isDefault 
      ? "" // No filter for default app
      : "AND (address NOT GLOB '*[0-9]*')"; 

  final messageResults = await db.rawQuery('''
    SELECT * FROM messages 
    WHERE body LIKE ? 
    $addressFilter
    ORDER BY date DESC LIMIT 50
  ''', [lowercaseQuery]);
  
  return messageResults.map((json) => AppSmsMessage.fromMap(json)).toList();
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
  // ── Campaigns ──────────────────────────────────────────────

  Future<int> insertCampaign(Campaign campaign) async {
    final db = await database;
    return await db.insert('campaigns', campaign.toMap());
  }

  Future<Campaign?> getActiveCampaign(String threadId) async {
    final db = await database;
    final result = await db.query(
      'campaigns',
      where: 'threadId = ? AND isActive = 1',
      whereArgs: [threadId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    final campaign = Campaign.fromMap(result.first);
    return await _hydrateCampaign(db, campaign);
  }

  Future<List<Campaign>> getCampaigns(String threadId) async {
    final db = await database;
    final result = await db.query(
      'campaigns',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'startDate DESC',
    );
    return Future.wait(result
        .map(Campaign.fromMap)
        .map((c) => _hydrateCampaign(db, c)));
  }

  Future<Campaign> _hydrateCampaign(Database db, Campaign campaign) async {
    final stats = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM contributions WHERE campaignId = ?
    ''', [campaign.id]);
    campaign.totalCollected = (stats.first['total'] as num?)?.toDouble() ?? 0;
    campaign.contributorCount = (stats.first['count'] as int?) ?? 0;
    return campaign;
  }

  Future<void> stopCampaign(int campaignId) async {
    final db = await database;
    await db.update(
      'campaigns',
      {'isActive': 0, 'endDate': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [campaignId],
    );
  }

  // ── Contributions ──────────────────────────────────────────

  Future<int> insertContribution(Contribution contribution) async {
    final db = await database;
    return await db.insert('contributions', contribution.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Contribution>> getContributions(int campaignId) async {
    final db = await database;
    final result = await db.query(
      'contributions',
      where: 'campaignId = ?',
      whereArgs: [campaignId],
      orderBy: 'date DESC',
    );
    return result.map(Contribution.fromMap).toList();
  }

  Future<bool> contributionExists(int campaignId, int messageId) async {
    final db = await database;
    final result = await db.query(
      'contributions',
      columns: ['id'],
      where: 'campaignId = ? AND messageId = ?',
      whereArgs: [campaignId, messageId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
  //TESTING CODE
  Future<void> seedTestData() async {
  final db = await database;

  // Realistic name/number pairs
  final List<Map<String, dynamic>> contacts = [
    {'name': 'Alice Johnson', 'number': '+12025550101'},
    {'name': 'Bob Smith', 'number': '+12025550102'},
    {'name': 'Carol White', 'number': '+12025550103'},
    {'name': 'David Brown', 'number': '+12025550104'},
    {'name': 'Eve Davis', 'number': '+12025550105'},
    {'name': 'Frank Miller', 'number': '+12025550106'},
    {'name': 'Grace Wilson', 'number': '+12025550107'},
    {'name': 'Henry Moore', 'number': '+12025550108'},
    {'name': 'Isla Taylor', 'number': '+12025550109'},
    {'name': 'Jack Anderson', 'number': '+12025550110'},
    {'name': 'Karen Thomas', 'number': '+12025550111'},
    {'name': 'Liam Jackson', 'number': '+12025550112'},
    {'name': 'Mia Harris', 'number': '+12025550113'},
    {'name': 'Noah Martin', 'number': '+12025550114'},
    {'name': 'Olivia Lee', 'number': '+12025550115'},
    {'name': 'Paul Garcia', 'number': '+12025550116'},
    {'name': 'Quinn Martinez', 'number': '+12025550117'},
    {'name': 'Rachel Robinson', 'number': '+12025550118'},
    {'name': 'Sam Clark', 'number': '+12025550119'},
    {'name': 'Tina Rodriguez', 'number': '+12025550120'},
    {'name': 'Uma Lewis', 'number': '+12025550121'},
    {'name': 'Victor Walker', 'number': '+12025550122'},
    {'name': 'Wendy Hall', 'number': '+12025550123'},
    {'name': 'Xander Allen', 'number': '+12025550124'},
    {'name': 'Yara Young', 'number': '+12025550125'},
    {'name': 'Zane King', 'number': '+12025550126'},
    {'name': 'Amy Scott', 'number': '+12025550127'},
    {'name': 'Brian Green', 'number': '+12025550128'},
    {'name': 'Chloe Baker', 'number': '+12025550129'},
    {'name': 'Derek Adams', 'number': '+12025550130'},
    {'name': 'Ella Nelson', 'number': '+12025550131'},
    {'name': 'Felix Carter', 'number': '+12025550132'},
    {'name': 'Gina Mitchell', 'number': '+12025550133'},
    {'name': 'Hank Perez', 'number': '+12025550134'},
    {'name': 'Iris Roberts', 'number': '+12025550135'},
    {'name': 'Jake Turner', 'number': '+12025550136'},
    {'name': 'Kylie Phillips', 'number': '+12025550137'},
    {'name': 'Leo Campbell', 'number': '+12025550138'},
    {'name': 'Maya Parker', 'number': '+12025550139'},
    {'name': 'Nate Evans', 'number': '+12025550140'},
    {'name': 'Opal Edwards', 'number': '+12025550141'},
    {'name': 'Pete Collins', 'number': '+12025550142'},
    {'name': 'Rosa Stewart', 'number': '+12025550143'},
    {'name': 'Sean Sanchez', 'number': '+12025550144'},
    {'name': 'Tara Morris', 'number': '+12025550145'},
    {'name': 'Ugo Rogers', 'number': '+12025550146'},
    {'name': 'Vera Reed', 'number': '+12025550147'},
    {'name': 'Will Cook', 'number': '+12025550148'},
    {'name': 'Xena Morgan', 'number': '+12025550149'},
    {'name': 'Yale Bell', 'number': '+12025550150'},
    // Short codes / businesses for variety
    {'name': 'Amazon', 'number': '262966'},
    {'name': 'FedEx', 'number': '33339'},
    {'name': 'Chase Bank', 'number': '24273'},
    {'name': 'Netflix', 'number': '63759'},
    {'name': 'Uber', 'number': '82785'},
    {'name': 'Twitter', 'number': '40404'},
    {'name': 'Google', 'number': '22000'},
    {'name': 'PayPal', 'number': '729725'},
    {'name': 'Apple', 'number': '27753'},
    {'name': 'Spotify', 'number': '78674'},
    {'name': 'Mom', 'number': '+12025550201'},
    {'name': 'Dad', 'number': '+12025550202'},
    {'name': 'Sister', 'number': '+12025550203'},
    {'name': 'Brother', 'number': '+12025550204'},
    {'name': 'Boss', 'number': '+12025550205'},
    {'name': 'Doctor', 'number': '+12025550206'},
    {'name': 'Dentist', 'number': '+12025550207'},
    {'name': 'Landlord', 'number': '+12025550208'},
    {'name': 'Gym', 'number': '+12025550209'},
    {'name': 'Pizza Place', 'number': '+12025550210'},
    {'name': 'Alex Kim', 'number': '+12025550211'},
    {'name': 'Bella Cruz', 'number': '+12025550212'},
    {'name': 'Carlos Diaz', 'number': '+12025550213'},
    {'name': 'Diana Fox', 'number': '+12025550214'},
    {'name': 'Ethan Gray', 'number': '+12025550215'},
    {'name': 'Fiona Hunt', 'number': '+12025550216'},
    {'name': 'George Iyer', 'number': '+12025550217'},
    {'name': 'Hannah James', 'number': '+12025550218'},
    {'name': 'Ivan Kline', 'number': '+12025550219'},
    {'name': 'Julia Lane', 'number': '+12025550220'},
    {'name': 'Kurt Mason', 'number': '+12025550221'},
    {'name': 'Luna Nash', 'number': '+12025550222'},
    {'name': 'Marco Owen', 'number': '+12025550223'},
    {'name': 'Nina Price', 'number': '+12025550224'},
    {'name': 'Oscar Quinn', 'number': '+12025550225'},
    {'name': 'Petra Ray', 'number': '+12025550226'},
    {'name': 'Quincy Stone', 'number': '+12025550227'},
    {'name': 'Rita Upton', 'number': '+12025550228'},
    {'name': 'Steve Vance', 'number': '+12025550229'},
    {'name': 'Tess Wade', 'number': '+12025550230'},
    {'name': 'Ursula Xavier', 'number': '+12025550231'},
    {'name': 'Vincent York', 'number': '+12025550232'},
    {'name': 'Wanda Zhang', 'number': '+12025550233'},
    {'name': 'Xander Abbot', 'number': '+12025550234'},
    {'name': 'Yasmine Berg', 'number': '+12025550235'},
    {'name': 'Zack Cole', 'number': '+12025550236'},
    {'name': 'Amber Dean', 'number': '+12025550237'},
    {'name': 'Blake Ellis', 'number': '+12025550238'},
    {'name': 'Cassie Ford', 'number': '+12025550239'},
    {'name': 'Dylan Grant', 'number': '+12025550240'},
  ];

  // Realistic message pool
  final List<String> inboundMessages = [
    "Hey, are you free later?",
    "Can you call me when you get a chance?",
    "Just checking in 😊",
    "Did you get my last message?",
    "Running 10 minutes late, sorry!",
    "Your package has been delivered.",
    "Don't forget about tomorrow!",
    "Thanks for the help earlier.",
    "What time works for you?",
    "I'll be there in 5.",
    "Happy birthday! 🎂🎉",
    "Your appointment is confirmed for Monday at 2pm.",
    "Can you pick up milk on the way home?",
    "Meeting pushed to 3pm.",
    "Are you coming to the event?",
    "Your OTP is 482910. Do not share this.",
    "Payment of \$45.00 received. Thank you!",
    "Your order has shipped! Track: 1Z999AA10123456784",
    "Low balance alert: Your account has \$12.50 remaining.",
    "Reminder: Your bill is due in 3 days.",
    "You've been mentioned in a post.",
    "New login detected on your account.",
    "Your ride is 2 minutes away 🚗",
    "Flight UA123 is on time. Gate B12.",
    "Dinner tonight? 🍕",
    "Call me ASAP.",
    "lol yeah that was wild",
    "omw",
    "👍",
    "K",
    "On my way!",
    "Can we reschedule?",
    "Miss you ❤️",
    "Where are you?",
    "This is hilarious 😂",
    "No worries at all!",
    "See you soon.",
    "Got it, thanks!",
    "That sounds good to me.",
    "Let me know when you land.",
  ];

  final List<String> outboundMessages = [
    "Sure, what time?",
    "On my way now.",
    "Sounds good!",
    "Yeah, I'll be there.",
    "Can we do 6pm instead?",
    "Just saw this, sorry for the late reply.",
    "Thanks! 🙏",
    "I'll call you in a bit.",
    "No problem at all.",
    "Done, just sent it over.",
    "What's the address?",
    "I'm outside.",
    "Give me 10 minutes.",
    "Perfect, see you then.",
    "Got it!",
    "Haha yeah 😂",
    "Miss you too ❤️",
    "Let me check and get back to you.",
    "Did you get my email?",
    "Yes, confirmed!",
    "I'll be there at 7.",
    "Can you send me the details?",
    "Just finished, heading over now.",
    "That works for me.",
    "👍",
    "Ok!",
    "On it.",
    "Just paid it.",
    "Leaving now.",
    "Already done!",
  ];

  final random = Random();
  final now = DateTime.now().millisecondsSinceEpoch;
  final batch = db.batch();

  for (int i = 0; i < 100; i++) {
    final contact = contacts[i % contacts.length];
    final address = contact['number'] as String;
    final threadId = (i + 1).toString();

    // Random number of messages between 2 and 15
    final messageCount = 2 + random.nextInt(14);

    // Conversation starts anywhere in the last 60 days
    final conversationStart =
        now - Duration(days: random.nextInt(60)).inMilliseconds;
    // Space messages a few minutes apart
    final spacing = Duration(minutes: 3 + random.nextInt(30)).inMilliseconds;

    String lastBody = '';
    int lastDate = 0;

    for (int j = 0; j < messageCount; j++) {
      final isOutgoing = random.nextBool();
      final msgDate = conversationStart + (j * spacing);
      final body = isOutgoing
          ? outboundMessages[random.nextInt(outboundMessages.length)]
          : inboundMessages[random.nextInt(inboundMessages.length)];

      lastBody = body;
      lastDate = msgDate;

      final message = {
        'address': address,
        'body': body,
        'date': msgDate,
        'type': isOutgoing ? 2 : 1,
        'read': (isOutgoing || random.nextBool()) ? 1 : 0,
        'threadId': threadId,
        'simId': random.nextInt(2), // sim 0 or 1
        'status': isOutgoing ? MessageStatus.sent.value : MessageStatus.unknown.value,
      };

      batch.insert('messages', message, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Insert chat summary using last message
    batch.insert(
      'chats',
      {
        'threadId': threadId,
        'address': address,
        'normalizedAddress': AppChat.normalizeAddress(address),
        'lastMessage': lastBody,
        'lastMessageDate': lastDate,
        'unreadCount': random.nextInt(5),
        'isArchived':  0, 
        'isPinned':  0,  
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);
  debugPrint('✅ Seeded 100 test conversations');
}
}
