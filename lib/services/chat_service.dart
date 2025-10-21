import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

/// Represents the type of attachment that can be sent inside a message.
enum AttachmentKind { image, file, contact }

/// Model describing a file or rich content attached to a chat message.
class ChatAttachment {
  ChatAttachment({
    required this.id,
    required this.kind,
    required this.label,
    this.url,
  });

  final String id;
  final AttachmentKind kind;
  final String label;
  final String? url;
}

/// Model describing a single chat message.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.timestamp,
    this.attachments = const <ChatAttachment>[],
    this.isRead = true,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime timestamp;
  final List<ChatAttachment> attachments;
  final bool isRead;
}

/// Model describing a family member that can join the chat.
class FamilyMember {
  FamilyMember({
    required this.id,
    required this.displayName,
    required this.relationship,
    this.profileImage,
    this.themeColor,
    this.statusMessage,
  });

  final String id;
  final String displayName;
  final String relationship;
  final String? profileImage;
  final Color? themeColor;
  final String? statusMessage;

  FamilyMember copyWith({
    String? displayName,
    String? relationship,
    String? profileImage,
    Color? themeColor,
    String? statusMessage,
  }) {
    return FamilyMember(
      id: id,
      displayName: displayName ?? this.displayName,
      relationship: relationship ?? this.relationship,
      profileImage: profileImage ?? this.profileImage,
      themeColor: themeColor ?? this.themeColor,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Model describing a specific chat thread.
class ChatThread {
  ChatThread({
    required this.id,
    required this.title,
    required this.participantIds,
    List<ChatMessage>? messages,
  }) : _messages = messages ?? <ChatMessage>[];

  final String id;
  final String title;
  final List<String> participantIds;
  final List<ChatMessage> _messages;

  UnmodifiableListView<ChatMessage> get messages => UnmodifiableListView(_messages);

  void addMessage(ChatMessage message) {
    _messages.add(message);
  }
}

/// Controller that manages family members and chat threads.
class ChatController extends ChangeNotifier {
  ChatController() {
    _bootstrap();
  }

  final List<FamilyMember> _members = <FamilyMember>[];
  final Map<String, ChatThread> _threads = <String, ChatThread>{};

  bool _isSyncing = false;
  String _activeThreadId = 'group';

  bool get isSyncing => _isSyncing;

  String get activeThreadId => _activeThreadId;

  UnmodifiableListView<FamilyMember> get members => UnmodifiableListView(_members);

  UnmodifiableListView<ChatThread> get threads => UnmodifiableListView(_threads.values.toList());

  ChatThread? get activeThread => _threads[_activeThreadId];

  void _bootstrap() {
    final FamilyMember dad = FamilyMember(
      id: _generateId(),
      displayName: '아빠',
      relationship: 'Father',
      themeColor: Colors.blue.shade400,
      statusMessage: '오늘 회식! 늦어요',
    );
    final FamilyMember mom = FamilyMember(
      id: _generateId(),
      displayName: '엄마',
      relationship: 'Mother',
      themeColor: Colors.pink.shade300,
      statusMessage: '저녁 뭐 먹을까?',
    );
    final FamilyMember me = FamilyMember(
      id: _generateId(),
      displayName: '나',
      relationship: 'You',
      themeColor: Colors.green.shade400,
      statusMessage: '코딩 중',
    );

    _members.addAll(<FamilyMember>[dad, mom, me]);

    final ChatThread groupThread = ChatThread(
      id: 'group',
      title: '우리 가족 단톡',
      participantIds: _members.map((FamilyMember m) => m.id).toList(),
      messages: <ChatMessage>[
        ChatMessage(
          id: _generateId(),
          senderId: mom.id,
          body: '오늘 저녁은 뭘 먹을까?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
        ChatMessage(
          id: _generateId(),
          senderId: dad.id,
          body: '나는 김치찌개 좋음!',
          timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        ),
        ChatMessage(
          id: _generateId(),
          senderId: me.id,
          body: '저는 아무거나~',
          timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
          attachments: <ChatAttachment>[
            ChatAttachment(
              id: _generateId(),
              kind: AttachmentKind.image,
              label: '식당메뉴.jpg',
            ),
          ],
        ),
      ],
    );

    _threads[groupThread.id] = groupThread;

    for (final FamilyMember member in _members) {
      final ChatThread dmThread = ChatThread(
        id: member.id,
        title: '${member.displayName} 채팅',
        participantIds: <String>[member.id],
        messages: <ChatMessage>[
          ChatMessage(
            id: _generateId(),
            senderId: member.id,
            body: '개인 대화방이 생성되었어요.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ],
      );
      _threads[dmThread.id] = dmThread;
    }
  }

  Future<void> registerMember({
    required String displayName,
    required String relationship,
    Color? themeColor,
    String? profileImage,
    String? statusMessage,
  }) async {
    _setSyncing(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final FamilyMember newMember = FamilyMember(
      id: _generateId(),
      displayName: displayName,
      relationship: relationship,
      themeColor: themeColor,
      profileImage: profileImage,
      statusMessage: statusMessage,
    );

    _members.add(newMember);
    _threads[newMember.id] = ChatThread(
      id: newMember.id,
      title: '${newMember.displayName} 채팅',
      participantIds: <String>[newMember.id],
    );

    _setSyncing(false);
    notifyListeners();
  }

  Future<void> updateMember(FamilyMember member) async {
    final int index = _members.indexWhere((FamilyMember m) => m.id == member.id);
    if (index == -1) {
      return;
    }

    _setSyncing(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final ChatThread? existingThread = _threads[member.id];
    _members[index] = member;
    _threads[member.id] = ChatThread(
      id: member.id,
      title: '${member.displayName} 채팅',
      participantIds: <String>[member.id],
      messages: existingThread == null
          ? <ChatMessage>[]
          : List<ChatMessage>.from(existingThread.messages),
    );

    _setSyncing(false);
    notifyListeners();
  }

  Future<void> deleteMember(String memberId) async {
    final int index = _members.indexWhere((FamilyMember m) => m.id == memberId);
    if (index == -1) {
      return;
    }

    _setSyncing(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    _members.removeAt(index);
    _threads.remove(memberId);

    if (_activeThreadId == memberId) {
      _activeThreadId = 'group';
    }

    _setSyncing(false);
    notifyListeners();
  }

  Future<void> sendMessage({
    required String senderId,
    required String threadId,
    required String body,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final ChatThread? thread = _threads[threadId];
    if (thread == null) {
      return;
    }

    final ChatMessage message = ChatMessage(
      id: _generateId(),
      senderId: senderId,
      body: body,
      attachments: attachments,
      timestamp: DateTime.now(),
    );

    thread.addMessage(message);
    notifyListeners();
  }

  void selectThread(String threadId) {
    if (_threads.containsKey(threadId)) {
      _activeThreadId = threadId;
      notifyListeners();
    }
  }

  FamilyMember? memberById(String id) {
    try {
      return _members.firstWhere((FamilyMember member) => member.id == id);
    } catch (_) {
      return null;
    }
  }

  void _setSyncing(bool value) {
    if (_isSyncing != value) {
      _isSyncing = value;
      notifyListeners();
    }
  }

  static String _generateId() {
    final Random random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() + random.nextInt(99999).toString();
  }
}
