import 'transaction_sms.dart';

/// Reads an Indian bank or UPI SMS and works out what the transaction was.
///
/// Everything here is pure text work — no permissions, no plugins, no network.
/// That matters twice over: it keeps the app's offline promise intact, and it
/// means the hard part can be tested exhaustively against real message shapes.
///
/// The parser is deliberately **reluctant**. A wrong reading quietly corrupts
/// someone's budget, so anything it is not sure about returns null and is
/// never shown. It refuses OTPs, balance updates, payment requests, failed
/// payments and anything scheduled for the future.
abstract final class SmsParser {
  /// Returns null when [body] is not a completed transaction.
  static TransactionSms? parse(String body, {required DateTime receivedAt}) {
    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();
    if (_isDisqualified(lower)) return null;

    final isCredit = _direction(lower);
    if (isCredit == null) return null;

    final amountPaise = _amount(text);
    if (amountPaise == null || amountPaise <= 0) return null;

    final accountTail = _accountTail(text);

    // A message with a direction verb and an amount but nothing resembling an
    // account is usually marketing ("get Rs 500 cashback when you pay with").
    // It is only accepted when something else makes it concrete.
    final hasUpiMarker =
        lower.contains('upi') || lower.contains('vpa') || lower.contains('ref');
    if (accountTail == null && !hasUpiMarker) return null;

    return TransactionSms(
      amountPaise: amountPaise,
      isCredit: isCredit,
      date: _date(text) ?? DateTime(
        receivedAt.year,
        receivedAt.month,
        receivedAt.day,
      ),
      confidence:
          accountTail != null ? ParseConfidence.high : ParseConfidence.medium,
      merchant: _merchant(text, isCredit: isCredit),
      accountTail: accountTail,
      bank: _bank(text),
    );
  }

  // ── Rejection ───────────────────────────────────────────────────────────

  /// Phrases that mean "this is not money that has already moved".
  static final _disqualifiers = [
    // One-time passwords quote an amount but move nothing.
    RegExp(r'\botp\b'),
    RegExp(r'one[ -]time password'),
    RegExp(r'do not share'),
    RegExp(r'\bverification code\b'),

    // Scheduled or requested, not done.
    RegExp(r'\bwill be (?:debited|credited|deducted|charged)\b'),
    RegExp(r'\bis due\b|\bdue on\b|\bdue date\b'),
    RegExp(r'\bhas requested\b|\brequesting\b|\bcollect request\b'),
    RegExp(r'\bplease pay\b|\bkindly pay\b|\bpay now\b'),

    // Did not go through — or was taken back, which the reversing credit
    // message will report separately.
    RegExp(r'\bfailed\b|\bdeclined\b|\bunsuccessful\b|\bcould not be\b'),

    // Marketing.
    RegExp(r'\bapply now\b|\boffer\b|\bwin \b|\bupgrade\b|\beligible for\b'),
    RegExp(r'\bt&c\b|\bterms and conditions\b'),
  ];

  static bool _isDisqualified(String lower) =>
      _disqualifiers.any((pattern) => pattern.hasMatch(lower));

  // ── Direction ───────────────────────────────────────────────────────────

  static final _creditWords = RegExp(
    r'\bcredited\b|\breceived\b|\brefund(?:ed)?\b|\bcashback\b|'
    r'\bdeposited\b|\breversed\b',
  );

  static final _debitWords = RegExp(
    r'\bdebited\b|\bspent\b|\bpaid\b|\bwithdrawn\b|\bpurchase[d]?\b|'
    r'\bsent\b|\bdeducted\b|\bcharged\b|\btransferred\b',
  );

  /// True for money in, false for money out, null when the message does not
  /// say which — in which case it is not a transaction we can use.
  static bool? _direction(String lower) {
    final credit = _creditWords.firstMatch(lower);
    final debit = _debitWords.firstMatch(lower);

    if (credit == null && debit == null) return null;
    if (credit != null && debit == null) return true;
    if (debit != null && credit == null) return false;

    // Both appear — "debited from A and credited to B". The first verb is
    // the one describing this account's side of it.
    return credit!.start < debit!.start;
  }

  // ── Amount ──────────────────────────────────────────────────────────────

  static final _amountPattern = RegExp(
    r'(?:(?:rs|inr)\.?\s*|₹\s*)([0-9][0-9,]*(?:\.[0-9]{1,2})?)'
    r'|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  /// Words that mark the number after them as a balance or a limit, not the
  /// transaction. Without this the parser reads "Avl Bal Rs 45,000" as a
  /// ₹45,000 expense.
  static final _notTheAmount = RegExp(
    r'(?:avl|avbl|available|a/c|ac|closing|total|current)?\s*'
    r'(?:bal|balance|limit|outstanding)\s*(?:is|:)?\s*$',
    caseSensitive: false,
  );

  static int? _amount(String text) {
    for (final match in _amountPattern.allMatches(text)) {
      final before = text.substring(
        (match.start - 24).clamp(0, text.length),
        match.start,
      );
      if (_notTheAmount.hasMatch(before)) continue;

      final digits = match.group(1) ?? match.group(2);
      if (digits == null) continue;

      final paise = _toPaise(digits);
      if (paise != null && paise > 0) return paise;
    }
    return null;
  }

  static int? _toPaise(String digits) {
    final cleaned = digits.replaceAll(',', '');
    final parts = cleaned.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;

    var frac = 0;
    if (parts.length > 1) {
      frac = int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0;
    }
    return whole * 100 + frac;
  }

  // ── Account ─────────────────────────────────────────────────────────────

  static final _accountPattern = RegExp(
    r'(?:a/c|a/c no|ac|acct|account|card)\.?\s*(?:no\.?|number)?\s*'
    r'[xX*]+\s*(\d{3,6})',
    caseSensitive: false,
  );

  /// Some banks write the mask without a leading keyword: "XX1234".
  static final _bareMaskPattern =
      RegExp(r'(?:[xX*]{2,})\s*(\d{3,6})\b');

  static String? _accountTail(String text) =>
      _accountPattern.firstMatch(text)?.group(1) ??
      _bareMaskPattern.firstMatch(text)?.group(1);

  // ── Date ────────────────────────────────────────────────────────────────

  static final _numericDate = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2}|\d{4})\b',
  );

  static final _namedMonthDate = RegExp(
    r'\b(\d{1,2})[-/ ]'
    r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*'
    r'[-/ ](\d{2}|\d{4})\b',
    caseSensitive: false,
  );

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Indian bank messages are day-first throughout, so 10-11-26 is
  /// 10 November 2026, never 11 October.
  static DateTime? _date(String text) {
    final named = _namedMonthDate.firstMatch(text);
    if (named != null) {
      return _build(
        int.parse(named.group(1)!),
        _months[named.group(2)!.toLowerCase()]!,
        int.parse(named.group(3)!),
      );
    }

    final numeric = _numericDate.firstMatch(text);
    if (numeric != null) {
      return _build(
        int.parse(numeric.group(1)!),
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(3)!),
      );
    }
    return null;
  }

  static DateTime? _build(int day, int month, int year) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final fullYear = year < 100 ? 2000 + year : year;

    final date = DateTime(fullYear, month, day);
    // Rejects 31 February, which DateTime would roll into March.
    if (date.day != day || date.month != month) return null;
    return date;
  }

  // ── Merchant ────────────────────────────────────────────────────────────

  static final _vpaPattern =
      RegExp(r'(?:to|from)?\s*(?:vpa\s*)?([\w.\-]{2,})@[\w.\-]+');

  static final _atMerchant = RegExp(
    r'\bat\s+([A-Za-z][A-Za-z0-9 &.\-\*]{2,29})',
  );

  static final _towards = RegExp(
    r'\b(?:towards|for)\s+([A-Za-z][A-Za-z0-9 &.\-]{2,29})',
    caseSensitive: false,
  );

  static final _toFrom = RegExp(
    r'\b(?:to|from)\s+([A-Za-z][A-Za-z0-9 &.\-]{2,29})',
    caseSensitive: false,
  );

  /// Trailing words that belong to the next clause, not the merchant name.
  static final _trailingNoise = RegExp(
    r'\s*\b(?:on|ref|refno|upi|txn|info|avl|bal|dated|date|'
    r'your|the|a/c|ac|account|card|is|was|has|and)\b.*$',
    caseSensitive: false,
  );

  static String? _merchant(String text, {required bool isCredit}) {
    // A UPI handle is the most reliable identifier when it is there.
    final vpa = _vpaPattern.firstMatch(text);
    if (vpa != null) {
      final handle = _clean(vpa.group(1));
      if (handle != null) return handle;
    }

    for (final pattern in [_atMerchant, _towards, _toFrom]) {
      final match = pattern.firstMatch(text);
      final value = _clean(match?.group(1));
      if (value != null) return value;
    }
    return null;
  }

  /// A sentence break, or the " -HDFC Bank" signature banks append. Cutting
  /// on "period + space" rather than any period keeps names like AMAZON.IN
  /// intact.
  static final _sentenceBreak = RegExp(r'(?:\.\s|\s[-\u2013\u2014]\s?).*$');

  static String? _clean(String? raw) {
    if (raw == null) return null;

    var value = raw.replaceAll(_sentenceBreak, '');
    value = value.replaceAll(_trailingNoise, '');
    value = value.replaceAll(RegExp(r'[\s.\-*]+$'), '').trim();

    // Reject leftovers that are only digits, or too short to mean anything.
    if (value.length < 3) return null;
    if (RegExp(r'^[\d\s]+$').hasMatch(value)) return null;

    return value;
  }

  // ── Bank ────────────────────────────────────────────────────────────────

  static final _banks = {
    'hdfc': 'HDFC Bank',
    'icici': 'ICICI Bank',
    'sbi': 'SBI',
    'axis': 'Axis Bank',
    'kotak': 'Kotak',
    'yes bank': 'Yes Bank',
    'idfc': 'IDFC FIRST',
    'pnb': 'PNB',
    'canara': 'Canara Bank',
    'bob': 'Bank of Baroda',
    'indusind': 'IndusInd',
    'paytm': 'Paytm',
    'phonepe': 'PhonePe',
    'gpay': 'Google Pay',
  };

  static String? _bank(String text) {
    final lower = text.toLowerCase();
    for (final entry in _banks.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
