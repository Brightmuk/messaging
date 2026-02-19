import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:messaging/models/sms_message.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/services/sms_service.dart';


class SelectContactScreen extends StatefulWidget {
  final bool isForwarding;
  final String? forwardMessage;
  const SelectContactScreen({super.key, this.isForwarding = false, this.forwardMessage});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initContacts();
    // Listen for search changes
    _phoneController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initContacts() async {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
  }

    void _onSearchChanged() {
      final query = _phoneController.text.toLowerCase();
      final normalizedQuery = AppChat.normalize(query);

      setState(() {
        _filteredContacts = _allContacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final matchesPhone = contact.phones.any((p) {
            final normalizedContactPhone = AppChat.normalize(p.number);
            return normalizedContactPhone.contains(normalizedQuery);
          });

          return name.contains(query) || matchesPhone;
        }).toList();
      });
    }


  void _navigateToChat(String address)async {
    String? threadId = await SmsService().getThreadId(address); 
    if(widget.isForwarding) {
       Navigator.pop(context);
    }
   
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SingleChatScreen(
          threadId: threadId,
          address: address,
          initialMessage: widget.isForwarding ? widget.forwardMessage : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _phoneController.text.trim();
    // Check if the query is a potential phone number
    final isNumber = RegExp(r'^[0-9+\-() ]+$').hasMatch(query);

    return Scaffold(
      appBar: AppBar(title:  Text(widget.isForwarding ? 'Forward Message' : 'New Message'), centerTitle: false),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                controller: _phoneController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'To',
                  hintText: 'Name or phone number',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                ),
                autofocus: true,
              ),
            ),
          

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                query.isEmpty ? 'Recent contacts' : 'Suggestions',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      // 1. Show the "Message {number}" option if query is a number and no exact contact matches perfectly
                      if (query.isNotEmpty && isNumber && _filteredContacts.isEmpty)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 20),
                          ),
                          title: Text('Message $query'),
                          subtitle: const Text('New number'),
                          onTap: () => _navigateToChat(query),
                        ),
                      
                      // 2. Show Filtered Contacts
                      ..._filteredContacts.map((contact) {
                        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: contact.photo != null ? MemoryImage(contact.photo!) : null,
                            child: contact.photo == null ? Text(contact.displayName.isNotEmpty ? contact.displayName [0]:'') : null,
                          ),
                          title: Text(contact.displayName),
                          subtitle: Text(phone),
                          onTap: () => _navigateToChat(phone),
                        );
                      }),
                      
                      // 3. Empty State if nothing matches and it's not a number
                      if (_filteredContacts.isEmpty && (!isNumber || query.isEmpty))
                        _buildEmptyState(theme),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No contacts found', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}