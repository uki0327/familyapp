import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _initialized = false;
  static const int _databaseVersion = 1;
  static const String _databaseName = 'familyapp.db';

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Safely check if running on desktop platform
  static bool _isDesktopPlatform() {
    try {
      // Try to check platform, but catch any unsupported operation errors
      return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    } catch (e) {
      print('[DatabaseHelper] Platform check failed: $e');
      // If platform check fails, assume desktop and use FFI
      // This is safe because mobile platforms won't fail the check
      return true;
    }
  }

  /// Get platform name for logging
  static String _getPlatformName() {
    try {
      if (Platform.isLinux) return 'Linux';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      return 'Unknown';
    } catch (e) {
      print('[DatabaseHelper] Platform name check failed: $e');
      return 'Desktop (fallback)';
    }
  }

  /// Initialize database factory for desktop platforms
  static void initialize() {
    if (_initialized) {
      print('[DatabaseHelper] Already initialized, skipping');
      return;
    }

    print('[DatabaseHelper] Initializing database factory...');

    try {
      final platformName = _getPlatformName();
      print('[DatabaseHelper] Platform detected: $platformName');

      // Initialize sqflite_common_ffi for desktop platforms
      if (_isDesktopPlatform()) {
        print('[DatabaseHelper] Desktop platform - initializing sqflite_common_ffi');

        // Initialize FFI
        sqfliteFfiInit();

        // Change the default factory to use FFI
        databaseFactory = databaseFactoryFfi;

        print('[DatabaseHelper] sqflite_common_ffi initialized successfully');
      } else {
        print('[DatabaseHelper] Mobile platform - using default sqflite');
      }

      _initialized = true;
      print('[DatabaseHelper] Initialization complete');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] Initialization error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      // Don't rethrow - we'll try to continue and fail gracefully later if needed
    }
  }

  /// Reset database instance (useful for retry scenarios)
  static void resetDatabase() {
    print('[DatabaseHelper] Resetting database instance');
    _database?.close();
    _database = null;
  }

  /// Get database path based on platform
  Future<String> _getDatabasePath() async {
    try {
      if (_isDesktopPlatform()) {
        // For desktop platforms, use application documents directory
        final directory = await getApplicationDocumentsDirectory();
        final dbDirectory = Directory(join(directory.path, 'familyapp'));

        // Create directory if it doesn't exist
        if (!await dbDirectory.exists()) {
          await dbDirectory.create(recursive: true);
          print('[DatabaseHelper] Created database directory: ${dbDirectory.path}');
        }

        final path = join(dbDirectory.path, _databaseName);
        print('[DatabaseHelper] Database path: $path');
        return path;
      } else {
        // For mobile platforms, use default databases path
        final databasesPath = await getDatabasesPath();
        final path = join(databasesPath, _databaseName);
        print('[DatabaseHelper] Database path: $path');
        return path;
      }
    } catch (e, stackTrace) {
      print('[DatabaseHelper] Error getting database path: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete database and all related files
  Future<void> _deleteDatabaseFiles(String path) async {
    try {
      print('[DatabaseHelper] Deleting database files at: $path');

      final mainFile = File(path);
      final shmFile = File('$path-shm');
      final walFile = File('$path-wal');
      final journalFile = File('$path-journal');

      if (await mainFile.exists()) {
        await mainFile.delete();
        print('[DatabaseHelper] Deleted main database file');
      }

      if (await shmFile.exists()) {
        await shmFile.delete();
        print('[DatabaseHelper] Deleted .db-shm file');
      }

      if (await walFile.exists()) {
        await walFile.delete();
        print('[DatabaseHelper] Deleted .db-wal file');
      }

      if (await journalFile.exists()) {
        await journalFile.delete();
        print('[DatabaseHelper] Deleted .db-journal file');
      }

      print('[DatabaseHelper] All database files deleted successfully');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] Error deleting database files: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      // Don't rethrow - we'll continue with database creation
    }
  }

  Future<Database> get database async {
    // Ensure database factory is initialized before accessing database
    initialize();

    if (_database != null) {
      print('[DatabaseHelper] Returning existing database instance');
      return _database!;
    }

    print('[DatabaseHelper] Creating new database instance');
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    print('[DatabaseHelper] === Starting database initialization ===');

    try {
      final path = await _getDatabasePath();
      print('[DatabaseHelper] Opening database at: $path');

      // Try to open the database
      final db = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('[DatabaseHelper] Database opened successfully');
        },
      );

      // Verify database integrity
      await _verifyDatabaseIntegrity(db);

      print('[DatabaseHelper] === Database initialization successful ===');
      return db;
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Database initialization failed !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      print('[DatabaseHelper] Attempting to recover by deleting and recreating database...');

      try {
        final path = await _getDatabasePath();

        // Delete all database files
        await _deleteDatabaseFiles(path);

        // Wait a bit to ensure files are deleted
        await Future.delayed(const Duration(milliseconds: 100));

        // Retry opening database (will trigger onCreate)
        print('[DatabaseHelper] Recreating database...');
        final db = await openDatabase(
          path,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            print('[DatabaseHelper] Database recreated and opened successfully');
          },
        );

        // Verify the newly created database
        await _verifyDatabaseIntegrity(db);

        print('[DatabaseHelper] === Database recovery successful ===');
        return db;
      } catch (retryError, retryStackTrace) {
        print('[DatabaseHelper] !!! Database recovery failed !!!');
        print('[DatabaseHelper] Recovery error: $retryError');
        print('[DatabaseHelper] Stack trace: $retryStackTrace');
        rethrow;
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('[DatabaseHelper] === Creating database schema (version $version) ===');

    try {
      // Create settings table
      print('[DatabaseHelper] Creating settings table...');
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      print('[DatabaseHelper] Settings table created');

      // Create translation history table
      print('[DatabaseHelper] Creating translation_history table...');
      await db.execute('''
        CREATE TABLE translation_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_text TEXT NOT NULL,
          translated_text TEXT NOT NULL,
          source_language TEXT NOT NULL,
          target_language TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
      print('[DatabaseHelper] Translation_history table created');

      print('[DatabaseHelper] === Schema creation complete ===');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Schema creation failed !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[DatabaseHelper] === Upgrading database: v$oldVersion -> v$newVersion ===');

    try {
      // Handle schema upgrades here
      // Example:
      // if (oldVersion < 2) {
      //   await db.execute('ALTER TABLE settings ADD COLUMN new_field TEXT');
      // }
      // if (oldVersion < 3) {
      //   await db.execute('CREATE TABLE new_table (...)');
      // }

      print('[DatabaseHelper] === Database upgrade complete ===');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Database upgrade failed !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _verifyDatabaseIntegrity(Database db) async {
    print('[DatabaseHelper] Verifying database integrity...');

    try {
      // Run SQLite integrity check
      final integrityResult = await db.rawQuery('PRAGMA integrity_check');
      print('[DatabaseHelper] Integrity check result: $integrityResult');

      // Check if required tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('settings', 'translation_history')"
      );

      print('[DatabaseHelper] Found ${tables.length} required tables');

      if (tables.length < 2) {
        final foundTables = tables.map((t) => t['name']).toList();
        throw Exception('Missing required tables. Found: $foundTables, Expected: [settings, translation_history]');
      }

      // Verify each table has correct structure
      for (final tableInfo in tables) {
        final tableName = tableInfo['name'] as String;
        final columns = await db.rawQuery('PRAGMA table_info($tableName)');
        print('[DatabaseHelper] Table "$tableName" has ${columns.length} columns');
      }

      print('[DatabaseHelper] Database integrity verification passed');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Database integrity verification failed !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Settings methods
  Future<void> saveSetting(String key, String value) async {
    try {
      print('[DatabaseHelper] Saving setting - key: $key, value length: ${value.length}');
      final db = await database;

      final result = await db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('[DatabaseHelper] Setting saved - result: $result');

      // Verify save
      final verification = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (verification.isEmpty) {
        throw Exception('Setting verification failed - data not found after save');
      }

      print('[DatabaseHelper] Setting verified successfully');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Save setting error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getSetting(String key) async {
    try {
      print('[DatabaseHelper] Getting setting - key: $key');
      final db = await database;

      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isNotEmpty) {
        final value = result.first['value'] as String;
        print('[DatabaseHelper] Setting found - value length: ${value.length}');
        return value;
      }

      print('[DatabaseHelper] Setting not found - key: $key');
      return null;
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Get setting error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Translation History methods
  Future<void> saveTranslation({
    required String sourceText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      print('[DatabaseHelper] Saving translation to history');
      final db = await database;

      await db.insert('translation_history', {
        'source_text': sourceText,
        'translated_text': translatedText,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('[DatabaseHelper] Translation saved to history');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Save translation error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      // Don't rethrow - translation history is not critical
    }
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({int limit = 50}) async {
    try {
      print('[DatabaseHelper] Getting translation history (limit: $limit)');
      final db = await database;

      final result = await db.query(
        'translation_history',
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      print('[DatabaseHelper] Retrieved ${result.length} translation records');
      return result;
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Get translation history error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      return []; // Return empty list instead of throwing
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      print('[DatabaseHelper] Closing database');
      await _database!.close();
      _database = null;
      print('[DatabaseHelper] Database closed');
    }
  }
}
