import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/support.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'support_thread_screen.dart';

/// Help and complaints: conversations with the Kudi9ja team.
///
/// A question or a complaint, by topic, and the team answers here — live, so
/// a reply appears while the customer is looking at the thread. Complaints
/// are acknowledged and resolved within the times the Terms promise.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final AppState _app = context.read<AppState>();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _app.holdSupportLive();
    unawaited(_load());
  }

  @override
  void dispose() {
    _app.releaseSupportLive();
    super.dispose();
  }

  Future<void> _load() async {
    await _app.refreshSupport();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _compose() async {
    final thread = await showModalBottomSheet<SupportThread>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewConversationSheet(),
    );
    if (thread == null || !mounted) return;
    await Navigator.of(context).push(
      slideRoute(SupportThreadScreen(conversationId: thread.conversation.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final conversations = app.supportConversations;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & complaints')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnGold,
        onPressed: _compose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: app.refreshSupport,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: [
                Text(
                  'Talk to the Kudi9ja team. Complaints are acknowledged and '
                  'resolved within the times in our Terms.',
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_loading && conversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (conversations.isEmpty)
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations yet',
                    message: 'Ask a question or make a complaint, and the team '
                        'will reply here.',
                    action: SizedBox(
                      width: 220,
                      child: GoldButton(label: 'Start one', onPressed: _compose),
                    ),
                  )
                else
                  KCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < conversations.length; i++) ...[
                          if (i > 0) const HairLine(indent: 52),
                          ConversationRow(
                            conversation: conversations[i],
                            onTap: () => Navigator.of(context).push(
                              slideRoute(SupportThreadScreen(
                                conversationId: conversations[i].id,
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Prefer email? ${AppConfig.supportEmail}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One conversation in a list — the customer's, or the team's queue.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.showCustomer = false,
  });

  final SupportConversation conversation;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final complaint = c.kind == SupportKind.complaint;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: complaint ? Icons.report_gmailerrorred_rounded : Icons.forum_outlined,
              color: complaint ? AppColors.danger : AppColors.info,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.subject,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        c.lastMessageAt.relative,
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  if (showCustomer && c.customerName.isNotEmpty)
                    Text(
                      '${c.customerName} · ${c.customerRef}',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  if (c.lastMessagePreview.isNotEmpty)
                    Text(
                      c.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  const SizedBox(height: 6),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.reference,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ),
                      if (c.unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${c.unread}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textOnGold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color supportStatusColor(SupportStatus s) => switch (s) {
  SupportStatus.open => AppColors.gold,
  SupportStatus.awaitingCustomer => AppColors.info,
  SupportStatus.resolved => AppColors.success,
};

/// A question or a complaint: which, about what, a title and what happened.
class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet();

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  /// The server's list, which the queue sorts by. These stand in until it
  /// answers.
  List<String> _topics = const [
    'Paying in',
    'Withdrawals',
    'Loans',
    'Savings',
    'Ajo circles',
    'My account',
    'Something else',
  ];
  SupportKind _kind = SupportKind.enquiry;
  String? _topic;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      try {
        final topics = await context.read<AppState>().api?.supportTopics();
        if (mounted && topics != null && topics.isNotEmpty) {
          setState(() => _topics = topics);
        }
      } on ApiException {
        // The stand-ins are the same list.
      }
    }());
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _ready =>
      _topic != null &&
      _subject.text.trim().length >= 4 &&
      _message.text.trim().isNotEmpty &&
      !_busy;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final thread = await context.read<AppState>().openSupportConversation(
        kind: _kind,
        category: _topic!,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
      );
      if (mounted) Navigator.pop(context, thread);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      top: AppSpacing.sm,
      bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start a conversation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: KOptionTile(
                  title: 'A question',
                  selected: _kind == SupportKind.enquiry,
                  onTap: () => setState(() => _kind = SupportKind.enquiry),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: KOptionTile(
                  title: 'A complaint',
                  selected: _kind == SupportKind.complaint,
                  onTap: () => setState(() => _kind = SupportKind.complaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Topic',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in _topics)
                ChoiceChip(
                  label: Text(t),
                  selected: _topic == t,
                  onSelected: (_) => setState(() => _topic = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          KField(
            label: 'A short title',
            hint: _kind == SupportKind.complaint
                ? 'Transfer not credited'
                : 'How do I repay early?',
            controller: _subject,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'What happened?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Dates, amounts and references help us answer faster.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'Send',
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _ready ? _send : null,
          ),
        ],
      ),
    ),
  );
}
