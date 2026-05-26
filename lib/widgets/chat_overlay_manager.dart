import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/widgets/chat_notification_popup.dart';

class ChatOverlayManager extends StatefulWidget {
  final Widget child;
  final kaawa.User currentUser;

  const ChatOverlayManager({
    super.key,
    required this.child,
    required this.currentUser,
  });

  @override
  State<ChatOverlayManager> createState() => _ChatOverlayManagerState();
}

class _ChatOverlayManagerState extends State<ChatOverlayManager> {
  StreamSubscription<Message>? _messageSubscription;
  OverlayEntry? _overlayEntry;
  final _processedMessageIds = <String>{};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageSubscription = SupabaseService.instance
        .getNewMessagesStream(widget.currentUser.id!)
        .listen((message) {
      if (_isFirstLoad) {
        _isFirstLoad = false;
        if (message.id != null) _processedMessageIds.add(message.id!);
        return;
      }

      if (message.id != null && !_processedMessageIds.contains(message.id)) {
        _processedMessageIds.add(message.id!);
        if (mounted) {
          _showNotification(message);
        }
      }
    });
  }

  // Since I can't easily change SupabaseService now without potentially breaking things,
  // let's try to find if there's an existing stream we can use or if I should add one.
  
  @override
  void dispose() {
    _messageSubscription?.cancel();
    _hideNotification();
    super.dispose();
  }

  void _showNotification(Message message) {
    _hideNotification();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: ChatNotificationPopup(
            message: message,
            onTap: () async {
              _hideNotification();
              final sender = await SupabaseService.instance.getProfile(message.senderId);
              if (sender != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      currentUser: widget.currentUser,
                      otherUser: sender,
                    ),
                  ),
                );
              }
            },
            onDismiss: _hideNotification,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    
    // Auto hide after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) _hideNotification();
    });
  }

  void _hideNotification() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
