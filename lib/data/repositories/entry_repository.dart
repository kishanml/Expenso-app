import '../../core/format/dates.dart';
import '../hive/hive_boxes.dart';
import '../models/entry.dart';

/// Reads and writes logged entries.
class EntryRepository {
  List<Entry> get all => HiveBoxes.entriesBox.values.toList();

  /// Every entry in [month], newest first.
  List<Entry> forMonth(DateTime month) {
    final result = HiveBoxes.entriesBox.values
        .where((e) => Dates.sameMonth(e.date, month))
        .toList();
    _sortNewestFirst(result);
    return result;
  }

  /// Every entry on [day], newest first.
  List<Entry> forDay(DateTime day) {
    final result = HiveBoxes.entriesBox.values
        .where((e) => Dates.sameDay(e.date, day))
        .toList();
    _sortNewestFirst(result);
    return result;
  }

  Future<void> save(Entry entry) =>
      HiveBoxes.entriesBox.put(entry.id, entry);

  Future<void> delete(String id) => HiveBoxes.entriesBox.delete(id);

  Future<void> deleteAll() => HiveBoxes.entriesBox.clear();

  static void _sortNewestFirst(List<Entry> list) {
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
  }
}
