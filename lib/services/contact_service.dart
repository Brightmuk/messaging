import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();

  factory ContactService() {
    return _instance;
  }

  ContactService._internal();

  final _contactStreamController = StreamController<int>.broadcast();
  Stream<int> get contactStream => _contactStreamController.stream;
  int _version = 0;

  Map<String, String> _cachedContacts = {};

  Future<void> fetchContactsInBackground() async {
   
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      
      final Map<String, String> newMap = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String clean = phone.number.replaceAll(RegExp(r'\D'), '');
          // Keep the last 9 digits for easier matching in Kenya
          if (clean.length >= 9) {
            newMap[clean.substring(clean.length - 9)] = contact.displayName;
          }
        }
      }
      _cachedContacts = newMap;
      _contactStreamController.add(++_version);
    
  }

   Future<void> refreshContacts() async {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
      
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          // Normalize the number to ensure matches (remove spaces, etc.)
          String cleanNumber = phone.number.replaceAll(RegExp(r'\D'), '');
          _cachedContacts[cleanNumber] = contact.displayName;
        }
      }
    
  }

String getName(String address) {
  if (RegExp(r'[A-Z]').hasMatch(address)) {
    return address;
  }

  String cleanNumber = address.replaceAll(RegExp(r'\D'), '');

  if (cleanNumber.length >= 9) {
    String uniqueSuffix = cleanNumber.substring(cleanNumber.length - 9);

    return _cachedContacts[uniqueSuffix] ?? address;
  }

  return address;
}
}