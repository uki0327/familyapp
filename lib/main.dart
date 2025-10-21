import 'package:flutter/material.dart';

void main() {
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
      home: const FamilyHomePage(),
    );
  }
}

class FamilyMember {
  final String name;
  final String role;
  final String emoji;

  FamilyMember({
    required this.name,
    required this.role,
    required this.emoji,
  });
}

class FamilyHomePage extends StatefulWidget {
  const FamilyHomePage({super.key});

  @override
  State<FamilyHomePage> createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends State<FamilyHomePage> {
  final List<FamilyMember> _familyMembers = [
    FamilyMember(name: '아빠', role: '가장', emoji: '👨'),
    FamilyMember(name: '엄마', role: '주부', emoji: '👩'),
    FamilyMember(name: '아들', role: '학생', emoji: '👦'),
    FamilyMember(name: '딸', role: '학생', emoji: '👧'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('우리 가족'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // 헤더 섹션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.family_restroom,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Family App',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '가족 구성원: ${_familyMembers.length}명',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          // 가족 구성원 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _familyMembers.length,
              itemBuilder: (context, index) {
                final member = _familyMembers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        member.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(member.role),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () {
                      _showMemberDetail(context, member);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddMemberDialog(context);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('구성원 추가'),
      ),
    );
  }

  void _showMemberDetail(BuildContext context, FamilyMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.emoji} ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이름: ${member.name}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('역할: ${member.role}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 구성원 추가'),
        content: const Text('이 기능은 곧 구현될 예정입니다!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
