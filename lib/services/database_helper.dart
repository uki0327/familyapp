import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

import 'mysql_models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _initialized = false;
  static const int _databaseVersion = 2;
  static const String _databaseName = 'familyapp.db';
  static const String _webSettingsKey = 'familyapp_web_settings';
  static const String _webHistoryKey = 'familyapp_web_history';
  static const int _webHistoryMaxItems = 200;
  static const String _webMysqlConfigKey = 'familyapp_web_mysql_config';

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Safely check if running on desktop platform
  static bool _isDesktopPlatform() {
    try {
      if (kIsWeb) {
        return false;
      }
      // Try to check platform, but catch any unsupported operation errors
      return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    } catch (e) {
      print('[DatabaseHelper] Platform check failed: $e');
      // If platform check fails, fall back to non-desktop configuration
      return false;
    }
  }

  /// Get platform name for logging
  static String _getPlatformName() {
    try {
      if (kIsWeb) return 'Web';
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

  /// Safely get environment variable
  static String? _getEnv(String key) {
    try {
      if (kIsWeb) {
        return null;
      }
      return Platform.environment[key];
    } catch (e) {
      print('[DatabaseHelper] Environment access failed for $key: $e');
      return null;
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

      // Initialize sqflite factories based on the platform
      if (kIsWeb) {
        print('[DatabaseHelper] Web platform - configuring web storage');
        databaseFactory = databaseFactoryFfiWeb;
        print('[DatabaseHelper] Web storage configured');
      } else if (_isDesktopPlatform()) {
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
  static Future<void> resetDatabase() async {
    print('[DatabaseHelper] Resetting database instance');

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webSettingsKey);
      await prefs.remove(_webHistoryKey);
      print('[DatabaseHelper] Cleared web storage data');
      return;
    }

    await _database?.close();
    _database = null;
  }

  /// Get database path based on platform
  Future<String> _getDatabasePath() async {
    print('[DatabaseHelper] === Getting database path ===');

    if (kIsWeb) {
      print('[DatabaseHelper] Web platform - using browser storage path');
      return _databaseName;
    }

    // For desktop platforms, use environment-based paths directly
    // to avoid getDatabasesPath() which requires databaseFactory
    if (_isDesktopPlatform()) {
      print('[DatabaseHelper] Desktop platform - using environment-based path');
      return _getDesktopDatabasePath();
    }

    // For mobile platforms, use standard getDatabasesPath()
    try {
      print('[DatabaseHelper] Mobile platform - using getDatabasesPath()');
      final databasesPath = await getDatabasesPath();
      print('[DatabaseHelper] getDatabasesPath() returned: $databasesPath');

      final path = join(databasesPath, _databaseName);
      print('[DatabaseHelper] Database path: $path');
      return path;
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! getDatabasesPath() failed !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      // Fallback to in-memory
      print('[DatabaseHelper] Using in-memory database as fallback');
      return ':memory:';
    }
  }

  /// Get database path for desktop platforms using environment variables
  String _getDesktopDatabasePath() {
    print('[DatabaseHelper] Getting desktop database path...');

    // Strategy 1: Use standard application data directories
    try {
      if (Platform.isLinux) {
        // Linux: Try XDG_DATA_HOME or HOME/.local/share
        final xdgDataHome = _getEnv('XDG_DATA_HOME');
        if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
          final path = join(xdgDataHome, 'familyapp', _databaseName);
          print('[DatabaseHelper] Using XDG_DATA_HOME: $path');
          return path;
        }

        final home = _getEnv('HOME');
        if (home != null && home.isNotEmpty) {
          final path = join(home, '.local', 'share', 'familyapp', _databaseName);
          print('[DatabaseHelper] Using HOME/.local/share: $path');
          return path;
        }
      }

      if (Platform.isMacOS) {
        // macOS: Use HOME/Library/Application Support
        final home = _getEnv('HOME');
        if (home != null && home.isNotEmpty) {
          final path = join(home, 'Library', 'Application Support', 'familyapp', _databaseName);
          print('[DatabaseHelper] Using macOS Application Support: $path');
          return path;
        }
      }

      if (Platform.isWindows) {
        // Windows: Try APPDATA or LOCALAPPDATA
        final appData = _getEnv('LOCALAPPDATA') ?? _getEnv('APPDATA');
        if (appData != null && appData.isNotEmpty) {
          final path = join(appData, 'familyapp', _databaseName);
          print('[DatabaseHelper] Using Windows AppData: $path');
          return path;
        }

        final userProfile = _getEnv('USERPROFILE');
        if (userProfile != null && userProfile.isNotEmpty) {
          final path = join(userProfile, '.familyapp', _databaseName);
          print('[DatabaseHelper] Using Windows UserProfile: $path');
          return path;
        }
      }
    } catch (e) {
      print('[DatabaseHelper] Platform-specific path failed: $e');
    }

    // Strategy 2: Use temp directory
    try {
      String tempPath;
      if (Platform.isWindows) {
        final temp = _getEnv('TEMP') ?? _getEnv('TMP');
        tempPath = temp ?? join('C:', 'Temp');
      } else {
        tempPath = '/tmp';
      }

      final path = join(tempPath, 'familyapp', _databaseName);
      print('[DatabaseHelper] Using temp directory: $path');
      return path;
    } catch (e) {
      print('[DatabaseHelper] Temp directory path failed: $e');
    }

    // Strategy 3: Last resort - relative path
    final path = join('.familyapp_data', _databaseName);
    print('[DatabaseHelper] Using relative path (last resort): $path');
    return path;
  }

  /// Delete database and all related files
  Future<void> _deleteDatabaseFiles(String path) async {
    // Don't delete in-memory database
    if (kIsWeb || path == ':memory:') {
      print('[DatabaseHelper] Skipping deletion for in-memory or web database');
      return;
    }

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
    if (kIsWeb) {
      throw UnsupportedError('Direct SQLite access is not supported on web.');
    }

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

      // Ensure directory exists (except for in-memory database)
      if (!kIsWeb && path != ':memory:') {
        final dbFile = File(path);
        final dbDir = dbFile.parent;

        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
          print('[DatabaseHelper] Created directory: ${dbDir.path}');
        }
      }

      // Try to open the database
      final db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            print('[DatabaseHelper] Database opened successfully');
          },
        ),
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

        // Ensure directory exists (except for in-memory database)
        if (!kIsWeb && path != ':memory:') {
          final dbFile = File(path);
          final dbDir = dbFile.parent;

          if (!await dbDir.exists()) {
            await dbDir.create(recursive: true);
            print('[DatabaseHelper] Created directory for recovery: ${dbDir.path}');
          }
        }

        // Retry opening database (will trigger onCreate)
        print('[DatabaseHelper] Recreating database...');
        final db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: _databaseVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
            onOpen: (db) async {
              print('[DatabaseHelper] Database recreated and opened successfully');
            },
          ),
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

      // Create MySQL configuration table
      print('[DatabaseHelper] Creating mysql_configs table...');
      await db.execute('''
        CREATE TABLE mysql_configs (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          host TEXT NOT NULL,
          port INTEGER NOT NULL,
          database TEXT NOT NULL,
          username TEXT NOT NULL,
          password TEXT NOT NULL,
          schema_verified INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER
        )
      ''');
      print('[DatabaseHelper] mysql_configs table created');

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
      if (oldVersion < 2) {
        print('[DatabaseHelper] Adding mysql_configs table for v2');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS mysql_configs (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            host TEXT NOT NULL,
            port INTEGER NOT NULL,
            database TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            schema_verified INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER
          )
        ''');
        print('[DatabaseHelper] mysql_configs table added');
      }

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
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('settings', 'translation_history', 'mysql_configs')",
      );

      print('[DatabaseHelper] Found ${tables.length} required tables');

      if (tables.length < 3) {
        final foundTables = tables.map((t) => t['name']).toList();
        throw Exception(
          'Missing required tables. Found: $foundTables, Expected: [settings, translation_history, mysql_configs]',
        );
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

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webSettingsKey);
        final Map<String, dynamic> settings = raw != null
            ? Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>)
            : <String, dynamic>{};
        settings[key] = value;
        await prefs.setString(_webSettingsKey, jsonEncode(settings));
        print('[DatabaseHelper] Setting saved to web storage');
        return;
      }

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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webSettingsKey);
        if (raw == null) {
          print('[DatabaseHelper] Web storage empty');
          return null;
        }
        final settings =
            Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
        final value = settings[key] as String?;
        if (value != null) {
          print('[DatabaseHelper] Setting found in web storage - value length: ${value.length}');
        } else {
          print('[DatabaseHelper] Setting not found in web storage - key: $key');
        }
        return value;
      }

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

  // MySQL configuration methods
  Future<void> saveMysqlConfig(MysqlConnectionConfig config) async {
    final data = config.copyWith(updatedAt: DateTime.now()).toMap()
      ..['id'] = 1;

    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_webMysqlConfigKey, jsonEncode(data));
        print('[DatabaseHelper] MySQL config saved to web storage');
        return;
      }

      final db = await database;
      await db.insert(
        'mysql_configs',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('[DatabaseHelper] MySQL config saved to sqlite');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Save MySQL config error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<MysqlConnectionConfig?> getMysqlConfig() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webMysqlConfigKey);
        if (raw == null) {
          return null;
        }
        final map = Map<String, Object?>.from(jsonDecode(raw) as Map<String, dynamic>);
        // jsonDecode returns num for integers, ensure cast
        map['port'] = (map['port'] as num).toInt();
        if (map['updated_at'] != null) {
          map['updated_at'] = (map['updated_at'] as num).toInt();
        }
        return MysqlConnectionConfig.fromMap(map);
      }

      final db = await database;
      final result = await db.query('mysql_configs', limit: 1);
      if (result.isEmpty) {
        return null;
      }

      final row = Map<String, Object?>.from(result.first);
      return MysqlConnectionConfig.fromMap(row);
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Get MySQL config error !!!');
      print('[DatabaseHelper] Error: $e');
      print('[DatabaseHelper] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> clearMysqlConfig() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_webMysqlConfigKey);
        print('[DatabaseHelper] MySQL config cleared from web storage');
        return;
      }

      final db = await database;
      await db.delete('mysql_configs');
      print('[DatabaseHelper] MySQL config cleared from sqlite');
    } catch (e, stackTrace) {
      print('[DatabaseHelper] !!! Clear MySQL config error !!!');
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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webHistoryKey);
        final List<Map<String, dynamic>> history = raw != null
            ? (jsonDecode(raw) as List)
                .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
                .toList()
            : <Map<String, dynamic>>[];
        history.insert(0, {
          'source_text': sourceText,
          'translated_text': translatedText,
          'source_language': sourceLanguage,
          'target_language': targetLanguage,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        if (history.length > _webHistoryMaxItems) {
          history.removeRange(_webHistoryMaxItems, history.length);
        }
        await prefs.setString(_webHistoryKey, jsonEncode(history));
        print('[DatabaseHelper] Translation saved to web history (total: ${history.length})');
        return;
      }

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

  Future<List<Map<String, dynamic>>> getTranslationHistory({int limit = 50, int offset = 0}) async {
    try {
      print('[DatabaseHelper] Getting translation history (limit: $limit, offset: $offset)');
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webHistoryKey);
        if (raw == null) {
          print('[DatabaseHelper] No translation history in web storage');
          return [];
        }
        final List<Map<String, dynamic>> history = (jsonDecode(raw) as List)
            .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
            .toList();
        final result = history
            .skip(offset)
            .take(limit)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        print('[DatabaseHelper] Retrieved ${result.length} translation records from web storage');
        return result;
      }

      final db = await database;

      final result = await db.query(
        'translation_history',
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
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
    if (kIsWeb) {
      print('[DatabaseHelper] Web storage in use - no SQLite connection to close');
      return;
    }

    if (_database != null) {
      print('[DatabaseHelper] Closing database');
      await _database!.close();
      _database = null;
      print('[DatabaseHelper] Database closed');
    }
  }
}
