import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan_application.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/primitives.dart';

/// Applications waiting on a decision.
///
/// This is where money is created out of a promise, so it is the most
/// consequential screen in the panel. The queue is deliberately thin — enough
/// to triage, not enough to decide on. Deciding happens on the file, which is
/// fetched on its own and carries the statement, the photographs and both
/// guarantors.
class AdminLoanApplicationsSection extends StatelessWidget {
  const AdminLoanApplicationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pending = app.adminLoanApplications.where((a) => a.isPending).toList();

    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Applications to borrow (${pending.length})'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Read the statement and the pictures before you decide. Approving '
          'puts the money in their wallet straight away.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final application in pending) ...[
          _ApplicationRow(application: application),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application});

  final LoanApplication application;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: InkWell(
        onTap: () => _openFile(context, application),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.amount.asNaira,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusPill(
                  label: application.status.label.toUpperCase(),
                  color: AppColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${application.customerName} · ${application.businessName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Over ${application.tenureMonths} months · '
                  '${application.purpose}',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
                const Spacer(),
                Text(
                  'Open file',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.gold),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the whole file, fetched on demand.
///
/// On demand rather than with the queue, deliberately: a signed link to every
/// customer's bank statement minted because somebody scrolled past their row is
/// exactly what signing the links is meant to prevent.
Future<void> _openFile(BuildContext context, LoanApplication row) async {
  final app = context.read<AppState>();
  final full = await app.loadLoanApplication(row.id);
  if (!context.mounted) return;
  if (full == null) {
    showToast(context, app.lastError ?? 'That application could not be opened.',
        error: true);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AdminLoanApplicationScreen(application: full)),
  );
}

/// One application, in full, with the two buttons that decide it.
class AdminLoanApplicationScreen extends StatefulWidget {
  const AdminLoanApplicationScreen({super.key, required this.application});

  final LoanApplication application;

  @override
  State<AdminLoanApplicationScreen> createState() =>
      _AdminLoanApplicationScreenState();
}

class _AdminLoanApplicationScreenState extends State<AdminLoanApplicationScreen> {
  bool _busy = false;

  LoanApplication get _a => widget.application;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve this loan?'),
        content: Text(
          '${_a.amount.asNaira} goes into ${_a.customerName}’s wallet as soon '
          'as you confirm, less the management fee. There is no undo — only '
          'their own change-of-mind window.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Approve', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final app = context.read<AppState>();
    final ok = await app.approveLoanApplication(_a.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
      showToast(context, '${_a.amount.asNaira} credited to ${_a.customerName}');
    } else {
      showToast(context, app.lastError ?? 'That could not be approved.',
          error: true);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final app = context.read<AppState>();
    final ok = await app.rejectLoanApplication(_a.id, reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
      showToast(context, 'Declined. ${_a.customerName} has been told why.');
    } else {
      showToast(context, app.lastError ?? 'That could not be declined.',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = context.read<AppState>().receiptHeaders;

    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _a.amount.asNaira,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'over ${_a.tenureMonths} months for ${_a.purpose}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                const HairLine(),
                const SizedBox(height: AppSpacing.md),
                _Row('Customer', _a.customerName),
                _Row('Account', _a.customerRef),
                _Row('Submitted', _a.submittedAt.asDay),
                if (_a.scoreAtSubmission != null)
                  // Advice, not a verdict. The score is one input beside the
                  // statement and the guarantors, and an admin who has read the
                  // file may reasonably disagree with it.
                  _Row('Credit score then', '${_a.scoreAtSubmission}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(title: 'The business'),
          const SizedBox(height: AppSpacing.sm),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('Name', _a.businessName),
                _Row('Address', _a.businessAddress),
                _Row('Monthly income claimed', _a.monthlyIncome.asNaira),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(title: 'Documents'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Check the statement against the income claimed above.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final document in _a.documents) ...[
            _DocumentTile(document: document, headers: headers),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Guarantors'),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _a.guarantors.length; i++) ...[
            _GuarantorCard(index: i + 1, guarantor: _a.guarantors[i]),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xl),

          if (_a.isPending) ...[
            GoldButton(
              label: 'Approve and disburse',
              loading: _busy,
              onPressed: _busy ? null : _approve,
            ),
            const SizedBox(height: AppSpacing.md),
            GhostButton(
              label: 'Decline with a reason',
              danger: true,
              onPressed: _busy ? null : _reject,
            ),
          ] else
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Already ${_a.status.label.toLowerCase()}'
                    '${_a.reviewedBy.isEmpty ? '' : ' by ${_a.reviewedBy}'}.',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (_a.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _a.rejectionReason,
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.headers});

  final ApplicationDocument document;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: InkWell(
        onTap: () => showReceipt(
          context,
          '',
          url: document.url,
          headers: headers,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 54,
                height: 54,
                // Only a picture has a thumbnail to draw. A PDF or a
                // spreadsheet gets an icon rather than a broken image under a
                // document that is perfectly fine.
                child: document.isImage
                    ? ReceiptImage(
                        path: '',
                        url: document.url,
                        headers: headers,
                      )
                    : ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Icon(Icons.description_rounded,
                            color: AppColors.textTertiary),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    document.isImage
                        ? 'Tap to open'
                        : 'Tap to open — ${_typeName(document.contentType)}',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.zoom_in_rounded, size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

/// A short name for a content type, for the line under a document.
String _typeName(String contentType) {
  final type = contentType.toLowerCase();
  if (type.contains('pdf')) return 'PDF';
  if (type.contains('word') || type.contains('msword')) return 'Word document';
  if (type.contains('sheet') || type.contains('excel')) return 'spreadsheet';
  if (type.contains('csv')) return 'CSV';
  if (type.contains('opendocument')) return 'document';
  return 'file';
}

class _GuarantorCard extends StatelessWidget {
  const _GuarantorCard({required this.index, required this.guarantor});

  final int index;
  final Guarantor guarantor;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantor $index — ${guarantor.fullName}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row('Phone', guarantor.phone),
          _Row('Relationship', guarantor.relationship),
          _Row('Address', guarantor.address),
          if (guarantor.occupation.isNotEmpty)
            _Row('Occupation', guarantor.occupation),
          // Recorded as given, never checked against the issuer — we have no
          // consent from this person to ask about them.
          _Row('BVN (unverified)', guarantor.bvn),
        ],
      ),
    );
  }
}

/// The reason a refusal has to carry.
///
/// The customer is shown exactly what is typed here, so the dialog says so.
/// Ten characters is not a quality bar, it is a guard against "no".
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enough = _reason.text.trim().length >= 10;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Why are you declining?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The customer reads this word for word. Tell them what to fix, so '
            'they can send a better application.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 4,
            maxLength: 1000,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'The statement covers one month. Send three, and make '
                  'sure the account name matches your profile.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              enough ? () => Navigator.pop(context, _reason.text.trim()) : null,
          child: Text(
            'Decline',
            style: TextStyle(
                color: enough ? AppColors.danger : AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
