import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../services/mysql_models.dart';
import '../services/mysql_service.dart';
import '../services/openai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLogout,
    required this.currentAccountId,
    this.mysqlConfig,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onLogout;
  final String currentAccountId;
  final MysqlConnectionConfig? mysqlConfig;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OpenAIService _openAIService = OpenAIService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final MysqlService _mysqlService = MysqlService();

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _passcodeSettingController = TextEditingController();
  final TextEditingController _passcodeConfirmController = TextEditingController();
  final TextEditingController _passcodeForCreationController = TextEditingController();
  final TextEditingController _newAccountIdController = TextEditingController();
  final TextEditingController _newAccountPasswordController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _socialController = TextEditingController();

  bool _isLoading = true;
  bool _isObscured = true;
  bool _isSaving = false;
  bool _isSavingPasscode = false;
  bool _isCreatingAccount = false;
  Timer? _debounceTimer;

  MysqlConnectionConfig? _mysqlConfig;
  String? _storedPasscodeHash;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _apiKeyController.dispose();
    _passcodeSettingController.dispose();
    _passcodeConfirmController.dispose();
    _passcodeForCreationController.dispose();
    _newAccountIdController.dispose();
    _newAccountPasswordController.dispose();
    _relationController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final apiKey = await _openAIService.getApiKey();
      final passcodeHash = await _databaseHelper.getSetting('account_passcode');
      final storedConfig = await _databaseHelper.getMysqlConfig();

      if (apiKey != null) {
        _apiKeyController.text = apiKey;
      }

      setState(() {
        _storedPasscodeHash = passcodeHash;
        _mysqlConfig = storedConfig ?? widget.mysqlConfig;
      });
    } catch (error, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정을 불러오지 못했습니다: $error')),
        );
      }
      debugPrint('SettingsScreen init error: $error\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(context),
                const SizedBox(height: 24),
                _buildMysqlSummaryCard(context),
                const SizedBox(height: 24),
                _buildApiKeyCard(context),
                const SizedBox(height: 24),
                _buildPasscodeCard(context),
                const SizedBox(height: 24),
                _buildAccountCreationCard(context),
                const SizedBox(height: 24),
                _buildTranslatorInfoCard(context),
              ],
            ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
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
                  Icons.person_pin_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 로그인 계정',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.currentAccountId),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              value: widget.themeMode == ThemeMode.dark,
              onChanged: (value) => widget
                  .onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light),
              title: const Text('다크 모드'),
              subtitle: const Text('앱 전반에 적용되는 테마 모드를 변경합니다.'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.onLogout();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMysqlSummaryCard(BuildContext context) {
    final config = _mysqlConfig;
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
                  Icons.storage_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'MySQL 연결 정보',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (config == null)
              Text(
                '저장된 MySQL 연결 정보가 없습니다. 로그인 화면에서 접속을 검증해주세요.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKeyValueRow('서버', config.host),
                  const SizedBox(height: 8),
                  _buildKeyValueRow('포트', config.port.toString()),
                  const SizedBox(height: 8),
                  _buildKeyValueRow('데이터베이스', config.database),
                  const SizedBox(height: 8),
                  _buildKeyValueRow('계정', config.username),
                  const SizedBox(height: 8),
                  _buildKeyValueRow(
                    '스키마 확인',
                    config.schemaVerified ? '완료' : '미확인',
                  ),
                  if (config.updatedAt != null) ...[
                    const SizedBox(height: 8),
                    _buildKeyValueRow(
                      '최근 저장',
                      '${config.updatedAt}',
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final latestConfig = await _databaseHelper.getMysqlConfig();
                  if (!mounted) return;
                  setState(() {
                    _mysqlConfig = latestConfig;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('최신 정보 불러오기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyCard(BuildContext context) {
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
                  Icons.key,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'OpenAI API 키',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                labelText: 'API 키',
                hintText: 'sk-...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    ),
                  ],
                ),
              ),
              onChanged: _onApiKeyChanged,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveApiKey(_apiKeyController.text),
                icon: const Icon(Icons.save),
                label: const Text('저장'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API 키는 입력 후 1초 뒤 자동 저장되거나, 저장 버튼을 눌러 즉시 저장할 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {},
              child: Text(
                'API 키는 https://platform.openai.com/api-keys 에서 발급받을 수 있습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasscodeCard(BuildContext context) {
    final bool hasPasscode = _storedPasscodeHash != null;
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
                  Icons.lock_reset,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '계정 생성 패스코드',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasPasscode
                  ? '현재 패스코드가 설정되어 있습니다. 새 패스코드를 입력하면 기존 값이 대체됩니다.'
                  : '계정을 생성하기 전에 패스코드를 먼저 설정해주세요.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passcodeSettingController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '새 패스코드',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.password),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passcodeConfirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '패스코드 확인',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingPasscode ? null : _savePasscode,
                icon: _isSavingPasscode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.security),
                label: Text(_isSavingPasscode ? '저장 중...' : '패스코드 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCreationCard(BuildContext context) {
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
                  Icons.person_add_alt_1,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '계정 생성 (1인 전용)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '패스코드로 보호된 한 명의 계정만 등록할 수 있습니다. MySQL 테이블 구조는 num, id, password, relation, bio, email, phone, address, social 컬럼을 포함해야 합니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passcodeForCreationController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '패스코드 확인',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_person),
              ),
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _newAccountIdController,
              label: '아이디 (id)',
              icon: Icons.badge,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _newAccountPasswordController,
              label: '비밀번호 (password)',
              icon: Icons.lock,
              obscureText: true,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _relationController,
              label: '관계 (relation)',
              icon: Icons.family_restroom,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _bioController,
              label: '소개 (bio)',
              icon: Icons.article,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _emailController,
              label: '이메일 (email)',
              icon: Icons.email,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _phoneController,
              label: '전화번호 (phone)',
              icon: Icons.phone,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _addressController,
              label: '주소 (address)',
              icon: Icons.home,
            ),
            const SizedBox(height: 12),
            _buildAccountField(
              controller: _socialController,
              label: 'SNS 링크 (social)',
              icon: Icons.link,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCreatingAccount ? null : _createAccount,
                icon: _isCreatingAccount
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_isCreatingAccount ? '등록 중...' : '계정 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslatorInfoCard(BuildContext context) {
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
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '번역기 정보',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('지원 언어', '한국어 ↔ 라오어'),
            const Divider(height: 24),
            _buildInfoRow('번역 엔진', 'OpenAI GPT-4o-mini'),
            const Divider(height: 24),
            _buildInfoRow('자동 언어 감지', '활성화'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildKeyValueRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
    );
  }

  void _onApiKeyChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (value.isNotEmpty) {
        _saveApiKey(value);
      }
    });
  }

  Future<void> _saveApiKey(String value) async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _openAIService.saveApiKey(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 키가 저장되었습니다'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API 키 저장 실패: $error'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _savePasscode() async {
    final String passcode = _passcodeSettingController.text.trim();
    final String confirm = _passcodeConfirmController.text.trim();

    if (passcode.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('패스코드와 확인 값을 입력해주세요.')),
      );
      return;
    }
    if (passcode != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('패스코드가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _isSavingPasscode = true);
    try {
      final String hashed = _hashPasscode(passcode);
      await _databaseHelper.saveSetting('account_passcode', hashed);
      if (mounted) {
        setState(() {
          _storedPasscodeHash = hashed;
          _passcodeSettingController.clear();
          _passcodeConfirmController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('패스코드가 저장되었습니다.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('패스코드 저장 실패: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPasscode = false);
      }
    }
  }

  Future<void> _createAccount() async {
    final MysqlConnectionConfig? config = await _databaseHelper.getMysqlConfig();
    setState(() {
      _mysqlConfig = config;
    });

    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MySQL 연결 정보가 없어 계정을 생성할 수 없습니다.')),
      );
      return;
    }

    final String passcode = _passcodeForCreationController.text.trim();
    if (_storedPasscodeHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 패스코드를 설정해주세요.')),
      );
      return;
    }
    if (_hashPasscode(passcode) != _storedPasscodeHash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('패스코드가 일치하지 않습니다.')),
      );
      return;
    }

    final String id = _newAccountIdController.text.trim();
    final String password = _newAccountPasswordController.text.trim();
    final String relation = _relationController.text.trim();

    if (id.isEmpty || password.isEmpty || relation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디, 비밀번호, 관계는 필수 입력 항목입니다.')),
      );
      return;
    }

    setState(() => _isCreatingAccount = true);
    try {
      final payload = <String, String>{
        'num': '1',
        'id': id,
        'password': password,
        'relation': relation,
        'bio': _bioController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'social': _socialController.text.trim(),
      };

      final result = await _mysqlService.createAccount(
        config,
        payload: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }

      if (result.success && mounted) {
        _passcodeForCreationController.clear();
        _newAccountIdController.clear();
        _newAccountPasswordController.clear();
        _relationController.clear();
        _bioController.clear();
        _emailController.clear();
        _phoneController.clear();
        _addressController.clear();
        _socialController.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('계정 생성 실패: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  String _hashPasscode(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }
}
