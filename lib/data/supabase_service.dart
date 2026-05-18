import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/conversation_data.dart';
import 'package:kaawa/data/review_data.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._privateConstructor();
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseService._privateConstructor();

  // Storage
  Future<String?> uploadImage(String bucket, String path, File file, {String? oldUrl}) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final fullPath = '$path/$fileName';
    
    await _supabase.storage.from(bucket).upload(fullPath, file);
    final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fullPath);

    if (oldUrl != null && oldUrl.isNotEmpty && oldUrl.contains(bucket)) {
      await deleteImage(bucket, oldUrl);
    }
    
    return publicUrl;
  }

  Future<void> deleteImage(String bucket, String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Expected public URL format: .../storage/v1/object/public/bucket/path/to/file
      final bucketIndex = pathSegments.indexOf(bucket);
      if (bucketIndex != -1 && pathSegments.length > bucketIndex + 1) {
        final path = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from(bucket).remove([path]);
      }
    } catch (e) {
      // Log error but don't fail the upload process
      print('SupabaseService.deleteImage error: $e');
    }
  }

  // Profiles / Users
  Future<kaawa.User?> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return kaawa.User.fromMap(response);
  }

  Future<List<kaawa.User>> getAllProfiles() async {
    final response = await _supabase.from('profiles').select();
    return (response as List).map((m) => kaawa.User.fromMap(m)).toList();
  }

  Future<void> updateProfile(kaawa.User user) async {
    await _supabase
        .from('profiles')
        .update(user.toMap())
        .eq('id', user.id!);
  }

  // Coffee Stock
  Future<List<CoffeeStock>> getAllCoffeeStock() async {
    final response = await _supabase
        .from('coffee_stock')
        .select()
        .order('is_sold', ascending: true)
        .order('created_at', ascending: false);
    return (response as List).map((m) => CoffeeStock.fromMap(m)).toList();
  }

  Future<CoffeeStock?> getCoffeeStockById(String stockId) async {
    final response = await _supabase
        .from('coffee_stock')
        .select()
        .eq('id', stockId)
        .maybeSingle();
    if (response == null) return null;
    return CoffeeStock.fromMap(response);
  }

  Future<List<CoffeeStock>> getCoffeeStockByFarmer(String farmerId) async {
    final response = await _supabase
        .from('coffee_stock')
        .select()
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => CoffeeStock.fromMap(m)).toList();
  }

  Future<void> insertCoffeeStock(CoffeeStock stock) async {
    await _supabase.from('coffee_stock').insert(stock.toMap());
  }

  Future<void> updateCoffeeStock(CoffeeStock stock) async {
    await _supabase
        .from('coffee_stock')
        .update(stock.toMap())
        .eq('id', stock.id!);
  }

  // Reviews
  Future<bool> hasReviewByUser(String reviewerId, String reviewedUserId) async {
    final response = await _supabase
        .from('reviews')
        .select('id')
        .eq('reviewer_id', reviewerId)
        .eq('reviewed_user_id', reviewedUserId)
        .maybeSingle();
    return response != null;
  }

  Future<void> insertReview(Review review) async {
    final response = await _supabase.from('reviews').insert(review.toMap()).select().single();
    
    await _supabase.from('review_notifications').insert({
      'recipient_id': review.reviewedUserId,
      'sender_id': review.reviewerId,
      'review_id': response['id'],
      'message': 'left you a review',
      'is_read': false,
    });
  }

  Future<int> getUnreadReviewNotificationCount(String userId) async {
    final response = await _supabase
        .from('review_notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<List<Map<String, dynamic>>> getReviewNotifications(String reviewedUserId) async {
    final response = await _supabase
        .from('review_notifications')
        .select('*, reviews(*, profiles:reviewer_id(*))')
        .eq('recipient_id', reviewedUserId)
        .order('created_at', ascending: false);
    
    return (response as List).map((row) {
      final reviewData = row['reviews'];
      final reviewerData = reviewData['profiles'];
      
      return {
        'notification': {
          'id': row['id'],
          'isRead': row['is_read'],
          'createdAt': row['created_at'],
        },
        'review': {
          'id': reviewData['id'],
          'reviewerId': reviewData['reviewer_id'],
          'reviewedUserId': reviewData['reviewed_user_id'],
          'rating': reviewData['rating'],
          'reviewText': reviewData['review_text'],
        },
        'reviewer': kaawa.User.fromMap(reviewerData),
      };
    }).toList();
  }

  Future<void> markAllReviewNotificationsRead(String reviewedUserId) async {
    await _supabase
        .from('review_notifications')
        .update({'is_read': true})
        .eq('recipient_id', reviewedUserId);
  }

  Future<Map<String, dynamic>> getRatingSummaryForUser(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select('rating')
        .eq('reviewed_user_id', userId);
    
    final reviews = response as List;
    if (reviews.isEmpty) return {'avg': 0.0, 'count': 0};
    
    final sum = reviews.fold<double>(0, (prev, element) => prev + (element['rating'] as num).toDouble());
    return {'avg': sum / reviews.length, 'count': reviews.length};
  }

  // Interests
  Future<List<String>> getInterestedStockIdsForBuyer(String buyerId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('coffee_stock_id')
        .eq('buyer_id', buyerId);
    return (response as List).map((m) => m['coffee_stock_id'].toString()).toList();
  }

  Future<int> getInterestCountForStock(String stockId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('id')
        .eq('coffee_stock_id', stockId);
    return (response as List).length;
  }

  Future<void> addInterest(String stockId, String buyerId) async {
    await _supabase.from('interested_buyers').insert({
      'coffee_stock_id': stockId,
      'buyer_id': buyerId,
    });
  }

  Future<void> removeInterest(String stockId, String buyerId) async {
    await _supabase
        .from('interested_buyers')
        .delete()
        .eq('coffee_stock_id', stockId)
        .eq('buyer_id', buyerId);
  }

  Future<int> getTotalInterestCountForFarmer(String farmerId) async {
    final stocksResponse = await _supabase
        .from('coffee_stock')
        .select('id')
        .eq('farmer_id', farmerId)
        .eq('is_sold', false);
    
    final stockIds = (stocksResponse as List).map((s) => s['id']).toList();
    if (stockIds.isEmpty) return 0;

    final response = await _supabase
        .from('interested_buyers')
        .select('id')
        .inFilter('coffee_stock_id', stockIds)
        .eq('seen_by_farmer', false);
    return (response as List).length;
  }

  Future<List<kaawa.User>> getInterestedBuyersForStock(String stockId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('profiles(*)')
        .eq('coffee_stock_id', stockId);
    
    return (response as List).map((m) => kaawa.User.fromMap(m['profiles'])).toList();
  }

  Future<void> markInterestsAsSeenForStock(String stockId) async {
    await _supabase
        .from('interested_buyers')
        .update({'seen_by_farmer': true})
        .eq('coffee_stock_id', stockId);
  }

  // Favorites
  Future<List<kaawa.User>> getFavorites(String userId) async {
    final response = await _supabase
        .from('favorites')
        .select('profiles!favorites_favorite_user_id_fkey(*)')
        .eq('user_id', userId);
    
    return (response as List).map((m) => kaawa.User.fromMap(m['profiles'])).toList();
  }

  Future<void> addFavorite(String userId, String favoriteUserId) async {
    await _supabase.from('favorites').insert({
      'user_id': userId,
      'favorite_user_id': favoriteUserId,
    });
  }

  Future<void> removeFavorite(String userId, String favoriteUserId) async {
    await _supabase
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('favorite_user_id', favoriteUserId);
  }

  // Conversations & Messages
  Future<List<Conversation>> getConversations(String userId) async {
    final response = await _supabase
        .from('messages')
        .select('*, profiles:sender_id(*), receiver:receiver_id(*)')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
    
    final messages = (response as List).map((m) => Message.fromMap(m)).toList();
    final Map<String, Message> latestMessages = {};
    final Map<String, kaawa.User> otherUsers = {};

    for (final msg in messages) {
      final otherId = msg.senderId == userId ? msg.receiverId : msg.senderId;
      if (!latestMessages.containsKey(otherId)) {
        latestMessages[otherId] = msg;
        
        final msgData = (response as List).firstWhere((element) => element['id'] == msg.id);
        if (msg.senderId == userId) {
          otherUsers[otherId] = kaawa.User.fromMap(msgData['receiver']);
        } else {
          otherUsers[otherId] = kaawa.User.fromMap(msgData['profiles']);
        }
      }
    }

    List<Conversation> conversations = [];
    for (final otherId in latestMessages.keys) {
      final lastMsg = latestMessages[otherId]!;
      CoffeeStock? stock;
      if (lastMsg.coffeeStockId != null) {
        stock = await getCoffeeStockById(lastMsg.coffeeStockId!);
      }
      
      conversations.add(Conversation(
        otherUser: otherUsers[otherId]!,
        lastMessage: lastMsg,
        coffeeStock: stock,
      ));
    }

    return conversations;
  }

  Future<List<Message>> getMessages(String userId1, String userId2) async {
    final response = await _supabase
        .from('messages')
        .select()
        .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
        .order('created_at', ascending: true);
    
    return (response as List).map((m) => Message.fromMap(m)).toList();
  }

  Future<int> getUnreadMessageCount(String userId) async {
    final response = await _supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<void> markMessagesAsRead(String receiverId, String senderId) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('receiver_id', receiverId)
        .eq('sender_id', senderId)
        .eq('is_read', false);
  }

  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert(message.toMap());
  }

  Future<List<Message>> getPurchaseRequestsForFarmer(String farmerId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('receiver_id', farmerId)
        .eq('is_purchase_request', true)
        .order('created_at', ascending: false);
    
    return (response as List).map((m) => Message.fromMap(m)).toList();
  }

  // Streams
  Stream<List<CoffeeStock>> getCoffeeStockStreamByFarmer(String farmerId) {
    return _supabase
        .from('coffee_stock')
        .stream(primaryKey: ['id'])
        .eq('farmer_id', farmerId)
        .map((data) => data.map((m) => CoffeeStock.fromMap(m)).toList());
  }

  Stream<List<CoffeeStock>> getAllCoffeeStockStream() {
    return _supabase
        .from('coffee_stock')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((m) => CoffeeStock.fromMap(m)).toList());
  }

  Stream<int> getUnreadMessageCountStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((data) {
          return data.where((m) {
            final isRead = m['is_read'];
            // Handle both boolean and int (0/1) for compatibility
            return isRead == false || isRead == 0;
          }).length;
        });
  }

  Stream<int> getUnreadReviewNotificationCountStream(String userId) {
    return _supabase
        .from('review_notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .map((data) => data.where((m) => m['is_read'] == false || m['is_read'] == 0).length);
  }

  Stream<int> getInterestedCountStreamForFarmer(String farmerId) {
    return _supabase
        .from('interested_buyers')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getTotalInterestCountForFarmer(farmerId));
  }

  Stream<int> getPurchaseRequestCountStreamForFarmer(String farmerId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', farmerId)
        .map((data) => data.where((m) => m['is_purchase_request'] == true).length);
  }

  Stream<List<Conversation>> getConversationsStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .asyncMap((data) async {
      final messages = data
          .where((m) => m['sender_id'] == userId || m['receiver_id'] == userId)
          .map((m) => Message.fromMap(m))
          .toList();
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final Map<String, Message> latestMessages = {};

      for (final msg in messages) {
        final otherId = msg.senderId == userId ? msg.receiverId : msg.senderId;
        if (!latestMessages.containsKey(otherId)) {
          latestMessages[otherId] = msg;
        }
      }

      List<Conversation> conversations = [];
      for (final otherId in latestMessages.keys) {
        final lastMsg = latestMessages[otherId]!;
        final otherUser = await getProfile(otherId);
        if (otherUser == null) continue;

        CoffeeStock? stock;
        if (lastMsg.coffeeStockId != null) {
          stock = await getCoffeeStockById(lastMsg.coffeeStockId!);
        }

        conversations.add(Conversation(
          otherUser: otherUser,
          lastMessage: lastMsg,
          coffeeStock: stock,
        ));
      }
      return conversations;
    });
  }

  Stream<List<Message>> getMessagesStream(String userId1, String userId2) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          final msgs = data
              .map((m) => Message.fromMap(m))
              .where((m) =>
                  (m.senderId == userId1 && m.receiverId == userId2) ||
                  (m.senderId == userId2 && m.receiverId == userId1))
              .toList();
          
          // Force a secondary sort in Dart to ensure perfect UI order 
          // even if network packets arrive slightly out of sequence
          msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return msgs;
        });
  }

  Stream<Map<String, dynamic>> getUserActivityStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .asyncMap((_) async {
          final listings = await _supabase
              .from('coffee_stock')
              .select('id')
              .eq('farmer_id', userId);
          
          final interests = await _supabase
              .from('interested_buyers')
              .select('id')
              .eq('buyer_id', userId);
          
          final convs = await getConversations(userId);
          
          final profile = await getProfile(userId);
          
          return {
            'listingsCount': (listings as List).length,
            'interestsCount': (interests as List).length,
            'conversationsCount': convs.length,
            'earliestActivityIso': profile?.id != null ? profile!.id : DateTime.now().toIso8601String(), // Fallback
          };
        });
  }

  Stream<Map<String, List<kaawa.User>>> getInterestedBuyersByStockStream(String farmerId) {
    return _supabase
        .from('interested_buyers')
        .stream(primaryKey: ['id'])
        .asyncMap((_) async {
      final stocks = await getCoffeeStockByFarmer(farmerId);
      final Map<String, List<kaawa.User>> map = {};

      await Future.wait(stocks.map((s) async {
        if (s.id != null) {
          final buyers = await getInterestedBuyersForStock(s.id!);
          if (buyers.isNotEmpty) {
            map[s.id!] = buyers;
          }
        }
      }));

      return map;
    });
  }

  // Activity Log
  Future<List<Map<String, dynamic>>> getUserActivityLog(String userId) async {
    final messagesResponse = await _supabase
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);

    final interestsResponse = await _supabase
        .from('interested_buyers')
        .select()
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);

    final stocksResponse = await _supabase
        .from('coffee_stock')
        .select('id')
        .eq('farmer_id', userId);
    
    final stockIds = (stocksResponse as List).map((s) => s['id']).toList();
    List interestsForFarmerResponse = [];
    if (stockIds.isNotEmpty) {
      interestsForFarmerResponse = await _supabase
          .from('interested_buyers')
          .select()
          .inFilter('coffee_stock_id', stockIds)
          .order('created_at', ascending: false);
    }

    final List<Map<String, dynamic>> log = [];

    for (final m in (messagesResponse as List)) {
      log.add({
        'type': 'message',
        'text': m['text'],
        'timestamp': m['created_at'],
        'senderId': m['sender_id'],
      });
    }

    for (final i in (interestsResponse as List)) {
      log.add({
        'type': 'interest',
        'coffeeStockId': i['coffee_stock_id'],
        'buyerId': i['buyer_id'],
        'timestamp': i['created_at'],
      });
    }

    for (final i in interestsForFarmerResponse) {
      log.add({
        'type': 'interest_for_farmer',
        'coffeeStockId': i['coffee_stock_id'],
        'buyerId': i['buyer_id'],
        'timestamp': i['created_at'],
      });
    }

    log.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return log;
  }

  // Admin password resets
  Future<void> insertPasswordResetRequest(String phoneNumber) async {
    await _supabase.from('password_resets').insert({
      'phone_number': phoneNumber,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPasswordResetRequests() async {
    final response = await _supabase
        .from('password_resets')
        .select()
        .eq('handled', false)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Stream<int> getPendingPasswordResetCountStream() {
    return _supabase
        .from('password_resets')
        .stream(primaryKey: ['id'])
        .map((data) => data.where((r) => r['handled'] == false).length);
  }

  Future<void> markPasswordResetHandled(String id, {String? adminId}) async {
    await _supabase.from('password_resets').update({
      'handled': true,
      'handled_at': DateTime.now().toIso8601String(),
      'handled_by_admin': adminId,
    }).eq('id', id);
  }

  Future<bool> adminSetUserPassword(String userId, String newPassword) async {
    await _supabase
        .from('profiles')
        .update({'must_change_password': true})
        .eq('id', userId);
    return true;
  }

  Future<void> suspendUser(String userId, DateTime until, {String? reason}) async {
    await _supabase
        .from('profiles')
        .update({
          'suspended_until': until.toIso8601String(),
          'suspension_reason': reason,
        })
        .eq('id', userId);
  }

  Future<void> unsuspendUser(String userId) async {
    await _supabase
        .from('profiles')
        .update({
          'suspended_until': null,
          'suspension_reason': null,
        })
        .eq('id', userId);
  }

  Future<Map<String, dynamic>> getUserActivitySummary(String userId) async {
    final listings = await _supabase
        .from('coffee_stock')
        .select('id')
        .eq('farmer_id', userId);
    
    final interests = await _supabase
        .from('interested_buyers')
        .select('id')
        .eq('buyer_id', userId);

    final messages = await _supabase
        .from('messages')
        .select('id')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId');

    final profile = await _supabase
        .from('profiles')
        .select('created_at')
        .eq('id', userId)
        .maybeSingle();

    return {
      'listingsCount': (listings as List).length,
      'interestsCount': (interests as List).length,
      'conversationsCount': (messages as List).length,
      'earliestActivityIso': profile?['created_at'],
    };
  }
}
