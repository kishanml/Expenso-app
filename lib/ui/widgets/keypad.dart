import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icons.dart';

/// The in-app number pad: a 3×4 grid of 52px keys on the soft fill, 16px
/// radius, 22/500 labels.
///
/// Add entry uses this instead of the system keyboard so the amount, the
/// category chips and Save all stay on screen at once.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onKey});

  /// Receives '0'–'9', '.' or 'del'.
  final ValueChanged<String> onKey;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '.', '0', 'del',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: _Key(value: _keys[row * 3 + col], onKey: onKey)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.value, required this.onKey});

  final String value;
  final ValueChanged<String> onKey;

  bool get _isDelete => value == 'del';

  String get _semanticLabel => switch (value) {
        'del' => 'Delete',
        '.' => 'Decimal point',
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: s.soft,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // A keypad with no travel needs some physical confirmation.
            HapticFeedback.selectionClick();
            onKey(value);
          },
          child: SizedBox(
            height: 52,
            child: Center(
              child: _isDelete
                  ? AppIcon(AppIcons.backspace, size: 24, color: s.ink)
                  : Text(
                      value,
                      style: AppText.displaySm.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: s.ink,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
