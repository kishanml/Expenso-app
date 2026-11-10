import '../core/format/money.dart';

/// The state of the amount being typed on the in-app keypad.
///
/// Held as the raw digit string rather than a number, so a half-typed value
/// like "333." survives a rebuild and the caret behaves the way the mockup's
/// `press()` does. The rules below are that function's, kept deliberately:
///
///  * at most two decimal places
///  * at most nine digits in total
///  * a leading "0" is replaced rather than appended to
///  * "." is accepted only once, and inserts a leading "0" if needed
class AmountInput {
  const AmountInput([this.raw = '']);

  final String raw;

  static const _maxDigits = 9;
  static const _maxDecimals = 2;

  /// Amounts above ₹10 lakh ask for confirmation before saving — a tap-slip on
  /// the keypad is otherwise indistinguishable from a real large entry.
  static const confirmAbovePaise = 100000000;

  AmountInput press(String key) => switch (key) {
        'del' => backspace(),
        '.' => _dot(),
        _ => _digit(key),
      };

  AmountInput backspace() =>
      raw.isEmpty ? this : AmountInput(raw.substring(0, raw.length - 1));

  AmountInput _dot() {
    if (raw.contains('.')) return this;
    return AmountInput('${raw.isEmpty ? '0' : raw}.');
  }

  AmountInput _digit(String key) {
    final dot = raw.indexOf('.');
    if (dot >= 0 && raw.length - dot > _maxDecimals) return this;
    if (raw.replaceAll('.', '').length >= _maxDigits) return this;
    return AmountInput(raw == '0' ? key : '$raw$key');
  }

  int get paise => Money.parseToPaise(raw);

  /// Nothing can be saved until an actual amount has been entered.
  bool get isValid => paise > 0;

  bool get needsConfirmation => paise > confirmAbovePaise;

  /// What the big figure shows — grouped, with a half-typed decimal intact.
  String get display => Money.groupTyped(raw.isEmpty ? '0' : raw);

  /// Seeds the keypad from a stored amount, for editing an existing entry.
  factory AmountInput.fromPaise(int paise) {
    if (paise <= 0) return const AmountInput();
    final whole = paise ~/ 100;
    final frac = paise % 100;
    if (frac == 0) return AmountInput(whole.toString());
    return AmountInput('$whole.${frac.toString().padLeft(2, '0')}');
  }
}
