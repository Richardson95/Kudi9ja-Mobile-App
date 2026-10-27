import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/file_opener.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// What a document attached to a loan's file is.
const kDocumentLabels = [
  'Loan agreement',
  'Bank statement',
  'ID card',
  'Passport photo',
  'Utility bill',
  'Business photo',
  'Guarantor form',
  'Other',
];

/// A repayment taken outside the app — cash at the shop, a transfer straight
/// to the company account. Payments through Paystack are applied by
/// themselves and never need this. Returns the entry, or null if cancelled.
Future<RepaymentEntry?> askForRepayment(
  BuildContext context, {
  required double outstanding,
}) {
  return showModalBottomSheet<RepaymentEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RepaymentSheet(outstanding: outstanding),
  );
}

class _RepaymentSheet extends StatefulWidget {
  const _RepaymentSheet({required this.outstanding});
  final double outstanding;

  @override
  State<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<_RepaymentSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  RepaymentMethod _method = RepaymentMethod.cash;
  DateTime _paidOn = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _today {
    final now = DateTime.now();
    return _paidOn.year == now.year && _paidOn.month == now.month && _paidOn.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final value = parseAmount(_amount.text);
    final tooMuch = value > widget.outstanding + 0.005;
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
            Text('Record a repayment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Money that came in outside the app. It is applied to the loan '
              'and never touches a wallet. ${widget.outstanding.asNaira} is owed.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AmountField(controller: _amount, onChanged: (_) => setState(() {})),
            if (tooMuch)
              Text(
                'That is more than is owed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.danger),
              ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in RepaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            KPickerField(
              label: 'Paid on',
              value: _paidOn.asDay,
              icon: Icons.event_rounded,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _paidOn,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _paidOn = picked);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            KField(label: 'Reference (optional)', controller: _reference),
            const SizedBox(height: AppSpacing.md),
            KField(label: 'Note (optional)', controller: _note),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: 'Record ${value > 0 ? value.asNaira : ''}',
              onPressed: value > 0 && !tooMuch
                  ? () => Navigator.pop(
                      context,
                      RepaymentEntry(
                        amount: value,
                        method: _method,
                        // Today means now; an earlier day is recorded at
                        // midday, so no time zone moves it.
                        paidAt: _today
                            ? null
                            : DateTime(_paidOn.year, _paidOn.month, _paidOn.day, 12),
                        reference: _reference.text,
                        note: _note.text,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks a file, asks what it is, and hands it to [upload]. Returns whether
/// something was uploaded.
Future<bool> pickAndUploadDocument(
  BuildContext context, {
  required Future<void> Function(List<int> bytes, String filename, String? type, String label)
      upload,
}) async {
  final label = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('What is it?')),
          for (final l in kDocumentLabels)
            ListTile(title: Text(l), onTap: () => Navigator.pop(sheetContext, l)),
        ],
      ),
    ),
  );
  if (label == null) return false;
  final picked = await FilePicker.platform.pickFiles();
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return false;
  final bytes = await File(path).readAsBytes();
  if (bytes.length > 12 * 1024 * 1024) {
    if (context.mounted) showToast(context, 'That file is over 12 MB.', error: true);
    return false;
  }
  final name = path.split(RegExp(r'[/\\]')).last;
  try {
    await upload(bytes, name, _typeOf(name), label);
    if (context.mounted) showToast(context, '$label attached.');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return false;
  }
}

String? _typeOf(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.csv')) return 'text/csv';
  return null;
}

/// Documents on a loan's file, each opened with the session.
class DocumentsList extends StatelessWidget {
  const DocumentsList({super.key, required this.documents, this.onRemove});

  final List<OfflineDocument> documents;
  final ValueChanged<OfflineDocument>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Text(
        'No documents yet.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      );
    }
    return Column(
      children: [
        for (final d in documents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              d.isImage ? Icons.image_outlined : Icons.description_outlined,
              color: AppColors.gold,
            ),
            title: Text(d.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                if (d.filename.isNotEmpty) d.filename,
                d.uploadedAt.asDay,
                if (d.uploadedBy.isNotEmpty) d.uploadedBy,
              ].join(' · '),
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
            onTap: () => openAuthedFile(
              context,
              url: d.url,
              label: d.label,
              contentType: d.contentType,
            ),
            trailing: onRemove == null
                ? null
                : IconButton(
                    tooltip: 'Remove',
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.textTertiary),
                    onPressed: () => onRemove!(d),
                  ),
          ),
      ],
    );
  }
}

/// Repayments recorded by hand, newest first.
class RecordedRepaymentsList extends StatelessWidget {
  const RecordedRepaymentsList({super.key, required this.repayments, this.onRemove});

  final List<OfflineRepayment> repayments;
  final ValueChanged<OfflineRepayment>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (repayments.isEmpty) {
      return Text(
        'No repayments recorded by hand.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      );
    }
    final sorted = [...repayments]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return Column(
      children: [
        for (final r in sorted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              r.amount.asNaira,
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
            ),
            subtitle: Text(
              [
                r.method.label,
                r.paidAt.asDay,
                if (r.reference.isNotEmpty) r.reference,
                if (r.recordedBy.isNotEmpty) 'by ${r.recordedBy}',
                if (r.note.isNotEmpty) r.note,
              ].join(' · '),
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
            trailing: onRemove == null
                ? null
                : IconButton(
                    tooltip: 'Recorded by mistake',
                    icon: Icon(Icons.undo_rounded, color: AppColors.textTertiary),
                    onPressed: () => onRemove!(r),
                  ),
          ),
      ],
    );
  }
}

/// Asks before something that cannot be taken back.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirm, style: TextStyle(color: danger ? AppColors.danger : AppColors.gold)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Who looks after a borrower: at least one officer, one of them leading.
///
/// For a customer with an account, or — before they sign up — for the paper
/// loan they will be found by.
class OfficersPanel extends StatefulWidget {
  const OfficersPanel({super.key, this.customerId, this.importId, this.canEdit = true})
    : assert(customerId != null || importId != null);

  final String? customerId;
  final String? importId;
  final bool canEdit;

  @override
  State<OfficersPanel> createState() => _OfficersPanelState();
}

class _OfficersPanelState extends State<OfficersPanel> {
  List<AssignedOfficer> _officers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    try {
      final list = widget.customerId != null
          ? await admin.customerOfficers(widget.customerId!)
          : await admin.importOfficers(widget.importId!);
      if (mounted) {
        setState(() {
          _officers = list;
          _loading = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showToast(context, done);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _add() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    final List<OfficerOption> options;
    try {
      options = await admin.officerOptions();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    final taken = _officers.map((o) => o.officerId).toSet();
    final chosen = await pickOfficers(
      context,
      options: options.where((o) => !taken.contains(o.id)).toList(),
    );
    if (chosen == null || chosen.isEmpty) return;
    await _act(
      () async => widget.customerId != null
          ? await admin.assignToCustomer(widget.customerId!, chosen, lead: _officers.isEmpty)
          : await admin.assignToImport(widget.importId!, chosen, lead: _officers.isEmpty),
      'Officers added',
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AppState>().adminApi;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _officers.length > 1 ? 'LOAN OFFICERS' : 'LOAN OFFICER',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (widget.canEdit)
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                  label: const Text('Add'),
                ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_officers.isEmpty)
            Text(
              'Nobody is looking after this borrower yet.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
            )
          else
            for (final o in _officers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Flexible(
                      child: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (o.lead) ...[
                      const SizedBox(width: 6),
                      StatusPill(label: 'LEAD', color: AppColors.gold, dense: true),
                    ],
                    if (!o.stillOnTeam) ...[
                      const SizedBox(width: 6),
                      StatusPill(label: 'LEFT THE TEAM', color: AppColors.danger, dense: true),
                    ],
                  ],
                ),
                subtitle: Text(
                  [o.email, if (o.phone.isNotEmpty) o.phone].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
                trailing: !widget.canEdit || admin == null
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) => v == 'lead'
                            ? _act(() => admin.makeLeadOfficer(o.id), '${o.name} now leads')
                            : _act(() => admin.removeOfficer(o.id), '${o.name} taken off'),
                        itemBuilder: (_) => [
                          if (!o.lead) const PopupMenuItem(value: 'lead', child: Text('Make lead')),
                          const PopupMenuItem(value: 'remove', child: Text('Take off')),
                        ],
                      ),
              ),
        ],
      ),
    );
  }
}

/// Chooses officers from the team. Returns their ids, first chosen first.
Future<List<String>?> pickOfficers(
  BuildContext context, {
  required List<OfficerOption> options,
  List<String> initial = const [],
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OfficerPicker(options: options, initial: initial),
  );
}

class _OfficerPicker extends StatefulWidget {
  const _OfficerPicker({required this.options, required this.initial});
  final List<OfficerOption> options;
  final List<String> initial;

  @override
  State<_OfficerPicker> createState() => _OfficerPickerState();
}

class _OfficerPickerState extends State<_OfficerPicker> {
  late final List<String> _picked = [...widget.initial];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Loan officers', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'The first you tick leads.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.options.isEmpty)
            Text(
              'Everyone on the team is already on this borrower.',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in widget.options)
                  CheckboxListTile(
                    value: _picked.contains(o.id),
                    onChanged: (on) => setState(() {
                      on == true ? _picked.add(o.id) : _picked.remove(o.id);
                    }),
                    title: Text(o.name),
                    subtitle: Text(
                      '${o.roleLabel} · ${o.borrowers} borrower${o.borrowers == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                    secondary: _picked.isNotEmpty && _picked.first == o.id
                        ? StatusPill(label: 'LEAD', color: AppColors.gold, dense: true)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GoldButton(
            label: 'Done',
            onPressed: () => Navigator.pop(context, _picked),
          ),
        ],
      ),
    ),
  );
}
