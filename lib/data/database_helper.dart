
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
    return await openDatabase(path, version: 5, onCreate: _createDb, onUpgrade: _onUpgrade);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phoneNumber TEXT NOT NULL UNIQUE,
        district TEXT NOT NULL,
        userType TEXT NOT NULL,
        profilePicturePath TEXT,
        latitude REAL,
        longitude REAL,
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
}
