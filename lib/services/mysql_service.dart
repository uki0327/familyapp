import 'package:mysql1/mysql1.dart';

import 'mysql_models.dart';

class MysqlService {
  static const String _accountsTable = 'family_accounts';
  static const List<String> _requiredAccountColumns = <String>[
    'num',
    'id',
    'password',
    'relation',
    'bio',
    'email',
    'phone',
    'address',
    'social',
  ];

  static const List<String> recommendedAccountColumns = <String>[
    'birthdate',
    'profile_image_url',
    'emergency_contact',
    'notes',
  ];

  Future<MySqlConnection> _openConnection(MysqlConnectionConfig config) {
    final settings = ConnectionSettings(
      host: config.host,
      port: config.port,
      db: config.database,
      user: config.username,
      password: config.password,
      timeout: const Duration(seconds: 10),
    );
    return MySqlConnection.connect(settings);
  }

  Future<MysqlConnectionResult> testConnection(MysqlConnectionConfig config) async {
    MySqlConnection? connection;
    try {
      connection = await _openConnection(config);
      final schemaCheck = await _verifySchema(connection);
      if (!schemaCheck.success) {
        return schemaCheck;
      }

      final accounts = await fetchAccountIds(connection);
      return MysqlConnectionResult(
        success: true,
        message: '데이터베이스 연결 및 스키마 확인이 완료되었습니다.',
        accounts: accounts,
      );
    } on MySqlException catch (error) {
      return MysqlConnectionResult(
        success: false,
        message: 'MySQL 연결 실패: ${error.message}',
      );
    } catch (error) {
      return MysqlConnectionResult(
        success: false,
        message: 'MySQL 연결 중 알 수 없는 오류가 발생했습니다: $error',
      );
    } finally {
      await connection?.close();
    }
  }

  Future<MysqlConnectionResult> _verifySchema(MySqlConnection connection) async {
    final tableResult = await connection.query(
      "SHOW TABLES LIKE '$_accountsTable'",
    );

    if (tableResult.isEmpty) {
      return const MysqlConnectionResult(
        success: false,
        message: '필수 테이블 family_accounts 가 존재하지 않습니다.',
      );
    }

    final columnResult = await connection.query('SHOW COLUMNS FROM $_accountsTable');
    final columns = columnResult.map((row) => row[0].toString()).toSet();

    final missingColumns = _requiredAccountColumns
        .where((column) => !columns.contains(column))
        .toList(growable: false);

    if (missingColumns.isNotEmpty) {
      return MysqlConnectionResult(
        success: false,
        message: '필수 컬럼이 누락되었습니다: ${missingColumns.join(', ')}',
        missingColumns: missingColumns,
      );
    }

    return const MysqlConnectionResult(
      success: true,
      message: '스키마 확인 완료',
    );
  }

  Future<List<String>> fetchAccountIds(MySqlConnection connection) async {
    final result = await connection.query(
      'SELECT id FROM $_accountsTable ORDER BY id ASC',
    );
    return result.map((row) => row[0].toString()).toList(growable: false);
  }

  Future<List<String>> loadAccounts(MysqlConnectionConfig config) async {
    MySqlConnection? connection;
    try {
      connection = await _openConnection(config);
      return await fetchAccountIds(connection);
    } finally {
      await connection?.close();
    }
  }

  Future<MysqlOperationResult> createAccount(
    MysqlConnectionConfig config, {
    required Map<String, String> payload,
  }) async {
    MySqlConnection? connection;
    try {
      connection = await _openConnection(config);
      final countResult = await connection.query(
        'SELECT COUNT(*) AS total FROM $_accountsTable',
      );
      final rawCount = countResult.first['total'];
      final count = rawCount is int ? rawCount : (rawCount as num).toInt();
      if (count > 0) {
        return const MysqlOperationResult(
          success: false,
          message: '이미 등록된 계정이 존재하므로 추가 등록이 불가능합니다.',
        );
      }

      final columns = <String>[];
      final parameters = <String>[];
      final values = <dynamic>[];
      for (final entry in payload.entries) {
        columns.add(entry.key);
        parameters.add('?');
        values.add(entry.value);
      }

      await connection.query(
        'INSERT INTO $_accountsTable (${columns.join(', ')}) VALUES (${parameters.join(', ')})',
        values,
      );

      return const MysqlOperationResult(
        success: true,
        message: '계정이 성공적으로 생성되었습니다.',
      );
    } on MySqlException catch (error) {
      return MysqlOperationResult(
        success: false,
        message: '계정 생성 중 오류가 발생했습니다: ${error.message}',
      );
    } catch (error) {
      return MysqlOperationResult(
        success: false,
        message: '계정 생성 중 알 수 없는 오류가 발생했습니다: $error',
      );
    } finally {
      await connection?.close();
    }
  }
}
