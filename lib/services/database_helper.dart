import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _initialized = false;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Initialize database factory for desktop platforms
  static void initialize() {
    if (_initialized) return;

    // Initialize sqflite_common_ffi for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory to use FFI
      databaseFactory = databaseFactoryFfi;
    }

    _initialized = true;
  }

  /// Reset database instance (useful for retry scenarios)
  static void resetDatabase() {
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'familyapp.db');

    try {
      // Try to open the database
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      // Verify database integrity
      await _verifyDatabaseIntegrity(db);

      print('[DatabaseHelper] 데이터베이스 초기화 성공: $path');
      return db;
    } catch (e) {
      print('[DatabaseHelper] 데이터베이스 열기 실패: $e');
      print('[DatabaseHelper] 데이터베이스 파일 삭제 후 재생성 시도');

      // Delete corrupted database file
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('[DatabaseHelper] 손상된 데이터베이스 파일 삭제 완료');
      }

      // Retry opening database (will trigger onCreate)
      try {
        final db = await openDatabase(
          path,
          version: 1,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );

        print('[DatabaseHelper] 데이터베이스 재생성 성공');
        return db;
      } catch (retryError) {
        print('[DatabaseHelper] 데이터베이스 재생성 실패: $retryError');
        rethrow;
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('[DatabaseHelper] 데이터베이스 테이블 생성 시작');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    print('[DatabaseHelper] settings 테이블 생성 완료');

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
    print('[DatabaseHelper] translation_history 테이블 생성 완료');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[DatabaseHelper] 데이터베이스 업그레이드: $oldVersion -> $newVersion');

    // Future schema changes can be handled here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE settings ADD COLUMN new_field TEXT');
    // }
  }

  Future<void> _verifyDatabaseIntegrity(Database db) async {
    try {
      // Check if required tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND (name='settings' OR name='translation_history')"
      );

      if (tables.length < 2) {
        throw Exception('필수 테이블이 존재하지 않습니다');
      }

      print('[DatabaseHelper] 데이터베이스 무결성 검증 완료');
    } catch (e) {
      print('[DatabaseHelper] 데이터베이스 무결성 검증 실패: $e');
      rethrow;
    }
  }

  // Settings 관련 메서드
  Future<void> saveSetting(String key, String value) async {
    try {
      print('[DatabaseHelper] saveSetting 시작 - key: $key, value length: ${value.length}');
      final db = await database;
      print('[DatabaseHelper] 데이터베이스 획득 성공');

      final result = await db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('[DatabaseHelper] 저장 완료 - result: $result');

      // 저장 검증
      final verification = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (verification.isNotEmpty) {
        print('[DatabaseHelper] 저장 검증 성공 - 저장된 값: ${verification.first['value']}');
      } else {
        print('[DatabaseHelper] 저장 검증 실패 - 데이터를 찾을 수 없음');
        throw Exception('저장 후 데이터 검증 실패');
      }
    } catch (e, stackTrace) {
      print('[DatabaseHelper] saveSetting 에러: $e');
      print('[DatabaseHelper] 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getSetting(String key) async {
    try {
      print('[DatabaseHelper] getSetting 시작 - key: $key');
      final db = await database;
      print('[DatabaseHelper] 데이터베이스 획득 성공');

      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isNotEmpty) {
        final value = result.first['value'] as String;
        print('[DatabaseHelper] 설정값 조회 성공 - value length: ${value.length}');
        return value;
      }

      print('[DatabaseHelper] 설정값 없음 - key: $key');
      return null;
    } catch (e, stackTrace) {
      print('[DatabaseHelper] getSetting 에러: $e');
      print('[DatabaseHelper] 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // Translation History 관련 메서드
  Future<void> saveTranslation({
    required String sourceText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final db = await database;
    await db.insert('translation_history', {
      'source_text': sourceText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'translation_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
}
