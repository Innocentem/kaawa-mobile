import 'dart:io';
import 'dart:async';
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
  Future<String?> uploadImage(String bucket, String path, File file,
      {String? oldUrl}) async {
    try {
      if (!await file.exists()) {
        print(
            'SupabaseService: Upload failed. File does not exist at ${file.path}');
        return null;
      }

      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}.$extension';

      // Sanitize path: remove leading/trailing slashes and trim
      final cleanPath = path.replaceAll(RegExp(r'^/|/$'), '').trim();
      final fullPath = cleanPath.isEmpty ? fileName : '$cleanPath/$fileName';

      // Determine content type
      String contentType = 'image/jpeg';
      if (extension == 'png')
        contentType = 'image/png';
      else if (extension == 'webp')
        contentType = 'image/webp';
      else if (extension == 'gif') contentType = 'image/gif';

      print(
          'SupabaseService: Uploading ${bytes.length} bytes to $bucket/$fullPath ($contentType)');

      // Using the path as the first argument, and bytes as the data.
      // supabase_flutter 2.x supports Uint8List in upload().
      await _supabase.storage.from(bucket).uploadBinary(
            fullPath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fullPath);

      // Basic validation of the returned URL
      if (publicUrl.isEmpty || !publicUrl.startsWith('http')) {
        print('SupabaseService: Invalid public URL generated: $publicUrl');
        return null;
      }

      print('SupabaseService: Upload successful. URL: $publicUrl');

      if (oldUrl != null && oldUrl.isNotEmpty && oldUrl.contains(bucket)) {
        // Run deletion in background
        deleteImage(bucket, oldUrl).catchError(
            (e) => print('SupabaseService: Delete old image failed: $e'));
      }

      return publicUrl;
    } catch (e) {
      print('SupabaseService: uploadImage exception: $e');
      return null;
    }
  }

  Future<void> deleteImage(String bucket, String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Expected public URL format: .../storage/v1/object/public/bucket/path/to/file

      // Find the index of 'public' in pathSegments, then skip it and get the rest
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1 && pathSegments.length > publicIndex + 2) {
        // After 'public' comes bucket, then the file path
        final bucketFromUrl = pathSegments[publicIndex + 1];

        // Verify the bucket matches
        if (bucketFromUrl == bucket) {
          // The file path is everything after bucket
          final filePath = pathSegments.sublist(publicIndex + 2).join('/');
          print('SupabaseService.deleteImage: Deleting $filePath from $bucket');
          await _supabase.storage.from(bucket).remove([filePath]);
        } else {
          print(
              'SupabaseService.deleteImage: Bucket mismatch. Expected $bucket, found $bucketFromUrl');
        }
      } else {
        print('SupabaseService.deleteImage: Could not parse URL: $url');
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

  Stream<kaawa.User?> getProfileStream(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.isNotEmpty ? kaawa.User.fromMap(data.first) : null);
  }

  Future<List<kaawa.User>> getAllProfiles() async {
    final response = await _supabase.from('profiles').select();
    return (response as List).map((m) => kaawa.User.fromMap(m)).toList();
  }

  Future<kaawa.User?> updateProfile(kaawa.User user) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update(user.toMap())
          .eq('id', user.id!)
          .select()
          .maybeSingle();
      return response != null ? kaawa.User.fromMap(response) : null;
    } catch (e) {
      print('SupabaseService.updateProfile error: $e');
      rethrow;
    }
  }

  Future<void> updateAuthMetadata(kaawa.User user) async {
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': user.fullName,
          'phone_number': user.phoneNumber,
          'district': user.district,
          'profile_picture_url': user.profilePicturePath,
        },
      ),
    );
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

  Future<void> updateCoffeeStockQuantity(String stockId, double quantitySold) async {
    final stock = await getCoffeeStockById(stockId);
    if (stock == null) return;

    final newRemaining = (stock.quantityRemaining - quantitySold).clamp(0.0, stock.quantity).toDouble();
    final isSold = newRemaining <= 0;

    await _supabase
        .from('coffee_stock')
        .update({
          'quantity_remaining': newRemaining,
          'is_sold': isSold,
        })
        .eq('id', stockId);
  }

  // Reviews
  Future<List<Map<String, dynamic>>> getReviewsForUserWithReviewers(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select('*, profiles!reviewer_id(*), coffee_stock(*)')
        .eq('reviewed_user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((map) {
      return {
        'review': Review.fromMap(map),
        'reviewer': map['profiles'] != null ? kaawa.User.fromMap(map['profiles']) : null,
        'coffeeStock': map['coffee_stock'] != null ? CoffeeStock.fromMap(map['coffee_stock']) : null,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getReviewsForProductWithReviewers(String stockId) async {
    final response = await _supabase
        .from('reviews')
        .select('*, profiles!reviewer_id(*)')
        .eq('coffee_stock_id', stockId)
        .order('created_at', ascending: false);
    return (response as List).map((map) {
      return {
        'review': Review.fromMap(map),
        'reviewer': map['profiles'] != null ? kaawa.User.fromMap(map['profiles']) : null,
      };
    }).toList();
  }

  Future<List<Review>> getReviewsForUser(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select()
        .eq('reviewed_user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => Review.fromMap(m)).toList();
  }

  Future<List<Review>> getReviewsForProduct(String stockId) async {
    final response = await _supabase
        .from('reviews')
        .select()
        .eq('coffee_stock_id', stockId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => Review.fromMap(m)).toList();
  }

  Future<void> insertReview(Review review) async {
    await _supabase.from('reviews').insert(review.toMap());
  }

  Future<bool> hasReviewByUser(String reviewerId, String reviewedUserId) async {
    final response = await _supabase
        .from('reviews')
        .select('id')
        .eq('reviewer_id', reviewerId)
        .eq('reviewed_user_id', reviewedUserId)
        .maybeSingle();
    return response != null;
  }

  Future<bool> hasReviewForProduct(String reviewerId, String stockId) async {
    final response = await _supabase
        .from('reviews')
        .select('id')
        .eq('reviewer_id', reviewerId)
        .eq('coffee_stock_id', stockId)
        .maybeSingle();
    return response != null;
  }

  Future<Map<String, dynamic>> getRatingSummaryForUser(String userId) async {
    final reviews = await getReviewsForUser(userId);
    if (reviews.isEmpty) {
      return {
        'averageRating': 0.0,
        'reviewCount': 0,
      };
    }
    final sum = reviews.fold(0.0, (prev, r) => prev + r.rating);
    return {
      'averageRating': sum / reviews.length,
      'reviewCount': reviews.length,
    };
  }

  Future<double> getAverageRatingForProduct(String stockId) async {
    final reviews = await getReviewsForProduct(stockId);
    if (reviews.isEmpty) return 0.0;
    final sum = reviews.fold(0.0, (prev, r) => prev + r.rating);
    return sum / reviews.length;
  }

  // Notifications
  Stream<int> getUnreadNotificationCountStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.where((row) => row['is_read'] == false).length);
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> markReviewNotificationRead(dynamic id) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getReviewNotifications(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('type', 'review')
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> result = [];
    for (final n in (response as List)) {
      final metadata = n['metadata'] as Map<String, dynamic>?;
      if (metadata == null || metadata['review_id'] == null) continue;

      final reviewData = await _supabase
          .from('reviews')
          .select()
          .eq('id', metadata['review_id'])
          .maybeSingle();

      if (reviewData != null) {
        final reviewer = await getProfile(metadata['reviewer_id']);
        final coffeeStockId = reviewData['coffee_stock_id'];
        CoffeeStock? coffeeStock;
        if (coffeeStockId != null) {
          coffeeStock = await getCoffeeStockById(coffeeStockId.toString());
        }

        result.add({
          'notification': n,
          'review': reviewData,
          'reviewer': reviewer,
          'coffeeStock': coffeeStock,
        });
      }
    }
    return result;
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId);
  }

  // Favorites
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

  Future<bool> isFavorite(String userId, String favoriteUserId) async {
    final response = await _supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('favorite_user_id', favoriteUserId)
        .maybeSingle();
    return response != null;
  }

  Future<List<kaawa.User>> getFavorites(String userId) async {
    final response = await _supabase
        .from('favorites')
        .select('profiles!favorites_favorite_user_id_fkey(*)')
        .eq('user_id', userId);
    
    return (response as List).map((row) => kaawa.User.fromMap(row['profiles'])).toList();
  }

  // Interested Buyers
  Future<void> toggleInterest(String stockId, String buyerId) async {
    final existing = await _supabase
        .from('interested_buyers')
        .select('id')
        .eq('coffee_stock_id', stockId)
        .eq('buyer_id', buyerId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('interested_buyers').insert({
        'coffee_stock_id': stockId,
        'buyer_id': buyerId,
      });
    } else {
      await _supabase
          .from('interested_buyers')
          .delete()
          .eq('id', existing['id']);
    }
  }

  Future<bool> isInterested(String stockId, String buyerId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('id')
        .eq('coffee_stock_id', stockId)
        .eq('buyer_id', buyerId)
        .maybeSingle();
    return response != null;
  }

  Future<List<String>> getInterestedStockIdsForBuyer(String buyerId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('coffee_stock_id')
        .eq('buyer_id', buyerId);
    return (response as List).map((r) => r['coffee_stock_id'].toString()).toList();
  }

  Future<int> getInterestCountForStock(String stockId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('id')
        .eq('coffee_stock_id', stockId);
    return (response as List).length;
  }

  Future<List<kaawa.User>> getInterestedBuyersForStock(String stockId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('profiles(*)')
        .eq('coffee_stock_id', stockId);
    return (response as List).map((row) => kaawa.User.fromMap(row['profiles'])).toList();
  }

  Future<int> getTotalInterestCountForFarmer(String farmerId) async {
    final stocks = await getCoffeeStockByFarmer(farmerId);
    int total = 0;
    for (final s in stocks) {
      if (s.id != null) {
        total += await getInterestCountForStock(s.id!);
      }
    }
    return total;
  }

  Future<int> getUnreadInterestedCountForFarmer(String farmerId) async {
    final stocks = await getCoffeeStockByFarmer(farmerId);
    if (stocks.isEmpty) return 0;
    
    final stockIds = stocks.map((s) => s.id).whereType<String>().toList();
    if (stockIds.isEmpty) return 0;

    final response = await _supabase
        .from('interested_buyers')
        .select('id')
        .inFilter('coffee_stock_id', stockIds)
        .eq('seen_by_farmer', false);
    
    return (response as List).length;
  }

  Future<void> markInterestsAsSeen(String stockId) async {
    await _supabase
        .from('interested_buyers')
        .update({'seen_by_farmer': true})
        .eq('coffee_stock_id', stockId)
        .eq('seen_by_farmer', false);
  }

  // Messages / Conversations
  Future<List<Conversation>> getConversations(String userId) async {
    final response = await _supabase
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(*), receiver:profiles!messages_receiver_id_fkey(*)')
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
          otherUsers[otherId] = kaawa.User.fromMap(msgData['sender']);
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

  Future<void> updateMessagePurchaseData(String messageId, String purchaseData) async {
    await _supabase
        .from('messages')
        .update({'purchase_request_data': purchaseData})
        .eq('id', messageId);
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

    // Mark as read after fetching
    await markPurchaseRequestsAsRead(farmerId);

    return (response as List).map((m) => Message.fromMap(m)).toList();
  }

  Future<void> markPurchaseRequestsAsRead(String farmerId) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('receiver_id', farmerId)
        .eq('is_purchase_request', true)
        .eq('is_read', false);
  }

  Future<int> getPurchaseRequestCountForFarmer(String farmerId) async {
    final response = await _supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', farmerId)
        .eq('is_purchase_request', true)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<List<Message>> getPurchaseHistory(String userId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('sender_id', userId)
        .eq('is_purchase_request', true)
        .order('created_at', ascending: false);

    return (response as List).map((m) => Message.fromMap(m)).toList();
  }

  Stream<List<Message>> getPurchaseHistoryStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', userId)
        .map((data) => data
            .where((m) => m['is_purchase_request'] == true)
            .map((m) => Message.fromMap(m))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
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
    return _supabase.from('coffee_stock').stream(primaryKey: ['id']).map(
        (data) => data.map((m) => CoffeeStock.fromMap(m)).toList());
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

  Stream<int> getInterestedCountStreamForFarmer(String farmerId) {
    return _supabase.from('interested_buyers').stream(primaryKey: [
      'id'
    ]).asyncMap((_) => getUnreadInterestedCountForFarmer(farmerId));
  }

  Stream<int> getPurchaseRequestCountStreamForFarmer(String farmerId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', farmerId)
        .map((data) => data
            .where((m) =>
                m['is_purchase_request'] == true && m['is_read'] == false)
            .length);
  }

  Stream<List<Conversation>> getConversationsStream(String userId) {
    // We listen to both messages and profiles to ensure the UI updates when a profile (like picture) changes.
    final messagesStream =
        _supabase.from('messages').stream(primaryKey: ['id']);
    final profilesStream =
        _supabase.from('profiles').stream(primaryKey: ['id']);

    final controller = StreamController<void>();

    // Send initial event
    controller.add(null);

    var messageSub = messagesStream.listen((_) => controller.add(null));
    var profileSub = profilesStream.listen((_) => controller.add(null));

    controller.onCancel = () {
      messageSub.cancel();
      profileSub.cancel();
      controller.close();
    };

    return controller.stream.asyncMap((_) async {
      final data = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final messages = (data as List).map((m) => Message.fromMap(m)).toList();

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
        .stream(primaryKey: ['id']).asyncMap((_) async {
      final listings = await _supabase
          .from('coffee_stock')
          .select('id')
          .eq('farmer_id', userId);

      final interests = await _supabase
          .from('interested_buyers')
          .select('id')
          .eq('buyer_id', userId);

      final convs = await getConversations(userId);

      final profileData = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      return {
        'listingsCount': (listings as List).length,
        'interestsCount': (interests as List).length,
        'conversationsCount': convs.length,
        'earliestActivityIso':
            profileData?['created_at'] ?? DateTime.now().toIso8601String(),
      };
    });
  }

  Future<List<kaawa.User>> getUnseenInterestedBuyersForStock(String stockId) async {
    final response = await _supabase
        .from('interested_buyers')
        .select('profiles(*)')
        .eq('coffee_stock_id', stockId)
        .eq('seen_by_farmer', false);
    return (response as List).map((row) => kaawa.User.fromMap(row['profiles'])).toList();
  }

  Stream<Map<String, List<kaawa.User>>> getInterestedBuyersByStockStream(
      String farmerId) {
    return _supabase
        .from('interested_buyers')
        .stream(primaryKey: ['id']).asyncMap((_) async {
      final stocks = await getCoffeeStockByFarmer(farmerId);
      final Map<String, List<kaawa.User>> map = {};

      await Future.wait(stocks.map((s) async {
        if (s.id != null) {
          final buyers = await getUnseenInterestedBuyersForStock(s.id!);
          if (buyers.isNotEmpty) {
            map[s.id!] = buyers;
          }
        }
      }));

      return map;
    });
  }

  Stream<Message> getNewMessagesStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          final unread = data.where((m) => m['is_read'] == false || m['is_read'] == 0).toList();
          if (unread.isEmpty) return null;
          
          final newest = unread.map((m) => Message.fromMap(m)).toList();
          newest.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return newest.first;
        })
        .where((m) => m != null)
        .cast<Message>();
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

    log.sort((a, b) =>
        (b['timestamp'] as String).compareTo(a['timestamp'] as String));
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
    return _supabase.from('password_resets').stream(primaryKey: ['id']).map(
        (data) => data.where((r) => r['handled'] == false).length);
  }

  Future<void> markPasswordResetHandled(String id, {String? adminId}) async {
    await _supabase.from('password_resets').update({
      'handled': true,
      'handled_at': DateTime.now().toIso8601String(),
      'handled_by_admin': adminId,
    }).eq('id', id);
  }

  Future<bool> adminSetUserPassword(String userId, String newPassword) async {
    // In a production app, you'd use a Supabase Edge Function with service_role to update auth.password.
    // For this prototype, we're flagging must_change_password in the public profile.
    // The actual password reset in Supabase Auth usually requires email or service_role.
    await _supabase
        .from('profiles')
        .update({'must_change_password': true}).eq('id', userId);
    return true;
  }

  Future<void> suspendUser(String userId, DateTime until,
      {String? reason}) async {
    await _supabase.from('profiles').update({
      'suspended_until': until.toIso8601String(),
      'suspension_reason': reason,
    }).eq('id', userId);
  }

  Future<void> unsuspendUser(String userId) async {
    await _supabase.from('profiles').update({
      'suspended_until': null,
      'suspension_reason': null,
    }).eq('id', userId);
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
