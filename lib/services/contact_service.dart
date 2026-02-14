import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'contact_db.dart'; // Import your DB class

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  final _contactStreamController = StreamController<int>.broadcast();
  Stream<int> get contactStream => _contactStreamController.stream;
  int _version = 0;

  // The high-speed memory cache for the UI
  Map<String, String> _cachedContacts = {};

  /// Call this on App Launch (e.g., in your Cubit or Main)
  Future<void> init() async {
    // 1. Load what we already have in DB into memory immediately (Fast)
    await _loadFromDb();
    
    // 2. Trigger an Isolate sync to catch changes in the background (Non-blocking)
      _startBackgroundSync();
    
  }

  Future<void> _loadFromDb() async {
    final db = ContactDb();
    final allContacts = await db.getAllContacts(); // Add this method to ContactDb
    _cachedContacts = allContacts;
    _contactStreamController.add(++_version);
  }

  void _startBackgroundSync() {
    final receivePort = ReceivePort();
    RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    Isolate.spawn(syncContactsIsolate, [receivePort.sendPort, rootIsolateToken]);

    receivePort.listen((message) {
      if (message == true) {
        // Sync finished! Reload memory cache from DB
        _loadFromDb();
        receivePort.close();
      }
    });
  }

  /// The synchronous lookup for your Chat List
  String getName(String address) {
    if (RegExp(r'[A-Z]').hasMatch(address)) return address;
    
    String clean = address.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 9) {
      String key = clean.substring(clean.length - 9);
      return _cachedContacts[key] ?? address;
    }
    return address;
  }
}