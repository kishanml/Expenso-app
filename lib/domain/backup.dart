import '../data/models/budget_item.dart';
import '../data/models/entry.dart';
import '../data/models/month_budget.dart';

/// Raised when an imported file is not an Expenso backup, or is one this build
/// cannot read.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A whole-app snapshot: every budget, every entry, and the preferences.
///
/// There is no cloud, so this file is the only backup a person has. The format
/// is plain JSON rather than a Hive dump so it stays readable and portable
/// even if the storage layer is ever replaced.
class Backup {
  const Backup({
    required this.budgets,
    required this.entries,
    required this.themeMode,
    required this.appLock,
    this.exportedAt,
  });

  /// Bumped only on a breaking change. [fromJson] refuses anything newer,
  /// because a future build's file may contain fields this one would silently
  /// drop on the next export.
  static const formatVersion = 1;
  static const _marker = 'expenso';

  final List<MonthBudget> budgets;
  final List<Entry> entries;
  final String themeMode;
  final bool appLock;
  final DateTime? exportedAt;

  Map<String, dynamic> toJson() => {
        'app': _marker,
        'version': formatVersion,
        'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
        'settings': {
          'themeMode': themeMode,
          'appLock': appLock,
        },
        'budgets': [
          for (final budget in budgets)
            {
              'monthKey': budget.monthKey,
              'salaryPaise': budget.salaryPaise,
              'items': [
                for (final item in budget.items)
                  {
                    'id': item.id,
                    'name': item.name,
                    'amountPaise': item.amountPaise,
                    'pinned': item.pinned,
                  },
              ],
            },
        ],
        'entries': [
          for (final entry in entries)
            {
              'id': entry.id,
              'amountPaise': entry.amountPaise,
              'isCredit': entry.isCredit,
              'category': entry.category,
              'date': entry.date.toIso8601String(),
              'note': entry.note,
              'createdAt': entry.createdAt.toIso8601String(),
            },
        ],
      };

  factory Backup.fromJson(Map<String, dynamic> json) {
    if (json['app'] != _marker) {
      throw const BackupFormatException(
        'That file is not an Expenso backup.',
      );
    }

    final version = json['version'];
    if (version is! int) {
      throw const BackupFormatException('That backup file is damaged.');
    }
    if (version > formatVersion) {
      throw const BackupFormatException(
        'That backup was made by a newer version of Expenso. '
        'Update the app and try again.',
      );
    }

    try {
      final settings = (json['settings'] as Map?) ?? const {};

      return Backup(
        exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
        themeMode: settings['themeMode'] as String? ?? 'light',
        appLock: settings['appLock'] as bool? ?? false,
        budgets: [
          for (final raw in (json['budgets'] as List? ?? const []))
            _budgetFrom(raw as Map),
        ],
        entries: [
          for (final raw in (json['entries'] as List? ?? const []))
            _entryFrom(raw as Map),
        ],
      );
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
        'That backup file could not be read. It may be damaged.',
      );
    }
  }

  static MonthBudget _budgetFrom(Map raw) => MonthBudget(
        monthKey: raw['monthKey'] as String,
        salaryPaise: raw['salaryPaise'] as int,
        items: [
          for (final item in (raw['items'] as List? ?? const []))
            BudgetItem(
              id: item['id'] as String,
              name: item['name'] as String,
              amountPaise: item['amountPaise'] as int,
              pinned: item['pinned'] as bool? ?? false,
            ),
        ],
      );

  static Entry _entryFrom(Map raw) {
    final date = DateTime.parse(raw['date'] as String);
    return Entry(
      id: raw['id'] as String,
      amountPaise: raw['amountPaise'] as int,
      isCredit: raw['isCredit'] as bool,
      category: raw['category'] as String,
      date: DateTime(date.year, date.month, date.day),
      note: raw['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? date,
    );
  }

  /// `expenso-backup-2026-11-11.json`
  static String fileNameFor(DateTime when) {
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return 'expenso-backup-$y-$m-$d.json';
  }
}
