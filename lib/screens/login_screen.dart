import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../services/mysql_models.dart';
import '../services/mysql_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLoginCompleted,
    required this.onBypassRequested,
    this.initialConfig,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final void Function(MysqlConnectionConfig config, String accountId)
      onLoginCompleted;
  final VoidCallback onBypassRequested;
  final MysqlConnectionConfig? initialConfig;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final MysqlService _mysqlService = MysqlService();

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '3306');
  final TextEditingController _databaseController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _accountIdController = TextEditingController();

  bool _isVerifying = false;
  bool _connectionVerified = false;
  bool _configExpanded = true;
  bool _obscurePassword = true;
  MysqlConnectionConfig? _verifiedConfig;
  MysqlConnectionResult? _lastResult;
  List<String> _accounts = <String>[];
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _accountIdController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialConfig() async {
    final config = widget.initialConfig;
    if (config != null) {
      _hostController.text = config.host;
      _portController.text = config.port.toString();
      _databaseController.text = config.database;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _configExpanded = false;
      if (config.schemaVerified) {
        _verifiedConfig = config;
        _connectionVerified = true;
        try {
          final accounts = await _mysqlService.loadAccounts(config);
          if (mounted) {
            setState(() {
              _accounts = accounts;
              if (accounts.isNotEmpty) {
                _selectedAccount = accounts.first;
                _accountIdController.text = accounts.first;
              }
            });
          }
        } catch (_) {
          // Ignore preloading errors. User can re-verify.
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family App',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '로그인 및 환경 설정을 완료해주세요.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                  Tooltip(
                    message: widget.themeMode == ThemeMode.dark
                        ? '라이트 모드로 전환'
                        : '다크 모드로 전환',
                    child: Switch.adaptive(
                      value: widget.themeMode == ThemeMode.dark,
                      onChanged: (value) => widget
                          .onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildMysqlConfigCard(context),
              const SizedBox(height: 16),
              if (_lastResult != null)
                _buildStatusBanner(context, _lastResult!),
              const SizedBox(height: 16),
              _buildAccountSelectionCard(context),
              const SizedBox(height: 16),
              _buildRecommendationsCard(context),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onBypassRequested,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    '바이패스',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMysqlConfigCard(BuildContext context) {
    final hasStoredConfig = widget.initialConfig != null;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MySQL 8 연결 정보',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        hasStoredConfig
                            ? '저장된 정보가 있어 접속 정보를 숨겼습니다. 필요시 펼쳐 수정하세요.'
                            : '서버 주소와 계정 정보를 입력한 뒤 접속을 확인하세요.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_configExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _configExpanded = !_configExpanded;
                    });
                  },
                ),
              ],
            ),
            if (_configExpanded) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _hostController,
                label: '서버 주소',
                icon: Icons.dns,
                hintText: '예) 192.168.0.10',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _portController,
                label: '포트',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _databaseController,
                label: '데이터베이스',
                icon: Icons.dataset,
                hintText: '예) family_app',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _usernameController,
                label: 'DB 계정 아이디',
                icon: Icons.person,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _passwordController,
                label: 'DB 계정 비밀번호',
                icon: Icons.lock,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _onVerifyConnection,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(_isVerifying ? '검증 중...' : '접속 및 스키마 확인'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _resetStoredConfig,
                  child: const Text('저장 정보 초기화'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelectionCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '계정 선택',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_connectionVerified)
              Text(
                '먼저 MySQL 연결을 검증해주세요. 검증이 완료되면 등록된 계정을 불러옵니다.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            if (_connectionVerified) ...[
              if (_accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedAccount,
                  decoration: const InputDecoration(
                    labelText: '등록된 계정 선택',
                    border: OutlineInputBorder(),
                  ),
                  items: _accounts
                      .map(
                        (account) => DropdownMenuItem<String>(
                          value: account,
                          child: Text(account),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAccount = value;
                      if (value != null) {
                        _accountIdController.text = value;
                      }
                    });
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Text(
                    '등록된 계정이 없습니다. 설정 화면에서 패스코드로 신규 계정을 생성할 수 있습니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _accountIdController,
                label: '로그인 아이디',
                icon: Icons.badge,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connectionVerified ? _onLogin : null,
                  icon: const Icon(Icons.login),
                  label: const Text('Family App 시작'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Text(
                  '추가 권장 필드',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '현재 필수 필드는 num, id, password, relation, bio, email, phone, address, social 입니다. '
              '추가로 생일(birthdate), 프로필 이미지 URL(profile_image_url), 비상 연락처(emergency_contact), '
              '메모(notes) 필드를 함께 관리하면 가족 정보를 더욱 풍부하게 기록할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, MysqlConnectionResult result) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool success = result.success;
    final Color background = success ? colors.primaryContainer : colors.errorContainer;
    final Color foreground = success ? colors.onPrimaryContainer : colors.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error_outline, color: foreground),
              const SizedBox(width: 8),
              Text(
                success ? '연결 성공' : '연결 실패',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          if (result.missingColumns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '누락된 컬럼: ${result.missingColumns.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _resetStoredConfig() async {
    await _databaseHelper.clearMysqlConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장된 MySQL 설정을 초기화했습니다.')),
    );
    setState(() {
      _configExpanded = true;
      _connectionVerified = false;
      _verifiedConfig = null;
      _accounts = <String>[];
      _selectedAccount = null;
      _lastResult = null;
    });
  }

  Future<void> _onVerifyConnection() async {
    final String host = _hostController.text.trim();
    final int? port = int.tryParse(_portController.text.trim());
    final String database = _databaseController.text.trim();
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (host.isEmpty || port == null || database.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 접속 정보를 정확히 입력해주세요.')),
      );
      return;
    }

    final config = MysqlConnectionConfig(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );

    setState(() {
      _isVerifying = true;
    });

    final result = await _mysqlService.testConnection(config);
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _lastResult = result;
      _connectionVerified = result.success;
      if (result.success) {
        _verifiedConfig = config.copyWith(schemaVerified: true);
        _accounts = result.accounts;
        if (_accounts.isNotEmpty) {
          _selectedAccount = _accounts.first;
          _accountIdController.text = _accounts.first;
        }
      } else {
        _verifiedConfig = null;
        _accounts = <String>[];
        _selectedAccount = null;
      }
    });

    if (result.success) {
      await _databaseHelper.saveMysqlConfig(_verifiedConfig!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MySQL 연결 정보가 저장되었습니다.')),
      );
    }
  }

  void _onLogin() {
    final String accountId = _accountIdController.text.trim();
    if (accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용할 계정 아이디를 입력하거나 선택해주세요.')),
      );
      return;
    }
    final config = _verifiedConfig;
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MySQL 연결 검증을 먼저 완료해주세요.')),
      );
      return;
    }

    widget.onLoginCompleted(config, accountId);
  }
}
