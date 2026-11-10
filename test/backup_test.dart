import 'dart:convert';
import 'dart:io';

import 'package:expenso/core/format/money.dart';
import 'package:expenso/data/hive/hive_boxes.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/domain/backup.dart';
import 'package:expenso/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// The backup file is the only copy of a person's data that leaves the phone,
/// so the round trip has to be exact and the failure modes have to be kind.
void main() {
  final mockToday = DateTime(2026, 11, 10);

  final sample = Backup(
    themeMode: 'dark',
    appLock: true,
    exportedAt: DateTime(2026, 11, 10, 9, 30),
    budgets: const [
      MonthBudget(
        monthKey: '2026-10',
        salaryPaise: 10000000,
        items: [
          BudgetItem(
            id: 'daily',
            name: kDailyExpensesName,
            amountPaise: 900000,
            pinned: true,
          ),
        ],
      ),
      MonthBudget(
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
        ],
      ),
    ],
    entries: [
      Entry(
        id: 'a',
        amountPaise: 18000,
        isCredit: false,
        category: kDailyExpensesName,
        date: DateTime(2026, 11, 10),
        note: 'Lunch',
        createdAt: DateTime(2026, 11, 10, 13, 5),
      ),
      Entry(
        id: 'b',
        amountPaise: 12000,
        isCredit: true,
        category: 'Shopping',
        date: DateTime(2026, 11, 9),
        note: 'Cashback',
        createdAt: DateTime(2026, 11, 9, 18),
      ),
    ],
  );

  group('Round trip', () {
    test('survives encoding to JSON text and back', () {
      final text = jsonEncode(sample.toJson());
      final restored =
          Backup.fromJson(jsonDecode(text) as Map<String, dynamic>);

      expect(restored.themeMode, 'dark');
      expect(restored.appLock, isTrue);
      expect(restored.budgets.length, 2);
      expect(restored.entries.length, 2);

      final november = restored.budgets[1];
      expect(november.monthKey, '2026-11');
      expect(Money.rupees(november.salaryPaise), '₹1,12,739');
      expect(november.items.length, 2);
      expect(november.dailyExpenses?.pinned, isTrue);

      final lunch = restored.entries.first;
      expect(lunch.id, 'a');
      expect(lunch.amountPaise, 18000);
      expect(lunch.isCredit, isFalse);
      expect(lunch.note, 'Lunch');
      expect(lunch.date, DateTime(2026, 11, 10));
      expect(lunch.createdAt, DateTime(2026, 11, 10, 13, 5));

      final cashback = restored.entries[1];
      expect(cashback.isCredit, isTrue);
      expect(cashback.category, 'Shopping');
    });

    test('keeps paise exactly', () {
      final odd = Backup(
        themeMode: 'light',
        appLock: false,
        budgets: const [],
        entries: [
          Entry(
            id: 'p',
            amountPaise: 33333,
            isCredit: false,
            category: kDailyExpensesName,
            date: DateTime(2026, 11, 1),
          ),
        ],
      );
      final restored = Backup.fromJson(
        jsonDecode(jsonEncode(odd.toJson())) as Map<String, dynamic>,
      );
      expect(restored.entries.single.amountPaise, 33333);
      expect(Money.rupeesPaise(restored.entries.single.amountPaise),
          '₹333.33');
    });

    test('names the file by date', () {
      expect(
        Backup.fileNameFor(DateTime(2026, 11, 3)),
        'expenso-backup-2026-11-03.json',
      );
    });
  });

  group('Rejecting files that are not ours', () {
    test('a JSON file from somewhere else', () {
      expect(
        () => Backup.fromJson({'hello': 'world'}),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('not an Expenso backup'),
        )),
      );
    });

    test('a backup from a newer version of the app', () {
      expect(
        () => Backup.fromJson({'app': 'expenso', 'version': 99}),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        )),
      );
    });

    test('a damaged file with the right marker', () {
      expect(
        () => Backup.fromJson({
          'app': 'expenso',
          'version': 1,
          'entries': [
            {'id': 'a'}, // missing every other field
          ],
        }),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('damaged'),
        )),
      );
    });

    test('a version field that is not a number', () {
      expect(
        () => Backup.fromJson({'app': 'expenso', 'version': 'one'}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('an empty but valid backup restores to nothing', () {
      final empty = Backup.fromJson({'app': 'expenso', 'version': 1});
      expect(empty.budgets, isEmpty);
      expect(empty.entries, isEmpty);
      expect(empty.themeMode, 'light');
    });
  });

  group('Restoring through AppState', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expenso_backup');
      await HiveBoxes.init(path: tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('export then restore reproduces the same figures', () async {
      final state = AppState()..clock = () => mockToday;

      await state.completeSetup(MonthBudget.seed('2026-11'));
      await state.saveEntry(Entry(
        id: 'x',
        amountPaise: 25000,
        isCredit: false,
        category: kDailyExpensesName,
        date: mockToday,
        note: 'Lunch',
      ));

      final before = state.currentSummary;
      final exported = state.buildBackup();

      // Simulate the file actually being written and read back.
      final text = jsonEncode(exported.toJson());
      final reread = Backup.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

      await state.restore(reread);

      final after = state.currentSummary;
      expect(after.todaySpentPaise, before.todaySpentPaise);
      expect(after.todayRemainingPaise, before.todayRemainingPaise);
      expect(after.savedPaise, before.savedPaise);
      expect(state.entriesForDay(mockToday).single.note, 'Lunch');
    });

    test('restoring replaces rather than merging', () async {
      final state = AppState()..clock = () => mockToday;

      await state.completeSetup(MonthBudget.seed('2026-11'));
      for (final id in ['one', 'two', 'three']) {
        await state.saveEntry(Entry(
          id: id,
          amountPaise: 10000,
          isCredit: false,
          category: kDailyExpensesName,
          date: mockToday,
        ));
      }
      expect(state.entriesForDay(mockToday).length, 3);

      await state.restore(sample);

      // The sample holds two entries, on 9 and 10 November.
      expect(state.entriesForMonth(mockToday).length, 2);
      expect(state.entriesForDay(mockToday).single.note, 'Lunch');
    });

    test('restoring brings back the settings too', () async {
      final state = AppState()..clock = () => mockToday;
      expect(state.themeMode, ThemeMode.light);

      await state.restore(sample);

      expect(state.themeMode, ThemeMode.dark);
      expect(state.appLock, isTrue);
      expect(state.setupComplete, isTrue);
    });

    test('restoring an empty backup leaves setup incomplete', () async {
      final state = AppState()..clock = () => mockToday;
      await state.completeSetup(MonthBudget.seed('2026-11'));
      expect(state.setupComplete, isTrue);

      await state.restore(const Backup(
        budgets: [],
        entries: [],
        themeMode: 'light',
        appLock: false,
      ));

      expect(state.setupComplete, isFalse);
    });
  });
}
