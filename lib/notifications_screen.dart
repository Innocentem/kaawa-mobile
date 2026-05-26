import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/widgets/shimmer_skeleton.dart';
import 'package:kaawa/product_detail_screen.dart';
import 'package:kaawa/review_notifications_screen.dart';
import 'package:kaawa/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final kaawa.User currentUser;
  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = SupabaseService.instance.getNotifications(widget.currentUser.id!);
    });
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'];
    final metadata = notification['metadata'] as Map<String, dynamic>?;

    if (notification['is_read'] == false) {
      await SupabaseService.instance.markNotificationRead(notification['id'].toString());
      _refresh();
    }

    if (!mounted) return;

    if (type == 'stock_update' && metadata != null && metadata.containsKey('stock_id')) {
      final stockId = metadata['stock_id'].toString();
      final stock = await SupabaseService.instance.getCoffeeStockById(stockId);
      if (stock != null) {
        final farmer = await SupabaseService.instance.getProfile(stock.farmerId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => ProductDetailScreen(
                stock: stock,
                farmer: farmer,
                currentUser: widget.currentUser,
                heroTag: 'notif_${stock.id}',
              ),
            ),
          );
        }
      }
    } else if (type == 'review') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ReviewNotificationsScreen(
            currentUser: widget.currentUser,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
              elevation: 0,
              foregroundColor: theme.colorScheme.onSurface,
              title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.done_all),
                  onPressed: () async {
                    await SupabaseService.instance.markAllNotificationsRead(widget.currentUser.id!);
                    _refresh();
                  },
                  tooltip: 'Mark all as read',
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                  left: 12,
                  right: 12,
                ),
                itemCount: 8,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerSkeleton.rect(height: 80, borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading notifications.'));
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: theme.hintColor.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text('No notifications yet.'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                left: 12,
                right: 12,
                bottom: 24,
              ),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = entries[index];
                final isRead = notification['is_read'] == true;
                
                return Card(
                  elevation: isRead ? 0 : 2,
                  color: isRead ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isRead ? BorderSide.none : BorderSide(color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: _getIconColor(notification['type'], theme),
                      child: Icon(_getIcon(notification['type']), color: Colors.white, size: 20),
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notification['content'] ?? ''),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(notification['created_at']),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                    onTap: () => _handleNotificationTap(notification),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'stock_update':
        return Icons.eco;
      case 'review':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String? type, ThemeData theme) {
    switch (type) {
      case 'stock_update':
        return Colors.green;
      case 'review':
        return Colors.amber;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
