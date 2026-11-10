import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/pill_button.dart';

/// Shown over everything while the app lock is engaged.
///
/// Not drawn in the mockups — `Settings.dc.html` has the switch but no locked
/// state. Built from the splash, which is the one screen in the system that
/// already stands alone on the dark gradient.
class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.onUnlock,
    required this.failed,
  });

  final VoidCallback onUnlock;

  /// True once an attempt has been made and refused, so the copy can change
  /// from the automatic first prompt to an explicit retry.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              48,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.onDark,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            Money.rupee,
                            style: AppText.displayMd.copyWith(
                              fontSize: 30,
                              height: 1,
                              color: AppColors.onDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Expenso is locked',
                        style: AppText.displayLg.copyWith(
                          color: AppColors.onDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        failed
                            ? 'That did not match. Try again.'
                            : 'Unlock with your fingerprint or PIN.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMd.copyWith(
                          color: AppColors.placeholder,
                        ),
                      ),
                    ],
                  ),
                ),
                PillButton(
                  label: 'Unlock',
                  variant: PillVariant.light,
                  onPressed: onUnlock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
