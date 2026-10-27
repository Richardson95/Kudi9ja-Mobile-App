import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'admin_lending_widgets.dart';
import 'admin_new_offline_loan_screen.dart';
import 'admin_offline_loans_screen.dart';
import 'admin_shell.dart';

/// Loan groups: numbered, named groups of borrowers, each run by one loan
/// officer. Members borrow on the loan-group terms.
class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key});

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  List<LoanGroup> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    try {
      final groups = await admin.groups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<LoanGroupDetail>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GroupSheet(),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminGroupScreen(groupId: created.group.id)),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final lent = _groups.fold(0.0, (s, g) => s + g.totalLent);
    final owed = _groups.fold(0.0, (s, g) => s + g.outstanding);
    return Scaffold(
      appBar: AppBar(title: const Text('Loan groups')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnGold,
        onPressed: _create,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('New group', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Lent to groups',
                        value: lent.asNaira,
                        icon: Icons.groups_2_outlined,
                        footnote: '${_groups.length} groups',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricTile(
                        label: 'Still owed',
                        value: owed.asNaira,
                        icon: Icons.hourglass_bottom_rounded,
                        tint: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: AppColors.danger))
                else if (_groups.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'No groups yet',
                    message: 'Open a group, name its officer, and enter its borrowers.',
                  )
                else
                  for (final g in _groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: KCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AdminGroupScreen(groupId: g.id)),
                          );
                          if (mounted) unawaited(_load());
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.goldWash,
                              child: Text('${g.number}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                      if (!g.active) ...[
                                        const SizedBox(width: 6),
                                        StatusPill(label: 'CLOSED', color: AppColors.textTertiary, dense: true),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    [
                                      if (g.area.isNotEmpty) g.area,
                                      g.officerName,
                                      '${g.members} members · ${g.signedUp} signed up',
                                    ].join(' · '),
                                    style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(g.outstanding.asNaira, style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (g.overdueMembers > 0)
                                  Text(
                                    '${g.overdueMembers} behind',
                                    style: TextStyle(fontSize: 11, color: AppColors.danger),
                                  ),
                              ],
                            ),
                          ],
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

/// Opens a group, or edits one.
class _GroupSheet extends StatefulWidget {
  const _GroupSheet({this.group});
  final LoanGroup? group;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _area = TextEditingController(text: widget.group?.area ?? '');
  late final _description = TextEditingController(text: widget.group?.description ?? '');
  late String? _officerId = widget.group?.officerId;
  List<OfficerOption> _options = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      try {
        final o = await context.read<AppState>().adminApi?.officerOptions();
        if (mounted && o != null) setState(() => _options = o);
      } on ApiException {
        // Without the list there is nobody to choose; the button stays off.
      }
    }());
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    setState(() => _busy = true);
    try {
      final g = widget.group;
      final detail = g == null
          ? await admin.createGroup(
              name: _name.text.trim(),
              area: _area.text,
              description: _description.text,
              officerId: _officerId!,
            )
          : await admin.updateGroup(
              g.id,
              name: _name.text.trim(),
              area: _area.text.trim(),
              description: _description.text.trim(),
              officerId: _officerId,
            );
      if (mounted) Navigator.pop(context, detail);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final officer = _options.where((o) => o.id == _officerId).firstOrNull;
    return Padding(
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
            Text(widget.group == null ? 'Open a group' : 'Edit the group', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            KField(label: 'Name — the market it is in, say', controller: _name, onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.md),
            KField(label: 'Area (optional)', controller: _area),
            const SizedBox(height: AppSpacing.md),
            KField(label: 'Description (optional)', controller: _description),
            const SizedBox(height: AppSpacing.md),
            KPickerField(
              label: 'Loan officer',
              value: officer?.name ?? (widget.group?.officerName),
              hint: 'Choose',
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheet) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final o in _options)
                          ListTile(
                            title: Text(o.name),
                            subtitle: Text('${o.roleLabel} · ${o.borrowers} borrowers'),
                            onTap: () => Navigator.pop(sheet, o.id),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null) setState(() => _officerId = picked);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: widget.group == null ? 'Open the group' : 'Save',
              loading: _busy,
              onPressed: _name.text.trim().isNotEmpty && _officerId != null ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// One group and every borrower in it.
class AdminGroupScreen extends StatefulWidget {
  const AdminGroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<AdminGroupScreen> createState() => _AdminGroupScreenState();
}

class _AdminGroupScreenState extends State<AdminGroupScreen> {
  LoanGroupDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    try {
      final d = await admin.group(widget.groupId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _apply(Future<LoanGroupDetail> Function() act, String done) async {
    try {
      final d = await act();
      if (!mounted) return;
      setState(() => _detail = d);
      showToast(context, done);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _addCustomer() async {
    final controller = TextEditingController();
    final ref = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a customer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Their customer reference, K9-…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ref == null || ref.isEmpty) return;
    if (!mounted) return;
    final admin = context.read<AppState>().adminApi!;
    await _apply(() => admin.addToGroup(widget.groupId, ref), 'Added to the group');
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppState>().adminApi;
    final d = _detail;
    final g = d?.group;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.title ?? 'Loan group'),
        actions: [
          if (g != null && g.canManage)
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    final updated = await showModalBottomSheet<LoanGroupDetail>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _GroupSheet(group: g),
                    );
                    if (updated != null && mounted) setState(() => _detail = updated);
                  case 'close':
                    await _apply(() => admin!.updateGroup(g.id, active: !g.active), g.active ? 'Group closed' : 'Group reopened');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'close', child: Text(g.active ? 'Close the group' : 'Reopen the group')),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: d == null
              ? Center(
                  child: _error != null ? Text(_error!, style: TextStyle(color: AppColors.danger)) : const CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      KCard(
                        gradient: AppColors.cardGradient,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Run by ${g!.officerName}${g.officerStillOnTeam ? '' : ' (no longer on the team)'}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (g.area.isNotEmpty || g.description.isNotEmpty)
                              Text(
                                [g.area, g.description].where((s) => s.isNotEmpty).join(' · '),
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '${g.members} members · ${g.signedUp} signed up · ${g.totalLent.asNaira} lent · '
                              '${g.outstanding.asNaira} owed'
                              '${g.overdueMembers > 0 ? ' · ${g.overdueMembers} behind' : ''}',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (g.canManage) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: GhostButton(
                                label: 'Add a customer',
                                icon: Icons.person_add_alt_rounded,
                                onPressed: _addCustomer,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: GoldButton(
                                label: 'Enter a loan',
                                icon: Icons.post_add_rounded,
                                height: 54,
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => AdminNewOfflineLoanScreen(group: g)),
                                  );
                                  if (mounted) unawaited(_load());
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      const AdminSectionLabel('MEMBERS'),
                      if (d.members.isEmpty)
                        Text('Nobody in this group yet.', style: TextStyle(color: AppColors.textTertiary))
                      else
                        KCard(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Column(
                            children: [
                              for (var i = 0; i < d.members.length; i++) ...[
                                if (i > 0) const HairLine(),
                                _Member(
                                  member: d.members[i],
                                  canManage: g.canManage,
                                  onRemove: () async {
                                    final m = d.members[i];
                                    if (await confirmAction(
                                      context,
                                      title: 'Take ${m.name} out?',
                                      message: 'Their loan is unchanged.',
                                      confirm: 'Take out',
                                      danger: true,
                                    )) {
                                      await _apply(() => admin!.removeFromGroup(g.id, m.id), '${m.name} taken out');
                                    }
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

class _Member extends StatelessWidget {
  const _Member({required this.member, required this.canManage, required this.onRemove});
  final LoanGroupMember member;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final m = member;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: m.importedLoanId.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminOfflineLoanScreen(importId: m.importedLoanId)),
            ),
      title: Row(
        children: [
          Flexible(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          StatusPill(
            label: m.signedUp ? 'SIGNED UP' : 'NOT SIGNED UP',
            color: m.signedUp ? AppColors.success : AppColors.info,
            dense: true,
          ),
          if (m.overdue) ...[
            const SizedBox(width: 6),
            StatusPill(label: 'BEHIND', color: AppColors.danger, dense: true),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (m.customerRef.isNotEmpty) m.customerRef,
          if (m.phone.isNotEmpty) m.phone,
          '${m.lent.asNaira} lent · ${m.outstanding.asNaira} owed',
          if (m.nextDue != null) 'next due ${m.nextDue!.asDay}',
        ].join(' · '),
        style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
      ),
      trailing: canManage
          ? IconButton(
              tooltip: 'Take out of the group',
              icon: Icon(Icons.person_remove_alt_1_outlined, color: AppColors.textTertiary),
              onPressed: onRemove,
            )
          : null,
    );
  }
}
