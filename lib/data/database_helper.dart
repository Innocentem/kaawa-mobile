
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/message_data.dart';
import 'package:kaawa_mobile/data/review_data.dart';

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
    return await openDatabase(path, version: 9, onCreate: _createDb, onUpgrade: _onUpgrade);
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
        fcmToken TEXT,
        village TEXT,
        coffeeType TEXT,
        quantity REAL,
        pricePerKg REAL,
        coffeePicturePath TEXT,
        coffeeTypeSought TEXT
      )
    ''');
    await _createMessagesTable(db);
    await _createReviewsTable(db);
    await _createFavoritesTable(db);
  }

  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL
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


  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN profilePicturePath TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN coffeePicturePath TEXT');
    }
    if (oldVersion < 3) {
      await _createMessagesTable(db);
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE users ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE users ADD COLUMN longitude REAL');
    }
    if (oldVersion < 5) {
      await _createReviewsTable(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE users ADD COLUMN quantity REAL');
      await db.execute('ALTER TABLE users ADD COLUMN pricePerKg REAL');
    }
    if (oldVersion < 8) {
      await _createFavoritesTable(db);
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE users ADD COLUMN fcmToken TEXT');
    }
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

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
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
}
