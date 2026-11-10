/// Money formatting for Expenso.
///
/// Amounts are stored and passed around as **integer paise** so that no
/// rounding error can accumulate. Rupees are a display concern only.
///
/// Grouping is Indian: the last three digits, then pairs — ₹1,12,739.
/// Paise are shown only for the daily limit (₹333.33), per DESIGN.md.
abstract final class Money {
  static const rupee = '₹';

  /// Groups a digit string Indian-style. "112739" → "1,12,739".
  static String groupDigits(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);

    final buf = StringBuffer();
    // Walk the leading part right-to-left in pairs.
    for (var i = 0; i < rest.length; i++) {
      final fromRight = rest.length - i;
      if (i > 0 && fromRight.isEven) buf.write(',');
      buf.write(rest[i]);
    }
    return '$buf,$last3';
  }

  /// ₹2,698 — whole rupees, paise rounded away. The default for every figure
  /// in the app except the daily limit.
  static String rupees(int paise) {
    final whole = (paise.abs() / 100).round();
    return '$rupee${groupDigits(whole.toString())}';
  }

  /// ₹333.33 — two decimal places, used for the daily limit only.
  static String rupeesPaise(int paise) {
    final abs = paise.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return '$rupee${groupDigits(whole.toString())}.$frac';
  }

  /// Drops the trailing ".00" so a whole-rupee limit reads ₹333 not ₹333.00.
  static String rupeesPaiseTrim(int paise) {
    if (paise.abs() % 100 == 0) return rupees(paise);
    return rupeesPaise(paise);
  }

  /// −₹180 / +₹120. Uses U+2212 minus, matching the mockups, not a hyphen.
  static String signed(int paise, {bool credit = false}) {
    final sign = credit ? '+' : '−';
    return '$sign${rupees(paise)}';
  }

  /// +₹66,294 for a gain, −₹1,240 for a loss, based on the value's own sign.
  static String withSign(int paise) {
    final sign = paise < 0 ? '−' : '+';
    return '$sign${rupees(paise)}';
  }

  /// "41.2%" — one decimal, as every percentage in the mockups is shown.
  static String percent(double fraction) =>
      '${(fraction * 100).toStringAsFixed(1)}%';

  /// Parses user keypad/field input ("1,12,739" or "250.5") into paise.
  static int parseToPaise(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;
    final parts = cleaned.split('.');
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    var frac = 0;
    if (parts.length > 1) {
      final f = parts[1].padRight(2, '0').substring(0, 2);
      frac = int.tryParse(f) ?? 0;
    }
    return whole * 100 + frac;
  }

  /// Formats a raw digit string being typed on the in-app keypad, preserving a
  /// trailing "." and partial paise so the field doesn't fight the user.
  static String groupTyped(String raw) {
    final parts = raw.split('.');
    final grouped = groupDigits(parts[0].isEmpty ? '0' : parts[0]);
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }
}
