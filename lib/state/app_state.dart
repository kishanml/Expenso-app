import 'package:flutter/material.dart';

import '../core/format/dates.dart';
import '../data/models/entry.dart';
import '../data/models/month_budget.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/entry_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/sms_inbox_service.dart';
import '../domain/backup.dart';
import '../domain/sms/entry_suggestion.dart';
import '../domain/month_summary.dart';

/// The app's single source of truth. Composes the three repositories and
/// notifies on every write, so screens rebuild from Hive rather than holding
/// their own copies of the data.
class AppState extends ChangeNotifier {
  AppState({
    SettingsRepository? settings,
    BudgetRepository? budgets,
    EntryRepository? entries,
    SmsInboxService? sms,
  })  : _settings = settings ?? SettingsRepository(),
        _budgets = budgets ?? BudgetRepository(),
        _entries = entries ?? EntryRepository(),
        _sms = sms ?? const SmsInboxService();

  final SettingsRepository _settings;
  final BudgetRepository _budgets;
  final EntryRepository _entries;
  final SmsInboxService _sms;

  /// Overridable so tests and the mockup-parity checks can pin a date.
  DateTime Function() clock = DateTime.now;

  DateTime get today => Dates.dayOnly(clock());

  // ── Settings ────────────────────────────────────────────────────────────

  bool get setupComplete => _settings.setupComplete;
  ThemeMode get themeMode => _settings.themeMode;
  bool get appLock => _settings.appLock;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setAppLock(bool value) async {
    await _settings.setAppLock(value);
    notifyListeners();
  }

  // ── Reading bank SMS ────────────────────────────────────────────────────

  bool get smsEnabled => _settings.smsEnabled;

  /// Suggestions waiting to be confirmed. Held in memory only: they are a view
  /// of the inbox, not data of our own.
  List<EntrySuggestion> get suggestions => List.unmodifiable(_suggestions);
  var _suggestions = <EntrySuggestion>[];

  Future<void> setSmsEnabled(bool value) async {
    await _settings.setSmsEnabled(value);
    if (!value) _suggestions = [];
    notifyListeners();
  }

  /// Reads new messages and works out which look like transactions.
  ///
  /// Looks back 30 days on the first scan so there is something to review
  /// straight away, and only since the last scan after that.
  Future<void> scanMessages({int firstScanDays = 30}) async {
    if (!smsEnabled) return;

    final last = _settings.lastSmsScan;
    final since = last.millisecondsSinceEpoch == 0
        ? today.subtract(Duration(days: firstScanDays))
        : last;

    final messages = await _sms.readInbox(since: since);

    _suggestions = SuggestionBuilder.build(
      messages: [
        for (final message in messages)
          (
            id: message.id,
            body: message.body,
            receivedAt: message.receivedAt,
            sender: message.sender,
          ),
      ],
      handledIds: _settings.handledSmsIds,
      categories: categories,
    );

    await _settings.setLastSmsScan(clock());
    notifyListeners();
  }

  /// Confirms a suggestion: writes the entry and never offers it again.
  Future<void> acceptSuggestion(
    EntrySuggestion suggestion, {
    String? category,
    String? note,
  }) async {
    await _entries.save(
      suggestion.toEntry(categoryOverride: category, noteOverride: note),
    );
    await _forget(suggestion);
  }

  /// Dismisses a suggestion without writing anything.
  Future<void> skipSuggestion(EntrySuggestion suggestion) =>
      _forget(suggestion);

  Future<void> _forget(EntrySuggestion suggestion) async {
    await _settings.markSmsHandled([suggestion.messageId]);
    _suggestions = [
      for (final other in _suggestions)
        if (other.messageId != suggestion.messageId) other,
    ];
    notifyListeners();
  }

  // ── Budget ──────────────────────────────────────────────────────────────

  /// The budget in force for [month], carried forward from the latest earlier
  /// snapshot when that month has none of its own.
  MonthBudget budgetFor(DateTime month) =>
      _budgets.forMonth(month) ?? MonthBudget.seed(Dates.monthKey(month));

  MonthBudget get currentBudget => budgetFor(today);

  /// Completes first-time setup: writes the opening budget for this month and
  /// flips the setup flag so the splash no longer leads here.
  Future<void> completeSetup(MonthBudget budget) async {
    await _budgets.save(budget.copyWith(monthKey: Dates.monthKey(today)));
    await _settings.setSetupComplete(true);
    notifyListeners();
  }

  /// Saves a budget edit, effective from [from] onward.
  Future<void> saveBudget(MonthBudget budget, {required DateTime from}) async {
    await _budgets.applyFrom(from, budget);
    notifyListeners();
  }

  // ── Backup ──────────────────────────────────────────────────────────────

  /// Everything the app holds, ready to be written to a file.
  Backup buildBackup() => Backup(
        budgets: _budgets.all,
        entries: _entries.all,
        themeMode: themeMode == ThemeMode.dark ? 'dark' : 'light',
        appLock: appLock,
      );

  /// Replaces all stored data with [backup].
  ///
  /// A restore replaces rather than merges: merging two histories would
  /// silently double up entries that exist in both, and there is no way for
  /// the app to tell which copy is right.
  Future<void> restore(Backup backup) async {
    await _entries.deleteAll();
    await _budgets.deleteAll();

    for (final budget in backup.budgets) {
      await _budgets.save(budget);
    }
    for (final entry in backup.entries) {
      await _entries.save(entry);
    }

    await _settings.setThemeMode(
      backup.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
    );
    await _settings.setAppLock(backup.appLock);
    // A restored file always contains a budget, so setup is behind us.
    await _settings.setSetupComplete(backup.budgets.isNotEmpty);

    notifyListeners();
  }

  // ── Entries ─────────────────────────────────────────────────────────────

  List<Entry> entriesForMonth(DateTime month) => _entries.forMonth(month);
  List<Entry> entriesForDay(DateTime day) => _entries.forDay(day);

  /// Entries from the last [days] days, newest first — the Home list.
  ///
  /// Deliberately not month-scoped: on the 1st, "Yesterday" belongs to the
  /// previous month and would otherwise vanish from the list.
  List<Entry> recentEntries({int days = 60}) {
    final cutoff = today.subtract(Duration(days: days));
    return _entries.all
        .where((e) => !e.date.isBefore(cutoff))
        .toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> saveEntry(Entry entry) async {
    await _entries.save(entry);
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await _entries.delete(id);
    notifyListeners();
  }

  // ── Derived ─────────────────────────────────────────────────────────────

  MonthSummary summaryFor(DateTime month) => MonthSummary(
        month: month,
        budget: budgetFor(month),
        entries: entriesForMonth(month),
        today: today,
      );

  MonthSummary get currentSummary => summaryFor(today);

  /// The category chips offered on Add entry: the pinned Daily-expenses item
  /// first, then the month's other budget items in their listed order.
  List<String> get categories {
    final items = currentBudget.items;
    final pinned = items.where((i) => i.pinned).map((i) => i.name);
    final rest = items.where((i) => !i.pinned).map((i) => i.name);
    return [...pinned, ...rest];
  }
}
