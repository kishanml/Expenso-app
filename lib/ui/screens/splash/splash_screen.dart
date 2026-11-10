import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/pill_button.dart';

/// Splash — `Main.dc.html`.
///
/// "Expenso" centred on the black→#282828 gradient under a ₹ in a ringed
/// circle, with a white pill and the offline reassurance pinned to the bottom.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons, since the splash is always dark.
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              // 0 24px 48px in the mockup.
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
                        // 64px ring with a 2px white border.
                        Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                          ),
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
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Expenso',
                          style: AppText.displayXxl.copyWith(
                            color: AppColors.onDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          "Know every day if you're on track.",
                          textAlign: TextAlign.center,
                          style: AppText.bodyMd.copyWith(
                            color: AppColors.placeholder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PillButton(
                    label: 'Get started',
                    variant: PillVariant.light,
                    onPressed: onGetStarted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Works offline. Your data stays on this phone.',
                    textAlign: TextAlign.center,
                    style: AppText.meta.copyWith(
                      color: AppColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
