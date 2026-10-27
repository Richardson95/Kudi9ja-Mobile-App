import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/support.dart';
import '../../state/app_state.dart';
import '../../widgets/file_opener.dart';
import '../../widgets/primitives.dart';
import 'support_screen.dart';

/// One conversation, from either side of it.
///
/// The customer and the team read the same thread; [staff] decides whose
/// side this is — which endpoints answer it, and the controls the team has
/// (take it on, resolve with a note, reopen). New messages arrive down the
/// live stream; writing is an ordinary request.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({
    super.key,
    required this.conversationId,
    this.staff = false,
  });

  final String conversationId;
  final bool staff;

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late final AppState _app = context.read<AppState>();
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  DateTime _lastTyping = DateTime(2000);
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _app.holdSupportLive(staff: widget.staff);
    unawaited(_load());
  }

  @override
  void dispose() {
    _app
      ..closeSupportThread()
      ..releaseSupportLive();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _app.loadSupportThread(widget.conversationId, staff: widget.staff);
    if (!mounted) return;
    setState(() => _loading = false);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _typing() {
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 3)) return;
    _lastTyping = now;
    _app.supportTyping(widget.conversationId, staff: widget.staff);
  }

  Future<void> _send({List<int>? bytes, String? filename, String? type}) async {
    final body = _reply.text.trim();
    if (body.isEmpty && bytes == null) return;
    setState(() => _sending = true);
    final problem = await _app.sendSupportMessage(
      widget.conversationId,
      body: body,
      fileBytes: bytes,
      filename: filename,
      contentType: type,
      staff: widget.staff,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (problem != null) {
      showToast(context, problem, error: true);
      return;
    }
    _reply.clear();
    _toBottom();
  }

  Future<void> _attach() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) showToast(context, 'That file is over 10 MB.', error: true);
      return;
    }
    final name = path.split(RegExp(r'[/\\]')).last;
    await _send(bytes: bytes, filename: name, type: _typeOf(name));
  }

  static String? _typeOf(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return null;
  }

  Future<void> _resolve() async {
    if (widget.staff) {
      final note = await _askNote();
      if (note == null) return;
      try {
        final c = await _app.adminApi!.supportResolve(widget.conversationId, note: note);
        _app.applySupportConversation(c);
      } on ApiException catch (e) {
        if (mounted) showToast(context, e.message, error: true);
      }
      return;
    }
    final problem = await _app.resolveSupportConversation(widget.conversationId);
    if (problem != null && mounted) showToast(context, problem, error: true);
  }

  Future<void> _staffAct(Future<SupportConversation> Function() act) async {
    try {
      _app.applySupportConversation(await act());
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<String?> _askNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark resolved'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'What was done — the customer sees this (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    controller.dispose();
    return note;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final thread = app.openThread;
    final current = thread != null && thread.conversation.id == widget.conversationId;
    final c = current ? thread.conversation : null;
    final messages = current ? thread.messages : const <SupportMessage>[];
    final typing = app.typingIn(widget.conversationId);
    if (messages.length != _seen) {
      _seen = messages.length;
      _toBottom();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c?.subject ?? 'Conversation',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (c != null)
              Text(
                [
                  if (widget.staff && c.customerName.isNotEmpty) c.customerName,
                  c.reference,
                  c.category,
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
          ],
        ),
        actions: [
          if (c != null && widget.staff)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'assign' => _staffAct(() => _app.adminApi!.supportAssign(c.id)),
                'reopen' => _staffAct(() => _app.adminApi!.supportReopen(c.id)),
                _ => _resolve(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'assign', child: Text('Take it on')),
                if (c.isResolved)
                  const PopupMenuItem(value: 'reopen', child: Text('Reopen'))
                else
                  const PopupMenuItem(value: 'resolve', child: Text('Mark resolved')),
              ],
            )
          else if (c != null && !c.isResolved)
            TextButton(onPressed: _resolve, child: const Text('Sorted')),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (c != null) _StatusBar(conversation: c, staff: widget.staff),
              Expanded(
                child: _loading && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: messages.length + (typing != null ? 1 : 0),
                        itemBuilder: (_, i) => i == messages.length
                            ? _Typing(name: typing!)
                            : _Bubble(message: messages[i]),
                      ),
              ),
              _Composer(
                controller: _reply,
                sending: _sending,
                hint: c?.isResolved == true && !widget.staff
                    ? 'Writing again reopens it'
                    : 'Write a message',
                onChanged: (_) => _typing(),
                onSend: () => _send(),
                onAttach: _attach,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.conversation, required this.staff});
  final SupportConversation conversation;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final parts = <String>[
      c.kindLabel.isEmpty ? c.kind.label : c.kindLabel,
      if (c.assignedToName.isNotEmpty) 'with ${c.assignedToName}',
      if (!c.isResolved && c.resolveBy != null) 'resolve by ${c.resolveBy!.asDay}',
      if (c.isResolved && c.resolvedAt != null) 'resolved ${c.resolvedAt!.asDay}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: c.statusLabel.isEmpty ? c.status.name : c.statusLabel,
                color: supportStatusColor(c.status),
                dense: true,
              ),
              if (c.overdue) ...[
                const SizedBox(width: 6),
                StatusPill(label: 'LATE', color: AppColors.danger, dense: true),
              ],
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          if (c.isResolved && c.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.resolutionNote,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.author == SupportAuthor.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            m.body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    final mine = m.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.goldWash : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: Border.all(
            color: mine ? AppColors.gold.withValues(alpha: 0.35) : AppColors.stroke,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  m.authorName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
            if (m.hasAttachment)
              InkWell(
                onTap: () => openAuthedFile(
                  context,
                  url: m.attachmentUrl,
                  label: m.attachmentName.isEmpty ? 'attachment' : m.attachmentName,
                  contentType: m.attachmentType,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.isImage ? Icons.image_outlined : Icons.description_outlined,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          m.attachmentName.isEmpty ? 'Attachment' : m.attachmentName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (m.body.isNotEmpty)
              Text(m.body, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 3),
            Text(
              m.createdAt.asTime,
              style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      '$name is typing…',
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: AppColors.textTertiary,
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.hint,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.black,
      border: Border(top: BorderSide(color: AppColors.stroke)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Attach a photo or document',
          onPressed: sending ? null : onAttach,
          icon: Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 5,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint, counterText: ''),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        sending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : IconButton(
                tooltip: 'Send',
                onPressed: onSend,
                icon: Icon(Icons.send_rounded, color: AppColors.gold),
              ),
      ],
    ),
  );
}
