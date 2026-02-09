import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:messaging/screens/single_chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a phone number';
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) return 'Please enter a valid phone number';
    return null;
  }

  void _startChat() {
    if (_formKey.currentState!.validate()) {
      final phoneNumber = _phoneController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SingleChatScreen(
            threadId: phoneNumber,
            address: phoneNumber,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Recipient Input Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                controller: _phoneController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'To',
                  hintText: 'Name or phone number',
                  
                  // M3 Rounded Border
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                ),
                
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+\-() ]')),
                ],
                validator: _validatePhoneNumber,
                autofocus: true,
                onFieldSubmitted: (_) => _startChat(),
              ),
            ),

            // 2. Quick Action Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Create group'),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.business_outlined, size: 18),
                    label: const Text('Businesses'),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Contact List / Empty State
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent contacts',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: _buildContacts(theme),
            ),

            // 4. M3 Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _startChat,
                  child: const Text('Start Chat'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContacts(ThemeData theme) {
    return FutureBuilder(
        future:
            FlutterContacts.getContacts(withProperties: true, withPhoto: true),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasError) {
            return Center(child: Text('Error: ${asyncSnapshot.error}'));
          } else if (asyncSnapshot.hasData) {
            List<Contact> contacts = asyncSnapshot.data as List<Contact>;
            if (contacts.isNotEmpty) {
              return ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final phone = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : 'No number';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: contact.photo != null
                          ? MemoryImage(contact.photo!)
                          : null,
                      child: contact.photo == null
                          ? Text(contact.displayName[0])
                          : null,
                    ),
                    title: Text(contact.displayName),
                    subtitle: Text(phone),
                    onTap: () {
                      // Auto-fill the phone controller or navigate
                      _phoneController.text = phone;
                    },
                  );
                },
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contacts_outlined,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent contacts',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sync your contacts to see them here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const SizedBox();
          }
        });
  }
}
