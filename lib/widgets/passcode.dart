import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The filled/empty dots above a keypad.
class PasscodeDots extends StatelessWidget {
  const PasscodeDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.size = 15,
  });

  final int length;
  final int filled;
  final bool error;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(length, (i) {
      final on = i < filled;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 9),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on
              ? (error ? AppColors.danger : AppColors.gold)
              : Colors.transparent,
          border: Border.all(
            color: error
                ? AppColors.danger
                : (on ? AppColors.gold : AppColors.surfaceHigh),
            width: 1.6,
          ),
          boxShadow: on && !error
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
      );
    }),
  );
}

/// The numeric keypad. [leftAction] is an optional extra key (biometrics,
/// "forgot", etc.) shown in the bottom-left slot.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leftAction,
    this.onLeftAction,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final IconData? leftAction;
  final VoidCallback? onLeftAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final d in row) _Key(digit: d, onTap: _tap(d))],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            leftAction == null
                ? const SizedBox(width: 76, height: 66)
                : _Key(icon: leftAction, onTap: enabled ? onLeftAction : null),
            _Key(digit: '0', onTap: _tap('0')),
            _Key(
              icon: Icons.backspace_outlined,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onBackspace();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  VoidCallback? _tap(String d) => enabled
      ? () {
          HapticFeedback.lightImpact();
          onDigit(d);
        }
      : null;
}

class _Key extends StatefulWidget {
  const _Key({this.digit, this.icon, this.onTap});
  final String? digit;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 76,
        height: 66,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: _down ? AppColors.goldWash : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _down ? AppColors.gold : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: widget.digit != null
            ? Text(
                widget.digit!,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              )
            : Icon(
                widget.icon,
                size: 24,
                color: active ? AppColors.textSecondary : AppColors.textTertiary,
              ),
      ),
    );
  }
}

/// Six independent boxes for entering an emailed / texted OTP.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.error = false,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool error;

  @override
  State<OtpBoxes> createState() => OtpBoxesState();
}

class OtpBoxesState extends State<OtpBoxes> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _nodes = List.generate(
    widget.length,
    (_) => FocusNode(),
  );

  String get value => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChanged(int i, String v) {
    if (v.length > 1) {
      // Paste of a full code.
      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
      for (var j = 0; j < widget.length; j++) {
        _controllers[j].text = j < digits.length ? digits[j] : '';
      }
      _nodes[(digits.length - 1).clamp(0, widget.length - 1)].requestFocus();
    } else if (v.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    }
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(widget.length, (i) {
      final filled = _controllers[i].text.isNotEmpty;
      final focused = _nodes[i].hasFocus;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: SizedBox(
          width: 48,
          height: 58,
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.backspace &&
                  _controllers[i].text.isEmpty &&
                  i > 0) {
                _controllers[i - 1].clear();
                _nodes[i - 1].requestFocus();
                setState(() {});
              }
            },
            child: TextField(
              controller: _controllers[i],
              focusNode: _nodes[i],
              autofocus: i == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: i == 0 ? widget.length : 1,
              onChanged: (v) => _onChanged(i, v),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                fillColor: filled ? AppColors.goldWash : AppColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: widget.error
                        ? AppColors.danger
                        : (filled ? AppColors.gold : AppColors.stroke),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: widget.error ? AppColors.danger : AppColors.gold,
                    width: focused ? 1.6 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}
