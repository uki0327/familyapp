import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_helper.dart';
import '../services/mysql_models.dart';
import '../services/openai_service.dart';
import 'settings_screen.dart';

class TranslationMessage {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  TranslationMessage({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({
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
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final OpenAIService _openAIService = OpenAIService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TranslationMessage> _messages = [];
  bool _isTranslating = false;
  bool _isHistoryLoading = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;

  static const int _historyPageSize = 50;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
  }

  void _hideToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _showToast(String message) {
    _hideToast();

    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _toastEntry = entry;
    _toastTimer = Timer(const Duration(seconds: 2), _hideToast);
  }

  Future<void> _copyTranslatedText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    _showToast('번역 결과가 복사되었어요');
  }

  Future<void> _copyMostRecentTranslation() async {
    if (_messages.isEmpty) return;
    await _copyTranslatedText(_messages.last.translatedText);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _hideToast();
    super.dispose();
  }

  TranslationMessage _mapHistoryRecord(Map<String, dynamic> record) {
    return TranslationMessage(
      originalText: record['source_text'] as String? ?? '',
      translatedText: record['translated_text'] as String? ?? '',
      sourceLanguage: record['source_language'] as String? ?? 'Korean',
      targetLanguage: record['target_language'] as String? ?? 'Lao',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (record['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Future<void> _loadInitialHistory() async {
    setState(() {
      _isHistoryLoading = true;
    });

    try {
      final history = await _databaseHelper.getTranslationHistory(
        limit: _historyPageSize,
      );

      if (!mounted) return;

      final messages = history.map(_mapHistoryRecord).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMoreHistory = history.length == _historyPageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isHistoryLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMoreHistory || !_hasMoreHistory) {
      return;
    }

    setState(() {
      _isLoadingMoreHistory = true;
    });

    try {
      final history = await _databaseHelper.getTranslationHistory(
        limit: _historyPageSize,
        offset: _messages.length,
      );

      if (!mounted) return;

      if (history.isEmpty) {
        setState(() {
          _hasMoreHistory = false;
        });
        return;
      }

      final messages = history.map(_mapHistoryRecord).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _messages.insertAll(0, messages);
        _hasMoreHistory = history.length == _historyPageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreHistory = false;
        });
      }
    }
  }

  Future<void> _handleHistoryRefresh() async {
    if (!_hasMoreHistory) {
      // Give the refresh indicator some time to animate even when nothing loads
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }

    await _loadMoreHistory();
  }

  Future<void> _translate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final sourceLanguage = _openAIService.detectLanguage(text);
      final targetLanguage = sourceLanguage == 'Korean' ? 'Lao' : 'Korean';

      final translatedText = await _openAIService.translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          TranslationMessage(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            timestamp: DateTime.now(),
          ),
        );
        _hasMoreHistory = true;
      });

      _textController.clear();

      // 스크롤을 맨 아래로 이동
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '설정',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      themeMode: widget.themeMode,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      onLogout: widget.onLogout,
                      currentAccountId: widget.currentAccountId,
                      mysqlConfig: widget.mysqlConfig,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Widget _buildMessageItem(TranslationMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 원문 (오른쪽 정렬 - 보낸 말풍선)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.sourceLanguage == 'Korean' ? '한국어' : 'ລາວ',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.originalText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 번역문 (왼쪽 정렬 - 번역 결과)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyTranslatedText(message.translatedText),
                  onLongPress: () => _copyTranslatedText(message.translatedText),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.targetLanguage == 'Korean' ? '한국어' : 'ລາວ',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.translatedText,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    if (_isHistoryLoading && _messages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.translate,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '아직 번역 기록이 없어요',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '번역을 시작하면 여기에 기록이 표시돼요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoadingMoreHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '과거 내역 불러오는 중...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (!_hasMoreHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '불러올 더 많은 번역 기록이 없어요',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            '과거 내역 더 보기',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '아래로 당겨서 과거 번역 기록을 불러와요',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('라오어 ↔ 한국어 번역기'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    onLogout: widget.onLogout,
                    currentAccountId: widget.currentAccountId,
                    mysqlConfig: widget.mysqlConfig,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 번역 결과 표시 영역 (채팅창 스타일)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleHistoryRefresh,
              edgeOffset: 12,
              displacement: 56,
              child: ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHistoryHeader();
                  }
                  final message = _messages[index - 1];
                  return _buildMessageItem(message);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemCount: _messages.length + 1,
              ),
            ),
          ),
          // 입력 영역
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: '번역할 텍스트를 입력하세요...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _translate(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '번역 결과 복사',
                      onPressed:
                          _messages.isEmpty ? null : () => _copyMostRecentTranslation(),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        disabledBackgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        disabledForegroundColor:
                            Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isTranslating
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _translate,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
