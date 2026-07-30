import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ContactDb {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'contacts.db'),
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE contacts(phone_key TEXT PRIMARY KEY, name TEXT)",
        );
      },
    );
    return _db!;
  }
  Future<Map<String, String>> getAllContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('contacts');
    
    return {
      for (var row in maps) row['phone_key'] as String: row['name'] as String
    };
  }

  // Fast lookup for the background notification
  Future<String?> getName(String phoneNumber) async {
    final db = await database;
    final key = _normalize(phoneNumber);
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      where: 'phone_key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) return maps.first['name'] as String;
    return null;
  }

  String _normalize(String phone) {
    // Extract last 9 digits to match +254..., 07..., etc.
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    return clean.length >= 9 ? clean.substring(clean.length - 9) : clean;
  }
}
@pragma('vm:entry-point')
Future<void> syncContactsIsolate(List<dynamic> args) async {
  SendPort sp = args[0];
  RootIsolateToken token = args[1];
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final contacts = await FlutterContacts.getAll();
  
  // 2. Open DB inside this isolate
  final db = ContactDb();
  final database = await db.database;
  
  Batch batch = database.batch();
  for (var contact in contacts) {
    for (var phone in contact.phones) {
      String key = db._normalize(phone.number);
      batch.insert(
        'contacts',
        {'phone_key': key, 'name': contact.displayName},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
  await batch.commit(noResult: true);
  sp.send(true); // Signal completion
}