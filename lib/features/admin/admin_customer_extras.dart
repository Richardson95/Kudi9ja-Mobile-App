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
    ]);
    if (!mounted) return;
    setState(() {
      _signatures = (results[0] as List<SignatureRecord>?) ?? const [];
      _groups = (results[1] as List<LoanGroup>?) ?? const [];
      _records = (results[2] as LoanRecords?) ?? const LoanRecords();
    });
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
