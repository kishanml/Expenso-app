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

/// First-time setup — `Welcome.dc.html`.
///
/// Salary, the locked "Daily expenses" item, then any number of other items.
/// The totals strip and the daily-limit note recompute as you type, so the
/// consequence of a number is visible before it is saved.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onSaved,
    required this.today,
  });

  final ValueChanged<MonthBudget> onSaved;
  final DateTime today;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TextEditingController _salary;
  late final List<_ItemDraft> _items;
  var _nextId = 0;

  @override
  void initState() {
    super.initState();

    // The screen opens on the values drawn in the mockup, so first-run has
    // something sensible to edit rather than empty fields.
    final seed = MonthBudget.seed(Dates.monthKey(widget.today));
    _salary = TextEditingController(
      text: Money.groupDigits((seed.salaryPaise ~/ 100).toString()),
    )..addListener(_recompute);

    _items = [
      for (final item in seed.items)
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

  @override
  void dispose() {
    _salary.dispose();
    for (final item in _items) {
      item.dispose();
    }
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
    final daily = _items.firstWhere((i) => i.pinned);
    final amount = Money.parseToPaise(daily.controller.text);
    return (amount / Dates.daysInMonth(widget.today)).round();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft(
        id: 'item-${_nextId++}',
        name: '',
        pinned: false,
        controller: TextEditingController()..addListener(_recompute),
      ));
    });
  }

  void _removeItem(_ItemDraft draft) {
    setState(() {
      _items.remove(draft);
    });
    draft.dispose();
  }

  void _save() {
    final items = <BudgetItem>[];
    for (final draft in _items) {
      final name = draft.pinned
          ? kDailyExpensesName
          : draft.nameController.text.trim();
      // A blank unnamed row is a row the user started and abandoned.
      if (name.isEmpty) continue;
      items.add(BudgetItem(
        id: draft.id,
        name: name,
        amountPaise: Money.parseToPaise(draft.controller.text),
        pinned: draft.pinned,
      ));
    }

    widget.onSaved(MonthBudget(
      monthKey: Dates.monthKey(widget.today),
      salaryPaise: _salaryPaise,
      items: items,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Scaffold(
      backgroundColor: s.surface,
      body: SafeArea(
        child: Padding(
          // 56px 24px 32px in the mockup; SafeArea already covers the status
          // bar, so the top inset here is the mockup's gap below it.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.xxxl,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(s),
                      const SizedBox(height: AppSpacing.xxl),
                      _salaryField(s),
                      const SizedBox(height: AppSpacing.xxl),
                      _budgetItems(s),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _totals(s),
              const SizedBox(height: AppSpacing.lg),
              PillButton(
                label: 'Save and continue',
                onPressed: _salaryPaise > 0 ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppSurfaces s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WELCOME TO EXPENSO',
            style: AppText.eyebrow.copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Set up your monthly budget', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Takes a minute. You can change it any time.',
            style: AppText.rowRegular.copyWith(color: s.textSecondary),
          ),
        ],
      );

  Widget _salaryField(AppSurfaces s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monthly salary (take-home)', style: AppText.bodySmStrong),
          const SizedBox(height: AppSpacing.sm),
          MoneyField(
            controller: _salary,
            semanticLabel: 'Monthly salary, take-home',
          ),
        ],
      );

  Widget _budgetItems(AppSurfaces s) {
    final pinned = _items.firstWhere((i) => i.pinned);
    final others = _items.where((i) => !i.pinned).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Budget items', style: AppText.bodySmStrong),
        const SizedBox(height: AppSpacing.md),

        // The pinned item sits in its own card, with the per-day consequence
        // of its amount spelled out underneath.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(AppIcons.lock, size: 16, color: s.ink),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(kDailyExpensesName, style: AppText.row),
                  ),
                  SizedBox(
                    width: 120,
                    child: MoneyField.compact(
                      controller: pinned.controller,
                      fill: s.surface,
                      semanticLabel: 'Daily expenses amount',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Always included · '
                '${Money.rupeesPaise(_dailyLimitPaise)} a day in '
                '${Dates.monthName(widget.today)}',
                style: AppText.meta.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        for (final item in others) ...[
          _OtherItemRow(
            draft: item,
            onRemove: () => _removeItem(item),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

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
      ],
    );
  }

  Widget _totals(AppSurfaces s) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text.rich(
            TextSpan(
              style: AppText.bodySm.copyWith(color: s.textSecondary),
              children: [
                const TextSpan(text: 'Total budgeted '),
                TextSpan(
                  text: Money.rupees(_budgetedPaise),
                  style: AppText.bodySm
                      .copyWith(color: s.ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              style: AppText.bodySm.copyWith(color: s.textSecondary),
              children: [
                const TextSpan(text: 'Planned savings '),
                TextSpan(
                  text: Money.withSign(_plannedSavingsPaise),
                  style: AppText.bodySm.copyWith(
                    // Red when the budget has been overcommitted, since a
                    // negative "savings" is the one number here that is a
                    // problem rather than information.
                    color: _plannedSavingsPaise < 0
                        ? s.error
                        : s.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

/// A removable, renameable budget row — "Rent", "EMI".
class _OtherItemRow extends StatelessWidget {
  const _OtherItemRow({required this.draft, required this.onRemove});

  final _ItemDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: draft.nameController,
              style: AppText.rowRegular.copyWith(color: s.ink),
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
                    AppText.rowRegular.copyWith(color: s.placeholder),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 120,
            child: MoneyField.compact(
              controller: draft.controller,
              semanticLabel: 'Amount',
            ),
          ),
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
