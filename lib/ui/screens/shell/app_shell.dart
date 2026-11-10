import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/month_budget.dart';
import '../../../data/services/app_lock_service.dart';
import '../../../data/services/backup_service.dart';
import '../../../domain/backup.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bottom_nav.dart';
import '../add_entry/add_entry_screen.dart';
import '../budget/budget_screen.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

/// The tabbed shell. Home opens by default after setup.
///
/// Tabs are kept alive in an [IndexedStack] so switching away and back does
/// not lose scroll position or a half-finished edit.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavTab _tab = NavTab.home;

  /// Calendar and Stats each browse a month. They share one selection, so
  /// moving to October in the calendar and switching to Stats shows October
  /// rather than snapping back to today.
  DateTime? _browsingMonth;

  void _select(NavTab tab) => setState(() => _tab = tab);

  void _setMonth(DateTime month) =>
      setState(() => _browsingMonth = Dates.firstOfMonth(month));

  final _backups = const BackupService();
  final _lock = AppLockService();

  bool _appLockAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lock.isAvailable().then((available) {
      if (mounted) setState(() => _appLockAvailable = available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = AppSurfaces.of(context);
    final month = _browsingMonth ?? Dates.firstOfMonth(state.today);

    return Scaffold(
      backgroundColor: s.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: _tab.index,
              children: [
                HomeScreen(
                  summary: state.currentSummary,
                  entries: state.recentEntries(),
                  today: state.today,
                  onOpenCalendar: () => _select(NavTab.calendar),
                  onOpenEntry: _openEntry,
                ),
                CalendarScreen(
                  summary: state.summaryFor(month),
                  month: month,
                  today: state.today,
                  onChangeMonth: _setMonth,
                  entriesForDay: state.entriesForDay,
                  onOpenEntry: _openEntry,
                ),
                StatsScreen(
                  summary: state.summaryFor(month),
                  month: month,
                  today: state.today,
                  onChangeMonth: _setMonth,
                ),
                BudgetScreen(
                  budget: state.budgetFor(month),
                  month: month,
                  today: state.today,
                  onSave: (budget, from) => _saveBudget(state, budget, from),
                ),
                SettingsScreen(
                  themeMode: state.themeMode,
                  appLock: state.appLock,
                  appLockAvailable: _appLockAvailable,
                  busy: _busy,
                  onExport: _export,
                  onImport: _import,
                  onToggleAppLock: _toggleAppLock,
                  onThemeChanged: state.setThemeMode,
                ),
              ],
            ),

            // The FAB belongs to Home only, and sits 16px above the nav bar.
            if (_tab == NavTab.home)
              Positioned(
                right: AppSpacing.screen,
                bottom: AppSpacing.lg,
                child: _AddEntryFab(onPressed: () => _openEntry(null)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(current: _tab, onSelect: _select),
    );
  }

  /// Opens Add entry, or the editor when [existing] is given, and applies
  /// whatever it hands back.
  Future<void> _openEntry(Entry? existing) async {
    final state = context.read<AppState>();

    final result = await Navigator.of(context).push<AddEntryResult>(
      _slideUpRoute(AddEntryScreen(
        categories: state.categories,
        today: state.today,
        existing: existing,
      )),
    );

    switch (result) {
      case SaveEntryResult(:final entry):
        await state.saveEntry(entry);
      case DeleteEntryResult(:final id):
        await state.deleteEntry(id);
      case null:
        break;
    }
  }

  /// Applies a budget edit from the chosen month onward, then confirms it.
  Future<void> _saveBudget(
    AppState state,
    MonthBudget budget,
    ApplyFrom from,
  ) async {
    final month = _browsingMonth ?? Dates.firstOfMonth(state.today);
    final effective =
        from == ApplyFrom.thisMonth ? month : Dates.nextMonth(month);

    await state.saveBudget(budget, from: effective);
    if (!mounted) return;

    showAppToast(
      context,
      'Saved \u00B7 applies from ${Dates.monthName(effective)}',
    );
  }

  Future<void> _export() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);

    try {
      final outcome = await _backups.export(state.buildBackup());
      if (!mounted) return;

      switch (outcome) {
        case ExportSaved(:final path):
          showAppToast(context, 'Exported to ${_fileNameOf(path)}');
        case ExportShared():
          showAppToast(context, 'Backup exported');
        case ExportCancelled():
          break;
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, 'Export failed: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);

    try {
      final backup = await _backups.pickAndRead();
      if (backup == null || !mounted) return;

      // Restoring replaces everything, so it has to be asked about plainly.
      final confirmed = await _confirmRestore(backup);
      if (!confirmed || !mounted) return;

      await state.restore(backup);
      if (!mounted) return;

      showAppToast(
        context,
        'Restored ${backup.entries.length} '
        '${backup.entries.length == 1 ? 'entry' : 'entries'}',
      );
    } on BackupFormatException catch (error) {
      if (mounted) showAppToast(context, error.message, isError: true);
    } catch (error) {
      if (mounted) {
        showAppToast(context, 'Import failed: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore(Backup backup) async {
    final s = AppSurfaces.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: s.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Replace everything?', style: AppText.displaySm),
        content: Text(
          'This backup holds ${backup.entries.length} entries and '
          '${backup.budgets.length} months of budget. Restoring it replaces '
          'what is on this phone now, and that cannot be undone.',
          style: AppText.bodySm.copyWith(color: s.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppText.bodySmStrong.copyWith(color: s.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Replace',
              style: AppText.bodySmStrong.copyWith(color: s.error),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Turning the lock on asks for authentication first — enabling a lock you
  /// cannot pass would shut you out of your own records.
  Future<void> _toggleAppLock(bool value) async {
    final state = context.read<AppState>();

    final passed = await _lock.authenticate(
      reason: value
          ? 'Confirm it is you before turning on the app lock'
          : 'Confirm it is you before turning off the app lock',
    );

    if (!mounted) return;
    if (!passed) {
      showAppToast(context, 'Could not confirm it is you', isError: true);
      return;
    }

    await state.setAppLock(value);
    if (!mounted) return;
    showAppToast(context, value ? 'App lock on' : 'App lock off');
  }

  static String _fileNameOf(String path) =>
      path.split(Platform.pathSeparator).last;

  /// Add entry arrives from the bottom, the way a sheet with a close button
  /// should, rather than sliding in sideways like a pushed page.
  Route<T> _slideUpRoute<T>(Widget child) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => child,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )),
          child: child,
        ),
      );
}

/// The 64px black FAB — the only elevated element on Home.
class _AddEntryFab extends StatelessWidget {
  const _AddEntryFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Semantics(
      button: true,
      label: 'Add entry',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadow.elevated,
        ),
        child: Material(
          color: s.ink,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppSizes.fab,
              height: AppSizes.fab,
              child: Center(
                child: AppIcon(
                  AppIcons.plusBold,
                  size: 28,
                  color: s.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
