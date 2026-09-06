import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'passcode.dart';
import 'primitives.dart';

/// Asks for a code the customer was sent by email.
///
/// Used where a PIN alone is not enough — changing the account money is paid
/// out to, and closing an account. Both are things somebody holding a stolen,
/// unlocked phone would do, and both are irreversible once done. A code sent to
/// the registered email means the phone on its own is not sufficient.
///
/// Returns the code, or null if the customer backed out. Like [confirmWithPin],
/// it does not check the code: the server does, as part of the operation.
Future<String?> confirmWithEmailedCode(
  BuildContext context, {
  required String title,
  required String message,
  int length = 6,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _CodeSheet(title: title, message: message, length: length),
    );

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({
    required this.title,
    required this.message,
    required this.length,
  });

  final String title;
  final String message;
  final int length;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon: Icons.mark_email_read_outlined,
            color: AppColors.gold,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OtpBoxes(
            length: widget.length,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: AppSpacing.xl),
          GoldButton(
            label: 'Confirm',
            onPressed: _code.length == widget.length
                ? () => Navigator.of(context).pop(_code)
                : null,
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
