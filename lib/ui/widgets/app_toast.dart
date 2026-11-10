import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icons.dart';

/// The black pill toast — one of only two elevated things in the app, the FAB
/// being the other.
///
/// Shown through [showAppToast] rather than a Material SnackBar so the shape,
/// inset and shadow match `Budget.dc.html` exactly.
void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final s = AppSurfaces.of(context);

  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      padding: EdgeInsets.zero,
      // The mockup sits the toast 100px from the frame bottom, which clears
      // the 80px nav bar by 20.
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      content: _Toast(message: message, isError: isError, surfaces: s),
    ));
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.message,
    required this.isError,
    required this.surfaces,
  });

  final String message;
  final bool isError;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final background = isError ? surfaces.error : surfaces.ink;
    final foreground = surfaces.surface;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pill,
          boxShadow: AppShadow.elevated,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              isError ? AppIcons.close : AppIcons.check,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: AppText.bodySmStrong.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
