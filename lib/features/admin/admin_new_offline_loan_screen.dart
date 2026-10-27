import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/lending_admin.dart';
import '../../data/models/loan_application.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../auth/signup/signup_draft.dart';
import 'admin_lending_widgets.dart';

/// One repayment made before the loan was entered, as typed.
class _PastPayment {
  _PastPayment(this.paidOn, this.amount, this.method);
  DateTime paidOn;
  double amount;
  RepaymentMethod method;
}

/// Enters a loan written outside the app, with what is known about the
/// borrower.
///
/// Someone new gets an account opened for them on the spot, waiting for them
/// to activate it by signing up with the BVN. Someone already on the system —
/// found by their BVN, or opened from their record — gets the loan on their
/// own account.
class AdminNewOfflineLoanScreen extends StatefulWidget {
  const AdminNewOfflineLoanScreen({super.key, this.customerId, this.customerName, this.group});

  /// An existing customer the loan goes on.
  final String? customerId;
  final String? customerName;

  /// The loan group the borrower joins. Priced on the group's terms.
  final LoanGroup? group;

  @override
  State<AdminNewOfflineLoanScreen> createState() => _AdminNewOfflineLoanScreenState();
}

class _AdminNewOfflineLoanScreenState extends State<AdminNewOfflineLoanScreen> {
  final _bvn = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _principal = TextEditingController();
  final _ratePct = TextEditingController();
  final _fee = TextEditingController();
  final _payoutFee = TextEditingController();
  final _feePct = TextEditingController();
  final _purpose = TextEditingController(text: 'Business');
  final _nin = TextEditingController();
  final _address = TextEditingController();
  final _occupation = TextEditingController();
  final _business = TextEditingController();
  final _businessAddress = TextEditingController();
  final _income = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _notes = TextEditingController();

  int _months = 6;
  RepaymentFrequency _frequency = RepaymentFrequency.monthly;
  DateTime _paidOut = DateTime.now();
  String _state = '';
  String _gender = '';
  bool _feeTouched = false;
  bool _rateTouched = false;
  bool _moreOpen = false;
  final List<_PastPayment> _payments = [];
  final List<Guarantor> _guarantors = [];
  List<OfficerOption> _options = [];
  List<String> _officers = [];

  BvnMatch? _match;
  Timer? _lookup;
  bool _busy = false;

  LendingTerms get _terms => widget.group != null ? settings.groupLending : settings.lending;

  String? get _existingId => widget.customerId ?? (_match?.found == true ? _match!.customerId : null);
  String? get _existingName => widget.customerName ?? (_match?.found == true ? _match!.fullName : null);

  @override
  void initState() {
    super.initState();
    _ratePct.text = (_terms.rateFor(_months) * 100).toStringAsFixed(1);
    _feePct.text = (_terms.repaymentFeeRate * 100).toStringAsFixed(1);
    unawaited(() async {
      try {
        final options = await context.read<AppState>().adminApi?.officerOptions();
        if (mounted && options != null) setState(() => _options = options);
      } on ApiException {
        // The officer picker stays empty; whoever enters the loan looks after it.
      }
    }());
  }

  @override
  void dispose() {
    _lookup?.cancel();
    for (final c in [
      _bvn, _name, _phone, _email, _principal, _ratePct, _fee, _payoutFee, _feePct, _purpose,
      _nin, _address, _occupation, _business, _businessAddress, _income, _bank, _account, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _amount => parseAmount(_principal.text);
  double get _rate => (double.tryParse(_ratePct.text) ?? 0) / 100;
  double get _repaymentFeeRate => (double.tryParse(_feePct.text) ?? 0) / 100;

  List<InstalmentPart> get _plan {
    if (_amount <= 0 || _months <= 0) return const [];
    final total = Finance.ceilNaira(_amount * (1 + _rate));
    return Finance.instalmentPlan(total, _frequency.installments(_months, _paidOut), _repaymentFeeRate);
  }

  double get _owed => _plan.fold(0.0, (s, p) => s + p.total);
  double get _repaid => _payments.fold(0.0, (s, p) => s + p.amount);

  void _onBvn(String v) {
    _lookup?.cancel();
    setState(() => _match = null);
    if (!RegExp(r'^\d{11}$').hasMatch(v)) return;
    _lookup = Timer(const Duration(milliseconds: 400), () async {
      try {
        final match = await context.read<AppState>().adminApi?.lookupBvn(v);
        if (mounted) setState(() => _match = match);
      } on ApiException {
        // Treated as new; the server checks again on save.
      }
    });
  }

  void _onPrincipal() {
    if (!_feeTouched && _amount > 0) {
      _fee.text = _terms.processingFeeFor(_amount).round().asPlain;
    }
    setState(() {});
  }

  void _onTenure(int m) {
    setState(() {
      _months = m;
      if (!_rateTouched) _ratePct.text = (_terms.rateFor(m) * 100).toStringAsFixed(1);
    });
  }

  /// Every instalment already due, as paid on its day — then the admin
  /// corrects the ones that were not.
  void _fillFromSchedule() {
    final now = DateTime.now();
    final rows = <_PastPayment>[];
    for (var i = 0; i < _plan.length; i++) {
      final due = _frequency.due(_paidOut, i + 1);
      if (due.isAfter(now)) break;
      rows.add(_PastPayment(due, _plan[i].total, RepaymentMethod.cash));
    }
    setState(() {
      _payments
        ..clear()
        ..addAll(rows);
    });
  }

  String? get _problem {
    if (_existingId == null) {
      if (!RegExp(r'^\d{11}$').hasMatch(_bvn.text)) return 'Enter the eleven-digit BVN.';
      if (_name.text.trim().split(RegExp(r'\s+')).length < 2) return 'Enter the full name.';
    }
    if (_amount <= 0) return 'Enter the amount lent.';
    if (_rate <= 0 || _rate > 3) return 'Enter the flat rate, as a percentage.';
    if (_repaymentFeeRate < 0 || _repaymentFeeRate > 0.2) return 'The transaction fee is between 0% and 20%.';
    if (parseAmount(_fee.text) + parseAmount(_payoutFee.text) >= _amount) {
      return 'The fees cannot be as much as the loan.';
    }
    if (_purpose.text.trim().isEmpty) return 'Say what the loan was for.';
    if (_repaid > _owed + 0.005) return 'More has been repaid than was owed.';
    if (_payments.any((p) => p.paidOn.isBefore(DateTime(_paidOut.year, _paidOut.month, _paidOut.day)))) {
      return 'A repayment is dated before the payout.';
    }
    if (_match?.found == true && _match!.hasRunningLoan && _repaid < _owed - 0.005) {
      return '${_match!.fullName} already has a running loan.';
    }
    if (_nin.text.isNotEmpty && !RegExp(r'^\d{11}$').hasMatch(_nin.text)) return 'A NIN is eleven digits.';
    if (_account.text.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(_account.text)) {
      return 'An account number is ten digits.';
    }
    return null;
  }

  Future<void> _save() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null || _problem != null) return;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final existing = _existingId;
    final midday = DateTime(_paidOut.year, _paidOut.month, _paidOut.day, 12);
    setState(() => _busy = true);
    try {
      final loan = await admin.importLoan({
        if (existing != null) 'customerId': existing else ...{'bvn': _bvn.text.trim(), 'fullName': _name.text.trim()},
        if (existing == null && opt(_email) != null) 'email': opt(_email),
        if (existing == null && opt(_phone) != null) 'phone': opt(_phone),
        'principal': _amount,
        'tenureMonths': _months,
        'repaymentFrequency': _frequency.wire,
        'flatRate': _rate,
        'repaymentFeeRate': _repaymentFeeRate,
        if (parseAmount(_fee.text) > 0) 'processingFee': parseAmount(_fee.text),
        if (parseAmount(_payoutFee.text) > 0) 'transactionFee': parseAmount(_payoutFee.text),
        'purpose': _purpose.text.trim(),
        'disbursedAt': midday.toUtc().toIso8601String(),
        'repayments': [
          for (final p in _payments)
            RepaymentEntry(
              amount: p.amount,
              method: p.method,
              paidAt: DateTime(p.paidOn.year, p.paidOn.month, p.paidOn.day, 12),
            ).toApi(),
        ],
        if (existing == null) ...{
          'nin': ?opt(_nin),
          'gender': ?(_gender.isEmpty ? null : _gender),
          'address': ?opt(_address),
          'state': ?(_state.isEmpty ? null : _state),
          'payoutBank': ?opt(_bank),
          'payoutAccountNumber': ?opt(_account),
        },
        'occupation': ?opt(_occupation),
        'businessName': ?opt(_business),
        'businessAddress': ?opt(_businessAddress),
        if (parseAmount(_income.text) > 0) 'monthlyIncome': parseAmount(_income.text),
        'notes': ?opt(_notes),
        'guarantors': [
          for (final g in _guarantors)
            {
              for (final e in g.toApi().entries)
                if ((e.value as String).isNotEmpty) e.key: e.value,
            },
        ],
        'officerIds': _officers,
        if (widget.group != null) 'groupId': widget.group!.id,
      });
      if (!mounted) return;
      showToast(
        context,
        existing != null ? 'Loan added to ${_existingName ?? 'their'} account' : 'Loan customer added',
      );
      Navigator.pop(context, loan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _addGuarantor() async {
    final g = await showModalBottomSheet<Guarantor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GuarantorSheet(),
    );
    if (g != null) setState(() => _guarantors.add(g));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final existing = _existingId;
    final problem = _problem;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group != null ? 'Enter a loan · ${widget.group!.title}' : 'Enter a loan from paper'),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _label('THE BORROWER'),
                    if (widget.customerId != null)
                      KCard(child: Text('On ${widget.customerName ?? 'their'} account', style: const TextStyle(fontWeight: FontWeight.w700)))
                    else ...[
                      KField(
                        label: 'BVN',
                        controller: _bvn,
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        onChanged: _onBvn,
                        helper: 'How the loan finds them when they sign up.',
                      ),
                      if (_match?.found == true) ...[
                        const SizedBox(height: AppSpacing.sm),
                        KCard(
                          borderColor: AppColors.info.withValues(alpha: 0.4),
                          child: Text(
                            'This BVN belongs to ${_match!.fullName} (${_match!.customerRef}, '
                            '${_match!.accountStatusLabel}). The loan goes on their account.'
                            '${_match!.hasRunningLoan ? ' They already have a running loan.' : ''}',
                            style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                        KField(
                          label: 'Full name, as on the BVN',
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        KField(label: 'Phone (optional)', controller: _phone, keyboardType: TextInputType.phone),
                        const SizedBox(height: AppSpacing.md),
                        KField(label: 'Email (optional)', controller: _email, keyboardType: TextInputType.emailAddress),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _label('THE LOAN'),
                    KField(
                      label: 'Amount lent',
                      controller: _principal,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      onChanged: (_) => _onPrincipal(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KPickerField(
                      label: 'Paid out on',
                      value: _paidOut.asDay,
                      icon: Icons.event_rounded,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _paidOut,
                          firstDate: DateTime(2018),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _paidOut = d);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KCard(
                      child: Row(
                        children: [
                          const Expanded(child: Text('Term', style: TextStyle(fontWeight: FontWeight.w600))),
                          IconButton(
                            onPressed: _months > 1 ? () => _onTenure(_months - 1) : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Text('$_months months', style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(
                            onPressed: _months < 60 ? () => _onTenure(_months + 1) : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        for (final f in RepaymentFrequency.values) ...[
                          if (f != RepaymentFrequency.values.first) const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: KOptionTile(
                              title: f.label,
                              subtitle: f.paymentsPhrase(_months, start: _paidOut),
                              selected: _frequency == f,
                              onTap: () => setState(() => _frequency = f),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KField(
                      label: 'Flat rate charged (%)',
                      controller: _ratePct,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => _rateTouched = true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KField(
                      label: 'Management fee taken',
                      controller: _fee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      helper: 'Starts at today\'s rule; correct it to what was actually taken.',
                      onChanged: (_) => setState(() => _feeTouched = true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KField(
                      label: 'Transaction fee on each repayment (%)',
                      controller: _feePct,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KField(
                      label: 'Flat fee taken at payout (older loans only)',
                      controller: _payoutFee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KField(label: 'What it was for', controller: _purpose, onChanged: (_) => setState(() {})),
                    if (plan.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      KCard(
                        child: Text(
                          '${plan.length} ${_frequency.adjective} payments of ${plan.first.total.asNaira} · '
                          '${_owed.asNaira} to repay · ${(_owed - _repaid).clamp(0, double.infinity).asNaira} still owed',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(child: _label('REPAID BEFORE IT WAS ENTERED')),
                        TextButton(onPressed: plan.isEmpty ? null : _fillFromSchedule, child: const Text('Fill from schedule')),
                      ],
                    ),
                    for (var i = 0; i < _payments.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_payments[i].amount.asNaira, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${_payments[i].paidOn.asDay} · ${_payments[i].method.label}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _payments.removeAt(i)),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        final entry = await askForRepayment(context, outstanding: (_owed - _repaid).clamp(0, double.infinity));
                        if (entry != null) {
                          setState(() => _payments.add(_PastPayment(entry.paidAt ?? DateTime.now(), entry.amount, entry.method)));
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add a repayment'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _label('GUARANTORS'),
                    for (var i = 0; i < _guarantors.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_guarantors[i].fullName),
                        subtitle: Text([_guarantors[i].relationship, _guarantors[i].phone].where((s) => s.isNotEmpty).join(' · ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _guarantors.removeAt(i)),
                        ),
                      ),
                    if (_guarantors.length < 4)
                      TextButton.icon(
                        onPressed: _addGuarantor,
                        icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                        label: const Text('Add a guarantor'),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    _label('LOAN OFFICERS'),
                    Text(
                      _officers.isEmpty
                          ? 'Nobody chosen: whoever enters the loan looks after it.'
                          : _officers.map((id) => _options.where((o) => o.id == id).firstOrNull?.name ?? '').join(', '),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _options.isEmpty
                          ? null
                          : () async {
                              final chosen = await pickOfficers(context, options: _options, initial: _officers);
                              if (chosen != null) setState(() => _officers = chosen);
                            },
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Text('Choose officers'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    InkWell(
                      onTap: () => setState(() => _moreOpen = !_moreOpen),
                      child: Row(
                        children: [
                          Expanded(child: _label('MORE ABOUT THE BORROWER (OPTIONAL)')),
                          Icon(_moreOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                        ],
                      ),
                    ),
                    if (_moreOpen) ...[
                      if (existing == null) ...[
                        KField(label: 'NIN', controller: _nin, keyboardType: TextInputType.number, maxLength: 11),
                        const SizedBox(height: AppSpacing.md),
                        KPickerField(
                          label: 'Gender',
                          value: _gender.isEmpty ? null : _gender,
                          onTap: () => _choose(kGenders, (v) => _gender = v),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        KField(label: 'Home address', controller: _address),
                        const SizedBox(height: AppSpacing.md),
                        KPickerField(
                          label: 'State',
                          value: _state.isEmpty ? null : _state,
                          onTap: () => _choose(kNigerianStates, (v) => _state = v),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        KField(label: 'Bank', controller: _bank),
                        const SizedBox(height: AppSpacing.md),
                        KField(label: 'Account number', controller: _account, keyboardType: TextInputType.number, maxLength: 10),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      KField(label: 'Occupation', controller: _occupation),
                      const SizedBox(height: AppSpacing.md),
                      KField(label: 'Business name', controller: _business),
                      const SizedBox(height: AppSpacing.md),
                      KField(label: 'Business address', controller: _businessAddress),
                      const SizedBox(height: AppSpacing.md),
                      KField(
                        label: 'Monthly income',
                        controller: _income,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      KField(label: 'Notes', controller: _notes),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Documents can be attached from the loan file once it is saved.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (problem != null && _amount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(problem, style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
                      ),
                    GoldButton(
                      label: existing != null ? 'Add the loan to their account' : 'Save the loan',
                      loading: _busy,
                      onPressed: problem == null ? _save : null,
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

  Future<void> _choose(List<String> options, void Function(String) apply) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          children: [for (final o in options) ListTile(title: Text(o), onTap: () => Navigator.pop(sheet, o))],
        ),
      ),
    );
    if (v != null) setState(() => apply(v));
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: AppColors.textTertiary),
    ),
  );
}

/// A guarantor on a paper loan. Only the name is required.
class _GuarantorSheet extends StatefulWidget {
  const _GuarantorSheet();

  @override
  State<_GuarantorSheet> createState() => _GuarantorSheetState();
}

class _GuarantorSheetState extends State<_GuarantorSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  final _address = TextEditingController();
  final _bvn = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _relationship, _address, _bvn]) {
      c.dispose();
    }
    super.dispose();
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
          Text('A guarantor', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          KField(label: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          KField(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone),
          const SizedBox(height: AppSpacing.md),
          KField(label: 'Relationship', controller: _relationship),
          const SizedBox(height: AppSpacing.md),
          KField(label: 'Address', controller: _address),
          const SizedBox(height: AppSpacing.md),
          KField(label: 'BVN', controller: _bvn, keyboardType: TextInputType.number, maxLength: 11),
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'Add',
            onPressed: _name.text.trim().length < 2
                ? null
                : () => Navigator.pop(
                    context,
                    Guarantor(
                      fullName: _name.text.trim(),
                      phone: _phone.text.trim(),
                      address: _address.text.trim(),
                      state: '',
                      localGovernment: '',
                      landmark: '',
                      relationship: _relationship.text.trim(),
                      bvn: _bvn.text.trim(),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
