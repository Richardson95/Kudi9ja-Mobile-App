import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../state/app_state.dart';
import 'passcode.dart';
import 'primitives.dart';

/// Every movement of money passes through here. Returns true once the
/// transaction PIN is confirmed.
Future<bool> confirmWithPin(
  BuildContext context, {
  required String title,
  required String amountLabel,
  double? amount,
  List<(String, String)> details = const [],
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _PinSheet(
      title: title,
      amountLabel: amountLabel,
      amount: amount,
      details: details,
    ),
  );
  return ok ?? false;
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.title,
    required this.amountLabel,
    this.amount,
    this.details = const [],
  });

  final String title;
  final String amountLabel;
  final double? amount;
  final List<(String, String)> details;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;
  int _attempts = 0;

  void _digit(String d) {
    if (_pin.length >= AppConfig.transactionPinLength || _busy) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == AppConfig.transactionPinLength) _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    if (context.read<AppState>().verifyTransactionPin(_pin)) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
      return;
    }

    HapticFeedback.vibrate();
    _attempts++;
    setState(() {
      _error = true;
      _busy = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _pin = '';
      _error = false;
    });
    if (_attempts >= 3 && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.amountLabel,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          if (widget.amount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.amount!.asNaira,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: AppColors.gold,
              ),
            ),
          ],
          if (widget.details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            KCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (final (k, v) in widget.details)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            k,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            v,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            _error ? 'Incorrect PIN, try again' : 'Enter your transaction PIN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _error ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasscodeDots(
            length: AppConfig.transactionPinLength,
            filled: _pin.length,
            error: _error,
          ),
          const SizedBox(height: AppSpacing.xl),
          NumericKeypad(
            enabled: !_busy,
            onDigit: _digit,
            onBackspace: () {
              if (_pin.isNotEmpty) {
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
