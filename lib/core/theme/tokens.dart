import 'package:flutter/material.dart';

/// Design tokens transcribed from `expenso-design/DESIGN.md` and the approved
/// mockups in `expenso-design/screens/`. These are the only place raw values
/// live — nothing else in the app should hard-code a colour or a radius.
abstract final class AppColors {
  // Ink
  static const primary = Color(0xFF000000);
  static const textSecondary = Color(0xFF545454);
  static const muted = Color(0xFF757575);
  static const placeholder = Color(0xFFAFAFAF);

  // Surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF6F6F6);
  static const surfaceSofter = Color(0xFFEEEEEE);
  static const border = Color(0xFFE2E2E2);

  // Semantics. Green/red mean only within/over limit, or saved/overspent,
  // and are always paired with + / − or ✓ / !.
  static const success = Color(0xFF276B45);
  static const successTint = Color(0xFFE3EFE7);
  static const error = Color(0xFFC62828);
  static const errorTint = Color(0xFFFBE6E6);

  static const onDark = Color(0xFFFFFFFF);

  // Dark theme surfaces. Not drawn in the mockups; DESIGN.md specifies
  // inverting the surface ramp while keeping the semantics unchanged.
  static const darkSurface = Color(0xFF000000);
  static const darkSurfaceSoft = Color(0xFF1A1A1A);
  static const darkSurfaceSofter = Color(0xFF282828);
  static const darkBorder = Color(0xFF3A3A3A);

  /// The black → charcoal gradient used by the splash, the Today card and the
  /// "Saved this month" card. 135° in CSS runs top-left → bottom-right.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF282828)],
  );
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Screen side padding.
  static const double screen = 20;
}

abstract final class AppRadius {
  /// Buttons, chips, toggles.
  static const pill = BorderRadius.all(Radius.circular(999));

  /// Cards.
  static const card = BorderRadius.all(Radius.circular(16));

  /// Calendar cells.
  static const cell = BorderRadius.all(Radius.circular(12));

  /// Segmented-toggle track.
  static const track = BorderRadius.all(Radius.circular(36));

  /// Inputs are square.
  static const none = BorderRadius.zero;
}

abstract final class AppShadow {
  /// Cards are flat. Only the FAB and toasts are elevated.
  static const elevated = [
    BoxShadow(
      color: Color(0x29000000), // rgba(0,0,0,.16)
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];
}

abstract final class AppSizes {
  /// Primary action height.
  static const double button = 56;

  /// Minimum touch target.
  static const double touch = 44;

  static const double bottomNav = 80;
  static const double bottomNavPad = 14;
  static const double fab = 64;

  /// Phone frame the mockups were drawn at.
  static const Size referenceFrame = Size(390, 844);
}
