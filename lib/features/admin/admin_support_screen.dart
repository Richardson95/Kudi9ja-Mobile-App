import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/support.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import '../support/support_screen.dart';
import '../support/support_thread_screen.dart';
import 'admin_shell.dart';

/// The team's side of help and complaints: the queue, waiting-on-us first.
///
/// Anyone with panel access can read it and answer, take, resolve and reopen
/// a conversation. Customers' messages arrive live while the queue is open.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.customerId, this.customerName});

  /// Narrows the queue to one customer, from their record.
  final String? customerId;
  final String? customerName;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late final AppState _app = context.read<AppState>();
  final _search = TextEditingController();
  Timer? _debounce;
  SupportStatus? _status;
  List<SupportConversation> _rows = [];
  bool _loading = true;
  String? _error;
  int _seenChange = 0;

  @override
  void initState() {
    super.initState();
    _app.holdSupportLive(staff: true);
    _seenChange = _app.supportStaffChanged;
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _app.releaseSupportLive();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = _app.adminApi;
    if (admin == null) return;
    setState(() {
      _loading = _rows.isEmpty;
      _error = null;
    });
    try {
      final page = await admin.supportQueue(
        status: _status,
        customerId: widget.customerId,
        query: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _rows = page.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Something moved in the queue down the stream: read it again.
    if (app.supportStaffChanged != _seenChange) {
      _seenChange = app.supportStaffChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
    final summary = app.supportSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName == null
            ? 'Help & complaints'
            : 'Conversations · ${widget.customerName}'),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                if (widget.customerId == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Waiting on us',
                          value: '${summary.open}',
                          icon: Icons.mark_chat_unread_outlined,
                          tint: summary.open > 0 ? AppColors.gold : AppColors.textTertiary,
                          footnote: '${summary.unassigned} not taken',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricTile(
                          label: 'Past their promised time',
                          value: '${summary.overdue}',
                          icon: Icons.alarm_rounded,
                          tint: summary.overdue > 0 ? AppColors.danger : AppColors.textTertiary,
                          footnote: '${summary.awaitingCustomer} awaiting customer',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search name, reference or subject',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 450), _load);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (label, status) in const [
                      ('All', null),
                      ('Open', SupportStatus.open),
                      ('Awaiting customer', SupportStatus.awaitingCustomer),
                      ('Resolved', SupportStatus.resolved),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _status == status,
                        onSelected: (_) {
                          setState(() => _status = status);
                          unawaited(_load());
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: AppColors.danger))
                else if (_rows.isEmpty)
                  const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Nothing here',
                    message: 'No conversations match.',
                  )
                else
                  KCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < _rows.length; i++) ...[
                          if (i > 0) const HairLine(indent: 52),
                          ConversationRow(
                            conversation: _rows[i],
                            showCustomer: true,
                            onTap: () async {
                              await Navigator.of(context).push(slideRoute(
                                SupportThreadScreen(conversationId: _rows[i].id, staff: true),
                              ));
                              if (mounted) unawaited(_load());
                            },
                          ),
                        ],
                      ],
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
