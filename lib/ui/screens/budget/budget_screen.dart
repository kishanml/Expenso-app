import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/budget_item.dart';
import '../../../data/models/month_budget.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/money_field.dart';
import '../../widgets/pill_button.dart';

/// Which month a budget edit starts applying from.
enum ApplyFrom { thisMonth, nextMonth }

/// Budget — `Budget.dc.html`.
///
/// Salary and the month's items, with Daily expenses pinned at the top.
/// Saving asks whether the change starts this month or next, because changing
/// a month already under way rewrites the limits its days were judged by.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.budget,
    required this.month,
    required this.today,
    required this.onSave,
  });

  final MonthBudget budget;
  final DateTime month;
  final DateTime today;
  final void Function(MonthBudget budget, ApplyFrom from) onSave;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late TextEditingController _salary;
  late List<_ItemDraft> _items;
  var _nextId = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.budget);
  }

  @override
  void didUpdateWidget(BudgetScreen old) {
    super.didUpdateWidget(old);
    // The browsed month changed under us, so the editor must follow it.
    if (old.budget.monthKey != widget.budget.monthKey) {
      _disposeDrafts();
      _load(widget.budget);
    }
  }

  void _load(MonthBudget budget) {
    _salary = TextEditingController(
      text: Money.groupDigits((budget.salaryPaise ~/ 100).toString()),
    )..addListener(_recompute);

    _items = [
      for (final item in budget.items)
        _ItemDraft(
          id: item.id,
          name: item.name,
          pinned: item.pinned,
          controller: TextEditingController(
            text: Money.groupDigits((item.amountPaise ~/ 100).toString()),
          )..addListener(_recompute),
        ),
    ];
    _nextId = _items.length;
  }

  void _disposeDrafts() {
    _salary.dispose();
    for (final item in _items) {
      item.dispose();
    }
  }

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _recompute() => setState(() {});

  int get _salaryPaise => Money.parseToPaise(_salary.text);

  int get _budgetedPaise => _items.fold(
        0,
        (sum, item) => sum + Money.parseToPaise(item.controller.text),
      );

  int get _plannedSavingsPaise => _salaryPaise - _budgetedPaise;

  int get _dailyLimitPaise {
    final daily = _items.where((i) => i.pinned).firstOrNull;
    if (daily == null) return 0;
    return (Money.parseToPaise(daily.controller.text) /
            Dates.daysInMonth(widget.month))
        .round();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft(
        id: 'item-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
        name: '',
        pinned: false,
        controller: TextEditingController()..addListener(_recompute),
      ));
    });
  }

  void _removeItem(_ItemDraft draft) {
    setState(() => _items.remove(draft));
    draft.dispose();
  }

  MonthBudget _collect() => MonthBudget(
        monthKey: Dates.monthKey(widget.month),
        salaryPaise: _salaryPaise,
        items: [
          for (final draft in _items)
            if (draft.pinned || draft.nameController.text.trim().isNotEmpty)
              BudgetItem(
                id: draft.id,
                name: draft.pinned
                    ? kDailyExpensesName
                    : draft.nameController.text.trim(),
                amountPaise: Money.parseToPaise(draft.controller.text),
                pinned: draft.pinned,
              ),
        ],
      );

  Future<void> _save() async {
    final choice = await showModalBottomSheet<ApplyFrom>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000), // rgba(0,0,0,.4)
      builder: (context) => _ApplySheet(month: widget.month),
    );

    if (choice == null || !mounted) return;
    widget.onSave(_collect(), choice);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final pinned = _items.where((i) => i.pinned).toList();
    final others = _items.where((i) => !i.pinned).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        Text('Budget', style: AppText.screenTitle),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Active for ${Dates.monthYear(widget.month)}',
          style: AppText.bodySm.copyWith(color: s.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text('Monthly salary', style: AppText.bodySmStrong),
        const SizedBox(height: AppSpacing.sm),
        MoneyField(
          controller: _salary,
          height: 52,
          semanticLabel: 'Monthly salary',
          textStyle: AppText.bodyLg.copyWith(fontWeight: FontWeight.w700),
          symbolStyle: AppText.bodyLg.copyWith(
            fontWeight: FontWeight.w700,
            color: s.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Text('Budget items', style: AppText.bodySmStrong),
        const SizedBox(height: AppSpacing.xxs),
        for (final item in [...pinned, ...others])
          _ItemRow(
            draft: item,
            note: item.pinned
                ? 'Always included · '
                    '${Money.rupeesPaiseTrim(_dailyLimitPaise)} a day'
                : 'Monthly',
            onRemove: item.pinned ? null : () => _removeItem(item),
          ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: PillButton(
            label: 'Add item',
            variant: PillVariant.subtle,
            height: AppSizes.touch,
            icon: AppIcons.plus,
            textStyle: AppText.bodySmStrong,
            onPressed: _addItem,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        AppCard(
          semanticLabel: 'Summary',
          child: Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'Budgeted',
                  value: Money.rupees(_budgetedPaise),
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'Salary',
                  value: Money.rupees(_salaryPaise),
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'Planned savings',
                  value: Money.withSign(_plannedSavingsPaise),
                  valueColor:
                      _plannedSavingsPaise < 0 ? s.error : s.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'Save budget',
          onPressed: _salaryPaise > 0 ? _save : null,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.draft,
    required this.note,
    required this.onRemove,
  });

  final _ItemDraft draft;
  final String note;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.softer)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The lock sits inline with the name rather than beside the
                // whole row: as a sibling it ends up level with the note
                // instead of the label it belongs to.
                if (draft.pinned)
                  Row(
                    children: [
                      AppIcon(AppIcons.lock, size: 16, color: s.ink),
                      const SizedBox(width: AppSpacing.sm),
                      Text(kDailyExpensesName, style: AppText.row),
                    ],
                  )
                else
                  TextField(
                    controller: draft.nameController,
                    style: AppText.row.copyWith(color: s.ink),
                    cursorColor: s.ink,
                    decoration: InputDecoration(
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Item name',
                      hintStyle:
                          AppText.row.copyWith(color: s.placeholder),
                    ),
                  ),
                Text(
                  note,
                  // Two lines, not an ellipsis: at 390px the pinned row's
                  // note does not fit beside a 116px field and the 44px
                  // spacer, and the daily figure is the point of it.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 116,
            child: MoneyField.compact(
              controller: draft.controller,
              semanticLabel: '${draft.nameController.text} amount',
            ),
          ),
          // The pinned row keeps the spacer so every amount field lines up.
          if (onRemove == null)
            const SizedBox(width: AppSizes.touch)
          else
            CircleIconButton(
              icon: AppIcons.close,
              iconSize: 18,
              background: Colors.transparent,
              foreground: s.textSecondary,
              semanticLabel: 'Remove item',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: s.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.row.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? s.ink,
          ),
        ),
      ],
    );
  }
}

/// "Apply from this month or next month?"
class _ApplySheet extends StatelessWidget {
  const _ApplySheet({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Container(
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xxl,
            AppSpacing.screen,
            AppSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Apply from this month or next month?',
                style: AppText.displaySm,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Past months keep the budget they had, so their colours and '
                'stats never change.',
                style: AppText.bodySm.copyWith(
                  color: s.textSecondary,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PillButton(
                label: 'This month · ${Dates.monthName(month)}',
                height: 52,
                onPressed: () =>
                    Navigator.of(context).pop(ApplyFrom.thisMonth),
              ),
              const SizedBox(height: AppSpacing.md),
              PillButton(
                label: 'Next month · '
                    '${Dates.monthName(Dates.nextMonth(month))}',
                variant: PillVariant.subtle,
                height: 52,
                expand: true,
                onPressed: () =>
                    Navigator.of(context).pop(ApplyFrom.nextMonth),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: AppText.row.copyWith(
                    color: s.ink,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mutable editing state for one budget row.
class _ItemDraft {
  _ItemDraft({
    required this.id,
    required String name,
    required this.pinned,
    required this.controller,
  }) : nameController = TextEditingController(text: name);

  final String id;
  final bool pinned;
  final TextEditingController controller;
  final TextEditingController nameController;

  void dispose() {
    controller.dispose();
    nameController.dispose();
  }
}
