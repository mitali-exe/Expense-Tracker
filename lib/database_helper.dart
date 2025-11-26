import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

enum TransactionType { income, expense }

class User {
  final int id;
  final String username;
  final String email;
  final String password;
  final String? profilePhoto;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.profilePhoto,
  });

  // Create User from Map (for login query)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'], // Hashed in DB
      profilePhoto: map['profile_photo'],
    );
  }

  // Map for registration (includes password)
  Map<String, dynamic> toRegistrationMap() {
    return {
      'username': username,
      'email': email,
      'password': _hashPassword(password), // Hash the password before storing
      'profile_photo': profilePhoto,
    };
  }

  // Helper method for hashing passwords
    static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}


class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final TransactionType type;
  final bool isSaving; // New field for savings

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    this.isSaving = false,
  });

  // Convert Transaction to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': type.toString().split('.').last,
      'is_saving': isSaving ? 1 : 0,
    };
  }

  // Create Transaction from Map
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'].toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'],
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      isSaving: map['is_saving'] == 1,
    );
  }
}

class Budget {
  final String category;
  final double allocated;
  final double spent; // Note: This is not stored in DB, calculated dynamically

  Budget({
    required this.category,
    required this.allocated,
    required this.spent,
  });

  // Convert Budget to Map for database (spent not stored)
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'allocated': allocated,
    };
  }

  // Create Budget from Map
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      category: map['category'],
      allocated: map['allocated'].toDouble(),
      spent: 0, // Will be calculated dynamically
    );
  }
}

class SavingsGoal {
  final String id;
  final String title;
  final double target;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.target,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target': target,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      title: map['title'],
      target: map['target'].toDouble(),
    );
  }
}

// Database Helper Class
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mymoney.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Incremented for savings_goals table and is_saving column
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        profile_photo TEXT
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        is_saving INTEGER DEFAULT 0,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        category TEXT PRIMARY KEY,
        allocated REAL NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Savings goals table
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target REAL NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table and update foreign keys if upgrading from v1
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL
        )
      ''');

      // Add user_id to existing tables (default to 1 for old data)
      await db.execute('ALTER TABLE transactions ADD COLUMN user_id INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE budgets ADD COLUMN user_id INTEGER DEFAULT 1');

      // Recreate tables with foreign keys if needed (simplified; in production, use more sophisticated migration)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          category TEXT PRIMARY KEY,
          allocated REAL NOT NULL,
          user_id INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add savings_goals table and is_saving column
      await db.execute('''
        CREATE TABLE savings_goals (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          target REAL NOT NULL,
          user_id INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
      await db.execute('ALTER TABLE transactions ADD COLUMN is_saving INTEGER DEFAULT 0');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE users ADD COLUMN profile_photo TEXT');
    }
  }

  // User methods
  Future<int> registerUser(User user) async {
    final db = await database;
    try {
      // Check if user already exists
      final existing = await db.query(
        'users',
        where: 'username = ? OR email = ?',
        whereArgs: [user.username, user.email],
      );
      if (existing.isNotEmpty) {
        return 0; // User exists
      }
      return await db.insert('users', user.toRegistrationMap()); // Password is now hashed
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<User?> loginUser(String email, String password) async {
    final db = await database;
    final hashedPassword = User._hashPassword(password); // Hash the input password
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword], // Compare with hashed password
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // New method for SharedPreferences auto-login
  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Transaction methods (updated to include user_id and is_saving)
  Future<void> insertTransaction(Transaction transaction, int userId) async {
    final db = await database;
    final map = transaction.toMap();
    map['user_id'] = userId;
    await db.insert('transactions', map);
  }

  Future<List<Transaction>> getAllTransactions(int userId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  // Add method to update profile photo
  Future<void> updateUserProfilePhoto(int userId, String? photoPath) async {
    final db = await database;
    await db.update(
      'users',
      {'profile_photo': photoPath},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Budget methods (updated to include user_id)
  Future<void> insertBudget(Budget budget, int userId) async {
    final db = await database;
    final map = budget.toMap();
    map['user_id'] = userId;
    await db.insert('budgets', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBudget(Budget budget, int userId) async {
    final db = await database;
    final map = budget.toMap();
    map['user_id'] = userId;
    await db.update(
      'budgets',
      map,
      where: 'category = ? AND user_id = ?',
      whereArgs: [budget.category, userId],
    );
  }

  // New: Delete Budget
  Future<void> deleteBudget(String category, int userId) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'category = ? AND user_id = ?',
      whereArgs: [category, userId],
    );
  }



  Future<void> updateTransaction(Transaction transaction, int userId) async {
    final db = await database;
    final map = transaction.toMap();
    map['user_id'] = userId;
    await db.update(
      'transactions',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [transaction.id, userId],
    );
  }

  Future<void> deleteTransaction(String id, int userId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<List<Budget>> getAllBudgets(int userId) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  // Savings goals methods
  Future<void> insertSavingsGoal(SavingsGoal goal, int userId) async {
    final db = await database;
    final map = goal.toMap();
    map['user_id'] = userId;
    await db.insert('savings_goals', map);
  }

  // New: Update Savings Goal
  Future<void> updateSavingsGoal(SavingsGoal goal, int userId) async {
    final db = await database;
    final map = goal.toMap();
    map['user_id'] = userId;
    await db.update(
      'savings_goals',
      map,
      where: 'id = ? AND user_id = ?',
      whereArgs: [goal.id, userId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // New: Delete Savings Goal
  Future<void> deleteSavingsGoal(String id, int userId) async {
    final db = await database;
    await db.delete(
      'savings_goals',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }



  Future<List<SavingsGoal>> getAllSavingsGoals(int userId) async {
    final db = await database;
    final maps = await db.query(
      'savings_goals',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => SavingsGoal.fromMap(maps[i]));
  }

  Future<double> getTotalSavings(int userId, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = 'user_id = ? AND is_saving = 1';
    List<dynamic> whereArgs = [userId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date BETWEEN ? AND ?';
      whereArgs.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE $whereClause',
      whereArgs,
    );
    return (result.first['total'] as double?) ?? 0.0;
  }

  // NEW: Get savings associated with a specific goal title
  Future<double> getTotalSavingsForGoal(int userId, String goalTitle) async {
    final db = await database;

    // Transactions are tagged with "Savings: [Goal Title]"
    final transactionTitlePattern = 'Savings: $goalTitle%';

    String whereClause = 'user_id = ? AND is_saving = 1 AND title LIKE ?';
    List<dynamic> whereArgs = [userId, transactionTitlePattern];

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE $whereClause',
      whereArgs,
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<void> deleteAllDataForUser(int userId) async {
    final db = await database;
    await db.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('budgets', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('savings_goals', where: 'user_id = ?', whereArgs: [userId]);
  }

  // In DatabaseHelper class
  Future<void> updateUserPassword(int userId, String hashedPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }


}