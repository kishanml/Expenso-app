import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/segmented_toggle.dart';

/// Settings — `Settings.dc.html`.
///
/// Export and import, the app lock, and the light/dark choice.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.appLock,
    required this.appLockAvailable,
    required this.smsEnabled,
    required this.smsSupported,
    required this.pendingCount,
    required this.onToggleSms,
    required this.onReview,
    required this.busy,
    required this.onExport,
    required this.onImport,
    required this.onToggleAppLock,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final bool appLock;

  /// False where the device has no biometrics or PIN — desktop, or a phone
  /// with no screen lock set.
  final bool appLockAvailable;

  /// Reading bank messages is on.
  final bool smsEnabled;

  /// False on iOS and desktop, where apps cannot read messages at all.
  final bool smsSupported;

  /// How many read transactions are waiting to be confirmed.
  final int pendingCount;

  final ValueChanged<bool> onToggleSms;
  final VoidCallback onReview;

  /// An export or import is in flight; the rows are inert until it finishes.
  final bool busy;

  final VoidCallback onExport;
  final VoidCallback onImport;
  final ValueChanged<bool> onToggleAppLock;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    const padding = EdgeInsets.fromLTRB(
      AppSpacing.screen,
      AppSpacing.md,
      AppSpacing.screen,
      AppSpacing.xl,
    );

    // The version footer is pinned to the bottom of the screen, as drawn, but
    // still scrolls away when the content is taller. ConstrainedBox plus
    // IntrinsicHeight is what gives the Spacer a bounded height inside a
    // scroll view.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - padding.vertical,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Settings', style: AppText.screenTitle),
                const SizedBox(height: AppSpacing.xxl),

                _SectionLabel('Backup'),
                const SizedBox(height: AppSpacing.sm),
                _Group(
                  children: [
                    _ActionRow(
                      icon: AppIcons.export,
                      title: 'Export data',
                      subtitle: 'Save all entries and budgets to a file',
                      onTap: busy ? null : onExport,
                      divider: true,
                    ),
                    _ActionRow(
                      icon: AppIcons.import,
                      title: 'Import data',
                      subtitle: 'Restore from a backup file',
                      onTap: busy ? null : onImport,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "There's no cloud — a file export is your only backup.",
                  style: AppText.caption.copyWith(
                    color: s.textSecondary,
                    height: 18 / 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (smsSupported) ...[
                  _SectionLabel('Automatic entries'),
                  const SizedBox(height: AppSpacing.sm),
                  _Group(
                    children: [
                      _SwitchRow(
                        icon: AppIcons.chat,
                        title: 'Read bank messages',
                        subtitle: smsEnabled
                            ? 'Expenso suggests entries you confirm'
                            : 'Off \u2014 nothing is read',
                        value: smsEnabled,
                        onChanged: onToggleSms,
                      ),
                      if (smsEnabled)
                        _ActionRow(
                          icon: AppIcons.check,
                          title: 'Review suggestions',
                          subtitle: pendingCount == 0
                              ? 'Nothing waiting'
                              : '$pendingCount waiting to be confirmed',
                          onTap: onReview,
                          topDivider: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Messages are read on this phone and never sent anywhere. '
                    'Nothing is added to your entries until you confirm it.',
                    style: AppText.caption.copyWith(
                      color: s.textSecondary,
                      height: 18 / 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                _SectionLabel('Security'),
                const SizedBox(height: AppSpacing.sm),
                _Group(
                  children: [
                    _LockRow(
                      enabled: appLock,
                      available: appLockAvailable,
                      onChanged: onToggleAppLock,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                _SectionLabel('Appearance'),
                const SizedBox(height: AppSpacing.sm),
                SegmentedToggle<ThemeMode>(
                  semanticLabel: 'Theme',
                  value: themeMode == ThemeMode.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  onChanged: onThemeChanged,
                  segments: const [
                    (value: ThemeMode.light, label: 'Light'),
                    (value: ThemeMode.dark, label: 'Dark'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxxl),
                const Spacer(),

                Column(
                  children: [
                    Text(
                      'Expenso',
                      style: AppText.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Version 1.0 · Works offline · '
                      'Data stays on this phone',
                      style: AppText.caption.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Text(
      text.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: s.textSecondary),
    );
  }
}

/// A rounded group of rows on the soft fill.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    return Container(
      decoration: BoxDecoration(color: s.soft, borderRadius: AppRadius.card),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.divider = false,
    this.topDivider = false,
  });

  final IconSpec icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool divider;
  final bool topDivider;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final disabled = onTap == null;
    final tint = disabled ? s.placeholder : s.ink;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: (divider || topDivider)
              ? BoxDecoration(
                  border: Border(
                    top: topDivider
                        ? BorderSide(color: s.border)
                        : BorderSide.none,
                    bottom: divider
                        ? BorderSide(color: s.border)
                        : BorderSide.none,
                  ),
                )
              : null,
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: tint),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: AppText.row.copyWith(color: tint)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.meta.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with a title, a subtitle and the pill switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconSpec icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final tint = s.ink;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          AppIcon(icon, size: 20, color: tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppText.row.copyWith(color: tint)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.meta.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          _Switch(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ],
      ),
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.enabled,
    required this.available,
    required this.onChanged,
  });

  final bool enabled;
  final bool available;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          AppIcon(
            AppIcons.lock,
            size: 20,
            color: available ? s.ink : s.placeholder,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'App lock',
                  style: AppText.row.copyWith(
                    color: available ? s.ink : s.placeholder,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Saying why it is off beats an unexplained dead switch.
                  available
                      ? 'Fingerprint or PIN'
                      : 'No screen lock on this device',
                  style: AppText.meta.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          _Switch(
            value: enabled && available,
            onChanged: available ? onChanged : null,
            semanticLabel: 'App lock',
          ),
        ],
      ),
    );
  }
}

/// The 52×32 pill switch from the mockup: ink track when on, #AFAFAF when
/// off, 26px white knob with a soft shadow.
class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final disabled = onChanged == null;

    return Semantics(
      toggled: value,
      enabled: !disabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 52,
          height: 32,
          decoration: BoxDecoration(
            color: disabled
                ? s.border
                : value
                ? s.ink
                : AppColors.placeholder,
            borderRadius: AppRadius.pill,
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
