import 'budget_item.dart';

/// A budget as it applied to one specific month, keyed "YYYY-MM".
///
/// Each month stores its own snapshot. That is what lets past months keep the
/// budget they had, so their calendar colours and stats never change when the
/// budget is edited later.
class MonthBudget {
  const MonthBudget({
    required this.monthKey,
    required this.salaryPaise,
    required this.items,
  });

  final String monthKey;
  final int salaryPaise;
  final List<BudgetItem> items;

  /// The pinned "Daily expenses" item, or null if somehow absent.
  BudgetItem? get dailyExpenses {
    for (final item in items) {
      if (item.pinned || item.name == kDailyExpensesName) return item;
    }
    return null;
  }

  int get dailyExpensesPaise => dailyExpenses?.amountPaise ?? 0;

  /// Sum of every budget item, including Daily expenses.
  int get budgetedPaise =>
      items.fold(0, (sum, item) => sum + item.amountPaise);

  /// salary − budgeted. What the Welcome and Budget screens call
  /// "Planned savings".
  int get plannedSavingsPaise => salaryPaise - budgetedPaise;

  /// Looks up a budget item's allowance by name, for the Stats category bars.
  int budgetForCategory(String name) {
    for (final item in items) {
      if (item.name == name) return item.amountPaise;
    }
    return 0;
  }

  MonthBudget copyWith({
    String? monthKey,
    int? salaryPaise,
    List<BudgetItem>? items,
  }) =>
      MonthBudget(
        monthKey: monthKey ?? this.monthKey,
        salaryPaise: salaryPaise ?? this.salaryPaise,
        items: items ?? this.items,
      );

  /// The budget a brand-new install starts from, matching the values shown in
  /// Welcome.dc.html.
  static MonthBudget seed(String monthKey) => MonthBudget(
        monthKey: monthKey,
        salaryPaise: 11273900,
        items: const [
          BudgetItem(
            id: 'daily',
            name: kDailyExpensesName,
            amountPaise: 1000000,
            pinned: true,
          ),
          BudgetItem(id: 'rent', name: 'Rent', amountPaise: 1600000),
          BudgetItem(id: 'emi', name: 'EMI', amountPaise: 810800),
        ],
      );
}
