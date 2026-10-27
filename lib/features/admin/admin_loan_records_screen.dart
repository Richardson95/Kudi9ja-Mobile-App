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
import '../../widgets/primitives.dart';
import 'admin_lending_widgets.dart';

/// What sits on a loan beyond its figures: the documents attached to it, and
/// the repayments that came in outside the app.
class AdminLoanRecordsScreen extends StatefulWidget {
  const AdminLoanRecordsScreen({
    super.key,
    required this.loanId,
    required this.title,
    required this.outstanding,
  });

  final String loanId;
  final String title;
  final double outstanding;

  @override
  State<AdminLoanRecordsScreen> createState() => _AdminLoanRecordsScreenState();
}

class _AdminLoanRecordsScreenState extends State<AdminLoanRecordsScreen> {
  LoanRecords? _records;
  late double _outstanding = widget.outstanding;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    try {
      final r = await admin.loanRecords(widget.loanId);
      if (mounted) setState(() => _records = r);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showToast(context, done);
      await _load();
      if (mounted) unawaited(context.read<AppState>().refreshAdminPanel());
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final admin = app.adminApi;
    final canAct = app.adminRole.canActOnLoans;
    final r = _records;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: r == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    if (canAct && _outstanding > 0.005) ...[
                      GoldButton(
                        label: 'Record a repayment',
                        icon: Icons.payments_outlined,
                        onPressed: () async {
                          final entry = await askForRepayment(context, outstanding: _outstanding);
                          if (entry == null) return;
                          await _run(() => admin!.recordOnLoan(widget.loanId, entry), '${entry.amount.asNaira} recorded');
                          setState(() => _outstanding -= entry.amount);
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Title('REPAYMENTS RECORDED BY HAND'),
                          RecordedRepaymentsList(
                            repayments: r.repayments,
                            onRemove: !canAct
                                ? null
                                : (p) async {
                                    if (await confirmAction(
                                      context,
                                      title: 'Take this repayment back?',
                                      message: '${p.amount.asNaira} comes off what was repaid.',
                                      confirm: 'Take back',
                                      danger: true,
                                    )) {
                                      await _run(() => admin!.removeRecordedRepayment(p.id), 'Repayment removed');
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: _Title('DOCUMENTS')),
                              if (canAct)
                                TextButton.icon(
                                  onPressed: () async {
                                    final done = await pickAndUploadDocument(
                                      context,
                                      upload: (bytes, name, type, label) => admin!.attachToLoan(
                                        widget.loanId,
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
                                ),
                            ],
                          ),
                          DocumentsList(
                            documents: r.documents,
                            onRemove: !canAct
                                ? null
                                : (d) async {
                                    if (await confirmAction(
                                      context,
                                      title: 'Remove ${d.label}?',
                                      message: 'It is taken off this loan.',
                                      confirm: 'Remove',
                                      danger: true,
                                    )) {
                                      await _run(() => admin!.removeDocument(d.id), 'Document removed');
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: AppColors.textTertiary),
    ),
  );
}
