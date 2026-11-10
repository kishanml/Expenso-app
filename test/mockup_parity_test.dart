import 'package:expenso/core/format/money.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity checks against the approved mockups in `expenso-design/screens/`.
///
/// The mock data is self-consistent, so every figure printed in Home.dc.html,
/// Calendar.dc.html, Stats.dc.html, Welcome.dc.html and Budget.dc.html is a
/// fixture the formulas have to reproduce. `PRD.md` was not delivered with the
/// designs, so these tests stand in for it.
void main() {
  // The Budget.dc.html item list, in paise.
  final budget = MonthBudget(
    monthKey: '2026-11',
    salaryPaise: 11273900, // ₹1,12,739
    items: const [
      BudgetItem(
          id: 'daily',
          name: kDailyExpensesName,
          amountPaise: 1000000,
          pinned: true),
      BudgetItem(id: 'rent', name: 'Rent', amountPaise: 1600000),
      BudgetItem(id: 'home', name: 'Money home', amountPaise: 1500000),
      BudgetItem(id: 'emi', name: 'EMI', amountPaise: 810800),
      BudgetItem(id: 'shop', name: 'Shopping', amountPaise: 400000),
      BudgetItem(id: 'bills', name: 'Bills', amountPaise: 250000),
      BudgetItem(id: 'gym', name: 'Gym', amountPaise: 150000),
    ],
  );

  // The Calendar.dc.html `data` map: day -> [note, category, rupees].
  // A negative amount there is a credit.
  const raw = <int, List<List<Object>>>{
    1: [
      ['Breakfast', kDailyExpensesName, 80],
      ['Groceries', kDailyExpensesName, 200],
      ['November rent', 'Rent', 16000],
    ],
    2: [
      ['Lunch', kDailyExpensesName, 210],
      ['Movie', kDailyExpensesName, 200],
      ['Bike EMI', 'EMI', 8108],
    ],
    3: [
      ['Auto', kDailyExpensesName, 150],
      ['Sent home', 'Money home', 15000],
    ],
    4: [
      ['Lunch', kDailyExpensesName, 183],
      ['Snacks', kDailyExpensesName, 150],
    ],
    5: [
      ['Dinner out', kDailyExpensesName, 520],
      ['Gym membership', 'Gym', 1500],
    ],
    6: [
      ['Tea', kDailyExpensesName, 90]
    ],
    7: [
      ['Groceries', kDailyExpensesName, 300],
      ['Shoes', 'Shopping', 1899],
    ],
    8: [],
    9: [
      ['Dinner', kDailyExpensesName, 245],
      ['Coffee', kDailyExpensesName, 120],
      ['Cashback', 'Shopping', -120],
    ],
    10: [
      ['Lunch', kDailyExpensesName, 180],
      ['Auto to college', kDailyExpensesName, 70],
      ['Electricity bill', 'Bills', 1240],
    ],
  };

  final entries = <Entry>[];
  raw.forEach((day, rows) {
    for (var i = 0; i < rows.length; i++) {
      final rupees = rows[i][2] as int;
      entries.add(Entry(
        id: '$day-$i',
        amountPaise: rupees.abs() * 100,
        isCredit: rupees < 0,
        category: rows[i][1] as String,
        date: DateTime(2026, 11, day),
        note: rows[i][0] as String,
      ));
    }
  });

  final summary = MonthSummary(
    month: DateTime(2026, 11),
    budget: budget,
    entries: entries,
    today: DateTime(2026, 11, 10),
  );

  group('Money formatting', () {
    test('groups rupees Indian-style', () {
      expect(Money.rupees(11273900), '₹1,12,739');
      expect(Money.rupees(6629400), '₹66,294');
      expect(Money.rupees(5710800), '₹57,108');
      expect(Money.rupees(269800), '₹2,698');
      expect(Money.rupees(189900), '₹1,899');
      expect(Money.rupees(1000000), '₹10,000');
      expect(Money.rupees(8300), '₹83');
    });

    test('shows paise only where the design asks for it', () {
      expect(Money.rupeesPaise(33333), '₹333.33');
      expect(Money.rupees(33333), '₹333');
    });

    test('uses a true minus sign, not a hyphen', () {
      expect(Money.signed(18000), '−₹180');
      expect(Money.signed(12000, credit: true), '+₹120');
    });

    test('round-trips keypad input', () {
      expect(Money.parseToPaise('1,12,739'), 11273900);
      expect(Money.parseToPaise('250'), 25000);
      expect(Money.parseToPaise('333.33'), 33333);
      expect(Money.parseToPaise('333.3'), 33330);
    });
  });

  group('Home.dc.html', () {
    test('daily limit is ₹333.33', () {
      expect(Money.rupeesPaise(summary.dailyLimitRounded), '₹333.33');
    });

    test('remaining today is ₹83 on ₹250 spent', () {
      expect(Money.rupees(summary.todaySpentPaise), '₹250');
      expect(Money.rupees(summary.todayRemainingPaise), '₹83');
      expect(summary.todayWithinLimit, isTrue);
    });

    test('today progress is 75%', () {
      expect((summary.todayProgress * 100).round(), 75);
    });

    test('salary used is 41.2%', () {
      expect(Money.percent(summary.salaryUsedFraction), '41.2%');
    });

    test('saved so far is +₹66,294', () {
      expect(Money.withSign(summary.savedPaise), '+₹66,294');
    });

    test('daily expenses so far is ₹2,698 of ₹3,333', () {
      expect(Money.rupees(summary.dailySoFarPaise), '₹2,698');
      expect(Money.rupees(summary.dailyAllowedSoFarPaise), '₹3,333');
    });

    test('daily progress bar is 81%', () {
      expect((summary.dailyProgress * 100).round(), 81);
    });
  });

  group('Stats.dc.html', () {
    test('debit and credit totals', () {
      expect(Money.rupees(summary.totalDebitsPaise), '₹46,445');
      expect(Money.rupees(summary.totalCreditsPaise), '₹120');
    });

    test('saved is 58.8% of salary', () {
      expect(Money.percent(summary.savedFraction), '58.8%');
    });

    test('daily expenses saved is +₹635', () {
      expect(Money.withSign(summary.dailySavedPaise), '+₹635');
    });

    test('category totals match the mockup rows', () {
      final rows = {
        for (final c in summary.categoryTotals)
          c.name: (Money.rupees(c.spentPaise), Money.rupees(c.budgetPaise))
      };
      expect(rows['Rent'], ('₹16,000', '₹16,000'));
      expect(rows['Money home'], ('₹15,000', '₹15,000'));
      expect(rows['EMI'], ('₹8,108', '₹8,108'));
      expect(rows[kDailyExpensesName], ('₹2,698', '₹10,000'));
      expect(rows['Shopping'], ('₹1,899', '₹4,000'));
      expect(rows['Gym'], ('₹1,500', '₹1,500'));
      expect(rows['Bills'], ('₹1,240', '₹2,500'));
    });

    test('categories are ordered largest first, as drawn', () {
      expect(
        summary.categoryTotals.map((c) => c.name).toList(),
        ['Rent', 'Money home', 'EMI', kDailyExpensesName, 'Shopping', 'Gym',
          'Bills'],
      );
    });

    test('daily trend matches the bar array in the mockup', () {
      final spend = summary.dayStats
          .take(10)
          .map((d) => d.dailyPaise ~/ 100)
          .toList();
      expect(spend, [280, 410, 150, 333, 520, 90, 300, 0, 365, 250]);
    });
  });

  group('Calendar.dc.html', () {
    test('three days are over the limit', () {
      expect(summary.overLimitDayCount, 3);
      final over = summary.dayStats
          .where((d) => d.isLogged && d.overLimit)
          .map((d) => d.day)
          .toList();
      expect(over, [2, 5, 9]);
    });

    test('day 8 has nothing logged and so is untinted', () {
      final d8 = summary.dayStats[7];
      expect(d8.hasEntries, isFalse);
      expect(d8.isLogged, isFalse);
      expect(d8.overLimit, isFalse);
    });

    test('day 10 badge reads +83', () {
      expect(summary.dayStats[9].gainPaise ~/ 100, 83);
    });

    test('day 9 badge is negative — overspent', () {
      final d9 = summary.dayStats[8];
      expect(d9.overLimit, isTrue);
      expect(d9.gainPaise.isNegative, isTrue);
      expect(Money.rupees(d9.gainPaise), '₹32');
    });

    test('day 1 total spent counts rent as well as daily expenses', () {
      expect(Money.rupees(summary.dayStats[0].totalSpentPaise), '₹16,280');
      expect(Money.rupees(summary.dayStats[0].dailyPaise), '₹280');
    });

    test('days after today are future, not empty', () {
      expect(summary.dayStats[10].isFuture, isTrue);
      expect(summary.dayStats[9].isFuture, isFalse);
    });
  });

  group('Budget.dc.html and Welcome.dc.html', () {
    test('full budget totals ₹57,108 with +₹55,631 planned savings', () {
      expect(Money.rupees(budget.budgetedPaise), '₹57,108');
      expect(Money.withSign(budget.plannedSavingsPaise), '+₹55,631');
    });

    test('the seed budget matches the first-time setup screen', () {
      final seed = MonthBudget.seed('2026-11');
      expect(Money.rupees(seed.salaryPaise), '₹1,12,739');
      expect(Money.rupees(seed.budgetedPaise), '₹34,108');
      expect(Money.withSign(seed.plannedSavingsPaise), '+₹78,631');
      expect(Money.rupeesPaise((seed.dailyExpensesPaise / 30).round()),
          '₹333.33');
    });
  });

  group('A 31-day month spreads the same allowance differently', () {
    test('₹10,000 over 31 days is ₹322.58 a day', () {
      final dec = MonthSummary(
        month: DateTime(2026, 12),
        budget: budget.copyWith(monthKey: '2026-12'),
        entries: const [],
        today: DateTime(2026, 12, 1),
      );
      expect(Money.rupeesPaise(dec.dailyLimitRounded), '₹322.58');
    });
  });
}
