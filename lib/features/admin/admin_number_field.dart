import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// What a typed figure is, which decides how it is shown and stored.
enum AdminNumberKind {
  /// Stored as a fraction (0.175), typed as a percentage (17.5).
  percent,

  /// Naira, grouped into thousands as it is typed.
  money,

  /// A count: months, days, tries.
  whole,
}

/// A figure in the settings, typed straight into the field — as it is on the
/// web panel, where every rate and limit is an input rather than a slider.
///
/// Each keystroke that makes a number updates the draft, so the save bar and
/// the previews follow along. While the field is being typed in, the text is
/// left alone; when it loses focus it is rewritten from the value, so "07"
/// settles to "7" and a half-typed "12." to "12".
class AdminNumberField extends StatefulWidget {
  const AdminNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.kind = AdminNumberKind.whole,
    this.enabled = true,
    this.suffix,
    this.width,
    this.missing = false,
    this.min,
  });

  /// In stored units: a percent field takes the fraction.
  final double value;
  final ValueChanged<double> onChanged;
  final AdminNumberKind kind;
  final bool enabled;

  /// Shown after the figure. A percent field shows "%" without being told.
  final String? suffix;
  final double? width;

  /// Marks a field that still needs a value, as a month with no rate does.
  final bool missing;

  /// The smallest figure accepted, in stored units. Anything under it is
  /// flagged and kept out of the draft until it is corrected.
  final double? min;

  @override
  State<AdminNumberField> createState() => _AdminNumberFieldState();
}

class _AdminNumberFieldState extends State<AdminNumberField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();
  bool _tooSmall = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        _sync(force: true);
        if (_tooSmall) setState(() => _tooSmall = false);
      }
    });
  }

  @override
  void didUpdateWidget(AdminNumberField old) {
    super.didUpdateWidget(old);
    // Changed from outside — a step button, Discard, a copied set of terms.
    // What is typed stays put while it still means the same number.
    _sync(force: !_focus.hasFocus);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sync({required bool force}) {
    final typed = _parse(_controller.text);
    final same = typed != null && (typed - widget.value).abs() < 1e-9;
    if (force ? _controller.text != _format(widget.value) : !same) {
      _controller.text = _format(widget.value);
    }
  }

  String _format(double v) => switch (widget.kind) {
    AdminNumberKind.percent => _trim((v * 100).toStringAsFixed(2)),
    AdminNumberKind.money => v.round().asPlain,
    AdminNumberKind.whole => v.round().toString(),
  };

  /// The typed text in stored units, or null while it is not a number yet.
  double? _parse(String text) {
    final n = double.tryParse(text.trim().replaceAll(',', ''));
    if (n == null) return null;
    return widget.kind == AdminNumberKind.percent ? n / 100 : n;
  }

  static String _trim(String v) => v.contains('.')
      ? v.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : v;

  @override
  Widget build(BuildContext context) {
    final border = widget.missing || _tooSmall ? AppColors.danger : AppColors.stroke;
    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      textAlign: TextAlign.end,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.kind == AdminNumberKind.percent,
      ),
      inputFormatters: [
        if (widget.kind == AdminNumberKind.money)
          ThousandsFormatter()
        else
          FilteringTextInputFormatter.allow(
            widget.kind == AdminNumberKind.percent
                ? RegExp(r'[0-9.]')
                : RegExp(r'[0-9]'),
          ),
      ],
      onChanged: (text) {
        final n = _parse(text);
        final tooSmall = n != null && widget.min != null && n < widget.min!;
        if (tooSmall != _tooSmall) setState(() => _tooSmall = tooSmall);
        if (n != null && !tooSmall) widget.onChanged(n);
      },
      onTapOutside: (_) => _focus.unfocus(),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.gold,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        prefixText: widget.kind == AdminNumberKind.money ? '₦ ' : null,
        suffixText: widget.kind == AdminNumberKind.percent
            ? '%'
            : widget.suffix,
        hintText: widget.missing ? 'Needs a rate' : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.stroke.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: _tooSmall ? AppColors.danger : AppColors.gold,
            width: 1.4,
          ),
        ),
      ),
    );
    return widget.width == null ? field : SizedBox(width: widget.width, child: field);
  }
}

/// The flat rate for every month of a rate card, one field each — the web
/// panel's "Flat rate by term" grid. A month with no rate of its own is
/// flagged, since a customer can choose it.
class RateByTermGrid extends StatelessWidget {
  const RateByTermGrid({
    super.key,
    required this.rates,
    required this.maxTenureMonths,
    required this.onChanged,
    required this.enabled,
  });

  final Map<int, double> rates;
  final int maxTenureMonths;
  final void Function(int months, double rate) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = AppSpacing.sm;
      final columns = box.maxWidth >= 420 ? 4 : 3;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: AppSpacing.md,
        children: [
          for (var m = 1; m <= maxTenureMonths; m++)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$m month${m == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AdminNumberField(
                    value: rates[m] ?? 0,
                    kind: AdminNumberKind.percent,
                    enabled: enabled,
                    missing: rates[m] == null,
                    onChanged: (r) => onChanged(m, r),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// [rates] with every month up to [months] priced: a month that has no rate
/// yet starts at the one before it, so lengthening the longest term never
/// offers a tenure the card says nothing about.
Map<int, double> ratesUpTo(Map<int, double> rates, int months) {
  final out = {...rates};
  var last = rates.isEmpty ? 0.0 : rates[rates.keys.reduce((a, b) => a < b ? a : b)]!;
  for (var m = 1; m <= months; m++) {
    out[m] ??= last;
    last = out[m]!;
  }
  return out;
}
