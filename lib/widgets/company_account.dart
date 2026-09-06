import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/platform_settings.dart';
import 'primitives.dart';

/// The collection account every incoming payment goes to, with copy buttons
/// and the narration the customer must quote so it can be matched.
class CompanyAccountCard extends StatelessWidget {
  const CompanyAccountCard({
    super.key,
    this.reference,
    this.amount,
    this.onReferenceCopied,
  });

  /// The narration for one specific payment. Null where the card is shown
  /// for reference rather than against a payment being made.
  final String? reference;
  final String? amount;

  /// Called the moment the reference reaches the clipboard.
  ///
  /// The copy is what the server records — until then the reference is text on
  /// a screen; afterwards it is on its way into a bank narration, and an admin
  /// needs it on the customer's record to match a statement against.
  final VoidCallback? onReferenceCopied;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 17,
              color: AppColors.gold,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Transfer to this account',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            if (amount != null)
              StatusPill(
                label: amount!,
                color: AppColors.success,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: [
            Expanded(
              child: Text(
                settings.companyAccountNumber,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _CopyButton(
              value: settings.companyAccountNumber,
              label: 'Account number copied',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          settings.companyAccountName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          settings.companyBank,
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),

        if (reference != null && reference!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const HairLine(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use this as the narration',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reference!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              _CopyButton(
                value: reference!,
                label: 'Reference copied',
                onCopied: onReferenceCopied,
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.infoWash,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.22)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: AppColors.info),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Quote the narration exactly so we can match your payment. Nothing is credited until our team confirms it against the bank statement.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.value,
    required this.label,
    this.onCopied,
  });
  final String value;
  final String label;
  final VoidCallback? onCopied;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Clipboard.setData(ClipboardData(text: value));
      HapticFeedback.selectionClick();
      showToast(context, label);
      onCopied?.call();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.copy_rounded, size: 13, color: AppColors.gold),
          SizedBox(width: 5),
          Text(
            'Copy',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Attaches the screenshot of a transfer receipt. Proof is what turns a
/// claim into a confirmed payment, so the control is deliberately prominent.
class ReceiptPicker extends StatelessWidget {
  const ReceiptPicker({
    super.key,
    required this.path,
    required this.onPicked,
    this.required = true,
  });

  final String path;
  final ValueChanged<String> onPicked;
  final bool required;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1400,
      );
      if (file != null) onPicked(file.path);
    } catch (_) {
      if (context.mounted) {
        showToast(context, 'Could not open that. Try the other option.',
            error: true);
      }
    }
  }

  void _choose(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.gold,
              ),
              title: const Text('Choose a screenshot'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: AppColors.gold,
              ),
              title: const Text('Take a photo of the receipt'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.camera);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final has = path.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              has ? 'Receipt attached' : 'Attach your receipt',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: has ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            if (required && !has) ...[
              const SizedBox(width: 6),
              Text(
                'required',
                style: TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: () => _choose(context),
          child: Container(
            height: has ? 190 : 104,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: has ? AppColors.success : AppColors.stroke,
                width: has ? 1.4 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: has
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            'Preview unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: AppColors.gold,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Replace',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 26,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Upload a screenshot of your transfer',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gallery or camera',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Opens a receipt full-screen so an admin can read the detail on it.
void showReceipt(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.black,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment receipt',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(
                  padding: EdgeInsets.all(AppSpacing.huge),
                  child: Text(
                    'This receipt image is no longer available on the device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    ),
  );
}
