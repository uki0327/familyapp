import 'package:flutter/foundation.dart';

@immutable
class MysqlConnectionConfig {
  const MysqlConnectionConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.schemaVerified = false,
    this.updatedAt,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool schemaVerified;
  final DateTime? updatedAt;

  MysqlConnectionConfig copyWith({
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    bool? schemaVerified,
    DateTime? updatedAt,
  }) {
    return MysqlConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      schemaVerified: schemaVerified ?? this.schemaVerified,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'host': host,
      'port': port,
      'database': database,
      'username': username,
      'password': password,
      'schema_verified': schemaVerified ? 1 : 0,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  static MysqlConnectionConfig fromMap(Map<String, Object?> map) {
    return MysqlConnectionConfig(
      host: map['host'] as String,
      port: map['port'] as int,
      database: map['database'] as String,
      username: map['username'] as String,
      password: map['password'] as String,
      schemaVerified: (map['schema_verified'] as int? ?? 0) == 1,
      updatedAt: (map['updated_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }
}

@immutable
class MysqlConnectionResult {
  const MysqlConnectionResult({
    required this.success,
    required this.message,
    this.accounts = const <String>[],
    this.missingColumns = const <String>[],
  });

  final bool success;
  final String message;
  final List<String> accounts;
  final List<String> missingColumns;
}

@immutable
class MysqlOperationResult {
  const MysqlOperationResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}
