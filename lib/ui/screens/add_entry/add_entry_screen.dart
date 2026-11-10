import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/budget_item.dart';
import '../../../data/models/entry.dart';
import '../../../domain/amount_input.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/keypad.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/segmented_toggle.dart';

/// What Add entry hands back when it closes.
sealed class AddEntryResult {
  const AddEntryResult();
}

class SaveEntryResult extends AddEntryResult {
  const SaveEntryResult(this.entry);
  final Entry entry;
}

class DeleteEntryResult extends AddEntryResult {
  const DeleteEntryResult(this.id);
  final String id;
}

/// Add entry — `AddEntry.dc.html`.
///
/// Amount on the in-app keypad, Debit/Credit, a category chip, the date and an
/// optional note. Save stays disabled until the amount is above zero.
///
/// Opening it with [existing] set turns it into an editor: the title changes
/// and the header's right-hand slot — an empty spacer when adding — becomes
/// the delete button. The Home mockup links each row here, so editing is what
/// those rows are for.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    super.key,
    required this.categories,
    required this.today,
    this.existing,
  });

  final List<String> categories;
  final DateTime today;
  final Entry? existing;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late AmountInput _amount;
  late bool _isCredit;
  late String _category;
  late DateTime _date;
  late final TextEditingController _note;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _amount = existing == null
        ? const AmountInput()
        : AmountInput.fromPaise(existing.amountPaise);
    _isCredit = existing?.isCredit ?? false;
    _date = existing?.date ?? widget.today;
    _note = TextEditingController(text: existing?.note ?? '');

    // Default to the pinned Daily-expenses item, which is what most entries
    // are, falling back to whatever the budget's first item is.
    _category = existing?.category ??
        (widget.categories.contains(kDailyExpensesName)
            ? kDailyExpensesName
            : widget.categories.firstOrNull ?? kDailyExpensesName);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _onKey(String key) => setState(() => _amount = _amount.press(key));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Logging into the future is not something a spend tracker should
      // encourage, but back-dating a forgotten entry is routine.
      firstDate: DateTime(widget.today.year - 5),
      lastDate: widget.today,
    );
    if (picked != null && mounted) {
      setState(() => _date = Dates.dayOnly(picked));
    }
  }

  Future<void> _save() async {
    if (!_amount.isValid) return;

    // The hint promises a confirmation above ₹10 lakh, so honour it.
    if (_amount.needsConfirmation && !await _confirmLargeAmount()) return;
    if (!mounted) return;

    final existing = widget.existing;
    final entry = existing != null
        ? existing.copyWith(
            amountPaise: _amount.paise,
            isCredit: _isCredit,
            category: _category,
            date: _date,
            note: _note.text.trim(),
          )
        : Entry(
            id: 'e${DateTime.now().microsecondsSinceEpoch}',
            amountPaise: _amount.paise,
            isCredit: _isCredit,
            category: _category,
            date: _date,
            note: _note.text.trim(),
          );

    Navigator.of(context).pop(SaveEntryResult(entry));
  }

  Future<bool> _confirmLargeAmount() async {
    final s = AppSurfaces.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: s.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Confirm this amount', style: AppText.displaySm),
        content: Text(
          'That is ${Money.rupeesPaiseTrim(_amount.paise)}. '
          'Is that right?',
          style: AppText.bodySm.copyWith(color: s.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Go back',
              style: AppText.bodySmStrong.copyWith(color: s.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes, save it',
              style: AppText.bodySmStrong.copyWith(color: s.ink),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete() async {
    final s = AppSurfaces.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: s.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete this entry?', style: AppText.displaySm),
        content: Text(
          'It will be removed from your totals. This cannot be undone.',
          style: AppText.bodySm.copyWith(color: s.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep it',
              style: AppText.bodySmStrong.copyWith(color: s.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppText.bodySmStrong.copyWith(color: s.error),
            ),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      Navigator.of(context).pop(DeleteEntryResult(widget.existing!.id));
    }
  }

  /// "Today, 10 Nov" — or the weekday for any other day.
  String get _dateLabel {
    if (Dates.sameDay(_date, widget.today)) {
      return 'Today, ${Dates.dayMonth(_date)}';
    }
    if (Dates.sameDay(_date, widget.today.subtract(const Duration(days: 1)))) {
      return 'Yesterday, ${Dates.dayMonth(_date)}';
    }
    return Dates.shortDay(_date);
  }

  String get _hint {
    if (!_amount.isValid) return 'Enter an amount';
    if (_amount.needsConfirmation) {
      return "Over ₹10 lakh — we'll ask you to confirm";
    }
    return '$_category · ${_isCredit ? 'money in' : 'money out'}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final valid = _amount.isValid;

    return Scaffold(
      backgroundColor: s.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          child: Column(
            children: [
              _header(s),
              const SizedBox(height: AppSpacing.lg),

              // The upper half scrolls, so a small screen or an open system
              // keyboard never pushes the keypad or Save out of reach.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _amountDisplay(s, valid),
                      const SizedBox(height: AppSpacing.lg),
                      _typeToggle(),
                      const SizedBox(height: AppSpacing.lg),
                      _categories(s),
                      const SizedBox(height: AppSpacing.lg),
                      _dateAndNote(s),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Keypad(onKey: _onKey),
              const SizedBox(height: AppSpacing.lg),
              PillButton(
                label: _isEditing ? 'Save changes' : 'Save entry',
                onPressed: valid ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppSurfaces s) => Row(
        children: [
          CircleIconButton(
            icon: AppIcons.close,
            semanticLabel: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit entry' : 'Add entry',
              textAlign: TextAlign.center,
              style: AppText.sheetTitle,
            ),
          ),
          if (_isEditing)
            CircleIconButton(
              icon: AppIcons.trash,
              semanticLabel: 'Delete entry',
              background: Colors.transparent,
              foreground: s.error,
              onPressed: _delete,
            )
          else
            const SizedBox(width: AppSizes.touch),
        ],
      );

  Widget _amountDisplay(AppSurfaces s, bool valid) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Text(
                '${_isCredit ? '+' : '−'}'
                '${Money.rupee}${_amount.display}',
                style: AppText.amountFigure.copyWith(
                  color: !valid
                      ? s.placeholder
                      : _isCredit
                          ? s.success
                          : s.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _hint,
                textAlign: TextAlign.center,
                style: AppText.meta.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _typeToggle() => SegmentedToggle<bool>(
        semanticLabel: 'Type',
        value: _isCredit,
        onChanged: (credit) => setState(() => _isCredit = credit),
        segments: const [
          (value: false, label: '− Debit'),
          (value: true, label: '+ Credit'),
        ],
      );

  Widget _categories(AppSurfaces s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: AppText.metaStrong.copyWith(color: s.textSecondary),
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
        ],
      );

  Widget _dateAndNote(AppSurfaces s) => Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Date, $_dateLabel',
              child: Material(
                color: s.soft,
                borderRadius: AppRadius.none,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _pickDate,
                  child: Container(
                    height: AppSizes.touch,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        AppIcon(AppIcons.calendar, size: 16, color: s.ink),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            _dateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodySmStrong.copyWith(color: s.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: AppSizes.touch,
              color: s.soft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: TextField(
                controller: _note,
                style: AppText.bodySm.copyWith(color: s.ink),
                cursorColor: s.ink,
                cursorWidth: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Note (optional)',
                  hintStyle:
                      AppText.bodySm.copyWith(color: s.placeholder),
                ),
              ),
            ),
          ),
        ],
      );
}
