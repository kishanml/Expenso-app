/// One line of a month's budget — "Rent", "EMI", "Daily expenses".
class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.name,
    required this.amountPaise,
    this.pinned = false,
  });

  final String id;
  final String name;
  final int amountPaise;

  /// "Daily expenses" is pinned: always present, never removable. It is the
  /// item the daily limit is derived from.
  final bool pinned;

  BudgetItem copyWith({String? name, int? amountPaise}) => BudgetItem(
        id: id,
        name: name ?? this.name,
        amountPaise: amountPaise ?? this.amountPaise,
        pinned: pinned,
      );
}

/// The reserved name of the pinned item. The daily limit is this item's amount
/// divided by the number of days in the month.
const kDailyExpensesName = 'Daily expenses';
