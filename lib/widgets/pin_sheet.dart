import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import 'passcode.dart';
import 'primitives.dart';

/// Every movement of money passes through here.
///
/// Returns the PIN the customer entered, or null if they backed out.
///
/// It deliberately does **not** check the PIN. The server does, as part of the
/// operation itself — every money endpoint takes the PIN in the same request
/// that moves the money. Checking here as well would be theatre: the hash is on
/// the device, anyone running a modified build skips the check entirely, and a
/// failed-attempt counter kept on the phone is reset by reinstalling the app.
///
/// Verifying with the operation also closes the gap between "PIN accepted" and
/// "money moved", which is the window an attacker with the unlocked phone wants.
///
/// The cost is that a wrong PIN is reported after a round trip rather than
/// instantly. That is the honest trade — immediate feedback from a check that
/// proves nothing is not worth keeping.
Future<String?> confirmWithPin(
  BuildContext context, {
  required String title,
  required String amountLabel,
  double? amount,
  List<(String, String)> details = const [],
}) =>
    showModalBottomSheet<String>(
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
  bool _busy = false;

  void _digit(String d) {
    if (_pin.length >= AppConfig.transactionPinLength || _busy) return;
    setState(() => _pin += d);
    if (_pin.length == AppConfig.transactionPinLength) _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    // Long enough for the last dot to register as filled before the sheet
    // leaves; without it the keypad appears to swallow the final digit.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(_pin);
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
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          if (widget.amount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.amount!.asNaira,
              style: TextStyle(
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
                            style: TextStyle(
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
            'Enter your transaction PIN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasscodeDots(
            length: AppConfig.transactionPinLength,
            filled: _pin.length,
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
