import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icons.dart';

/// A bottom sheet listing the months you can look at.
///
/// Not drawn in the mockups — `Stats.dc.html` shows the trigger pill with a
/// chevron but nothing behind it. Built in the system's own language: a
/// 16-radius sheet, pill rows, ink for the selected month.
Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime selected,
  required DateTime today,
  int monthsBack = 24,
}) {
  final s = AppSurfaces.of(context);

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: s.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final months = [
        for (var i = 0; i < monthsBack; i++)
          DateTime(today.year, today.month - i),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xxl,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose a month', style: AppText.displaySm),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: months.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final isSelected = Dates.sameMonth(month, selected);

                    return Material(
                      color: isSelected ? s.ink : s.softer,
                      borderRadius: AppRadius.pill,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(month),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                          ),
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    Dates.monthYear(month),
                                    style: AppText.bodyMdStrong.copyWith(
                                      color: isSelected ? s.surface : s.ink,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  AppIcon(
                                    AppIcons.check,
                                    size: 18,
                                    color: s.surface,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
