/// How sure the parser is that it read a message correctly.
///
/// Nothing is ever written to the ledger on the parser's word alone, but a
/// low-confidence reading is worth showing differently so the person looks
/// harder before confirming it.
enum ParseConfidence {
  /// Amount, direction and an account or card tail all found.
  high,

  /// Amount and direction found, but nothing identifying the account.
  medium,
}

/// A bank or UPI message the parser recognised as a completed transaction.
///
/// This is a *reading* of a message, not an entry. It becomes an [Entry] only
/// when the person confirms it.
class TransactionSms {
  const TransactionSms({
    required this.amountPaise,
    required this.isCredit,
    required this.date,
    required this.confidence,
    this.merchant,
    this.accountTail,
    this.bank,
  });

  final int amountPaise;
  final bool isCredit;

  /// The transaction's own date when the message states one, otherwise the
  /// day the message arrived.
  final DateTime date;

  final ParseConfidence confidence;

  /// Who the money went to or came from — a UPI handle, a card merchant, or
  /// a bill description. Null when the message does not say.
  final String? merchant;

  /// The last digits of the account or card, e.g. "1234".
  final String? accountTail;

  /// The sender bank, when the message names one.
  final String? bank;

  /// What to put in the entry's note. Falls back to something honest rather
  /// than inventing a description.
  String get suggestedNote => merchant ?? (isCredit ? 'Money in' : 'Money out');

  @override
  String toString() => 'TransactionSms(${isCredit ? '+' : '-'}$amountPaise, '
      'merchant: $merchant, account: $accountTail, date: $date)';
}
