import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan_application.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/primitives.dart';
import 'admin_change_terms_sheet.dart';

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
    // Open ones, whichever side they wait on: the team, or a customer
    // answering changed terms. To decide first, then with the customer.
    final pending = [
      ...app.adminLoanApplications.where((a) => a.isPending),
      ...app.adminLoanApplications.where((a) => a.isOffered),
    ];

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
                  label: application.isOffered
                      ? 'WITH CUSTOMER'
                      : application.status.label.toUpperCase(),
                  color: application.isOffered ? AppColors.info : AppColors.gold,
                ),
              ],
            ),
            if (application.isPending && application.hasAgreedTerms) ...[
              const SizedBox(height: 4),
              Text(
                'Customer agreed to changed terms',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
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
                  'Over ${application.tenureMonths} months, '
                  '${application.repaymentFrequency.adjective} · '
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

  /// Replaced when changed terms are sent, so the screen shows the offer.
  late LoanApplication _a = widget.application;

  /// The terms the applicant borrows on: the loan group's, or the standard.
  LendingTerms get _terms =>
      _a.groupPricing ? settings.groupLending : settings.lending;

  /// What it is priced on now: changed terms once sent, agreed or waiting,
  /// else the terms in force for what was asked.
  LoanPreview get _preview {
    final offer = _a.offer;
    return Finance.loanPreview(
      _a.amount,
      _a.pricedMonths,
      frequency: _a.repaymentFrequency,
      terms: _terms,
      flatRate: offer?.flatRate,
      managementFee: offer?.managementFee,
      repaymentFeeRate: offer?.repaymentFeeRate,
    );
  }

  Future<void> _changeTerms() async {
    final updated = await showChangeTermsSheet(
      context,
      application: _a,
      terms: _terms,
    );
    if (updated != null && mounted) setState(() => _a = updated);
  }

  Future<void> _approve() async {
    final p = _preview;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Approve ${_a.amount.asNaira} for ${_a.customerName}?'),
        content: Text(
          '${_a.hasAgreedTerms ? 'On the changed terms they agreed to. ' : ''}'
          '${p.net.asNaira} goes into their Kudi9ja wallet now, after the '
          '${p.fee.asNaira} management fee. They repay ${p.each.asNaira} a '
          '${p.frequency.unit} (${p.base.asNaira} + ${p.instalmentFee.asNaira} '
          'transaction fee) — ${p.frequency.paymentsPhrase(_a.pricedMonths)}, '
          '${p.total.asNaira} in all. There is no undo.',
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

  /// Where changed terms stand, if any were sent.
  List<Widget> _offerNotice() {
    final offer = _a.offer;
    if (offer == null) return const [];
    final (Color color, String title, String body) = switch (_a.status) {
      LoanApplicationStatus.offered => (
          AppColors.info,
          'Waiting for the customer',
          'Changed terms were sent ${offer.offeredAt.asDayTime}'
              '${offer.offeredBy.isEmpty ? '' : ' by ${offer.offeredBy}'}. '
              'It comes back here to approve once they agree; if they turn '
              'them down, it closes.',
        ),
      LoanApplicationStatus.pending when offer.agreed => (
          AppColors.success,
          'The customer agreed to the changed terms',
          'Agreed ${offer.agreedAt!.asDayTime}. Approving lends on these terms.',
        ),
      LoanApplicationStatus.termsDeclined => (
          AppColors.textSecondary,
          'The customer turned down the changed terms',
          'Nothing was lent and the application is closed.',
        ),
      _ => (AppColors.textSecondary, '', ''),
    };
    if (title.isEmpty) return const [];
    return [
      KCard(
        borderColor: color.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            if (offer.note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Note sent: ${offer.note}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  /// The loan as it would be lent, on what it is priced on now.
  Widget _loanCard() {
    final p = _preview;
    final offer = _a.offer;
    final freq = _a.repaymentFrequency;
    final pricedOn = offer != null
        ? 'Changed terms${offer.agreed ? ', agreed' : _a.isOffered ? ', waiting for the customer' : ''}'
        : _a.groupPricing
            ? 'Loan group terms'
            : 'Standard terms';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'The loan'),
        const SizedBox(height: AppSpacing.sm),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row('Term', freq.length(_a.pricedMonths)),
              if (offer != null && offer.months != _a.tenureMonths)
                _Row('Asked for', freq.length(_a.tenureMonths)),
              _Row('Priced on', pricedOn),
              _Row('Repaid', freq.paymentsPhrase(_a.pricedMonths)),
              _Row(offer != null ? 'Rate' : 'Rate today',
                  '${fractionPct(p.rate)} flat'),
              _Row(
                'Each ${freq.unit}',
                '${p.each.asNaira} (${p.base.asNaira} + '
                    '${p.instalmentFee.asNaira} fee)',
              ),
              _Row('Transaction fees (${fractionPct(p.feeRate)} of each repayment)',
                  p.fees.asNaira),
              _Row('Total to repay', p.total.asNaira),
              _Row('Management fee', p.fee.asNaira),
              _Row('Paid out', p.net.asNaira),
            ],
          ),
        ),
      ],
    );
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
                  'over ${_a.tenureMonths} months, repaid '
                  '${_a.repaymentFrequency.adjective}, for ${_a.purpose}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                if (_a.groupPricing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  // Priced on the group's own terms when it is approved.
                  StatusPill(
                    label: 'LOAN GROUP TERMS',
                    color: AppColors.info,
                    dense: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const HairLine(),
                const SizedBox(height: AppSpacing.md),
                // The face beside the name, at the top, where the admin looks
                // first — not the fourth item in a list of documents. This is
                // who the money goes to.
                if (_a.selfie != null) ...[
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => showReceipt(
                          context,
                          '',
                          url: _a.selfie!.url,
                          headers: headers,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: ReceiptImage(
                              path: '',
                              url: _a.selfie!.url,
                              headers: headers,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _a.customerName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _a.customerRef,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the photo to enlarge',
                              style: TextStyle(
                                  fontSize: 10.5, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else ...[
                  _Row('Customer', _a.customerName),
                  _Row('Account', _a.customerRef),
                ],
                _Row('Submitted', _a.submittedAt.asDay),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._offerNotice(),
          _loanCard(),
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
          // The selfie is drawn at the top beside the name, so it is left out
          // here rather than shown twice.
          for (final document in _a.documents)
            if (document != _a.selfie) ...[
              _DocumentTile(
                document: document,
                headers: headers,
                password: document == _a.bankStatement
                    ? _a.statementPassword
                    : '',
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.md),

          SectionHeader(title: _a.guarantors.length == 1 ? 'Guarantor' : 'Guarantors'),
          const SizedBox(height: AppSpacing.sm),
          for (final guarantor in _a.guarantors) ...[
            _GuarantorCard(guarantor: guarantor),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xl),

          if (_a.status.isOpen) ...[
            // With the customer, it can only be re-offered or declined: it
            // comes back here to approve once they agree.
            if (_a.isPending) ...[
              GoldButton(
                label: 'Approve and disburse',
                loading: _busy,
                onPressed: _busy ? null : _approve,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            GhostButton(
              label: _a.isOffered ? 'Change the offer' : 'Change terms',
              icon: Icons.tune_rounded,
              onPressed: _busy ? null : _changeTerms,
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
  const _DocumentTile({
    required this.document,
    required this.headers,
    this.password = '',
  });

  final ApplicationDocument document;
  final Map<String, String> headers;

  /// What opens the file, when the bank locked it. Shown under the tile and
  /// copied on a tap, because the admin is about to be asked for it by the
  /// PDF viewer and a date of birth is easy to mistype.
  final String password;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: InkWell(
        onTap: () => document.isImage
            ? showReceipt(
                context,
                '',
                url: document.url,
                headers: headers,
              )
            : _openFile(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(),
            if (password.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: password));
                  if (context.mounted) {
                    showToast(context, 'Password copied.');
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.key_rounded, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      'Opens with  ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                    Text(
                      password,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap to copy',
                      style: TextStyle(fontSize: 11, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens a document that is not a picture — a PDF statement, usually.
  ///
  /// The image viewer cannot draw one, and the link needs the admin's session,
  /// so it cannot be handed to a browser either. It is fetched here, saved to
  /// the app's cache, and opened with whatever the phone reads that type with.
  Future<void> _openFile(BuildContext context) async {
    showToast(context, 'Opening ${document.label}...');
    try {
      final response =
          await http.get(Uri.parse(document.url), headers: headers);
      if (response.statusCode != 200) {
        if (context.mounted) {
          // Only a 403 is an expired link. Anything else is the file not
          // coming back from storage, and reopening will not change that.
          showToast(
            context,
            response.statusCode == 403
                ? 'This link has expired — go back and open the application again.'
                : 'This document could not be fetched (${response.statusCode}). '
                    'Try again in a moment.',
            error: true,
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final name = document.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final file = File('${dir.path}/$name${_extension(document.contentType)}');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      final result = await OpenFilex.open(
        file.path,
        type: document.contentType.isEmpty ? null : document.contentType,
      );
      if (result.type != ResultType.done && context.mounted) {
        showToast(
          context,
          result.type == ResultType.noAppToOpen
              ? 'No app on this phone opens ${_typeName(document.contentType)} files.'
              : 'The document could not be opened.',
          error: true,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showToast(
          context,
          'This document could not be downloaded. Check your connection '
          'and try again.',
          error: true,
        );
      }
    }
  }

  Widget _row() {
    return Row(
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
        );
  }
}

/// The file extension a saved document needs, so the phone knows what opens it.
String _extension(String contentType) {
  final type = contentType.toLowerCase();
  if (type.contains('pdf')) return '.pdf';
  if (type.contains('openxmlformats-officedocument.wordprocessingml')) {
    return '.docx';
  }
  if (type.contains('msword')) return '.doc';
  if (type.contains('openxmlformats-officedocument.spreadsheetml')) {
    return '.xlsx';
  }
  if (type.contains('excel')) return '.xls';
  if (type.contains('csv')) return '.csv';
  return '';
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
  const _GuarantorCard({required this.guarantor});

  final Guarantor guarantor;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guarantor.fullName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row('Phone', guarantor.phone),
          _Row('Relationship', guarantor.relationship),
          _Row('Address', guarantor.address),
          _Row('State', guarantor.state),
          _Row('Local government', guarantor.localGovernment),
          _Row('Landmark', guarantor.landmark),
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
