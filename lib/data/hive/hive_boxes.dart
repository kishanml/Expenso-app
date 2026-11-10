import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/entry.dart';
import '../models/month_budget.dart';
import 'adapters.dart';

/// Opens every box the app uses. All data lives in these three boxes on the
/// phone — there is no network layer anywhere in Expenso.
abstract final class HiveBoxes {
  static const entries = 'entries';
  static const budgets = 'budgets';
  static const settings = 'settings';

  /// Opens the store. [path] is for tests and tooling only — on a device the
  /// location comes from the platform, via `initFlutter`.
  static Future<void> init({String? path}) async {
    if (path == null) {
      await Hive.initFlutter('expenso');
    } else {
      Hive.init(path);
    }

    if (!Hive.isAdapterRegistered(HiveTypeIds.entry)) {
      Hive.registerAdapter(EntryAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.budgetItem)) {
      Hive.registerAdapter(BudgetItemAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.monthBudget)) {
      Hive.registerAdapter(MonthBudgetAdapter());
    }

    await Future.wait([
      Hive.openBox<Entry>(entries),
      Hive.openBox<MonthBudget>(budgets),
      Hive.openBox<dynamic>(settings),
    ]);
  }

  static Box<Entry> get entriesBox => Hive.box<Entry>(entries);
  static Box<MonthBudget> get budgetsBox => Hive.box<MonthBudget>(budgets);
  static Box<dynamic> get settingsBox => Hive.box<dynamic>(settings);
}
