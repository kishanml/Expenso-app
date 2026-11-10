import '../../core/format/dates.dart';
import '../hive/hive_boxes.dart';
import '../models/month_budget.dart';

/// Reads and writes the per-month budget snapshots.
class BudgetRepository {
  /// The budget that applied in [month].
  ///
  /// When that month has no snapshot of its own, the most recent earlier
  /// snapshot is carried forward — a budget stays in force until it is
  /// changed. A month before any snapshot falls back to the earliest one, so
  /// the app always has a budget to work from.
  MonthBudget? forMonth(DateTime month) {
    final box = HiveBoxes.budgetsBox;
    if (box.isEmpty) return null;

    final key = Dates.monthKey(month);
    final exact = box.get(key);
    if (exact != null) return exact;

    final keys = box.keys.cast<String>().toList()..sort();

    String? best;
    for (final k in keys) {
      if (k.compareTo(key) <= 0) {
        best = k;
      } else {
        break;
      }
    }
    // Carried forward, or the earliest snapshot for a month before all of them.
    return box.get(best ?? keys.first)?.copyWith(monthKey: key);
  }

  Future<void> save(MonthBudget budget) =>
      HiveBoxes.budgetsBox.put(budget.monthKey, budget);

  /// Writes the budget so it takes effect from [month] onward.
  ///
  /// Any later snapshots are removed, because an edit applied from a month
  /// supersedes the months after it. Earlier months are untouched, which is
  /// what keeps their stats stable.
  Future<void> applyFrom(DateTime month, MonthBudget budget) async {
    final key = Dates.monthKey(month);
    final box = HiveBoxes.budgetsBox;

    final later = box.keys
        .cast<String>()
        .where((k) => k.compareTo(key) > 0)
        .toList();
    await box.deleteAll(later);
    await box.put(key, budget.copyWith(monthKey: key));
  }

  /// Every stored snapshot, oldest month first.
  List<MonthBudget> get all {
    final keys = HiveBoxes.budgetsBox.keys.cast<String>().toList()..sort();
    return [
      for (final key in keys) ?HiveBoxes.budgetsBox.get(key),
    ];
  }

  Future<void> deleteAll() => HiveBoxes.budgetsBox.clear();

  bool get hasAny => HiveBoxes.budgetsBox.isNotEmpty;
}
