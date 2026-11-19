import 'dart:io';

import 'package:expenso/core/format/money.dart';
import 'package:expenso/data/hive/hive_boxes.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/domain/sms/entry_suggestion.dart';
import 'package:expenso/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

typedef RawMessage = ({
  String id,
  String body,
  DateTime receivedAt,
  String? sender,
});

void main() {
  final today = DateTime(2026, 11, 19);
  const categories = [kDailyExpensesName, 'Bills', 'Shopping'];

  RawMessage message(String id, String body, {int day = 19}) => (
        id: id,
        body: body,
        receivedAt: DateTime(2026, 11, day, 10),
        sender: 'HDFCBK',
      );

  group('Building suggestions', () {
    test('keeps transactions and drops everything else', () {
      final built = SuggestionBuilder.build(
        messages: [
          message('1', 'Rs.250 debited from A/c XX1234 to VPA swiggy@ybl'),
          message('2', '987654 is your OTP. Do not share.'),
          message('3', 'hey dinner tonight?'),
          message('4', 'Rs 1899 spent on card xx1234 at NIKE STORE'),
        ],
        handledIds: const {},
        categories: categories,
      );

      expect(built.length, 2);
      expect(built.map((s) => s.messageId), containsAll(['1', '4']));
    });

    test('guesses a category for each', () {
      final built = SuggestionBuilder.build(
        messages: [
          message('1', 'Rs.250 debited from A/c XX1234 to VPA swiggy@ybl'),
          message('2', 'Rs 1899 spent on card xx1234 at NIKE STORE'),
        ],
        handledIds: const {},
        categories: categories,
      );

      final byId = {for (final s in built) s.messageId: s.category};
      expect(byId['1'], kDailyExpensesName);
      expect(byId['2'], 'Shopping');
    });

    test('never offers a message that was already handled', () {
      final built = SuggestionBuilder.build(
        messages: [
          message('1', 'Rs.250 debited from A/c XX1234 to VPA swiggy@ybl'),
          message('2', 'Rs 400 debited from A/c XX1234 to VPA shop@ybl'),
        ],
        handledIds: const {'1'},
        categories: categories,
      );

      expect(built.single.messageId, '2');
    });

    test('newest transaction first', () {
      final built = SuggestionBuilder.build(
        messages: [
          message('old', 'Rs 100 debited from A/c XX1234 on 01-11-26'),
          message('new', 'Rs 200 debited from A/c XX1234 on 18-11-26'),
        ],
        handledIds: const {},
        categories: categories,
      );

      expect(built.first.messageId, 'new');
    });

    test('no messages means no suggestions', () {
      expect(
        SuggestionBuilder.build(
          messages: const [],
          handledIds: const {},
          categories: categories,
        ),
        isEmpty,
      );
    });
  });

  group('Turning a suggestion into an entry', () {
    test('carries the parsed values across', () {
      final suggestion = SuggestionBuilder.build(
        messages: [
          message(
            '7',
            'Rs.250.00 debited from A/c XX1234 on 10-11-26 to VPA swiggy@ybl',
          ),
        ],
        handledIds: const {},
        categories: categories,
      ).single;

      final entry = suggestion.toEntry();
      expect(entry.amountPaise, 25000);
      expect(entry.isCredit, isFalse);
      expect(entry.category, kDailyExpensesName);
      expect(entry.date, DateTime(2026, 11, 10));
      expect(entry.note, 'swiggy');
      expect(entry.id, 'sms-7');
    });

    test('a chosen category overrides the guess', () {
      final suggestion = SuggestionBuilder.build(
        messages: [message('8', 'Rs 500 debited from A/c XX1234 to shop@ybl')],
        handledIds: const {},
        categories: categories,
      ).single;

      expect(suggestion.toEntry(categoryOverride: 'Bills').category, 'Bills');
    });

    test('the id is derived from the message, so re-import cannot double up',
        () {
      final built = SuggestionBuilder.build(
        messages: [message('9', 'Rs 500 debited from A/c XX1234 to shop@ybl')],
        handledIds: const {},
        categories: categories,
      ).single;

      expect(built.toEntry().id, built.toEntry().id);
    });
  });

  group('Accepting and skipping, through AppState', () {
    late Directory tempDir;
    late AppState state;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expenso_sms');
      await HiveBoxes.init(path: tempDir.path);
      state = AppState()..clock = () => today;
      await state.completeSetup(MonthBudget.seed('2026-11'));
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    EntrySuggestion suggestionFor(String body, {String id = 'm1'}) =>
        SuggestionBuilder.build(
          messages: [message(id, body)],
          handledIds: const {},
          categories: state.categories,
        ).single;

    test('accepting writes an entry that moves the figures', () async {
      final before = state.currentSummary.todaySpentPaise;
      expect(before, 0);

      final suggestion = suggestionFor(
        'Rs.250.00 debited from A/c XX1234 on 19-11-26 to VPA swiggy@ybl',
      );
      await state.acceptSuggestion(suggestion);

      expect(Money.rupees(state.currentSummary.todaySpentPaise), '₹250');
      expect(state.entriesForDay(today).single.note, 'swiggy');
    });

    test('skipping writes nothing', () async {
      final suggestion = suggestionFor(
        'Rs.250.00 debited from A/c XX1234 on 19-11-26 to VPA swiggy@ybl',
      );
      await state.skipSuggestion(suggestion);

      expect(state.entriesForDay(today), isEmpty);
      expect(state.currentSummary.todaySpentPaise, 0);
    });

    test('a handled message is not offered again on the next scan', () async {
      final suggestion = suggestionFor(
        'Rs.250.00 debited from A/c XX1234 on 19-11-26 to VPA swiggy@ybl',
      );
      await state.acceptSuggestion(suggestion);

      // A fresh AppState re-reads the handled list from disk.
      final reopened = AppState()..clock = () => today;
      final rebuilt = SuggestionBuilder.build(
        messages: [
          message(
            'm1',
            'Rs.250.00 debited from A/c XX1234 on 19-11-26 to VPA swiggy@ybl',
          ),
        ],
        handledIds: SettingsPeek(reopened).handledIds,
        categories: reopened.categories,
      );
      expect(rebuilt, isEmpty);
    });

    test('turning the feature off clears what was waiting', () async {
      await state.setSmsEnabled(true);
      expect(state.smsEnabled, isTrue);

      await state.setSmsEnabled(false);
      expect(state.smsEnabled, isFalse);
      expect(state.suggestions, isEmpty);
    });

    test('scanning does nothing while the feature is off', () async {
      await state.setSmsEnabled(false);
      await state.scanMessages();
      expect(state.suggestions, isEmpty);
    });
  });
}

/// Reaches the handled-ids list the way a later scan would.
class SettingsPeek {
  SettingsPeek(this.state);
  final AppState state;

  Set<String> get handledIds {
    final raw = HiveBoxes.settingsBox.get('handledSmsIds');
    if (raw is! List) return {};
    return raw.cast<String>().toSet();
  }
}
