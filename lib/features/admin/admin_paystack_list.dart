import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/paystack.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// Payments taken through Paystack, newest first. Read-only: Paystack decides
/// whether a payment happened, and a successful one is already credited.
class AdminPaystackList extends StatefulWidget {
  const AdminPaystackList({super.key, this.customerId});

  /// One customer's payments, on their record.
  final String? customerId;

  @override
  State<AdminPaystackList> createState() => _AdminPaystackListState();
}

class _AdminPaystackListState extends State<AdminPaystackList> {
  List<PaystackPayment> _rows = [];
  PaystackStatus? _status = PaystackStatus.successful;
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
      final page = widget.customerId != null
          ? await admin.customerPaystack(widget.customerId!)
          : await admin.paystackPayments(
              status: _status?.name.toUpperCase(),
              size: 100,
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
    final total = _rows.where((p) => p.credited).fold(0.0, (s, p) => s + p.amount);
    final fees = _rows.fold(0.0, (s, p) => s + p.fees);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.customerId == null) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (label, status) in const [
                ('Paid', PaystackStatus.successful),
                ('Waiting', PaystackStatus.initialized),
                ('Failed', PaystackStatus.failed),
                ('Abandoned', PaystackStatus.abandoned),
                ('All', null),
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
          const SizedBox(height: AppSpacing.md),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: TextStyle(color: AppColors.danger))
        else if (_rows.isEmpty)
          const EmptyState(
            icon: Icons.credit_card_off_outlined,
            title: 'No payments',
            message: 'Card, transfer and USSD payments appear here.',
          )
        else ...[
          Text(
            '${total.asNaira} credited · ${fees.asNaira} in Paystack fees',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _rows.length; i++) ...[
                  if (i > 0) const HairLine(),
                  _Row(payment: _rows[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.payment});
  final PaystackPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final color = switch (p.status) {
      PaystackStatus.successful => AppColors.success,
      PaystackStatus.initialized => AppColors.gold,
      PaystackStatus.failed => AppColors.danger,
      PaystackStatus.abandoned => AppColors.textTertiary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.customerName.isEmpty ? p.reference : p.customerName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (p.customerRef.isNotEmpty) p.customerRef,
                    p.purposeLabel,
                    (p.paidAt ?? p.createdAt).asDayTime,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
                if (p.paidWith.isNotEmpty || p.fees > 0)
                  Text(
                    [
                      if (p.paidWith.isNotEmpty) p.paidWith,
                      if (p.fees > 0) 'fee ${p.fees.asNaira}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                if (p.gatewayResponse.isNotEmpty && p.status != PaystackStatus.successful)
                  Text(
                    p.gatewayResponse,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p.amount.asNaira,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              StatusPill(
                label: (p.statusLabel.isEmpty ? p.status.name : p.statusLabel).toUpperCase(),
                color: color,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
