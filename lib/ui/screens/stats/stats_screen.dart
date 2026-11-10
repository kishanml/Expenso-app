import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/month_summary.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/month_picker.dart';
import '../../widgets/progress_bar.dart';

/// Stats — `Stats.dc.html`.
///
/// What the month saved, where it went by category, and the shape of daily
/// spending against the limit.
class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.summary,
    required this.month,
    required this.today,
    required this.onChangeMonth,
  });

  final MonthSummary summary;
  final DateTime month;
  final DateTime today;
  final ValueChanged<DateTime> onChangeMonth;

  /// The category swatch ramp, darkest first — spending reads as a single
  /// monochrome scale rather than seven arbitrary hues.
  static const _swatches = [
    Color(0xFF000000),
    Color(0xFF333333),
    Color(0xFF545454),
    Color(0xFF757575),
    Color(0xFF949494),
    Color(0xFFAFAFAF),
    Color(0xFFCFCFCF),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        _header(context),
        const SizedBox(height: AppSpacing.lg),
        _SavedCard(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _StatGrid(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _CategoryBreakdown(summary: summary, swatches: _swatches),
        const SizedBox(height: AppSpacing.lg),
        _DailyTrend(summary: summary),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Stats', style: AppText.screenTitle),
        Semantics(
          button: true,
          label: 'Change month, ${Dates.monthYear(month)}',
          excludeSemantics: true,
          child: Material(
            color: s.softer,
            borderRadius: AppRadius.pill,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                final picked = await showMonthPicker(
                  context: context,
                  selected: month,
                  today: today,
                );
                if (picked != null) onChangeMonth(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Dates.monthYear(month),
                        style: AppText.bodySmStrong.copyWith(color: s.ink),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppIcon(
                        AppIcons.chevronDown,
                        size: 16,
                        color: s.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dark hero: what the month has saved so far.
class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final saved = summary.savedPaise;
    final elapsed = summary.daysElapsed;

    return AppCard(
      fill: CardFill.hero,
      semanticLabel: 'Saved this month',
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            saved < 0 ? 'Overspent this month' : 'Saved this month',
            style: AppText.bodySm.copyWith(color: AppColors.placeholder),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Money.withSign(saved),
            style: AppText.statFigure.copyWith(color: AppColors.onDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${Money.percent(summary.savedFraction)} of salary'
            '${summary.isCurrentMonth ? ' · so far, $elapsed of '
                '${summary.daysInMonth} days' : ''}',
            style: AppText.bodySm.copyWith(color: AppColors.placeholder),
          ),
        ],
      ),
    );
  }
}

/// The four small cards: credit, debit, salary used, daily expenses saved.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final dailySaved = summary.dailySavedPaise;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniCard(
                  label: 'Credit · in',
                  value: '+${Money.rupees(summary.totalCreditsPaise)}',
                  valueColor: s.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniCard(
                  label: 'Debit · out',
                  value: '−${Money.rupees(summary.totalDebitsPaise)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniCard(
                  label: 'Salary used',
                  value: Money.percent(summary.salaryUsedFraction),
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: ProgressBar(
                      value: summary.salaryUsedFraction,
                      trackColor: s.border,
                      fillColor: s.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniCard(
                  label: 'Daily expenses saved',
                  value: Money.withSign(dailySaved),
                  valueColor: dailySaved < 0 ? s.error : s.success,
                  caption:
                      '${Money.rupees(summary.dailyAllowedSoFarPaise)} '
                      'allowed − '
                      '${Money.rupees(summary.dailySoFarPaise)}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.caption,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppText.caption.copyWith(
            color: s.textSecondary,
          )),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppText.bodyLg.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? s.ink,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: AppText.caption.copyWith(color: s.textSecondary),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Share of spending by category: a stacked bar, then a row per category with
/// actual against budget.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary, required this.swatches});

  final MonthSummary summary;
  final List<Color> swatches;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final categories = summary.categoryTotals;

    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category', style: AppText.sheetTitle),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nothing logged this month yet.',
            style: AppText.bodySm.copyWith(color: s.textSecondary),
          ),
        ],
      );
    }

    final total = categories.fold(0, (sum, c) => sum + c.spentPaise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Spending by category', style: AppText.sheetTitle),
        const SizedBox(height: AppSpacing.md),

        Semantics(
          label: 'Share of spending by category',
          child: ClipRRect(
            borderRadius: AppRadius.pill,
            child: SizedBox(
              height: 16,
              child: Row(
                // Without stretch the Row centres each segment, and a
                // childless ColoredBox then collapses to zero height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < categories.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: (categories[i].spentPaise / total * 10000).round(),
                      child: ColoredBox(
                        color: swatches[i % swatches.length],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        for (var i = 0; i < categories.length; i++)
          _CategoryRow(
            name: categories[i].name,
            spentPaise: categories[i].spentPaise,
            budgetPaise: categories[i].budgetPaise,
            swatch: swatches[i % swatches.length],
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.spentPaise,
    required this.budgetPaise,
    required this.swatch,
  });

  final String name;
  final int spentPaise;
  final int budgetPaise;
  final Color swatch;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final over = budgetPaise > 0 && spentPaise > budgetPaise;
    final fraction =
        budgetPaise <= 0 ? 1.0 : (spentPaise / budgetPaise).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.softer)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: AppText.bodySmStrong.copyWith(color: s.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: Money.rupees(spentPaise),
                      style: AppText.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: s.ink,
                      ),
                    ),
                    TextSpan(
                      // An unbudgeted category has nothing to measure against.
                      text: budgetPaise > 0
                          ? ' / ${Money.rupees(budgetPaise)}'
                          : ' · no budget',
                      style: AppText.bodySm.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ProgressBar(
            value: fraction,
            height: 4,
            trackColor: s.softer,
            fillColor: over ? s.error : s.ink,
          ),
        ],
      ),
    );
  }
}

/// Daily expenses per day with the limit drawn across as a dashed line.
class _DailyTrend extends StatelessWidget {
  const _DailyTrend({required this.summary});

  final MonthSummary summary;

  static const _chartHeight = 140.0;

  /// The mockup fixes the vertical scale at ₹700 so the limit line lands at
  /// 67/140. That is kept while the data fits under it, and only grows when a
  /// day would otherwise overflow the chart.
  static const _baseScalePaise = 70000.0;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final days = summary.dayStats
        .where((d) => !d.isFuture)
        .toList();

    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    final peak = days.fold<int>(0, (m, d) => d.dailyPaise > m ? d.dailyPaise : m);
    final scale = peak > _baseScalePaise
        ? peak * 1.1
        : _baseScalePaise;

    final limit = summary.dailyLimitPaise;
    final limitOffset = (limit / scale * _chartHeight).clamp(0.0, _chartHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text('Daily expenses trend', style: AppText.sheetTitle),
            ),
            Text(
              '- - limit ${Money.rupeesPaiseTrim(summary.dailyLimitRounded)}',
              style: AppText.caption.copyWith(color: s.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Semantics(
          label: 'Daily expenses per day, 1 to ${days.length} '
              '${Dates.monthName(summary.month)}, '
              '${summary.overLimitDayCount} days over the limit',
          excludeSemantics: true,
          child: SizedBox(
            height: _chartHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: limitOffset,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1.5),
                    painter: _DashedLinePainter(color: s.textSecondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < days.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Container(
                            height: days[i].dailyPaise == 0
                                ? 2
                                : (days[i].dailyPaise / scale * _chartHeight)
                                    .clamp(2.0, _chartHeight),
                            decoration: BoxDecoration(
                              color: days[i].dailyPaise == 0
                                  ? s.border
                                  : days[i].overLimit
                                      ? s.error
                                      : s.ink,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 1, color: s.border),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${days[i].day}',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      color: days[i].overLimit ? s.error : s.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
