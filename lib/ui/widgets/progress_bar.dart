import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// The 6px pill progress track used by the Today card and the month card.
/// On the dark hero card the track is white at 18% and the fill solid white.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.trackColor,
    required this.fillColor,
    this.height = 6,
  });

  final double value;
  final Color trackColor;
  final Color fillColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: AppRadius.pill,
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: trackColor,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: ClipRRect(
                borderRadius: AppRadius.pill,
                child: ColoredBox(color: fillColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
