import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icons.dart';

enum PillVariant {
  /// Black fill, white label. The screen's single main action.
  primary,

  /// White fill, black label. Used on the dark splash.
  light,

  /// #EEEEEE fill, black label. "Add item", "Next month · December".
  subtle,
}

/// The pill action used across every screen: radius 999, flat, no border.
///
/// Disabled renders as the #EEEEEE / #757575 pair the mockups show on Add
/// entry, which is a distinct treatment rather than an opacity change.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillVariant.primary,
    this.height = AppSizes.button,
    this.icon,
    this.textStyle,
    this.expand,
    this.hugPadding = 18,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final double height;
  final IconSpec? icon;
  final TextStyle? textStyle;

  /// Whether the pill fills the available width. Primary and light actions are
  /// full-width everywhere in the mockups; subtle ones ("Add item") hug their
  /// label and are left-aligned by their parent.
  final bool? expand;

  /// Side padding when the pill hugs its label — 18px, per the mockups'
  /// "Add item" button.
  final double hugPadding;

  bool get _enabled => onPressed != null;
  bool get _expand => expand ?? variant != PillVariant.subtle;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    final (Color background, Color foreground) = switch (variant) {
      _ when !_enabled => (s.softer, AppColors.muted),
      PillVariant.primary => (s.ink, s.surface),
      PillVariant.light => (AppColors.surface, AppColors.primary),
      PillVariant.subtle => (s.softer, s.ink),
    };

    final style = (textStyle ?? AppText.buttonMd).copyWith(color: foreground);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Material(
        color: background,
        borderRadius: AppRadius.pill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            width: _expand ? double.infinity : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              // Shrink-wraps the label when the pill hugs; a Center here
              // would expand to the full bounded width instead.
              mainAxisSize: _expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (!_expand) SizedBox(width: hugPadding),
                if (icon != null) ...[
                  AppIcon(icon!, size: 16, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: style,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (!_expand) SizedBox(width: hugPadding),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 44×44 circular icon button on a soft fill — the calendar shortcut on
/// Home, the close button on Add entry, the month arrows on Calendar.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = AppSizes.touch,
    this.iconSize = 20,
    this.background,
    this.foreground,
  });

  final IconSpec icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background ?? s.soft,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: AppIcon(
                icon,
                size: iconSize,
                color: foreground ?? s.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
