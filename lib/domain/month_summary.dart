import '../core/format/dates.dart';
import '../data/models/budget_item.dart';
import '../data/models/entry.dart';
import '../data/models/month_budget.dart';

/// Everything one day of the month works out to, for the calendar grid and the
/// daily-expenses trend chart.
class DayStat {
  const DayStat({
    required this.day,
    required this.dailyPaise,
    required this.totalSpentPaise,
    required this.totalReceivedPaise,
    required this.entryCount,
    required this.overLimit,
    required this.gainPaise,
    required this.isFuture,
  });

  final int day;

  /// Debits against "Daily expenses" only — what the limit is measured on.
  final int dailyPaise;

  /// Every debit, including Rent, EMI and the rest.
  final int totalSpentPaise;
  final int totalReceivedPaise;
  final int entryCount;

  /// True when [dailyPaise] exceeded the daily limit. False for a day with no
  /// entries, which is never "over".
  final bool overLimit;

  /// limit − dailyPaise. Positive is saved, negative is overspent.
  final int gainPaise;

  final bool isFuture;

  bool get hasEntries => entryCount > 0;

  /// A day is tinted only once it has something logged on it.
  bool get isLogged => hasEntries && !isFuture;
}

/// Every derived figure the app displays, computed in one place from a month's
/// budget snapshot and its entries.
///
/// The formulas are those the approved mockups implement. Two are worth
/// calling out because they are deliberate:
///
///  * **Saved** is `salary − debits`. Credits are *not* added back. The
///    mockups show ₹1,12,739 − ₹46,445 = +₹66,294, not +₹66,414.
///  * **The daily limit** divides the Daily-expenses budget by the days in the
///    month, so it is ₹333.33 in a 30-day month and ₹322.58 in a 31-day one.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.budget,
    required this.entries,
    required this.today,
  });

  final DateTime month;
  final MonthBudget budget;
  final List<Entry> entries;

  /// The day "today" means for this summary. Injected rather than read from the
  /// clock so the figures are reproducible in tests.
  final DateTime today;

  int get daysInMonth => Dates.daysInMonth(month);

  bool get isCurrentMonth => Dates.sameMonth(month, today);
  bool get isFutureMonth =>
      Dates.firstOfMonth(month).isAfter(Dates.firstOfMonth(today));

  /// How many days of the month have happened. A past month has run its full
  /// length; a future month, none of it.
  int get daysElapsed {
    if (isCurrentMonth) return today.day;
    if (isFutureMonth) return 0;
    return daysInMonth;
  }

  // ── Daily limit ─────────────────────────────────────────────────────────

  /// The Daily-expenses allowance spread evenly across the month, in paise.
  /// Kept fractional so that 30 days of ₹333.33 still add up to ₹10,000.
  double get dailyLimitPaise => daysInMonth == 0
      ? 0
      : budget.dailyExpensesPaise / daysInMonth;

  /// The limit as shown — ₹333.33.
  int get dailyLimitRounded => dailyLimitPaise.round();

  // ── Today ───────────────────────────────────────────────────────────────

  /// Daily-expenses debits logged today.
  int get todaySpentPaise => _sumDaily(entriesOn(today.day));

  /// limit − spent. Negative once the day has gone over.
  int get todayRemainingPaise =>
      (dailyLimitPaise - todaySpentPaise).round();

  double get todayProgress => dailyLimitPaise <= 0
      ? 0
      : (todaySpentPaise / dailyLimitPaise).clamp(0.0, 1.0);

  bool get todayWithinLimit => todaySpentPaise <= dailyLimitPaise;

  // ── Month to date ───────────────────────────────────────────────────────

  /// Daily-expenses debits for the whole month so far.
  int get dailySoFarPaise => _sumDaily(entries);

  /// limit × days elapsed — the "of ₹3,333" figure.
  int get dailyAllowedSoFarPaise => (dailyLimitPaise * daysElapsed).round();

  /// What was not spent out of the allowance so far. Negative when over.
  int get dailySavedPaise => dailyAllowedSoFarPaise - dailySoFarPaise;

  double get dailyProgress => dailyAllowedSoFarPaise <= 0
      ? 0
      : (dailySoFarPaise / dailyAllowedSoFarPaise).clamp(0.0, 1.0);

  int get totalDebitsPaise => entries
      .where((e) => !e.isCredit)
      .fold(0, (sum, e) => sum + e.amountPaise);

  int get totalCreditsPaise => entries
      .where((e) => e.isCredit)
      .fold(0, (sum, e) => sum + e.amountPaise);

  int get salaryPaise => budget.salaryPaise;

  double get salaryUsedFraction =>
      salaryPaise <= 0 ? 0 : totalDebitsPaise / salaryPaise;

  /// salary − debits. See the class note: credits are excluded by design.
  int get savedPaise => salaryPaise - totalDebitsPaise;

  double get savedFraction => salaryPaise <= 0 ? 0 : savedPaise / salaryPaise;

  // ── Breakdowns ──────────────────────────────────────────────────────────

  /// Debits per category, largest first — the Stats category bars.
  List<({String name, int spentPaise, int budgetPaise})> get categoryTotals {
    final totals = <String, int>{};
    for (final e in entries) {
      if (e.isCredit) continue;
      totals[e.category] = (totals[e.category] ?? 0) + e.amountPaise;
    }

    final rows = totals.entries
        .map((e) => (
              name: e.key,
              spentPaise: e.value,
              budgetPaise: budget.budgetForCategory(e.key),
            ))
        .toList();
    rows.sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
    return rows;
  }

  /// One [DayStat] per day of the month, day 1 first.
  List<DayStat> get dayStats {
    final out = <DayStat>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final dayEntries = entriesOn(day);
      final daily = _sumDaily(dayEntries);
      final isFuture = isFutureMonth || (isCurrentMonth && day > today.day);

      out.add(DayStat(
        day: day,
        dailyPaise: daily,
        totalSpentPaise: dayEntries
            .where((e) => !e.isCredit)
            .fold(0, (sum, e) => sum + e.amountPaise),
        totalReceivedPaise: dayEntries
            .where((e) => e.isCredit)
            .fold(0, (sum, e) => sum + e.amountPaise),
        entryCount: dayEntries.length,
        overLimit: dayEntries.isNotEmpty && daily > dailyLimitPaise,
        gainPaise: (dailyLimitPaise - daily).round(),
        isFuture: isFuture,
      ));
    }
    return out;
  }

  /// How many days have gone over the limit — "! 3 red days".
  int get overLimitDayCount =>
      dayStats.where((d) => d.isLogged && d.overLimit).length;

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<Entry> entriesOn(int day) =>
      entries.where((e) => e.date.day == day).toList();

  /// Only debits against the pinned Daily-expenses item count toward the limit.
  static int _sumDaily(List<Entry> entries) => entries
      .where((e) => !e.isCredit && e.category == kDailyExpensesName)
      .fold(0, (sum, e) => sum + e.amountPaise);
}
