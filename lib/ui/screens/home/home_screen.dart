import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/entry.dart';
import '../../../domain/month_summary.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/progress_bar.dart';

/// Home — `Home.dc.html`.
///
/// Today's remaining allowance on the hero card, the month's position below it,
/// then the entries grouped by day.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.summary,
    required this.entries,
    required this.today,
    required this.onOpenCalendar,
    required this.onOpenEntry,
  });

  final MonthSummary summary;
  final List<Entry> entries;
  final DateTime today;
  final VoidCallback onOpenCalendar;
  final ValueChanged<Entry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return ListView(
      padding: const EdgeInsets.only(
        left: AppSpacing.screen,
        right: AppSpacing.screen,
        top: AppSpacing.md,
        // Clears the FAB, which overhangs the list's last row.
        bottom: AppSizes.fab + AppSpacing.xxl,
      ),
      children: [
        _Header(today: today, onOpenCalendar: onOpenCalendar),
        const SizedBox(height: AppSpacing.lg),
        _TodayCard(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _ThisMonthCard(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        if (entries.isEmpty)
          _EmptyEntries(s: s)
        else
          ..._groupedEntries(context),
      ],
    );
  }

  /// Entries under a heading per day, newest day first. The two most recent
  /// days read "Today" and "Yesterday" as the mockup shows; older days get
  /// their date.
  List<Widget> _groupedEntries(BuildContext context) {
    final byDay = <DateTime, List<Entry>>{};
    for (final entry in entries) {
      final day = Dates.dayOnly(entry.date);
      byDay.putIfAbsent(day, () => []).add(entry);
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final yesterday = today.subtract(const Duration(days: 1));

    final widgets = <Widget>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final heading = Dates.sameDay(day, today)
          ? 'Today'
          : Dates.sameDay(day, yesterday)
              ? 'Yesterday'
              : Dates.shortDay(day);

      widgets.add(Padding(
        padding: EdgeInsets.only(
          top: i == 0 ? AppSpacing.xxs : AppSpacing.lg,
          bottom: AppSpacing.xxs,
        ),
        child: Text(heading, style: AppText.row.copyWith(
          fontWeight: FontWeight.w700,
        )),
      ));

      for (final entry in byDay[day]!) {
        widgets.add(_EntryRow(entry: entry, onTap: () => onOpenEntry(entry)));
      }
    }
    return widgets;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.onOpenCalendar});

  final DateTime today;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Dates.longHeader(today),
                style: AppText.meta.copyWith(color: s.textSecondary),
              ),
              const SizedBox(height: 2),
              Text('Expenso', style: AppText.screenTitle),
            ],
          ),
        ),
        CircleIconButton(
          icon: AppIcons.calendar,
          semanticLabel: 'Open calendar',
          onPressed: onOpenCalendar,
        ),
      ],
    );
  }
}

/// The dark hero card: remaining today, the within/over badge, and the
/// progress of today's daily-expenses spending against the limit.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final within = summary.todayWithinLimit;
    final remaining = summary.todayRemainingPaise;

    return AppCard(
      fill: CardFill.hero,
      semanticLabel: 'Today',
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                within ? 'Remaining today' : 'Over today',
                style: AppText.bodySm.copyWith(color: AppColors.placeholder),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppSpacing.xxs,
                ),
                decoration: const BoxDecoration(
                  // rgba(255,255,255,0.14)
                  color: Color(0x24FFFFFF),
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  // Green and red never appear on this card; the ✓ / !
                  // pairing is what carries the meaning here.
                  within ? '✓ Within limit' : '! Over limit',
                  style: AppText.caption.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Money.rupees(remaining),
            style: AppText.heroFigure.copyWith(color: AppColors.onDark),
          ),
          const SizedBox(height: 14),
          ProgressBar(
            value: summary.todayProgress,
            trackColor: const Color(0x2EFFFFFF), // rgba(255,255,255,0.18)
            fillColor: AppColors.onDark,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStat(
                label: 'Spent',
                value: Money.rupees(summary.todaySpentPaise),
              ),
              _HeroStat(
                label: 'Daily limit',
                value: Money.rupeesPaiseTrim(summary.dailyLimitRounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          style: AppText.meta.copyWith(color: AppColors.placeholder),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: AppText.metaStrong.copyWith(color: AppColors.onDark),
            ),
          ],
        ),
      );
}

/// Salary used, saved so far, and daily-expenses progress for the month.
class _ThisMonthCard extends StatelessWidget {
  const _ThisMonthCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final saved = summary.savedPaise;

    return AppCard(
      semanticLabel: 'This month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'THIS MONTH',
            style: AppText.eyebrow.copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Salary used',
                  value: Money.percent(summary.salaryUsedFraction),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Stat(
                  label: 'Saved so far',
                  value: Money.withSign(saved),
                  valueColor:
                      saved < 0 ? s.error : s.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily expenses so far',
                style: AppText.meta.copyWith(color: s.textSecondary),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: Money.rupees(summary.dailySoFarPaise),
                      style: AppText.metaStrong.copyWith(color: s.ink),
                    ),
                    TextSpan(
                      text: ' of '
                          '${Money.rupees(summary.dailyAllowedSoFarPaise)}',
                      style:
                          AppText.meta.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ProgressBar(
            value: summary.dailyProgress,
            trackColor: s.border,
            // Over the allowance the bar turns red, which is the only way the
            // flat black bar could otherwise signal a problem.
            fillColor: summary.dailySavedPaise < 0 ? s.error : s.ink,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.meta.copyWith(color: s.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.displaySm.copyWith(color: valueColor ?? s.ink),
        ),
      ],
    );
  }
}

/// One logged amount. 60px tall minimum, hairline rule beneath.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.softer)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: s.soft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                entry.initial,
                style: AppText.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: s.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.title, style: AppText.row),
                  const SizedBox(height: 2),
                  Text(
                    entry.category,
                    style: AppText.meta.copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              Money.signed(entry.amountPaise, credit: entry.isCredit),
              style: AppText.row.copyWith(
                color: entry.isCredit ? s.success : s.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on a fresh install, before anything has been logged. Not drawn in the
/// mockups, so it stays as quiet as the rest of the system allows.
class _EmptyEntries extends StatelessWidget {
  const _EmptyEntries({required this.s});

  final AppSurfaces s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Column(
          children: [
            Text(
              'Nothing logged yet',
              style: AppText.row.copyWith(color: s.ink),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Tap + to add your first entry.',
              style: AppText.meta.copyWith(color: s.textSecondary),
            ),
          ],
        ),
      );
}
