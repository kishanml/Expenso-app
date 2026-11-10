import 'dart:io';

import 'package:expenso/core/theme/app_theme.dart';
import 'package:expenso/data/hive/hive_boxes.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/state/app_state.dart';
import 'package:expenso/ui/screens/add_entry/add_entry_screen.dart';
import 'package:expenso/ui/screens/budget/budget_screen.dart';
import 'package:expenso/ui/screens/calendar/calendar_screen.dart';
import 'package:expenso/ui/screens/lock/lock_screen.dart';
import 'package:expenso/ui/screens/settings/settings_screen.dart';
import 'package:expenso/ui/screens/shell/app_shell.dart';
import 'package:expenso/ui/screens/stats/stats_screen.dart';
import 'package:expenso/ui/screens/splash/splash_screen.dart';
import 'package:expenso/ui/screens/welcome/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

/// Renders each Phase 1 screen at the mockups' 390×844 phone frame and writes
/// a golden, so the layout can be held against
/// `expenso-design/screens/*.dc.html`.
///
/// Refresh with `flutter test test/golden --update-goldens`.
///
/// Note: every Hive write happens in `setUpAll`. Inside a `testWidgets` body
/// the binding runs a fake clock, and Hive's file I/O never completes there.
void main() {
  /// 10 November 2026 — the date the mockups are drawn on.
  final mockToday = DateTime(2026, 11, 10);

  late Directory tempDir;

  setUpAll(() async {
    // Real Inter, not the test placeholder font, or every measurement in the
    // golden would be wrong.
    final loader = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File('assets/fonts/Inter-$weight.ttf')
            .readAsBytes()
            .then((bytes) => bytes.buffer.asByteData()),
      );
    }
    await loader.load();

    tempDir = await Directory.systemTemp.createTemp('expenso_golden');
    await HiveBoxes.init(path: tempDir.path);

    await HiveBoxes.settingsBox.put('setupComplete', true);
    await HiveBoxes.budgetsBox.put('2026-11', _mockBudget);

    for (var i = 0; i < _mockEntries.length; i++) {
      final row = _mockEntries[i];
      await HiveBoxes.entriesBox.put(
        'e$i',
        Entry(
          id: 'e$i',
          amountPaise: row.$4 * 100,
          isCredit: row.$5,
          category: row.$3,
          date: DateTime(2026, 11, row.$1),
          note: row.$2,
          // Descending minute keeps each day's rows in the mockup's order.
          createdAt: DateTime(2026, 11, row.$1, 12, 59 - i),
        ),
      );
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // A 390×844 phone's real insets: status bar above, home indicator below.
  // Without them the screens sit flush to the frame edge and the padding
  // reads wrong against the mockups.
  Widget frame(Widget child, {ThemeData? theme, double height = 844}) =>
      MediaQuery(
        data: MediaQueryData(
          size: Size(390, height),
          padding: const EdgeInsets.only(top: 47, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme ?? AppTheme.light,
          home: child,
        ),
      );

  Future<void> shoot(
    WidgetTester tester,
    Widget child,
    String name, {
    ThemeData? theme,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(frame(child, theme: theme, height: height));
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('images/$name.png'),
    );
  }

  testWidgets('splash', (tester) async {
    await shoot(tester, SplashScreen(onGetStarted: () {}), 'splash');
  });

  testWidgets('welcome', (tester) async {
    await shoot(
      tester,
      WelcomeScreen(today: mockToday, onSaved: (_) {}),
      'welcome',
    );
  });

  testWidgets('home', (tester) async {
    final state = AppState()..clock = () => mockToday;
    await shoot(
      tester,
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const AppShell(),
      ),
      'home',
    );
  });

  testWidgets('add entry empty', (tester) async {
    await shoot(
      tester,
      AddEntryScreen(categories: _categories, today: mockToday),
      'add_entry_empty',
    );
  });

  testWidgets('add entry filled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(frame(
      AddEntryScreen(categories: _categories, today: mockToday),
    ));

    // Type 250 on the in-app keypad, exactly as the mockup's state shows.
    for (final key in ['2', '5', '0']) {
      await tester.tap(find.bySemanticsLabel(key));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('images/add_entry_filled.png'),
    );
  });

  testWidgets('calendar', (tester) async {
    final state = AppState()..clock = () => mockToday;
    await shoot(
      tester,
      Scaffold(
        body: SafeArea(
          bottom: false,
          child: CalendarScreen(
            summary: state.summaryFor(mockToday),
            month: DateTime(2026, 11),
            today: mockToday,
            onChangeMonth: (_) {},
            entriesForDay: state.entriesForDay,
            onOpenEntry: (_) {},
          ),
        ),
      ),
      'calendar',
      // The mockup is drawn at 1060 tall, not the phone frame.
      height: 1060,
    );
  });

  testWidgets('stats', (tester) async {
    final state = AppState()..clock = () => mockToday;
    await shoot(
      tester,
      Scaffold(
        body: SafeArea(
          bottom: false,
          child: StatsScreen(
            summary: state.summaryFor(mockToday),
            month: DateTime(2026, 11),
            today: mockToday,
            onChangeMonth: (_) {},
          ),
        ),
      ),
      'stats',
      // The mockup is drawn at 1240 tall.
      height: 1240,
    );
  });

  testWidgets('budget', (tester) async {
    final state = AppState()..clock = () => mockToday;
    await shoot(
      tester,
      Scaffold(
        body: SafeArea(
          bottom: false,
          child: BudgetScreen(
            budget: state.budgetFor(mockToday),
            month: DateTime(2026, 11),
            today: mockToday,
            onSave: (_, _) {},
          ),
        ),
      ),
      'budget',
      // The mockup is drawn at 1000 tall.
      height: 1000,
    );
  });

  testWidgets('settings', (tester) async {
    await shoot(
      tester,
      Scaffold(
        body: SafeArea(
          bottom: false,
          child: SettingsScreen(
            themeMode: ThemeMode.light,
            appLock: true,
            appLockAvailable: true,
            busy: false,
            onExport: () {},
            onImport: () {},
            onToggleAppLock: (_) {},
            onThemeChanged: (_) {},
          ),
        ),
      ),
      'settings',
    );
  });

  testWidgets('lock', (tester) async {
    await shoot(
      tester,
      LockScreen(onUnlock: () {}, failed: false),
      'lock',
    );
  });

  testWidgets('home dark', (tester) async {
    final state = AppState()..clock = () => mockToday;
    await shoot(
      tester,
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const AppShell(),
      ),
      'home_dark',
      theme: AppTheme.dark,
    );
  });
}

/// The chip order Add entry offers: the pinned item first, then the month's
/// other budget items.
const _categories = [
  kDailyExpensesName,
  'Rent',
  'Money home',
  'EMI',
  'Shopping',
  'Bills',
  'Gym',
];

/// The item list from `Budget.dc.html`, in paise.
const _mockBudget = MonthBudget(
  monthKey: '2026-11',
  salaryPaise: 11273900,
  items: [
    BudgetItem(
      id: 'daily',
      name: kDailyExpensesName,
      amountPaise: 1000000,
      pinned: true,
    ),
    BudgetItem(id: 'rent', name: 'Rent', amountPaise: 1600000),
    BudgetItem(id: 'home', name: 'Money home', amountPaise: 1500000),
    BudgetItem(id: 'emi', name: 'EMI', amountPaise: 810800),
    BudgetItem(id: 'shop', name: 'Shopping', amountPaise: 400000),
    BudgetItem(id: 'bills', name: 'Bills', amountPaise: 250000),
    BudgetItem(id: 'gym', name: 'Gym', amountPaise: 150000),
  ],
);

/// The `data` map from `Calendar.dc.html`: (day, note, category, rupees,
/// isCredit). Days 9 and 10 are what Home shows as Yesterday and Today.
const _mockEntries = <(int, String, String, int, bool)>[
  (10, 'Lunch', kDailyExpensesName, 180, false),
  (10, 'Auto to college', kDailyExpensesName, 70, false),
  (10, 'Electricity bill', 'Bills', 1240, false),
  (9, 'Dinner', kDailyExpensesName, 245, false),
  (9, 'Cashback', 'Shopping', 120, true),
  (9, 'Coffee', kDailyExpensesName, 120, false),
  (7, 'Groceries', kDailyExpensesName, 300, false),
  (7, 'Shoes', 'Shopping', 1899, false),
  (6, 'Tea', kDailyExpensesName, 90, false),
  (5, 'Dinner out', kDailyExpensesName, 520, false),
  (5, 'Gym membership', 'Gym', 1500, false),
  (4, 'Lunch', kDailyExpensesName, 183, false),
  (4, 'Snacks', kDailyExpensesName, 150, false),
  (3, 'Auto', kDailyExpensesName, 150, false),
  (3, 'Sent home', 'Money home', 15000, false),
  (2, 'Lunch', kDailyExpensesName, 210, false),
  (2, 'Movie', kDailyExpensesName, 200, false),
  (2, 'Bike EMI', 'EMI', 8108, false),
  (1, 'Breakfast', kDailyExpensesName, 80, false),
  (1, 'Groceries', kDailyExpensesName, 200, false),
  (1, 'November rent', 'Rent', 16000, false),
];
