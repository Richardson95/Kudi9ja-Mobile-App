import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// The signature this customer gave when they accepted their agreements,
/// and which versions they signed — their own copy of the record.
class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  late final Future<List<SignatureRecord>> _records =
      context.read<AppState>().loadMySignatures();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signed agreements')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<SignatureRecord>>(
            future: _records,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snap.data ?? const [];
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.draw_outlined,
                  title: 'Nothing signed here',
                  message: 'Accounts opened before signatures were asked for '
                      'accepted the agreements without one.',
                );
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  for (final r in records) ...[
                    _Record(record: r),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    'Signed electronically. You agreed that this signature is '
                    'the legal equivalent of a handwritten one, and that '
                    '${AppConfig.legalEntity} may keep this record as evidence '
                    'of the agreement under section 93 of the Evidence Act '
                    '2011.',
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textTertiary),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.record});
  final SignatureRecord record;

  Uint8List? get _png {
    final image = record.image;
    final comma = image.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(image.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIGNED ${record.signedAt.asDayTime.toUpperCase()}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            height: 120,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.stroke),
            ),
            child: png == null
                ? const Center(
                    child: Text(
                      'The image is not available right now.',
                      style: TextStyle(color: Color(0xFFA8957A)),
                    ),
                  )
                : Image.memory(png, fit: BoxFit.contain),
          ),
          const SizedBox(height: AppSpacing.md),
          _Line('Typed name', record.typedName),
          _Line('Agreements', _documents(record.documents)),
          if (record.device.isNotEmpty) _Line('Device', record.device),
        ],
      ),
    );
  }

  /// "lending 1.1, privacy 1.2" read as the documents' names.
  static String _documents(String raw) => raw
      .split(',')
      .map((part) {
        final bits = part.trim().split(' ');
        if (bits.length < 2) return part.trim();
        final name = switch (bits.first.toLowerCase()) {
          'terms' => 'Terms of Service',
          'privacy' => 'Privacy Policy',
          'lending' => 'Lending Agreement',
          _ => bits.first,
        };
        return '$name ${bits.last}';
      })
      .join('\n');
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
