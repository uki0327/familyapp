import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/translator_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_helper.dart';
import 'services/mysql_models.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print('Flutter Error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    };

    try {
      // Initialize database for desktop platforms
      DatabaseHelper.initialize();
      print('[Main] 데이터베이스 초기화 완료');
    } catch (e, stackTrace) {
      print('[Main] 초기화 에러: $e');
      print('[Main] 스택 트레이스: $stackTrace');
    }

    runApp(const FamilyApp());
  }, (error, stack) {
    print('[Main] Zone Error: $error');
    print('[Main] Stack trace: $stack');
  });
}

class FamilyApp extends StatefulWidget {
  const FamilyApp({super.key});

  @override
  State<FamilyApp> createState() => _FamilyAppState();
}

class _FamilyAppState extends State<FamilyApp> {
  bool _isInitialized = false;
  String? _initError;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoggedIn = false;
  String? _activeAccountId;
  MysqlConnectionConfig? _mysqlConfig;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _initError = null;
      // Test database initialization by getting an instance
      if (!kIsWeb) {
        await DatabaseHelper().database;
        print('[FamilyApp] 데이터베이스 연결 확인 완료');
      } else {
        print('[FamilyApp] 웹 환경 - 데이터베이스 연결 확인 생략');
      }

      final themeSetting = await DatabaseHelper().getSetting('theme_mode');
      if (themeSetting == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeSetting == 'light') {
        _themeMode = ThemeMode.light;
      }

      _mysqlConfig = await DatabaseHelper().getMysqlConfig();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      print('[FamilyApp] 초기화 에러: $e');
      print('[FamilyApp] 스택 트레이스: $stackTrace');

      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitialized = true; // Show error screen instead of loading
        });
      }
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isInitialized = false;
      _initError = null;
    });

    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: _isInitialized
          ? (_initError != null
              ? _ErrorScreen(
                  error: _initError!,
                  onRetry: _retryInitialization,
                )
              : _isLoggedIn
                  ? MainMenuScreen(
                      themeMode: _themeMode,
                      onThemeModeChanged: _updateThemeMode,
                      onLogout: _handleLogout,
                      currentAccountId: _activeAccountId ?? '알 수 없음',
                      mysqlConfig: _mysqlConfig,
                    )
                  : LoginScreen(
                      themeMode: _themeMode,
                      onThemeModeChanged: _updateThemeMode,
                      initialConfig: _mysqlConfig,
                      onLoginCompleted: _handleLoginSuccess,
                      onBypassRequested: _handleBypass,
                    ))
          : const _LoadingScreen(),
    );
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await DatabaseHelper()
        .saveSetting('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void _handleLoginSuccess(MysqlConnectionConfig config, String accountId) {
    setState(() {
      _mysqlConfig = config;
      _activeAccountId = accountId;
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _activeAccountId = null;
    });
  }

  void _handleBypass() {
    setState(() {
      _isLoggedIn = true;
      _activeAccountId ??= '바이패스';
    });
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.family_restroom,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                '앱 초기화 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatefulWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  State<_ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<_ErrorScreen> {
  bool _isRetrying = false;

  Future<void> _retryInitialization() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      print('[ErrorScreen] 데이터베이스 재초기화 시도');

      // Reset the database instance
      await DatabaseHelper.resetDatabase();

      // Try to initialize database again
      if (!kIsWeb) {
        await DatabaseHelper().database;
      }

      print('[ErrorScreen] 데이터베이스 재초기화 성공');
      await widget.onRetry();
    } catch (e) {
      print('[ErrorScreen] 재초기화 실패: $e');

      if (mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('재시도 실패'),
            content: Text('데이터베이스 초기화에 실패했습니다.\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade50,
              Colors.red.shade100,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  '앱 초기화 실패',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.error,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _retryInitialization,
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isRetrying ? '재시도 중...' : '다시 시도'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
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
  Widget build(BuildContext context) {
    final menuItems = [
      MenuItem(
        title: '번역기',
        icon: Icons.translate,
        color: Colors.blue,
        builder: (context) => TranslatorScreen(
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
          onLogout: onLogout,
          currentAccountId: currentAccountId,
          mysqlConfig: mysqlConfig,
        ),
      ),
      MenuItem(
        title: '채팅',
        icon: Icons.chat,
        color: Colors.green,
        builder: (context) => const ChatScreen(),
      ),
      MenuItem(
        title: '갤러리',
        icon: Icons.photo_library,
        color: Colors.orange,
        builder: (context) => const GalleryScreen(),
      ),
      MenuItem(
        title: '설정',
        icon: Icons.settings,
        color: Colors.purple,
        builder: (context) => SettingsScreen(
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
          onLogout: onLogout,
          currentAccountId: currentAccountId,
          mysqlConfig: mysqlConfig,
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 로고 및 헤더 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 로고 아이콘
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.family_restroom,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Family App',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우리 가족을 위한 모든 것',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceTint
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '현재 계정: $currentAccountId',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceTint
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '현재 계정: $currentAccountId',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 메뉴 그리드
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _MenuCard(
                      item: item,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: item.builder),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _MenuCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.color.withOpacity(0.1),
                item.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  size: 48,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
