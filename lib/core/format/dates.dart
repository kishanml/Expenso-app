import 'package:intl/intl.dart';

/// Date labels, copied from the wording in the mockups.
abstract final class Dates {
  /// "Tuesday, 10 Nov" — Home header.
  static String longHeader(DateTime d) => DateFormat('EEEE, d MMM').format(d);

  /// "Tue, 9 Nov" — Calendar day-detail title.
  static String shortDay(DateTime d) => DateFormat('EEE, d MMM').format(d);

  /// "10 Nov" — AddEntry date button, prefixed with "Today, " when it is today.
  static String dayMonth(DateTime d) => DateFormat('d MMM').format(d);

  /// "November 2026" — Calendar and Stats month headers.
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  /// "November" — the apply-from sheet's button labels.
  static String monthName(DateTime d) => DateFormat('MMMM').format(d);

  /// "November 2026" key-safe form used to key budgets: "2026-11".
  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime fromMonthKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Midnight of the given day — the canonical form for storing an entry date.
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  static DateTime nextMonth(DateTime d) => DateTime(d.year, d.month + 1);

  static DateTime previousMonth(DateTime d) => DateTime(d.year, d.month - 1);
}
