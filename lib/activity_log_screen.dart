import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:intl/intl.dart';
import 'widgets/compact_loader.dart';

class ActivityLogScreen extends StatefulWidget {
  final int userId;
  const ActivityLogScreen({super.key, required this.userId});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  late Future<List<Map<String, dynamic>>> _logFuture;

  @override
  void initState() {
    super.initState();
    _logFuture = DatabaseHelper.instance.getUserActivityLog(widget.userId);
  }

  String _formatTs(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CompactLoader());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading log: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('No activity yet.'));

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final it = items[index];
              final type = it['type'] as String? ?? 'unknown';
              final ts = _formatTs(it['timestamp'] as String?);

              if (type == 'message') {
                final text = it['text'] ?? '';
                return ListTile(
                  title: Text('Message'),
                  subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(ts, style: theme.textTheme.bodySmall),
                  onTap: () {
                    // open chat: not wired here (needs currentUser context), so just show details
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Message'),
                        content: Text('$text\n\nAt: $ts'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                        ],
                      ),
                    );
                  },
                );
              } else if (type == 'interest' || type == 'interest_for_farmer') {
                final stockId = it['coffeeStockId'];
                final buyerId = it['buyerId'] ?? it['buyerId'];
                return ListTile(
                  title: Text(type == 'interest' ? 'You showed interest' : 'Buyer showed interest'),
                  subtitle: Text('Stock #$stockId · Buyer #$buyerId'),
                  trailing: Text(ts, style: theme.textTheme.bodySmall),
                  onTap: () {},
                );
              }

              return ListTile(
                title: Text('Activity'),
                subtitle: Text(it.toString()),
                trailing: Text(ts, style: theme.textTheme.bodySmall),
              );
            },
          );
        },
      ),
    );
  }
}
