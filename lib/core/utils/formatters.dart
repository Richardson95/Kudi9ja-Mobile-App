import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _naira = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 2,
);
final _nairaFlat = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 0,
);
final _plain = NumberFormat('#,##0.##', 'en_NG');

const naira = '₦';

extension MoneyFormat on num {
  String get asNaira => _naira.format(this);
  String get asNairaFlat => _nairaFlat.format(this);
  String get asPlain => _plain.format(this);

  /// Compact form for tight spaces: 1.2M, 450k, 900.
  String get asShortNaira {
    if (this >= 1000000) {
      final v = this / 1000000;
      return '$naira${v.toStringAsFixed(this % 1000000 == 0 ? 0 : 1)}M';
    }
    if (this >= 1000) {
      final v = this / 1000;
      return '$naira${v.toStringAsFixed(this % 1000 == 0 ? 0 : 1)}k';
    }
    return '$naira${toStringAsFixed(0)}';
  }
}

extension DateFormatX on DateTime {
  String get asDay => DateFormat('d MMM yyyy').format(this);
  String get asDayTime => DateFormat('d MMM yyyy, h:mm a').format(this);
  String get asTime => DateFormat('h:mm a').format(this);
  String get asMonthYear => DateFormat('MMMM yyyy').format(this);

  String get relative {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return asDay;
  }

  String get countdown {
    final diff = difference(DateTime.now());
    if (diff.isNegative) return 'Matured';
    if (diff.inDays >= 365) {
      final y = diff.inDays ~/ 365;
      final m = (diff.inDays % 365) ~/ 30;
      if (m == 0) return '$y ${y == 1 ? 'year' : 'years'} left';
      return '${y}y ${m}m left';
    }
    if (diff.inDays >= 60) return '${diff.inDays ~/ 30} months left';
    if (diff.inDays >= 1) return '${diff.inDays} days left';
    return '${diff.inHours} hours left';
  }
}

/// Groups digits into thousands live, as the user types an amount.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final digits = next.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final formatted = NumberFormat.decimalPattern(
      'en_NG',
    ).format(int.parse(trimmed));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double parseAmount(String raw) =>
    double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

String maskTail(String value) =>
    value.length <= 4 ? value : '******${value.substring(value.length - 4)}';

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'K9';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
