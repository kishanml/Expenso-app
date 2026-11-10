import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Groups digits Indian-style as they are typed, so the salary field reads
/// 1,12,739 while the caret stays at the end.
class IndianGroupingFormatter extends TextInputFormatter {
  const IndianGroupingFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    // Drop leading zeros so "0250" becomes "250".
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = Money.groupDigits(trimmed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A square (radius 0) money input on a soft fill, with the ₹ sign sitting
/// outside the editable area as a static prefix. Focus draws the 2px inset
/// ring the mockups' `input:focus` rule specifies.
///
/// Two sizes appear in the designs: the tall salary field (56px, bold 20) and
/// the narrow per-item field (44px, medium 15, right-aligned).
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.height = 56,
    this.textStyle,
    this.symbolStyle,
    this.align = TextAlign.left,
    this.fill,
    this.semanticLabel,
    this.onChanged,
    this.horizontalPadding = AppSpacing.lg,
    this.symbolGap = AppSpacing.xs,
  });

  /// The narrow in-row variant: 44px tall, right-aligned.
  const MoneyField.compact({
    super.key,
    required this.controller,
    this.fill,
    this.semanticLabel,
    this.onChanged,
  })  : height = AppSizes.touch,
        textStyle = null,
        symbolStyle = null,
        align = TextAlign.right,
        horizontalPadding = AppSpacing.md,
        symbolGap = AppSpacing.xxs;

  final TextEditingController controller;
  final double height;
  final TextStyle? textStyle;
  final TextStyle? symbolStyle;
  final TextAlign align;
  final Color? fill;
  final String? semanticLabel;
  final ValueChanged<String>? onChanged;
  final double horizontalPadding;
  final double symbolGap;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  bool get _compact => widget.height == AppSizes.touch;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    final valueStyle = widget.textStyle ??
        (_compact
            ? AppText.row.copyWith(color: s.ink)
            : AppText.displaySm.copyWith(color: s.ink));

    final prefixStyle = widget.symbolStyle ??
        (_compact
            ? AppText.bodyMd.copyWith(color: s.textSecondary)
            : AppText.displaySm.copyWith(color: s.textSecondary));

    final field = Container(
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
      decoration: BoxDecoration(
        color: widget.fill ?? s.soft,
        borderRadius: AppRadius.none,
      ),
      // `inset 0 0 0 2px` — painted over the content rather than as a real
      // border, so taking focus does not shift the text by the ring's width.
      foregroundDecoration: _focused
          ? BoxDecoration(border: Border.all(color: s.ink, width: 2))
          : null,
      child: Row(
        children: [
          Text(Money.rupee, style: prefixStyle),
          SizedBox(width: widget.symbolGap),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              keyboardType: TextInputType.number,
              textAlign: widget.align,
              style: valueStyle,
              cursorColor: s.ink,
              cursorWidth: 2,
              inputFormatters: const [IndianGroupingFormatter()],
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.semanticLabel == null) return field;
    return Semantics(label: widget.semanticLabel, child: field);
  }
}
