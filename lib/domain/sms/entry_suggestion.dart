import '../../data/models/entry.dart';
import 'category_matcher.dart';
import 'sms_parser.dart';
import 'transaction_sms.dart';

/// A transaction read out of a message, ready for the person to confirm.
///
/// Holds the message's id so a suggestion that is accepted or skipped is never
/// offered again.
class EntrySuggestion {
  const EntrySuggestion({
    required this.messageId,
    required this.transaction,
    required this.category,
    this.sender,
  });

  final String messageId;
  final TransactionSms transaction;

  /// The guessed budget item. The review screen shows it pre-selected and
  /// lets the person change it.
  final String category;

  final String? sender;

  /// Turns the suggestion into a real entry. Nothing calls this until the
  /// person has confirmed what they are looking at.
  Entry toEntry({String? categoryOverride, String? noteOverride}) => Entry(
        // Keyed by message, so re-importing the same message twice would
        // overwrite rather than duplicate.
        id: 'sms-$messageId',
        amountPaise: transaction.amountPaise,
        isCredit: transaction.isCredit,
        category: categoryOverride ?? category,
        date: transaction.date,
        note: noteOverride ?? transaction.suggestedNote,
      );
}

/// Turns a batch of raw messages into suggestions worth showing.
abstract final class SuggestionBuilder {
  /// Parses [messages], drops anything already handled, and returns the rest
  /// newest first.
  ///
  /// [handledIds] are messages already imported or skipped. [categories] are
  /// the month's budget item names, so a guess can never name a category the
  /// budget does not have.
  static List<EntrySuggestion> build({
    required List<({String id, String body, DateTime receivedAt, String? sender})>
        messages,
    required Set<String> handledIds,
    required List<String> categories,
  }) {
    final suggestions = <EntrySuggestion>[];

    for (final message in messages) {
      if (handledIds.contains(message.id)) continue;

      final transaction = SmsParser.parse(
        message.body,
        receivedAt: message.receivedAt,
      );
      if (transaction == null) continue;

      suggestions.add(EntrySuggestion(
        messageId: message.id,
        transaction: transaction,
        category: CategoryMatcher.match(transaction.merchant, categories),
        sender: message.sender,
      ));
    }

    suggestions.sort(
      (a, b) => b.transaction.date.compareTo(a.transaction.date),
    );
    return suggestions;
  }
}
