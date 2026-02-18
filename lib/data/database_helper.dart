import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/message_data.dart';
import 'package:kaawa_mobile/data/review_data.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/data/conversation_data.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kaawa_database.db');
    // bump DB version to 23: add password_resets table for admin-handled resets
    return await openDatabase(path, version: 23, onCreate: _createDb, onUpgrade: _onUpgrade);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phoneNumber TEXT NOT NULL UNIQUE,
        district TEXT NOT NULL,
        password TEXT NOT NULL,
        userType TEXT NOT NULL,
        profilePicturePath TEXT,
        latitude REAL,
        longitude REAL,
        village TEXT
        -- xp and badgesCount removed intentionally
      )
    ''');
    await _createMessagesTable(db);
    await _createReviewsTable(db);
    await _createFavoritesTable(db);
    await _createCoffeeStockTable(db);
    await _createInterestedBuyersTable(db);
    // password_resets table allows users to request admin help resetting passwords
    await db.execute('''
      CREATE TABLE password_resets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phoneNumber TEXT NOT NULL,
        requestedAt TEXT NOT NULL,
        handled INTEGER NOT NULL DEFAULT 0,
        handledAt TEXT,
        handledByAdmin TEXT
      )
    ''');
  }

  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        coffeeStockId INTEGER
      )
    ''');
  }

  Future<void> _createReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE reviews(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reviewerId INTEGER NOT NULL,
        reviewedUserId INTEGER NOT NULL,
        rating REAL NOT NULL,
        reviewText TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE favorites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        favoriteUserId INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCoffeeStockTable(Database db) async {
    await db.execute('''
      CREATE TABLE coffee_stock(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        farmerId INTEGER NOT NULL,
        coffeeType TEXT NOT NULL,
        quantity REAL NOT NULL,
        pricePerKg REAL NOT NULL,
        coffeePicturePath TEXT,
        description TEXT DEFAULT '',
        isSold INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createInterestedBuyersTable(Database db) async {
    await db.execute('''
      CREATE TABLE interested_buyers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        coffeeStockId INTEGER NOT NULL,
        buyerId INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        seenByFarmer INTEGER NOT NULL DEFAULT 0,
        UNIQUE(coffeeStockId, buyerId)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 13) {
      await db.execute('CREATE TABLE users_temp AS SELECT id, fullName, phoneNumber, district, password, userType, profilePicturePath, latitude, longitude, village FROM users');
      await db.execute('DROP TABLE users');
      await db.execute('ALTER TABLE users_temp RENAME TO users');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE coffee_stock ADD COLUMN coffeePicturePath TEXT');
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE coffee_stock ADD COLUMN isSold INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE messages ADD COLUMN isRead INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE messages ADD COLUMN coffeeStockId INTEGER');
    }
    if (oldVersion < 18) {
      await _createInterestedBuyersTable(db);
    }
    if (oldVersion < 19) {
      // add seenByFarmer flag to track whether farmer has viewed the interested buyers for a stock
      await db.execute('ALTER TABLE interested_buyers ADD COLUMN seenByFarmer INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 20) {
      // add description column to coffee_stock
      await db.execute("ALTER TABLE coffee_stock ADD COLUMN description TEXT DEFAULT ''");
    }
    // Migration to remove xp and badgesCount from users (safe migration)
    if (oldVersion < 22) {
      try {
        // Copy only the desired columns into a temp table, drop original, rename back
        await db.execute('CREATE TABLE users_temp AS SELECT id, fullName, phoneNumber, district, password, userType, profilePicturePath, latitude, longitude, village FROM users');
        await db.execute('DROP TABLE users');
        await db.execute('ALTER TABLE users_temp RENAME TO users');
      } catch (e) {
        // if anything goes wrong, ignore to preserve backward compatibility
      }
    }
    if (oldVersion < 23) {
      // create password_resets table introduced in version 23
      await db.execute('''
        CREATE TABLE IF NOT EXISTS password_resets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phoneNumber TEXT NOT NULL,
          requestedAt TEXT NOT NULL,
          handled INTEGER NOT NULL DEFAULT 0,
          handledAt TEXT,
          handledByAdmin TEXT
        )
      ''');
    }
  }

  /// Returns a polling stream of the user's activity summary.
  Stream<Map<String, dynamic>> getUserActivityStream(int userId, {Duration interval = const Duration(seconds: 2)}) {
    return Stream.periodic(interval).asyncMap((_) => getUserActivitySummary(userId)).asBroadcastStream();
  }

  /// Returns a combined, sorted activity log for the user.
  Future<List<Map<String, dynamic>>> getUserActivityLog(int userId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> items = [];

    // messages involving user
    final msgMaps = await db.query('messages', where: 'senderId = ? OR receiverId = ?', whereArgs: [userId, userId], orderBy: 'timestamp DESC');
    for (final m in msgMaps) {
      items.add({
        'type': 'message',
        'senderId': m['senderId'],
        'receiverId': m['receiverId'],
        'text': m['text'],
        'timestamp': m['timestamp'],
        'coffeeStockId': m['coffeeStockId'],
      });
    }

    // interests where user is buyer
    final interestBuyerMaps = await db.query('interested_buyers', where: 'buyerId = ?', whereArgs: [userId], orderBy: 'timestamp DESC');
    for (final ib in interestBuyerMaps) {
      items.add({
        'type': 'interest',
        'buyerId': ib['buyerId'],
        'coffeeStockId': ib['coffeeStockId'],
        'timestamp': ib['timestamp'],
      });
    }

    // interests where user is farmer (i.e., buyers interested in this farmer's stock)
    final interestFarmerMaps = await db.rawQuery('SELECT ib.* FROM interested_buyers ib INNER JOIN coffee_stock cs ON cs.id = ib.coffeeStockId WHERE cs.farmerId = ? ORDER BY ib.timestamp DESC', [userId]);
    for (final ib in interestFarmerMaps) {
      items.add({
        'type': 'interest_for_farmer',
        'buyerId': ib['buyerId'],
        'coffeeStockId': ib['coffeeStockId'],
        'timestamp': ib['timestamp'],
      });
    }

    // sort by timestamp desc when possible
    items.sort((a, b) {
      final ta = a['timestamp'] as String?;
      final tb = b['timestamp'] as String?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return DateTime.parse(tb).compareTo(DateTime.parse(ta));
    });

    return items;
  }

  Future<int> insertUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser(String phoneNumber) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'phoneNumber = ?',
      whereArgs: [phoneNumber],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<User?> getUserById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  /// Returns a summary of user activity: listingsCount (if farmer), interestsCount (as buyer),
  /// conversationsCount (distinct other users messaged) and earliest activity ISO timestamp (nullable).
  Future<Map<String, dynamic>> getUserActivitySummary(int userId) async {
    final db = await instance.database;

    // listingsCount for farmer
    final listingsResult = await db.rawQuery('SELECT COUNT(*) as c FROM coffee_stock WHERE farmerId = ?', [userId]);
    final listingsCount = Sqflite.firstIntValue(listingsResult) ?? 0;

    // interestsCount as buyer
    final interestsResult = await db.rawQuery('SELECT COUNT(*) as c FROM interested_buyers WHERE buyerId = ?', [userId]);
    final interestsCount = Sqflite.firstIntValue(interestsResult) ?? 0;

    // conversationsCount: distinct other user ids in messages
    final convResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT IIF(senderId = ?, receiverId, senderId)) as c
      FROM messages
      WHERE senderId = ? OR receiverId = ?
    ''', [userId, userId, userId]);
    final conversationsCount = Sqflite.firstIntValue(convResult) ?? 0;

    // earliest activity timestamp from messages and interested_buyers (if any)
    String? earliestIso;
    final msgResult = await db.rawQuery('SELECT MIN(timestamp) as m FROM messages WHERE senderId = ? OR receiverId = ?', [userId, userId]);
    final earliestMsg = msgResult.isNotEmpty ? msgResult.first['m'] as String? : null;
    final interestResult = await db.rawQuery('SELECT MIN(timestamp) as m FROM interested_buyers WHERE buyerId = ?', [userId]);
    final earliestInterest = interestResult.isNotEmpty ? interestResult.first['m'] as String? : null;

    if (earliestMsg != null && earliestInterest != null) {
      earliestIso = DateTime.parse(earliestMsg).isBefore(DateTime.parse(earliestInterest)) ? earliestMsg : earliestInterest;
    } else if (earliestMsg != null) {
      earliestIso = earliestMsg;
    } else if (earliestInterest != null) {
      earliestIso = earliestInterest;
    }

    return {
      'listingsCount': listingsCount,
      'interestsCount': interestsCount,
      'conversationsCount': conversationsCount,
      'earliestActivityIso': earliestIso,
    };
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> insertMessage(Message message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<Message>> getMessages(int userId1, int userId2) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> markMessagesAsRead(int receiverId, int senderId) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {'isRead': 1},
      where: 'receiverId = ? AND senderId = ?',
      whereArgs: [receiverId, senderId],
    );
  }

  Future<int> getUnreadMessageCount(int receiverId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE receiverId = ? AND isRead = 0',
      [receiverId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Conversation>> getConversations(int userId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        m.id,
        m.senderId,
        m.receiverId,
        m.text,
        m.timestamp,
        m.isRead,
        m.coffeeStockId
      FROM messages m
      INNER JOIN (
        SELECT
          IIF(senderId = ?, receiverId, senderId) as otherUserId,
          MAX(timestamp) as maxTimestamp
        FROM messages
        WHERE senderId = ? OR receiverId = ?
        GROUP BY otherUserId
      ) as last_message ON (IIF(m.senderId = ?, m.receiverId, m.senderId) = last_message.otherUserId AND m.timestamp = last_message.maxTimestamp)
      ORDER BY m.timestamp DESC
    ''', [userId, userId, userId, userId]);

    final conversations = <Conversation>[];
    for (final map in maps) {
      final lastMessage = Message.fromMap(map);
      final otherUserId = lastMessage.senderId == userId ? lastMessage.receiverId : lastMessage.senderId;
      final otherUser = await getUserById(otherUserId);
      CoffeeStock? coffeeStock;
      if (lastMessage.coffeeStockId != null) {
        coffeeStock = await getCoffeeStockById(lastMessage.coffeeStockId!);
      }
      conversations.add(Conversation(
        otherUser: otherUser!,
        lastMessage: lastMessage,
        coffeeStock: coffeeStock,
      ));
    }
    return conversations;
  }

  Future<int> insertReview(Review review) async {
    final db = await instance.database;
    return await db.insert('reviews', review.toMap());
  }

  Future<List<Review>> getReviews(int reviewedUserId) async {
    final db = await instance.database;
    final maps = await db.query(
      'reviews',
      where: 'reviewedUserId = ?',
      whereArgs: [reviewedUserId],
    );
    return maps.map((map) => Review.fromMap(map)).toList();
  }

  Future<void> addFavorite(int userId, int favoriteUserId) async {
    final db = await instance.database;
    await db.insert('favorites', {'userId': userId, 'favoriteUserId': favoriteUserId});
  }

  Future<void> removeFavorite(int userId, int favoriteUserId) async {
    final db = await instance.database;
    await db.delete('favorites', where: 'userId = ? AND favoriteUserId = ?', whereArgs: [userId, favoriteUserId]);
  }

  Future<List<User>> getFavorites(int userId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('favorites', where: 'userId = ?', whereArgs: [userId]);
    if (maps.isEmpty) {
      return [];
    }

    List<int> favoriteIds = maps.map((map) => map['favoriteUserId'] as int).toList();
    final userMaps = await db.query('users', where: 'id IN (?)', whereArgs: [favoriteIds]);

    return userMaps.map((map) => User.fromMap(map)).toList();
  }

  Future<bool> isFavorite(int userId, int favoriteUserId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('favorites', where: 'userId = ? AND favoriteUserId = ?', whereArgs: [userId, favoriteUserId]);
    return maps.isNotEmpty;
  }

  Future<int> insertCoffeeStock(CoffeeStock stock) async {
    final db = await instance.database;
    return await db.insert('coffee_stock', stock.toMap());
  }

  Future<int> updateCoffeeStock(CoffeeStock stock) async {
    final db = await instance.database;
    return await db.update(
      'coffee_stock',
      stock.toMap(),
      where: 'id = ?',
      whereArgs: [stock.id],
    );
  }

  Future<CoffeeStock?> getCoffeeStockById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'coffee_stock',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CoffeeStock.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<CoffeeStock>> getCoffeeStock(int farmerId) async {
    final db = await instance.database;
    final maps = await db.query('coffee_stock', where: 'farmerId = ?', whereArgs: [farmerId]);
    return maps.map((map) => CoffeeStock.fromMap(map)).toList();
  }

  Future<List<CoffeeStock>> getAllCoffeeStock() async {
    final db = await instance.database;
    final maps = await db.query('coffee_stock', where: 'isSold = 0');
    return maps.map((map) => CoffeeStock.fromMap(map)).toList();
  }

  /// Returns the total number of interested buyers across all active (isSold = 0) stocks for the given farmer.
  Future<int> getTotalInterestCountForFarmer(int farmerId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT COUNT(ib.id) FROM interested_buyers ib
      INNER JOIN coffee_stock cs ON cs.id = ib.coffeeStockId
      WHERE cs.farmerId = ? AND cs.isSold = 0 AND ib.seenByFarmer = 0
    ''', [farmerId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Interested buyers helpers
  Future<void> addInterest(int coffeeStockId, int buyerId) async {
    final db = await instance.database;
    await db.insert('interested_buyers', {
      'coffeeStockId': coffeeStockId,
      'buyerId': buyerId,
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeInterest(int coffeeStockId, int buyerId) async {
    final db = await instance.database;
    await db.delete('interested_buyers', where: 'coffeeStockId = ? AND buyerId = ?', whereArgs: [coffeeStockId, buyerId]);
  }

  Future<bool> isInterested(int coffeeStockId, int buyerId) async {
    final db = await instance.database;
    final maps = await db.query('interested_buyers', where: 'coffeeStockId = ? AND buyerId = ?', whereArgs: [coffeeStockId, buyerId]);
    return maps.isNotEmpty;
  }

  Future<int> getInterestCountForStock(int coffeeStockId) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM interested_buyers WHERE coffeeStockId = ?', [coffeeStockId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<User>> getInterestedBuyersForStock(int coffeeStockId) async {
    final db = await instance.database;
    final maps = await db.rawQuery('''
      SELECT u.* FROM users u
      INNER JOIN interested_buyers ib ON u.id = ib.buyerId
      WHERE ib.coffeeStockId = ?
    ''', [coffeeStockId]);
    return maps.map((map) => User.fromMap(map)).toList();
  }

  /// Marks all interests for a given stock as seen by the farmer.
  Future<void> markInterestsAsSeenForStock(int coffeeStockId) async {
    final db = await instance.database;
    await db.update('interested_buyers', {'seenByFarmer': 1}, where: 'coffeeStockId = ?', whereArgs: [coffeeStockId]);
  }

  /// Returns a list of coffeeStock IDs that the given buyer has expressed interest in.
  Future<List<int>> getInterestedStockIdsForBuyer(int buyerId) async {
    final db = await instance.database;
    final maps = await db.query('interested_buyers', columns: ['coffeeStockId'], where: 'buyerId = ?', whereArgs: [buyerId]);
    return maps.map((m) => m['coffeeStockId'] as int).toList();
  }

  /// Fetch reviews for a reviewed user together with reviewer user info using a single JOIN.
  /// Returns a list where each element is a Map with keys: 'review' (Review) and 'reviewer' (User?).
  Future<List<Map<String, dynamic>>> getReviewsWithReviewers(int reviewedUserId) async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT
        r.id as review_id,
        r.reviewerId as reviewerId,
        r.reviewedUserId as reviewedUserId,
        r.rating as rating,
        r.reviewText as reviewText,
        u.id as reviewer_id,
        u.fullName as reviewer_fullName,
        u.phoneNumber as reviewer_phoneNumber,
        u.district as reviewer_district,
        u.password as reviewer_password,
        u.userType as reviewer_userType,
        u.profilePicturePath as reviewer_profilePicturePath,
        u.latitude as reviewer_latitude,
        u.longitude as reviewer_longitude,
        u.village as reviewer_village
      FROM reviews r
      LEFT JOIN users u ON r.reviewerId = u.id
      WHERE r.reviewedUserId = ?
      ORDER BY r.id DESC
    ''', [reviewedUserId]);

    final List<Map<String, dynamic>> result = [];
    for (final row in rows) {
      final review = {
        'id': row['review_id'],
        'reviewerId': row['reviewerId'],
        'reviewedUserId': row['reviewedUserId'],
        'rating': row['rating'],
        'reviewText': row['reviewText'],
      };

      User? reviewer;
      if (row['reviewer_id'] != null) {
        reviewer = User(
          id: row['reviewer_id'] as int?,
          fullName: row['reviewer_fullName']?.toString() ?? '',
          phoneNumber: row['reviewer_phoneNumber']?.toString() ?? '',
          district: row['reviewer_district']?.toString() ?? '',
          password: row['reviewer_password']?.toString() ?? '',
          userType: (row['reviewer_userType'] != null && row['reviewer_userType'].toString().contains('farmer')) ? UserType.farmer : UserType.buyer,
          profilePicturePath: row['reviewer_profilePicturePath']?.toString(),
          latitude: row['reviewer_latitude'] is num ? (row['reviewer_latitude'] as num).toDouble() : null,
          longitude: row['reviewer_longitude'] is num ? (row['reviewer_longitude'] as num).toDouble() : null,
          village: row['reviewer_village']?.toString(),
        );
      }

      result.add({'review': review, 'reviewer': reviewer});
    }

    return result;
  }

  /// Password reset request helpers (admin-handled)
  Future<int> insertPasswordResetRequest(String phoneNumber) async {
    final db = await instance.database;
    return await db.insert('password_resets', {
      'phoneNumber': phoneNumber,
      'requestedAt': DateTime.now().toIso8601String(),
      'handled': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPasswordResetRequests() async {
    final db = await instance.database;
    final maps = await db.query('password_resets', where: 'handled = 0', orderBy: 'requestedAt DESC');
    return maps;
  }

  Future<void> markPasswordResetHandled(int id, {String? adminName}) async {
    final db = await instance.database;
    await db.update('password_resets', {
      'handled': 1,
      'handledAt': DateTime.now().toIso8601String(),
      'handledByAdmin': adminName ?? 'admin',
    }, where: 'id = ?', whereArgs: [id]);
  }

  /// Helper to let admin set a user's password by phone number. Returns true if a user was updated.
  Future<bool> adminSetUserPasswordByPhone(String phoneNumber, String newPasswordHash) async {
    final db = await instance.database;
    final res = await db.update('users', {'password': newPasswordHash}, where: 'phoneNumber = ?', whereArgs: [phoneNumber]);
    return res > 0;
  }
}
