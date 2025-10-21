import 'package:flutter/material.dart';
import 'dart:async';
import '../services/openai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OpenAIService _openAIService = OpenAIService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isObscured = true;
  bool _isSaving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    print('[SettingsScreen] _loadApiKey 시작');
    setState(() => _isLoading = true);
    try {
      final apiKey = await _openAIService.getApiKey();
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
        print('[SettingsScreen] API 키 로드 성공 - 길이: ${apiKey.length}');
      } else {
        print('[SettingsScreen] 저장된 API 키 없음');
      }
    } catch (e, stackTrace) {
      print('[SettingsScreen] _loadApiKey 에러: $e');
      print('[SettingsScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API 키 불러오기 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveApiKey(String value) async {
    if (_isSaving) {
      print('[SettingsScreen] 이미 저장 중이므로 스킵');
      return;
    }

    setState(() => _isSaving = true);
    print('[SettingsScreen] _saveApiKey 시작 - 값 길이: ${value.length}');

    try {
      await _openAIService.saveApiKey(value);
      print('[SettingsScreen] API 키 저장 성공');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 키가 저장되었습니다'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[SettingsScreen] _saveApiKey 에러: $e');
      print('[SettingsScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API 키 저장 실패: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _onApiKeyChanged(String value) {
    // 기존 타이머 취소
    _debounceTimer?.cancel();

    // 1초 후에 저장 (debounce)
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (value.isNotEmpty) {
        _saveApiKey(value);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _apiKeyController.dispose();
    super.dispose();
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
                Card(
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
                                  icon: Icon(
                                    _isObscured ? Icons.visibility : Icons.visibility_off,
                                  ),
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
                            onPressed: _isSaving
                                ? null
                                : () => _saveApiKey(_apiKeyController.text),
                            icon: const Icon(Icons.save),
                            label: const Text('저장'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'API 키는 입력 후 1초 뒤 자동 저장되거나, 저장 버튼을 눌러 즉시 저장할 수 있습니다.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            // URL을 열 수 있는 기능 추가 가능
                          },
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
                ),
                const SizedBox(height: 24),
                Card(
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
                ),
              ],
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}
