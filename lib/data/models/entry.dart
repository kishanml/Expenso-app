/// A single logged amount — money out (debit) or money in (credit).
///
/// [amountPaise] is always a positive magnitude; [isCredit] carries the
/// direction. Storing the sign separately keeps "total spent" and "total
/// received" sums unambiguous.
class Entry {
  Entry({
    required this.id,
    required this.amountPaise,
    required this.isCredit,
    required this.category,
    required this.date,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final int amountPaise;
  final bool isCredit;

  /// The budget item this entry counts against, by name — e.g. "Daily
  /// expenses", "Rent". Matched by name so renaming a budget item in a later
  /// month never rewrites history.
  final String category;

  /// Midnight of the day the entry belongs to.
  final DateTime date;
  final String note;
  final DateTime createdAt;

  /// Signed value in paise: negative for money out, positive for money in.
  int get signedPaise => isCredit ? amountPaise : -amountPaise;

  /// First letter of the note, used for the list-row avatar. Falls back to the
  /// category when there is no note.
  String get initial {
    final source = note.trim().isNotEmpty ? note.trim() : category;
    return source.isEmpty ? '?' : source[0].toUpperCase();
  }

  /// What the row shows as its title — the note, or the category when blank.
  String get title => note.trim().isNotEmpty ? note.trim() : category;

  Entry copyWith({
    int? amountPaise,
    bool? isCredit,
    String? category,
    DateTime? date,
    String? note,
  }) =>
      Entry(
        id: id,
        amountPaise: amountPaise ?? this.amountPaise,
        isCredit: isCredit ?? this.isCredit,
        category: category ?? this.category,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}
