import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/sms/entry_suggestion.dart';
import '../../../domain/sms/transaction_sms.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/pill_button.dart';

/// Review — transactions read out of bank messages, waiting to be confirmed.
///
/// No mockup exists for this; it is built from the system's own parts. The
/// shape is deliberate: **nothing is written until the person taps Add**.
/// An inferred amount in the wrong category quietly distorts every figure in
/// the app, so the guess is always shown as a guess.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    super.key,
    required this.suggestions,
    required this.categories,
    required this.onAccept,
    required this.onSkip,
  });

  final List<EntrySuggestion> suggestions;
  final List<String> categories;
  final void Function(EntrySuggestion suggestion, String category) onAccept;
  final ValueChanged<EntrySuggestion> onSkip;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Scaffold(
      backgroundColor: s.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                0,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: AppIcons.close,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'From your messages',
                      textAlign: TextAlign.center,
                      style: AppText.sheetTitle,
                    ),
                  ),
                  const SizedBox(width: AppSizes.touch),
                ],
              ),
            ),
            Expanded(
              child: suggestions.isEmpty
                  ? _Empty(s: s)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.lg,
                        AppSpacing.screen,
                        AppSpacing.xl,
                      ),
                      itemCount: suggestions.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xxs,
                            ),
                            child: Text(
                              'Expenso read these from your bank messages. '
                              'Nothing is added until you say so.',
                              style: AppText.meta.copyWith(
                                color: s.textSecondary,
                                height: 18 / 13,
                              ),
                            ),
                          );
                        }
                        final suggestion = suggestions[index - 1];
                        return _SuggestionCard(
                          key: ValueKey(suggestion.messageId),
                          suggestion: suggestion,
                          categories: categories,
                          onAccept: (category) =>
                              onAccept(suggestion, category),
                          onSkip: () => onSkip(suggestion),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.s});

  final AppSurfaces s;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nothing to review', style: AppText.row),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'New bank messages will show up here.',
                textAlign: TextAlign.center,
                style: AppText.meta.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    super.key,
    required this.suggestion,
    required this.categories,
    required this.onAccept,
    required this.onSkip,
  });

  final EntrySuggestion suggestion;
  final List<String> categories;
  final ValueChanged<String> onAccept;
  final VoidCallback onSkip;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  late String _category = widget.suggestion.category;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final transaction = widget.suggestion.transaction;
    final isCredit = transaction.isCredit;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.suggestedNote,
                      style: AppText.row,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(transaction),
                      style: AppText.caption.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Money.signed(transaction.amountPaise, credit: isCredit),
                style: AppText.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCredit ? s.success : s.ink,
                ),
              ),
            ],
          ),

          // A medium-confidence reading is called out rather than dressed up
          // as a certainty.
          if (transaction.confidence == ParseConfidence.medium) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '! Check this one — the message did not name an account',
              style: AppText.caption.copyWith(color: s.error),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Text(
            'Category',
            style: AppText.caption.copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in widget.categories)
                ChipButton(
                  label: category,
                  selected: category == _category,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Skip',
                  variant: PillVariant.subtle,
                  height: AppSizes.touch,
                  expand: true,
                  textStyle: AppText.bodySmStrong,
                  onPressed: widget.onSkip,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PillButton(
                  label: 'Add',
                  height: AppSizes.touch,
                  textStyle: AppText.bodySmStrong,
                  onPressed: () => widget.onAccept(_category),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(TransactionSms transaction) {
    final parts = <String>[
      Dates.shortDay(transaction.date),
      if (transaction.bank != null) transaction.bank!,
      if (transaction.accountTail != null) '••${transaction.accountTail}',
    ];
    return parts.join(' · ');
  }
}
