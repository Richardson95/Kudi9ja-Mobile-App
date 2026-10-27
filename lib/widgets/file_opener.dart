import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/api/api_exception.dart';
import '../state/app_state.dart';
import 'primitives.dart';

/// Opens a file that needs the session to fetch — a support attachment, a
/// document on a loan's file.
///
/// A picture is drawn in place. Anything else — a PDF, a spreadsheet — is
/// saved to the app's cache and handed to whatever the phone opens that type
/// with, since the link cannot be given to a browser that has no session.
Future<void> openAuthedFile(
  BuildContext context, {
  required String url,
  String label = 'file',
  String contentType = '',
}) async {
  final app = context.read<AppState>();
  showToast(context, 'Opening $label…', icon: Icons.download_rounded);
  try {
    final file = await app.download(url);
    final type = contentType.isNotEmpty ? contentType : file.contentType;
    if (!context.mounted) return;

    if (type.toLowerCase().startsWith('image/')) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    Uint8List.fromList(file.bytes),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final safe = file.filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final saved = File('${dir.path}/$safe');
    await saved.writeAsBytes(file.bytes, flush: true);
    final result = await OpenFilex.open(saved.path, type: type.isEmpty ? null : type);
    if (result.type != ResultType.done && context.mounted) {
      showToast(
        context,
        result.type == ResultType.noAppToOpen
            ? 'No app on this phone opens this kind of file.'
            : 'The file could not be opened.',
        error: true,
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) {
      showToast(
        context,
        'The file could not be downloaded. Check your connection and try again.',
        error: true,
      );
    }
  }
}
