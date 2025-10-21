import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'familyapp.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

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
