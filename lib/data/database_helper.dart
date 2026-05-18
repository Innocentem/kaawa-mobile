import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'user_data.dart' as kaawa;
import 'coffee_stock_data.dart';
import 'message_data.dart';
import 'cart_item.dart';
import 'review_data.dart';
import 'package:kaawa/utils/date_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kaawa.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 27,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        password TEXT NOT NULL,
        userType TEXT NOT NULL,
        location TEXT,
        profilePicture TEXT,
        mustChangePassword INTEGER DEFAULT 0,
        suspendedUntil TEXT,
        suspensionReason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE coffee_stock (
        id TEXT PRIMARY KEY,
        farmer_id TEXT NOT NULL,
        coffee_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        price_per_kg REAL NOT NULL,
        coffee_picture_url TEXT,
        description TEXT,
        is_sold INTEGER DEFAULT 0,
        FOREIGN KEY (farmer_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        is_purchase_request INTEGER DEFAULT 0,
        coffee_stock_id TEXT,
        purchase_request_data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cart_items (
        id TEXT PRIMARY KEY,
        buyerId TEXT NOT NULL,
        coffeeStockId TEXT NOT NULL,
        quantity REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (buyerId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (coffeeStockId) REFERENCES coffee_stock (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reviewerId TEXT NOT NULL,
        reviewedUserId TEXT NOT NULL,
        rating REAL NOT NULL,
        comment TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (reviewerId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (reviewedUserId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE admin_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adminId TEXT NOT NULL,
        action TEXT NOT NULL,
        targetType TEXT NOT NULL,
        targetId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        details TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 27) {
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS coffee_stock');
      await db.execute('DROP TABLE IF EXISTS messages');
      await db.execute('DROP TABLE IF EXISTS cart_items');
      await db.execute('DROP TABLE IF EXISTS reviews');
      await db.execute('DROP TABLE IF EXISTS admin_logs');
      await _createDB(db, newVersion);
    }
  }

  // User methods
  Future<int> insertUser(kaawa.User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<kaawa.User?> getUser(String id) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return kaawa.User.fromMap(maps.first);
    }
    return null;
  }

  Future<kaawa.User?> getUserByPhone(String phoneNumber) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'phoneNumber = ?', whereArgs: [phoneNumber]);
    if (maps.isNotEmpty) {
      return kaawa.User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(kaawa.User user) async {
    final db = await instance.database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<List<kaawa.User>> getAdmins() async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'userType = ?', whereArgs: ['admin']);
    return maps.map((map) => kaawa.User.fromMap(map)).toList();
  }

  // Coffee Stock methods
  Future<int> insertCoffeeStock(CoffeeStock stock) async {
    final db = await instance.database;
    final map = stock.toMap();
    map['is_sold'] = stock.isSold ? 1 : 0;
    return await db.insert('coffee_stock', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CoffeeStock>> getAllCoffeeStock() async {
    final db = await instance.database;
    final maps = await db.query('coffee_stock');
    return maps.map((map) => CoffeeStock.fromMap(map)).toList();
  }

  Future<List<CoffeeStock>> getFarmerCoffeeStock(String farmerId) async {
    final db = await instance.database;
    final maps = await db.query('coffee_stock', where: 'farmer_id = ?', whereArgs: [farmerId]);
    return maps.map((map) => CoffeeStock.fromMap(map)).toList();
  }

  Future<int> updateCoffeeStock(CoffeeStock stock) async {
    final db = await instance.database;
    final map = stock.toMap();
    map['is_sold'] = stock.isSold ? 1 : 0;
    return await db.update('coffee_stock', map, where: 'id = ?', whereArgs: [stock.id]);
  }

  Future<int> deleteCoffeeStock(String id) async {
    final db = await instance.database;
    return await db.delete('coffee_stock', where: 'id = ?', whereArgs: [id]);
  }

  // Message methods
  Future<int> insertMessage(Message message) async {
    final db = await instance.database;
    final map = message.toMap();
    map['is_read'] = message.isRead ? 1 : 0;
    map['is_purchase_request'] = message.isPurchaseRequest ? 1 : 0;
    return await db.insert('messages', map);
  }

  Future<List<Message>> getMessages(String userId1, String userId2) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT DISTINCT 
        CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END as otherUserId
      FROM messages
      WHERE sender_id = ? OR receiver_id = ?
    ''', [userId, userId, userId]);
  }

  // Cart methods
  Future<int> insertCartItem(CartItem item) async {
    final db = await instance.database;
    return await db.insert('cart_items', {
      'id': item.id,
      'buyerId': item.buyerId,
      'coffeeStockId': item.stock.id,
      'quantity': item.quantityKg,
      'timestamp': item.addedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CartItem>> getCartItems(String buyerId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        c.id as cart_id, c.quantity as cart_quantity, c.timestamp as cart_timestamp,
        s.*, 
        u.id as user_id, u.name as user_name, u.phoneNumber as user_phoneNumber, 
        u.password as user_password, u.userType as user_userType, u.location as user_location,
        u.profilePicture as user_profilePicture, u.mustChangePassword as user_mustChangePassword,
        u.suspendedUntil as user_suspendedUntil, u.suspensionReason as user_suspensionReason
      FROM cart_items c
      JOIN coffee_stock s ON c.coffeeStockId = s.id
      JOIN users u ON s.farmer_id = u.id
      WHERE c.buyerId = ?
    ''', [buyerId]);

    return maps.map((map) {
      final stock = CoffeeStock.fromMap(map);
      final farmer = kaawa.User(
        id: map['user_id'],
        fullName: map['user_name'],
        phoneNumber: map['user_phoneNumber'],
        district: map['user_location'] ?? '',
        password: map['user_password'],
        userType: kaawa.UserType.values.firstWhere(
          (e) => e.toString().split('.').last == map['user_userType'],
          orElse: () => kaawa.UserType.farmer,
        ),
        profilePicturePath: map['user_profilePicture'],
        mustChangePassword: map['user_mustChangePassword'] == 1,
        suspendedUntil: parseDateSafe(map['user_suspendedUntil']),
        suspensionReason: map['user_suspensionReason'],
      );

      return CartItem(
        id: map['cart_id'],
        buyerId: buyerId,
        stock: stock,
        farmer: farmer,
        quantityKg: (map['cart_quantity'] as num).toDouble(),
        addedAt: parseDateSafe(map['cart_timestamp']) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<int> deleteCartItem(String id) async {
    final db = await instance.database;
    return await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearCart(String buyerId) async {
    final db = await instance.database;
    return await db.delete('cart_items', where: 'buyerId = ?', whereArgs: [buyerId]);
  }

  // Review methods
  Future<int> insertReview(Review review) async {
    final db = await instance.database;
    return await db.insert('reviews', review.toMap());
  }

  Future<List<Review>> getReviewsForUser(String userId) async {
    final db = await instance.database;
    final maps = await db.query('reviews', where: 'reviewedUserId = ?', whereArgs: [userId]);
    return maps.map((map) => Review.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getReviewsWithReviewers(String userId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        r.id as review_id, r.reviewerId as review_reviewerId, r.reviewedUserId as review_reviewedUserId,
        r.rating as review_rating, r.comment as review_comment, r.timestamp as review_timestamp,
        u.id as user_id, u.name as user_name, u.phoneNumber as user_phoneNumber, 
        u.password as user_password, u.userType as user_userType, u.location as user_location,
        u.profilePicture as user_profilePicture, u.mustChangePassword as user_mustChangePassword,
        u.suspendedUntil as user_suspendedUntil, u.suspensionReason as user_suspensionReason
      FROM reviews r
      JOIN users u ON r.reviewerId = u.id
      WHERE r.reviewedUserId = ?
      ORDER BY r.timestamp DESC
    ''', [userId]);

    return maps.map((map) {
      final reviewer = kaawa.User(
        id: map['user_id'],
        fullName: map['user_name'],
        phoneNumber: map['user_phoneNumber'],
        district: map['user_location'] ?? '',
        password: map['user_password'],
        userType: kaawa.UserType.values.firstWhere(
          (e) => e.toString().split('.').last == map['user_userType'],
          orElse: () => kaawa.UserType.buyer,
        ),
        profilePicturePath: map['user_profilePicture'],
        mustChangePassword: map['user_mustChangePassword'] == 1,
        suspendedUntil: parseDateSafe(map['user_suspendedUntil']),
        suspensionReason: map['user_suspensionReason'],
      );

      return {
        'review': {
          'id': map['review_id'],
          'reviewerId': map['review_reviewerId'],
          'reviewedUserId': map['review_reviewedUserId'],
          'rating': map['review_rating'],
          'reviewText': map['review_comment'],
          'timestamp': map['review_timestamp'],
        },
        'reviewer': reviewer,
      };
    }).toList();
  }

  // Admin methods
  Future<List<kaawa.User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    return maps.map((map) => kaawa.User.fromMap(map)).toList();
  }

  Future<int> logAdminAction(String adminId, String action, String targetType, String targetId, {String? details}) async {
    final db = await instance.database;
    return await db.insert('admin_logs', {
      'adminId': adminId,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'timestamp': DateTime.now().toIso8601String(),
      'details': details,
    });
  }

  // Purchase Request methods
  Future<int> insertPurchaseRequest(String buyerId, String farmerId, String coffeeStockId, double quantity, double totalPrice) async {
    final db = await instance.database;
    final message = Message(
      senderId: buyerId,
      receiverId: farmerId,
      text: 'Purchase Request: $quantity kg of coffee',
      timestamp: DateTime.now(),
      isPurchaseRequest: true,
      coffeeStockId: coffeeStockId,
    );
    final map = message.toMap();
    map['is_purchase_request'] = 1;
    return await db.insert('messages', map);
  }

  Future<int> respondToPurchaseRequest(String farmerId, String buyerId, String responseText) async {
    final db = await instance.database;
    final responseMessage = Message(
      senderId: farmerId,
      receiverId: buyerId,
      text: responseText,
      timestamp: DateTime.now(),
      isPurchaseRequest: false,
    );
    return await db.insert('messages', responseMessage.toMap());
  }

  Future<List<Message>> getPurchaseRequestResponses(String buyerId, String farmerId, DateTime purchaseRequestTime) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'sender_id = ? AND receiver_id = ? AND created_at > ? AND is_purchase_request = 0',
      whereArgs: [farmerId, buyerId, purchaseRequestTime.toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<bool> hasRespondedToPurchaseRequest(String buyerId, String farmerId, DateTime purchaseRequestTime) async {
    final responses = await getPurchaseRequestResponses(buyerId, farmerId, purchaseRequestTime);
    return responses.isNotEmpty;
  }

  Future<List<Message>> getUnreadPurchaseRequestsForFarmer(String farmerId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'receiver_id = ? AND is_purchase_request = 1 AND is_read = 0',
      whereArgs: [farmerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getPurchaseRequestsForFarmer(String farmerId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'receiver_id = ? AND is_purchase_request = 1',
      whereArgs: [farmerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> markPurchaseRequestAsRead(int messageId) async {
    final db = await instance.database;
    await db.update('messages', {'is_read': 1}, where: 'id = ? AND is_purchase_request = 1', whereArgs: [messageId]);
  }

  Future<List<Message>> getBuyerFarmerConversation(String buyerId, String farmerId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [buyerId, farmerId, farmerId, buyerId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getPurchaseRequestsBetween(String buyerId, String farmerId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'sender_id = ? AND receiver_id = ? AND is_purchase_request = 1',
      whereArgs: [buyerId, farmerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<int> getUnrespondedPurchaseRequestCount(String farmerId) async {
    final db = await instance.database;
    final purchaseRequests = await db.rawQuery('''
      SELECT DISTINCT sender_id, MIN(id) as first_message_id
      FROM messages
      WHERE receiver_id = ? AND is_purchase_request = 1
      GROUP BY sender_id
    ''', [farmerId]);

    int unrespondedCount = 0;
    for (final pr in purchaseRequests) {
      final buyerId = pr['sender_id'] as String;
      final prTimestamp = await db.rawQuery('''
        SELECT created_at FROM messages WHERE id = ?
      ''', [pr['first_message_id']]);

      if (prTimestamp.isNotEmpty) {
        final prTime = prTimestamp.first['created_at'] as String;
        final responses = await db.query(
          'messages',
          where: 'sender_id = ? AND receiver_id = ? AND created_at > ? AND is_purchase_request = 0',
          whereArgs: [farmerId, buyerId, prTime],
        );
        if (responses.isEmpty) {
          unrespondedCount++;
        }
      }
    }
    return unrespondedCount;
  }
}
