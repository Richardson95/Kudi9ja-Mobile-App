import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// Reports to download: customers, loans, repayments and the rest, for any
/// period. Owners and administrators only; every download is logged.
///
/// The server hands over the rows; the phone writes them as a spreadsheet
/// file and opens it with whatever reads one.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTimeRange? _range;
  ExportReportName? _busy;

  Future<void> _download(ExportReportName name) async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    setState(() => _busy = name);
    try {
      final report = await admin.exportReport(name, from: _range?.start, to: _range?.end);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/kudi9ja-${name.name}-$stamp.csv');
      await file.writeAsString(toCsv(report), encoding: utf8, flush: true);
      if (!mounted) return;
      setState(() => _busy = null);
      showToast(context, '${report.rows.length} rows — ${report.period.isEmpty ? 'all time' : report.period}');
      final result = await OpenFilex.open(file.path, type: 'text/csv');
      if (result.type != ResultType.done && mounted) {
        showToast(
          context,
          result.type == ResultType.noAppToOpen
              ? 'No app on this phone opens spreadsheets. The file is at ${file.path}.'
              : 'The report could not be opened.',
          error: true,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              KPickerTile(
                label: _range == null ? 'All time' : '${_range!.start.asDay} – ${_range!.end.asDay}',
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                    initialDateRange: _range,
                  );
                  if (picked != null) setState(() => _range = picked);
                },
                onClear: _range == null ? null : () => setState(() => _range = null),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final r in ExportReportName.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: KCard(
                    onTap: _busy == null ? () => _download(r) : null,
                    child: Row(
                      children: [
                        IconBadge(icon: Icons.table_chart_outlined, size: 42),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(r.blurb, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                        _busy == r
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.download_rounded, color: AppColors.gold),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Each download is written to the audit log with your name.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A date-range row with a clear button.
class KPickerTile extends StatelessWidget {
  const KPickerTile({super.key, required this.label, required this.onTap, this.onClear});
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    child: Row(
      children: [
        Icon(Icons.date_range_rounded, color: AppColors.gold),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (onClear != null)
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClear)
        else
          Text('Change', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// The report as CSV: a heading block, the column names, then the rows.
/// Money stays a plain number so a spreadsheet can add it up.
String toCsv(ExportReport r) {
  String cell(Object? v) {
    final s = switch (v) {
      null => '',
      num n => n.toString(),
      _ => '$v',
    };
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final out = StringBuffer()
    ..writeln(cell(r.title))
    ..writeln(cell('${r.company} · ${r.period} · generated ${r.generatedAt.asDayTime} by ${r.generatedBy}'))
    ..writeln()
    ..writeln(r.columns.map((c) => cell(c.label)).join(','));
  for (final row in r.rows) {
    out.writeln(row.map(cell).join(','));
  }
  return out.toString();
}
