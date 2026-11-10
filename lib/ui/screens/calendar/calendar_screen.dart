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

/// Calendar — `Calendar.dc.html`.
///
/// A month of days tinted green or red by whether that day's daily expenses
/// stayed under the limit, with a detail panel for the selected day.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.summary,
    required this.month,
    required this.today,
    required this.onChangeMonth,
    required this.entriesForDay,
    required this.onOpenEntry,
  });

  final MonthSummary summary;
  final DateTime month;
  final DateTime today;
  final ValueChanged<DateTime> onChangeMonth;
  final List<Entry> Function(DateTime) entriesForDay;
  final ValueChanged<Entry> onOpenEntry;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int? _selectedDay;

  /// Defaults to today in the current month, or the 1st in any other.
  int get _day {
    final fallback = widget.summary.isCurrentMonth ? widget.today.day : 1;
    final day = _selectedDay ?? fallback;
    return day.clamp(1, widget.summary.daysInMonth);
  }

  DateTime get _selectedDate =>
      DateTime(widget.month.year, widget.month.month, _day);

  void _changeMonth(DateTime month) {
    // A day selected in one month means nothing in the next.
    setState(() => _selectedDay = null);
    widget.onChangeMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      children: [
        _header(),
        const SizedBox(height: AppSpacing.lg),
        _summaryCards(summary),
        const SizedBox(height: AppSpacing.lg),
        const _WeekdayHeader(),
        const SizedBox(height: AppSpacing.sm),
        _MonthGrid(
          summary: summary,
          month: widget.month,
          today: widget.today,
          selectedDay: _day,
          onSelect: (day) => setState(() => _selectedDay = day),
        ),
        const SizedBox(height: AppSpacing.md),
        const _Legend(),
        const SizedBox(height: AppSpacing.lg),
        _DayDetail(
          date: _selectedDate,
          today: widget.today,
          stat: summary.dayStats[_day - 1],
          dailyLimitPaise: summary.dailyLimitRounded,
          entries: widget.entriesForDay(_selectedDate),
          onOpenEntry: widget.onOpenEntry,
        ),
      ],
    );
  }

  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      CircleIconButton(
        icon: AppIcons.chevronLeft,
        semanticLabel: 'Previous month',
        onPressed: () => _changeMonth(Dates.previousMonth(widget.month)),
      ),
      Text(Dates.monthYear(widget.month), style: AppText.displaySm),
      CircleIconButton(
        icon: AppIcons.chevronRight,
        semanticLabel: 'Next month',
        onPressed: () => _changeMonth(Dates.nextMonth(widget.month)),
      ),
    ],
  );

  Widget _summaryCards(MonthSummary summary) {
    final s = AppSurfaces.of(context);
    final overDays = summary.overLimitDayCount;

    // IntrinsicHeight, not CrossAxisAlignment.stretch: inside a ListView the
    // cross axis is unbounded, and stretch would force an infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily expenses so far',
                    style: AppText.caption.copyWith(color: s.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: AppText.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: s.ink,
                      ),
                      children: [
                        TextSpan(text: Money.rupees(summary.dailySoFarPaise)),
                        TextSpan(
                          text:
                              ' of '
                              '${Money.rupees(summary.dailyAllowedSoFarPaise)}',
                          style: AppText.meta.copyWith(color: s.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Over-limit days',
                    style: AppText.caption.copyWith(color: s.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // "!" carries the warning so the red is never load-bearing
                    // on its own.
                    overDays == 0
                        ? '✓ None'
                        : '! $overDays red ${overDays == 1 ? 'day' : 'days'}',
                    style: AppText.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: overDays == 0 ? s.success : s.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  // Sunday-first, as drawn.
  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                _labels[i],
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: s.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The 7-column month grid.
///
/// The mockup renders day 1 in the first column, which happens to be right for
/// November 2026 because the 1st is a Sunday. Real leading blanks are computed
/// here so every other month lands correctly too.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.summary,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.onSelect,
  });

  final MonthSummary summary;
  final DateTime month;
  final DateTime today;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday is 1=Mon..7=Sun; the grid starts on Sunday.
    final leading = Dates.firstOfMonth(month).weekday % 7;
    final stats = summary.dayStats;
    final rows = ((leading + stats.length) / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              for (var col = 0; col < 7; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final index = row * 7 + col - leading;
                      if (index < 0 || index >= stats.length) {
                        return const SizedBox(height: 56);
                      }
                      return _DayCell(
                        stat: stats[index],
                        month: month,
                        isToday: Dates.sameDay(
                          DateTime(month.year, month.month, index + 1),
                          today,
                        ),
                        selected: index + 1 == selectedDay,
                        onTap: () => onSelect(index + 1),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.stat,
    required this.month,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final DayStat stat;
  final DateTime month;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final logged = stat.isLogged;
    final over = stat.overLimit;

    final background = !logged
        ? Colors.transparent
        : over
        ? s.errorTint
        : s.successTint;

    final numberColor = logged
        ? (over ? s.error : s.success)
        : stat.isFuture
        ? AppColors.muted
        : s.ink;

    // Selection is a 2px ink ring; an unlogged day keeps a 1px hairline so the
    // grid still reads as a grid.
    final border = selected
        ? Border.all(color: s.ink, width: 2)
        : logged
        ? null
        : Border.all(color: s.softer);

    final sub = logged
        ? Money.withSign(stat.gainPaise).replaceFirst(Money.rupee, '')
        : isToday
        ? 'Today'
        : '';

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${stat.day} ${Dates.monthName(month)}'
          '${logged ? (over ? ', over limit' : ', within limit') : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.cell,
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${stat.day}',
                style: AppText.row.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: numberColor,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 12,
                child: Text(
                  sub,
                  style: AppText.caption.copyWith(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: logged
                        ? (over ? s.error : s.success)
                        : s.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final style = AppText.caption.copyWith(color: s.textSecondary);

    Widget item(String label, {Color? fill, bool outlined = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: outlined ? Border.all(color: AppColors.placeholder) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: style),
      ],
    );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        item('Within limit', fill: s.successTint),
        item('Over limit', fill: s.errorTint),
        item('No entries', outlined: true),
      ],
    );
  }
}

/// The panel below the grid: totals for the selected day and its entries.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.date,
    required this.today,
    required this.stat,
    required this.dailyLimitPaise,
    required this.entries,
    required this.onOpenEntry,
  });

  final DateTime date;
  final DateTime today;
  final DayStat stat;
  final int dailyLimitPaise;
  final List<Entry> entries;
  final ValueChanged<Entry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final future = stat.isFuture;
    final has = entries.isNotEmpty;

    final title =
        '${Dates.shortDay(date)}'
        '${Dates.sameDay(date, today) ? ' · Today' : ''}';

    // A past day with nothing logged saved the whole allowance.
    final (String gainLabel, Color gainColor) = future
        ? ('Upcoming', s.textSecondary)
        : !has
        ? ('Saved +${Money.rupees(dailyLimitPaise)}', s.success)
        : stat.gainPaise < 0
        ? ('Overspent −${Money.rupees(stat.gainPaise)}', s.error)
        : ('Saved +${Money.rupees(stat.gainPaise)}', s.success);

    return AppCard(
      semanticLabel: 'Selected day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(title, style: AppText.sheetTitle)),
              Text(
                gainLabel,
                style: AppText.row.copyWith(
                  fontWeight: FontWeight.w700,
                  color: gainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DayStatCell(
                  label: 'Total spent',
                  value: future
                      ? '—'
                      : Money.rupees(stat.totalSpentPaise),
                ),
              ),
              Expanded(
                child: _DayStatCell(
                  label: 'Daily expenses',
                  value: future ? '—' : Money.rupees(stat.dailyPaise),
                ),
              ),
              Expanded(
                child: _DayStatCell(
                  label: 'Daily limit',
                  value: Money.rupeesPaiseTrim(dailyLimitPaise),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: AppRadius.cell,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: has
                ? Column(
                    children: [
                      for (final entry in entries)
                        _DayEntryRow(
                          entry: entry,
                          onTap: () => onOpenEntry(entry),
                        ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      future
                          ? 'This day has not happened yet.'
                          : 'Nothing logged on this day.',
                      style: AppText.bodySm.copyWith(color: s.textSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayStatCell extends StatelessWidget {
  const _DayStatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: s.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: AppText.row.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DayEntryRow extends StatelessWidget {
  const _DayEntryRow({required this.entry, required this.onTap});

  final Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.softer)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    style: AppText.bodySmStrong.copyWith(color: s.ink),
                  ),
                  Text(
                    entry.category,
                    style: AppText.caption.copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              Money.signed(entry.amountPaise, credit: entry.isCredit),
              style: AppText.bodySmStrong.copyWith(
                color: entry.isCredit ? s.success : s.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
