import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'transaction_list.dart';

/// A formal, shareable receipt for a single transaction.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().user;
    final tint = colorForTx(tx);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            tooltip: 'Copy receipt',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _asText(user?.fullName)));
              HapticFeedback.selectionClick();
              showToast(context, 'Receipt copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const BrandWordmark(width: 128),
                          const SizedBox(height: AppSpacing.xl),
                          IconBadge(
                            icon: iconForTx(tx.kind),
                            color: tint,
                            size: 58,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            '${tx.isCredit ? '+' : '-'}${tx.amount.asNaira}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.3,
                              color: tx.isCredit
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusPill(
                            label: 'SUCCESSFUL',
                            color: AppColors.success,
                            icon: Icons.check_circle_rounded,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const _Perforation(),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          _Row('Transaction', tx.kind.label),
                          const _Sep(),
                          _Row('Description', tx.description),
                          if (tx.counterparty.isNotEmpty) ...[
                            const _Sep(),
                            _Row('Counterparty', tx.counterparty),
                          ],
                          const _Sep(),
                          _Row('Date', tx.date.asDayTime),
                          const _Sep(),
                          _Row('Account holder', user?.fullName ?? '-'),
                          const _Sep(),
                          _Row(
                            'Payout account',
                            user == null || !user.hasPayoutAccount
                                ? '-'
                                : '${user.payoutBank} • ${user.payoutAccountNumber}',
                          ),
                          const _Sep(),
                          _Row('Balance after', tx.balanceAfter.asNaira),
                          const _Sep(),
                          _Row('Reference', tx.reference, mono: true),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                        horizontal: AppSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.stroke),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'This receipt was generated by Kudi9ja and is valid without a signature.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Queries: ${AppConfig.supportEmail}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GoldButton(
                label: 'Copy receipt details',
                icon: Icons.copy_rounded,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _asText(user?.fullName)),
                  );
                  showToast(context, 'Receipt copied to clipboard');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _asText(String? holder) => [
    'KUDI9JA TRANSACTION RECEIPT',
    '',
    'Amount:        ${tx.isCredit ? '+' : '-'}${tx.amount.asNaira}',
    'Transaction:   ${tx.kind.label}',
    'Description:   ${tx.description}',
    if (tx.counterparty.isNotEmpty) 'Counterparty:  ${tx.counterparty}',
    'Date:          ${tx.date.asDayTime}',
    'Account:       ${holder ?? '-'}',
    'Balance after: ${tx.balanceAfter.asNaira}',
    'Reference:     ${tx.reference}',
    'Status:        Successful',
  ].join('\n');
}

/// The torn-ticket divider between the receipt header and its body.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: Row(
      children: [
        _Notch(),
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                (c.maxWidth / 10).floor().clamp(1, 60),
                (_) => Container(
                  width: 5,
                  height: 1.4,
                  color: AppColors.stroke,
                ),
              ),
            ),
          ),
        ),
        _Notch(left: false),
      ],
    ),
  );
}

class _Notch extends StatelessWidget {
  const _Notch({this.left = true});
  final bool left;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: AppColors.black,
      borderRadius: BorderRadius.horizontal(
        left: left ? Radius.zero : const Radius.circular(22),
        right: left ? const Radius.circular(22) : Radius.zero,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 108,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: mono ? 0.5 : 0,
          ),
        ),
      ),
    ],
  );
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: HairLine(),
  );
}
