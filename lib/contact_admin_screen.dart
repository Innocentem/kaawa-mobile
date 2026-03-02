import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/chat_screen.dart';

class ContactAdminScreen extends StatelessWidget {
  final User? currentUser;
  const ContactAdminScreen({super.key, this.currentUser});

  Future<void> _callAdmin(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin contact'),
            const SizedBox(height: 8),
            if (currentUser == null)
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Kaawa Admin'),
                subtitle: const Text('0751433267'),
                trailing: ElevatedButton(
                  onPressed: () => _callAdmin('0751433267'),
                  child: const Icon(Icons.call),
                ),
              )
            else
              FutureBuilder<List<User>>(
                future: DatabaseHelper.instance.getAdmins(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final admins = snapshot.data ?? [];
                  if (admins.isEmpty) {
                    return const Text('No admin accounts found.');
                  }
                  return Column(
                    children: admins.map((admin) {
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(admin.fullName),
                        subtitle: Text(admin.phoneNumber),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: () => _callAdmin(admin.phoneNumber),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      currentUser: currentUser!,
                                      otherUser: admin,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Message'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            const SizedBox(height: 12),
            const Text('You can call the admin for immediate support or send a message in-app.'),
          ],
        ),
      ),
    );
  }
}
