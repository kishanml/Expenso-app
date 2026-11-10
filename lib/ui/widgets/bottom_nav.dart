import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icons.dart';

/// The five destinations, in the order the mockups lay them out.
enum NavTab {
  home('Home', AppIcons.home),
  calendar('Calendar', AppIcons.calendar),
  stats('Stats', AppIcons.stats),
  budget('Budget', AppIcons.budget),
  settings('Settings', AppIcons.settings);

  const NavTab(this.label, this.icon);

  final String label;
  final IconSpec icon;
}

/// 80px tall with 14px of bottom padding and a 1px top border. The active item
/// is black at weight 700; the rest are #757575 at 500.
///
/// The mockups' 14px bottom padding is the home-indicator allowance, so on a
/// device that reports a larger bottom inset the bar grows to match rather
/// than letting the labels sit under the indicator.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final NavTab current;
  final ValueChanged<NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPad = inset > AppSizes.bottomNavPad
        ? inset
        : AppSizes.bottomNavPad;

    return Semantics(
      container: true,
      label: 'Main',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: s.surface,
          border: Border(top: BorderSide(color: s.border)),
        ),
        child: SizedBox(
          height: AppSizes.bottomNav -
              AppSizes.bottomNavPad +
              bottomPad,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final tab in NavTab.values)
                  _NavItem(
                    tab: tab,
                    selected: tab == current,
                    onTap: () => onSelect(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppSurfaces.of(context);
    final color = selected ? s.ink : AppColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 60),
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(tab.icon, size: 24, color: color),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                tab.label,
                style: (selected ? AppText.navLabelActive : AppText.navLabel)
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
