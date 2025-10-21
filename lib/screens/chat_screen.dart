import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatAttachment> _pendingAttachments = <ChatAttachment>[];

  String? _selectedSenderId;
  int _attachmentIndex = 1;

  @override
  void initState() {
    super.initState();
    _controller = ChatController()
      ..addListener(() {
        if (_selectedSenderId == null && _controller.members.isNotEmpty) {
          _selectedSenderId = _controller.members.last.id;
        } else if (_selectedSenderId != null &&
            _controller.memberById(_selectedSenderId!) == null) {
          _selectedSenderId = _controller.members.isNotEmpty ? _controller.members.first.id : null;
        }
        setState(() {});
      });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final ChatThread? activeThread = _controller.activeThread;
        final FamilyMember? currentProfile = _selectedSenderId != null
            ? _controller.memberById(_selectedSenderId!)
            : (_controller.members.isNotEmpty ? _controller.members.first : null);

        return Scaffold(
          appBar: AppBar(
            title: const Text('실시간 가족 채팅'),
            actions: <Widget>[
              if (_controller.members.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentProfile?.id,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _controller.members
                          .map(
                            (FamilyMember member) => DropdownMenuItem<String>(
                              value: member.id,
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundColor: member.themeColor ?? Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      member.displayName.characters.first,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(member.displayName),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedSenderId = value;
                        });
                      },
                    ),
                  ),
                ),
              IconButton(
                tooltip: '가족 등록',
                onPressed: _controller.isSyncing ? null : () => _showMemberEditor(context),
                icon: const Icon(Icons.person_add_alt_1),
              ),
              IconButton(
                tooltip: '가족 관리',
                onPressed: () => _openMemberManager(context),
                icon: const Icon(Icons.manage_accounts),
              ),
            ],
            bottom: _controller.isSyncing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(minHeight: 4),
                  )
                : null,
          ),
          body: Column(
            children: <Widget>[
              _HeaderSection(
                controller: _controller,
                onSelectThread: (String threadId) {
                  _controller.selectThread(threadId);
                },
              ),
              const Divider(height: 1),
              if (_pendingAttachments.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _pendingAttachments
                        .map(
                          (ChatAttachment attachment) => InputChip(
                            label: Text(_attachmentLabel(attachment.kind, attachment.label)),
                            avatar: Icon(_attachmentIcon(attachment.kind)),
                            onDeleted: () {
                              setState(() {
                                _pendingAttachments.remove(attachment);
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              Expanded(
                child: activeThread == null
                    ? const Center(child: Text('대화방이 없습니다. 가족을 등록해 주세요.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        reverse: true,
                        itemCount: activeThread.messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ChatMessage message = activeThread.messages.reversed.toList()[index];
                          final FamilyMember? sender = _controller.memberById(message.senderId);
                          final bool isMine = message.senderId == currentProfile?.id;

                          return _MessageBubble(
                            message: message,
                            sender: sender,
                            alignRight: isMine,
                            onAttachmentTap: (ChatAttachment attachment) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${attachment.label} 다운로드를 시작합니다.'),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              _Composer(
                controller: _controller,
                messageController: _messageController,
                focusNode: _messageFocusNode,
                pendingAttachments: _pendingAttachments,
                onSelectAttachment: _openAttachmentPicker,
                onSend: () async {
                  final String text = _messageController.text.trim();
                  if ((_pendingAttachments.isEmpty && text.isEmpty) || _controller.activeThread == null) {
                    return;
                  }

                  final String senderId = _selectedSenderId ?? _controller.members.first.id;

                  await _controller.sendMessage(
                    senderId: senderId,
                    threadId: _controller.activeThreadId,
                    body: text.isEmpty ? '첨부파일을 보냈습니다.' : text,
                    attachments: List<ChatAttachment>.from(_pendingAttachments),
                  );

                  _messageController.clear();
                  _pendingAttachments.clear();
                  setState(() {
                    _attachmentIndex = 1;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMemberManager(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      '가족 구성원 관리',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: '새 가족 등록',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showMemberEditor(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _controller.members.length,
                    separatorBuilder: (BuildContext context, int index) => const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final FamilyMember member = _controller.members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: member.themeColor ?? Theme.of(context).colorScheme.primaryContainer,
                          child: Text(member.displayName.characters.first),
                        ),
                        title: Text(member.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(member.relationship),
                            if (member.statusMessage != null && member.statusMessage!.isNotEmpty)
                              Text(
                                member.statusMessage!,
                                style: TextStyle(color: Theme.of(context).colorScheme.primary),
                              ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showMemberEditor(context, member: member);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('구성원 삭제'),
                                      content: Text('${member.displayName} 님을 삭제할까요?'),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('취소'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('삭제'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirm == true) {
                                  await _controller.deleteMember(member.id);
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMemberEditor(BuildContext context, {FamilyMember? member}) async {
    final TextEditingController nameController = TextEditingController(text: member?.displayName ?? '');
    final TextEditingController relationController = TextEditingController(text: member?.relationship ?? '');
    final TextEditingController statusController = TextEditingController(text: member?.statusMessage ?? '');
    Color? selectedColor = member?.themeColor ?? Colors.blueGrey.shade300;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setStateDialog) {
            return AlertDialog(
              title: Text(member == null ? '가족 등록' : '가족 정보 수정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '이름'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: relationController,
                      decoration: const InputDecoration(labelText: '관계'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: statusController,
                      decoration: const InputDecoration(labelText: '상태 메시지 (선택)'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: <Color>[
                        Colors.blue.shade400,
                        Colors.red.shade400,
                        Colors.green.shade400,
                        Colors.orange.shade400,
                        Colors.purple.shade400,
                        Colors.teal.shade400,
                      ].map((Color color) {
                        final bool isSelected = selectedColor == color;
                        return ChoiceChip(
                          label: const SizedBox(width: 24, height: 24),
                          selected: isSelected,
                          avatar: CircleAvatar(backgroundColor: color),
                          onSelected: (_) {
                            setStateDialog(() {
                              selectedColor = color;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || relationController.text.trim().isEmpty) {
                      return;
                    }

                    if (member == null) {
                      await _controller.registerMember(
                        displayName: nameController.text.trim(),
                        relationship: relationController.text.trim(),
                        statusMessage: statusController.text.trim().isEmpty
                            ? null
                            : statusController.text.trim(),
                        themeColor: selectedColor,
                      );
                    } else {
                      await _controller.updateMember(
                        member.copyWith(
                          displayName: nameController.text.trim(),
                          relationship: relationController.text.trim(),
                          statusMessage: statusController.text.trim().isEmpty
                              ? null
                              : statusController.text.trim(),
                          themeColor: selectedColor,
                        ),
                      );
                    }

                    if (!mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAttachmentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('이미지 업로드'),
                onTap: () {
                  _addAttachment(AttachmentKind.image);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('파일 업로드'),
                onTap: () {
                  _addAttachment(AttachmentKind.file);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_page),
                title: const Text('연락처 공유'),
                onTap: () {
                  _addAttachment(AttachmentKind.contact);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _addAttachment(AttachmentKind kind) {
    setState(() {
      _pendingAttachments.add(
        ChatAttachment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          kind: kind,
          label: '${kind.name}_${_attachmentIndex.toString().padLeft(2, '0')}',
        ),
      );
      _attachmentIndex++;
    });
  }

  IconData _attachmentIcon(AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.image:
        return Icons.image_outlined;
      case AttachmentKind.file:
        return Icons.insert_drive_file_outlined;
      case AttachmentKind.contact:
        return Icons.contact_mail_outlined;
    }
  }

  String _attachmentLabel(AttachmentKind kind, String label) {
    switch (kind) {
      case AttachmentKind.image:
        return '이미지 $label';
      case AttachmentKind.file:
        return '파일 $label';
      case AttachmentKind.contact:
        return '연락처 $label';
    }
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.controller,
    required this.onSelectThread,
  });

  final ChatController controller;
  final ValueChanged<String> onSelectThread;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceVariant.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => onSelectThread('group'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: controller.activeThreadId == 'group' ? colors.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '우리가족단톡방',
                style: TextStyle(
                  color: controller.activeThreadId == 'group' ? Colors.white : colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: controller.members
                    .map(
                      (FamilyMember member) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(member.displayName),
                          avatar: CircleAvatar(
                            backgroundColor: member.themeColor ?? colors.primary,
                            child: Text(
                              member.displayName.characters.first,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          selected: controller.activeThreadId == member.id,
                          onSelected: (_) => onSelectThread(member.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.messageController,
    required this.focusNode,
    required this.pendingAttachments,
    required this.onSelectAttachment,
    required this.onSend,
  });

  final ChatController controller;
  final TextEditingController messageController;
  final FocusNode focusNode;
  final List<ChatAttachment> pendingAttachments;
  final VoidCallback onSelectAttachment;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '첨부 추가',
              onPressed: onSelectAttachment,
            ),
            Expanded(
              child: TextField(
                controller: messageController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: controller.activeThreadId == 'group'
                      ? '가족 전체에게 메시지 보내기'
                      : '메시지를 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              label: const Text('전송'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.alignRight,
    required this.onAttachmentTap,
  });

  final ChatMessage message;
  final FamilyMember? sender;
  final bool alignRight;
  final ValueChanged<ChatAttachment> onAttachmentTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color bubbleColor = alignRight ? colors.primary : colors.surfaceVariant;
    final Color textColor = alignRight ? Colors.white : colors.onSurface;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          color: bubbleColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                if (!alignRight && sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      sender!.displayName,
                      style: TextStyle(
                        color: alignRight ? Colors.white70 : colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  message.body,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment:
                          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: message.attachments
                          .map(
                            (ChatAttachment attachment) => TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: alignRight ? Colors.white : colors.primary,
                              ),
                              onPressed: () => onAttachmentTap(attachment),
                              icon: Icon(_iconForAttachment(attachment.kind)),
                              label: Text(attachment.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime timestamp) {
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static IconData _iconForAttachment(AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.image:
        return Icons.photo;
      case AttachmentKind.file:
        return Icons.attach_file;
      case AttachmentKind.contact:
        return Icons.contact_phone;
    }
  }
}
