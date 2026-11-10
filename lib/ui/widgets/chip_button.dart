import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// A category chip: 36px tall, 14px side padding, pill radius. Selected flips
/// to the ink fill with a white label.
class ChipButton extends StatelessWidget {
  const ChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? s.ink : s.softer,
        borderRadius: AppRadius.pill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // A Container with `alignment` — or a Center — would expand to the
          // Wrap's full width and stack the chips vertically. The min-size Row
          // shrink-wraps the label while still centring it.
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppText.bodySmStrong.copyWith(
                      color: selected ? s.surface : s.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
