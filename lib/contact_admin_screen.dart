import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactAdminScreen extends StatelessWidget {
  const ContactAdminScreen({super.key});

  Future<void> _callAdmin() async {
    final uri = Uri.parse('tel:0751433267');
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
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Kaawa Admin'),
              subtitle: const Text('0751433267'),
              trailing: ElevatedButton(
                onPressed: _callAdmin,
                child: const Icon(Icons.call),
              ),
            ),
            const SizedBox(height: 12),
            const Text('You can call the number above for immediate support.'),
          ],
        ),
      ),
    );
  }
}
