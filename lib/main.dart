import 'package:flutter/material.dart';
import 'screens/translator_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for desktop platforms
  DatabaseHelper.initialize();

  runApp(const FamilyApp());
}

class FamilyApp extends StatelessWidget {
  const FamilyApp({super.key});

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
      home: const MainMenuScreen(),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget screen;

  MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      MenuItem(
        title: '번역기',
        icon: Icons.translate,
        color: Colors.blue,
        screen: const TranslatorScreen(),
      ),
      MenuItem(
        title: '채팅',
        icon: Icons.chat,
        color: Colors.green,
        screen: const ChatScreen(),
      ),
      MenuItem(
        title: '갤러리',
        icon: Icons.photo_library,
        color: Colors.orange,
        screen: const GalleryScreen(),
      ),
      MenuItem(
        title: '설정',
        icon: Icons.settings,
        color: Colors.purple,
        screen: const SettingsScreen(),
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
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
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
                          MaterialPageRoute(builder: (context) => item.screen),
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
