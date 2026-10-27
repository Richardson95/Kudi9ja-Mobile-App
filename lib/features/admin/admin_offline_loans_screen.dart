import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/admin.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_lending_widgets.dart';
import 'admin_new_offline_loan_screen.dart';

/// Every loan entered from paper: those waiting for their borrower to sign
/// up, and those already on an account.
class AdminOfflineLoansScreen extends StatefulWidget {
  const AdminOfflineLoansScreen({super.key});

  @override
  State<AdminOfflineLoansScreen> createState() => _AdminOfflineLoansScreenState();
}

class _AdminOfflineLoansScreenState extends State<AdminOfflineLoansScreen> {
  bool? _claimed = false;
  List<ImportedLoan> _rows = [];
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await admin.importedLoans(claimed: _claimed);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
    final canAct = context.watch<AppState>().adminRole.canActOnLoans;
    final owed = _rows.fold(0.0, (s, l) => s + l.outstanding);
    return Scaffold(
      appBar: AppBar(title: const Text('Loans from paper')),
      floatingActionButton: canAct
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnGold,
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Enter a loan', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () async {
                await Navigator.of(context).push(slideRoute(const AdminNewOfflineLoanScreen()));
                if (mounted) unawaited(_load());
              },
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 100),
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final (label, value) in const [
                      ('Waiting to be claimed', false),
                      ('On an account', true),
                      ('All', null),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _claimed == value,
                        onSelected: (_) {
                          setState(() => _claimed = value);
                          unawaited(_load());
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_loading && _error == null && _rows.isNotEmpty)
                  Text(
                    '${_rows.length} loan${_rows.length == 1 ? '' : 's'} · ${owed.asNaira} still owed',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: AppColors.danger))
                else if (_rows.isEmpty)
                  const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Nothing here',
                    message: 'Loans written outside the app appear here once entered.',
                  )
                else
                  for (final l in _rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: KCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            slideRoute(AdminOfflineLoanScreen(importId: l.id)),
                          );
                          if (mounted) unawaited(_load());
                        },
                        child: Row(
                          children: [
                            IconBadge(
                              icon: l.claimed ? Icons.verified_user_outlined : Icons.hourglass_empty_rounded,
                              color: l.claimed ? AppColors.success : AppColors.info,
                              size: 42,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${l.principal.asNaira} · ${l.termPhrase} · ${l.purpose}',
                                    style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(l.outstanding.asNaira,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  l.isOpen ? 'owed' : 'repaid',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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

/// One paper loan with its whole file: the terms, the borrower, guarantors,
/// officers, documents and every repayment that came in by hand.
class AdminOfflineLoanScreen extends StatefulWidget {
  const AdminOfflineLoanScreen({super.key, required this.importId});
  final String importId;

  @override
  State<AdminOfflineLoanScreen> createState() => _AdminOfflineLoanScreenState();
}

class _AdminOfflineLoanScreenState extends State<AdminOfflineLoanScreen> {
  OfflineLoanFile? _file;
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
      final f = await admin.importedLoan(widget.importId);
      if (mounted) setState(() => _file = f);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showToast(context, done);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _editContact(ImportedLoan l) async {
    final admin = context.read<AppState>().adminApi!;
    final phone = TextEditingController(text: l.phone);
    final email = TextEditingController(text: l.email);
    final address = TextEditingController(text: l.address);
    final notes = TextEditingController(text: l.notes);
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(sheet).viewInsets.bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Correct the file', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              TextField(
                controller: notes,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: AppSpacing.lg),
              GoldButton(label: 'Save', onPressed: () => Navigator.pop(sheet, true)),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      await _run(
        () async => admin.updateImportedLoan(widget.importId, {
          'phone': phone.text.trim(),
          'email': email.text.trim().isEmpty ? null : email.text.trim(),
          'address': address.text.trim(),
          'notes': notes.text.trim(),
        }..removeWhere((_, v) => v == null)),
        'File updated',
      );
    }
    for (final c in [phone, email, address, notes]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final admin = app.adminApi;
    final canAct = app.adminRole.canActOnLoans;
    final f = _file;

    return Scaffold(
      appBar: AppBar(
        title: Text(f?.loan.fullName ?? 'Loan file'),
        actions: [
          if (f != null && canAct)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final l = f.loan;
                switch (v) {
                  case 'edit':
                    await _editContact(l);
                  case 'delete':
                    if (await confirmAction(
                      context,
                      title: 'Remove this entry?',
                      message: 'Nobody has claimed it yet. It is removed, and the removal is audited.',
                      confirm: 'Remove',
                      danger: true,
                    )) {
                      try {
                        await admin!.deleteImportedLoan(l.id);
                        if (context.mounted) Navigator.pop(context);
                      } on ApiException catch (e) {
                        if (context.mounted) showToast(context, e.message, error: true);
                      }
                    }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Correct the file')),
                if (!f.loan.claimed)
                  const PopupMenuItem(value: 'delete', child: Text('Remove the entry')),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: f == null
              ? Center(
                  child: _error != null
                      ? Text(_error!, style: TextStyle(color: AppColors.danger))
                      : const CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      _Summary(loan: f.loan),
                      const SizedBox(height: AppSpacing.lg),
                      if (canAct && f.loan.isOpen)
                        GoldButton(
                          label: 'Record a repayment',
                          icon: Icons.payments_outlined,
                          onPressed: () async {
                            final entry = await askForRepayment(context, outstanding: f.loan.outstanding);
                            if (entry == null) return;
                            await _run(
                              () => f.loan.claimed && f.loan.loanId.isNotEmpty
                                  ? admin!.recordOnLoan(f.loan.loanId, entry)
                                  : admin!.recordOnImport(f.loan.id, entry),
                              '${entry.amount.asNaira} recorded',
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      _Section(
                        title: 'REPAYMENTS RECORDED BY HAND',
                        child: RecordedRepaymentsList(
                          repayments: f.repayments,
                          onRemove: !canAct
                              ? null
                              : (r) async {
                                  if (await confirmAction(
                                    context,
                                    title: 'Take this repayment back?',
                                    message: '${r.amount.asNaira} comes off what was repaid. A loan it had closed runs again.',
                                    confirm: 'Take back',
                                    danger: true,
                                  )) {
                                    await _run(() => admin!.removeRecordedRepayment(r.id), 'Repayment removed');
                                  }
                                },
                        ),
                      ),
                      _Section(
                        title: 'DOCUMENTS',
                        action: canAct
                            ? TextButton.icon(
                                onPressed: () async {
                                  final done = await pickAndUploadDocument(
                                    context,
                                    upload: (bytes, name, type, label) => admin!.attachToImport(
                                      f.loan.id,
                                      bytes: bytes,
                                      filename: name,
                                      contentType: type,
                                      label: label,
                                    ),
                                  );
                                  if (done) await _load();
                                },
                                icon: const Icon(Icons.attach_file_rounded, size: 16),
                                label: const Text('Attach'),
                              )
                            : null,
                        child: DocumentsList(
                          documents: f.documents,
                          onRemove: !canAct
                              ? null
                              : (d) async {
                                  if (await confirmAction(
                                    context,
                                    title: 'Remove ${d.label}?',
                                    message: 'It is taken off this loan file.',
                                    confirm: 'Remove',
                                    danger: true,
                                  )) {
                                    await _run(() => admin!.removeDocument(d.id), 'Document removed');
                                  }
                                },
                        ),
                      ),
                      OfficersPanel(
                        importId: f.loan.id,
                        customerId: f.loan.claimed && f.loan.customerId.isNotEmpty ? f.loan.customerId : null,
                        canEdit: canAct,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Section(title: 'THE BORROWER', child: _Borrower(loan: f.loan)),
                      if (f.loan.guarantors.isNotEmpty)
                        _Section(
                          title: f.loan.guarantors.length == 1 ? 'GUARANTOR' : 'GUARANTORS',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final g in f.loan.guarantors)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        [
                                          if (g.relationship.isNotEmpty) g.relationship,
                                          if (g.phone.isNotEmpty) g.phone,
                                          if (g.address.isNotEmpty) g.address,
                                          if (g.state.isNotEmpty) g.state,
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.loan});
  final ImportedLoan loan;

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final progress = l.totalRepayable <= 0 ? 0.0 : (l.amountRepaid / l.totalRepayable).clamp(0.0, 1.0);
    return KCard(
      gradient: AppColors.cardGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Still owed', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ),
              StatusPill(
                label: l.claimed ? 'ON AN ACCOUNT' : 'WAITING FOR SIGN-UP',
                color: l.claimed ? AppColors.success : AppColors.info,
                dense: true,
              ),
            ],
          ),
          Text(
            l.outstanding.asNaira,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: progress, minHeight: 6),
          const SizedBox(height: AppSpacing.md),
          _Kv('Lent', l.principal.asNaira),
          _Kv('Term', l.termPhrase),
          _Kv('Flat rate', '${(l.flatRate * 100).toStringAsFixed(1)}%'),
          _Kv('Management fee', l.processingFee.asNaira),
          if (l.transactionFee > 0) _Kv('Fee taken at payout', l.transactionFee.asNaira),
          if (l.repaymentFeeRate > 0)
            _Kv('Transaction fee', '${(l.repaymentFeeRate * 100).toStringAsFixed(1)}% of each repayment · ${l.repaymentFees.asNaira} in all'),
          _Kv('Received', l.netDisbursed.asNaira),
          _Kv('To repay', l.totalRepayable.asNaira),
          _Kv('Repaid', l.amountRepaid.asNaira),
          if (l.disbursedAt != null) _Kv('Paid out', l.disbursedAt!.asDay),
          if (l.dueDate != null) _Kv('Last due', l.dueDate!.asDay),
          _Kv('Purpose', l.purpose),
          if (l.importedBy.isNotEmpty)
            _Kv('Entered', '${l.importedBy}${l.importedAt == null ? '' : ' · ${l.importedAt!.asDay}'}'),
        ],
      ),
    );
  }
}

class _Borrower extends StatelessWidget {
  const _Borrower({required this.loan});
  final ImportedLoan loan;

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return Column(
      children: [
        if (l.bvnLast4.isNotEmpty) _Kv('BVN', '••••••• ${l.bvnLast4}'),
        if (l.ninLast4.isNotEmpty) _Kv('NIN', '••••••• ${l.ninLast4}'),
        if (l.phone.isNotEmpty) _Kv('Phone', l.phone),
        if (l.email.isNotEmpty) _Kv('Email', l.email),
        if (l.dateOfBirth != null) _Kv('Born', l.dateOfBirth!.asDay),
        if (l.gender.isNotEmpty) _Kv('Gender', l.gender),
        if (l.address.isNotEmpty) _Kv('Address', [l.address, if (l.state.isNotEmpty) l.state].join(', ')),
        if (l.occupation.isNotEmpty) _Kv('Occupation', l.occupation),
        if (l.businessName.isNotEmpty) _Kv('Business', [l.businessName, if (l.businessAddress.isNotEmpty) l.businessAddress].join(', ')),
        if (l.monthlyIncome > 0) _Kv('Monthly income', l.monthlyIncome.asNaira),
        if (l.payoutAccountNumber.isNotEmpty) _Kv('Bank', '${l.payoutBank} · ${l.payoutAccountNumber}'),
        if (l.notes.isNotEmpty) _Kv('Notes', l.notes),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
