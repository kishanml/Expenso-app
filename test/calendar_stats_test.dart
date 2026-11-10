import 'package:expenso/core/format/dates.dart';
import 'package:expenso/core/format/money.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour the Calendar and Stats screens depend on, beyond the figures the
/// mockup-parity suite already pins.
void main() {
  const budget = MonthBudget(
    monthKey: '2026-11',
    salaryPaise: 11273900,
    items: [
      BudgetItem(
        id: 'daily',
        name: kDailyExpensesName,
        amountPaise: 1000000,
        pinned: true,
      ),
      BudgetItem(id: 'bills', name: 'Bills', amountPaise: 250000),
    ],
  );

  MonthSummary summaryWith(
    List<Entry> entries, {
    DateTime? month,
    DateTime? today,
  }) =>
      MonthSummary(
        month: month ?? DateTime(2026, 11),
        budget: budget,
        entries: entries,
        today: today ?? DateTime(2026, 11, 10),
      );

  Entry debit(int day, int rupees, {String category = kDailyExpensesName}) =>
      Entry(
        id: '$day-$rupees-$category',
        amountPaise: rupees * 100,
        isCredit: false,
        category: category,
        date: DateTime(2026, 11, day),
      );

  group('Calendar grid alignment', () {
    test('November 2026 starts on a Sunday, so it needs no leading blanks', () {
      expect(Dates.firstOfMonth(DateTime(2026, 11)).weekday % 7, 0);
    });

    test('a month starting mid-week is offset correctly', () {
      // 1 December 2026 is a Tuesday: Sun=0, Mon=1, Tue=2.
      expect(Dates.firstOfMonth(DateTime(2026, 12)).weekday % 7, 2);
      // 1 January 2027 is a Friday.
      expect(Dates.firstOfMonth(DateTime(2027)).weekday % 7, 5);
    });

    test('day stats cover exactly the days in the month', () {
      expect(summaryWith(const []).dayStats.length, 30);
      expect(
        summaryWith(const [], month: DateTime(2026, 12)).dayStats.length,
        31,
      );
      expect(
        summaryWith(const [], month: DateTime(2028, 2)).dayStats.length,
        29,
      );
    });
  });

  group('Day tinting', () {
    test('a day with no entries is never tinted or counted as over', () {
      final day = summaryWith(const []).dayStats[2];
      expect(day.hasEntries, isFalse);
      expect(day.isLogged, isFalse);
      expect(day.overLimit, isFalse);
    });

    test('a day under the limit is within', () {
      final day = summaryWith([debit(3, 150)]).dayStats[2];
      expect(day.isLogged, isTrue);
      expect(day.overLimit, isFalse);
      expect(day.gainPaise, greaterThan(0));
    });

    test('a day over the limit is red and its badge negative', () {
      final day = summaryWith([debit(3, 520)]).dayStats[2];
      expect(day.overLimit, isTrue);
      expect(day.gainPaise, lessThan(0));
      expect(Money.rupees(day.gainPaise), '₹187');
    });

    test('a non-daily debit alone leaves the day within limit', () {
      // Rent does not eat the daily allowance, but it is still "total spent".
      final day = summaryWith([debit(3, 16000, category: 'Bills')]).dayStats[2];
      expect(day.overLimit, isFalse);
      expect(day.dailyPaise, 0);
      expect(Money.rupees(day.totalSpentPaise), '₹16,000');
    });

    test('future days are neither logged nor over', () {
      final future = summaryWith(const []).dayStats[20];
      expect(future.isFuture, isTrue);
      expect(future.isLogged, isFalse);
    });

    test('a past month counts all its days as elapsed', () {
      final october = summaryWith(
        const [],
        month: DateTime(2026, 10),
      );
      expect(october.daysElapsed, 31);
      expect(october.dayStats.every((d) => !d.isFuture), isTrue);
    });

    test('a future month has elapsed nothing', () {
      final december = summaryWith(const [], month: DateTime(2026, 12));
      expect(december.daysElapsed, 0);
      expect(december.dayStats.every((d) => d.isFuture), isTrue);
      expect(december.dailyAllowedSoFarPaise, 0);
    });
  });

  group('Stats breakdown', () {
    test('categories are ordered by spend, largest first', () {
      final summary = summaryWith([
        debit(1, 100),
        debit(2, 5000, category: 'Bills'),
      ]);
      expect(
        summary.categoryTotals.map((c) => c.name).toList(),
        ['Bills', kDailyExpensesName],
      );
    });

    test('a category with no budget reports zero rather than throwing', () {
      final summary = summaryWith([debit(1, 500, category: 'Petrol')]);
      final row = summary.categoryTotals.single;
      expect(row.name, 'Petrol');
      expect(row.budgetPaise, 0);
    });

    test('credits are excluded from the category breakdown', () {
      final summary = summaryWith([
        debit(1, 100),
        Entry(
          id: 'c',
          amountPaise: 50000,
          isCredit: true,
          category: 'Bills',
          date: DateTime(2026, 11, 1),
        ),
      ]);
      expect(summary.categoryTotals.map((c) => c.name), [kDailyExpensesName]);
      expect(Money.rupees(summary.totalCreditsPaise), '₹500');
    });

    test('an empty month produces no category rows', () {
      expect(summaryWith(const []).categoryTotals, isEmpty);
    });
  });

  group('Edge cases that would otherwise divide by zero', () {
    test('a budget with no daily-expenses item has no limit', () {
      const bare = MonthBudget(
        monthKey: '2026-11',
        salaryPaise: 11273900,
        items: [BudgetItem(id: 'b', name: 'Bills', amountPaise: 250000)],
      );
      final summary = MonthSummary(
        month: DateTime(2026, 11),
        budget: bare,
        entries: const [],
        today: DateTime(2026, 11, 10),
      );
      expect(summary.dailyLimitPaise, 0);
      expect(summary.todayProgress, 0);
      expect(summary.dailyProgress, 0);
    });

    test('a zero salary does not blow up the percentages', () {
      const unpaid = MonthBudget(
        monthKey: '2026-11',
        salaryPaise: 0,
        items: [
          BudgetItem(
            id: 'daily',
            name: kDailyExpensesName,
            amountPaise: 1000000,
            pinned: true,
          ),
        ],
      );
      final summary = MonthSummary(
        month: DateTime(2026, 11),
        budget: unpaid,
        entries: [debit(1, 100)],
        today: DateTime(2026, 11, 10),
      );
      expect(summary.salaryUsedFraction, 0);
      expect(summary.savedFraction, 0);
      expect(Money.percent(summary.salaryUsedFraction), '0.0%');
    });
  });
}
