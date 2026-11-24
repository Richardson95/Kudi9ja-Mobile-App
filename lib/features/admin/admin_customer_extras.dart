import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/admin.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/file_opener.dart';
import '../../widgets/primitives.dart';
import 'admin_groups_screen.dart';
import 'admin_lending_widgets.dart';
import 'admin_new_offline_loan_screen.dart';
import 'admin_offline_loans_screen.dart';
import 'admin_paystack_list.dart';
import 'admin_shell.dart';
import 'admin_support_screen.dart';

/// Everything about a customer that the panel learned to keep since the
/// record was first drawn: who looks after them, the groups they borrow in,
/// loans and repayments entered by hand, what they signed, and how they paid.
class CustomerExtras extends StatefulWidget {
  const CustomerExtras({super.key, required this.customer});
  final CustomerRecord customer;

  @override
  State<CustomerExtras> createState() => _CustomerExtrasState();
}

class _CustomerExtrasState extends State<CustomerExtras> {
  List<SignatureRecord> _signatures = const [];
  List<LoanGroup> _groups = const [];
  LoanRecords _records = const LoanRecords();
  List<Map<String, dynamic>> _facePhotos = const [];
  Map<String, dynamic>? _credit;
  bool _checking = false;
  bool _showPaystack = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    final id = widget.customer.id;
    Future<T?> quietly<T>(Future<T> Function() read) async {
      try {
        return await read();
      } on ApiException {
        return null;
      }
    }

    final results = await Future.wait([
      quietly(() => admin.customerSignatures(id)),
      quietly(() => admin.customerGroups(id)),
      quietly(() => admin.customerLoanRecords(id)),
      quietly(() => admin.customerFacePhotos(id)),
      quietly(() => admin.customerCreditChecks(id)),
    ]);
    if (!mounted) return;
    setState(() {
      _signatures = (results[0] as List<SignatureRecord>?) ?? const [];
      _groups = (results[1] as List<LoanGroup>?) ?? const [];
      _records = (results[2] as LoanRecords?) ?? const LoanRecords();
      _facePhotos = (results[3] as List<Map<String, dynamic>>?) ?? const [];
      _credit = results[4] as Map<String, dynamic>?;
    });
  }

  Future<void> _runCreditCheck() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Check credit score?'),
        content: const Text(
          'Looks up the customer\'s BVN with the credit bureaus through Dojah. Each check is charged to the Dojah wallet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Check')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    setState(() => _checking = true);
    try {
      await admin.runCreditCheck(widget.customer.id);
      final fresh = await admin.customerCreditChecks(widget.customer.id);
      if (!mounted) return;
      setState(() => _credit = fresh);
      showToast(context, 'Credit score updated');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _creditCard(bool canAct) {
    final checks = (_credit?['checks'] as List?) ?? const [];
    final available = _credit?['available'] == true;
    final latest = checks.isEmpty ? null : Map<String, dynamic>.from(checks.first as Map);
    final muted = TextStyle(color: AppColors.textSecondary, height: 1.5);
    String when(Map<String, dynamic> c) =>
        '${DateTime.tryParse('${c['checkedAt']}')?.toLocal().asDayTime ?? ''} by ${c['checkedBy']}';
    Widget row(String k, Object? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(k, style: muted)),
              Flexible(child: Text(v == null ? '-' : '$v', textAlign: TextAlign.right)),
            ],
          ),
        );
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest == null)
            Text(available ? 'Not checked yet.' : 'Credit checks are not set up on the server yet.', style: muted)
          else if (latest['found'] != true)
            Text('The credit bureaus hold no record for this BVN. Checked ${when(latest)}.', style: muted)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${latest['score'] ?? '-'}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.md),
                if (latest['rating'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${latest['rating']}',
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            row('Has loans', latest['hasLoans']),
            row('Loans in arrears', latest['delinquentFacilities']),
            row('Last reported', latest['lastReported']),
            row('Checked', when(latest)),
            if (latest['reasons'] != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('${latest['reasons']}', style: muted.copyWith(fontSize: 13)),
            ],
          ],
          if (canAct && available) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _checking ? null : _runCreditCheck,
              child: Text(_checking ? 'Checking...' : latest == null ? 'Check' : 'Check again'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.isOnline) return const SizedBox.shrink();
    final c = widget.customer;
    final canAct = app.adminRole.canActOnLoans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const AdminSectionLabel('CREDIT SCORE'),
        _creditCard(canAct),
        const SizedBox(height: AppSpacing.xl),
        const AdminSectionLabel('FACE CHECK'),
        KCard(
          child: _facePhotos.isEmpty
              ? Text(
                  'No face check photos. Accounts opened before the face check, or by the team, have none.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                )
              : Column(
                  children: [
                    for (final p in _facePhotos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.face_retouching_natural, color: AppColors.gold),
                        title: Text(_poseLabel('${p['pose']}')),
                        subtitle: Text(DateTime.tryParse('${p['capturedAt']}')?.toLocal().asDayTime ?? ''),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        // The link is signed and every view of it is audited.
                        onTap: () => openAuthedFile(
                          context,
                          url: '${p['url']}',
                          label: '${_poseLabel('${p['pose']}')} of ${c.fullName}',
                          contentType: 'image/jpeg',
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AdminSectionLabel('WHO LOOKS AFTER THEM'),
        OfficersPanel(customerId: c.id, canEdit: canAct),
        if (_groups.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOAN GROUPS',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: AppColors.textTertiary),
                ),
                for (final g in _groups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(g.title),
                    subtitle: Text('Run by ${g.officerName}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminGroupScreen(groupId: g.id)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (!_records.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminSectionLabel('ENTERED AND RECORDED BY HAND'),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in _records.importedLoans)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.description_outlined, color: AppColors.gold),
                    title: Text('${l.principal.asNaira} · ${l.purpose}'),
                    subtitle: Text('${l.termPhrase} · ${l.outstanding.asNaira} owed'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminOfflineLoanScreen(importId: l.id)),
                    ),
                  ),
                if (_records.repayments.isNotEmpty) RecordedRepaymentsList(repayments: _records.repayments),
                if (_records.documents.isNotEmpty) DocumentsList(documents: _records.documents),
              ],
            ),
          ),
        ],
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminSectionLabel('SIGNED AGREEMENTS'),
          KCard(
            child: Column(
              children: [
                for (final s in _signatures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.draw_outlined, color: AppColors.gold),
                    title: Text(s.typedName),
                    subtitle: Text('${s.documents}\n${s.signedAt.asDayTime}'),
                    isThreeLine: true,
                    trailing: s.url.isEmpty ? null : const Icon(Icons.open_in_new_rounded, size: 18),
                    // The link is signed and every view of it is audited.
                    onTap: s.url.isEmpty
                        ? null
                        : () => openAuthedFile(
                            context,
                            url: s.url,
                            label: 'Signature of ${c.fullName}',
                            contentType: 'image/png',
                          ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const AdminSectionLabel('MORE'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.forum_outlined, color: AppColors.gold),
                title: const Text('Conversations with the team'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminSupportScreen(customerId: c.id, customerName: c.fullName),
                  ),
                ),
              ),
              const HairLine(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.credit_card_rounded, color: AppColors.gold),
                title: const Text('Paystack payments'),
                trailing: Icon(_showPaystack ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onTap: () => setState(() => _showPaystack = !_showPaystack),
              ),
              if (_showPaystack) ...[
                AdminPaystackList(customerId: c.id),
                const SizedBox(height: AppSpacing.md),
              ],
              if (canAct) ...[
                const HairLine(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.post_add_rounded, color: AppColors.gold),
                  title: const Text('Enter a past or running loan for them'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminNewOfflineLoanScreen(customerId: c.id, customerName: c.fullName),
                      ),
                    );
                    if (mounted) unawaited(_load());
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _poseLabel(String pose) => switch (pose) {
      'BLINK' => 'Blink',
      'TURN' => 'Head turn',
      'MOUTH' => 'Open mouth',
      _ => pose,
    };

/// Asks why, then changes the account's status on the server.
///
/// The server refuses a change without a reason: it is the record of why a
/// customer could not move their money.
Future<bool> changeCustomerStatus(
  BuildContext context, {
  required CustomerRecord customer,
  required String status,
  required String title,
  required String message,
  required String confirm,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Why — kept on the audit log'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(confirm, style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  controller.dispose();
  if (reason == null || !context.mounted) return false;
  if (reason.isEmpty) {
    showToast(context, 'Say why.', error: true);
    return false;
  }
  final admin = context.read<AppState>().adminApi;
  if (admin == null) return false;
  try {
    if (status == 'FLAGGED') {
      await admin.flagCustomer(customer.id, reason: reason);
    } else {
      await admin.setCustomerStatus(customer.id, status: status, reason: reason);
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return false;
  }
}
