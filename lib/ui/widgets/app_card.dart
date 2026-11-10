import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Cards are flat with a 16px radius. Three fills appear in the mockups:
/// plain white, the soft #F6F6F6 tint, and the black→charcoal hero gradient.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.fill = CardFill.soft,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final CardFill fill;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    final decoration = switch (fill) {
      CardFill.hero => BoxDecoration(
          gradient: s.heroGradient,
          borderRadius: AppRadius.card,
        ),
      CardFill.soft => BoxDecoration(
          color: s.soft,
          borderRadius: AppRadius.card,
        ),
      CardFill.surface => BoxDecoration(
          color: s.surface,
          borderRadius: AppRadius.card,
        ),
    };

    final card = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    if (semanticLabel == null) return card;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: card,
    );
  }
}

enum CardFill { hero, soft, surface }
