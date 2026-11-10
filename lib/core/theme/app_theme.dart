import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Surface colours for the current theme, reached through
/// `AppSurfaces.of(context)`.
///
/// The mockups are drawn light only. Dark mode inverts the surface ramp to
/// #000000 / #1A1A1A / #282828 as DESIGN.md directs, and keeps the success and
/// error semantics untouched so green and red keep meaning the same thing.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.surface,
    required this.soft,
    required this.softer,
    required this.border,
    required this.ink,
    required this.textSecondary,
    required this.muted,
    required this.placeholder,
    required this.heroGradient,
    required this.success,
    required this.successTint,
    required this.error,
    required this.errorTint,
  });

  final Color surface;
  final Color soft;
  final Color softer;
  final Color border;
  final Color ink;
  final Color textSecondary;
  final Color muted;
  final Color placeholder;

  /// The gradient behind the Today card and the Stats hero.
  final LinearGradient heroGradient;

  // Green and red keep their meaning across themes, but not their exact hex:
  // #276B45 on #000000 is too dark to read, so dark mode lightens both.
  final Color success;
  final Color successTint;
  final Color error;
  final Color errorTint;

  static const light = AppSurfaces(
    surface: AppColors.surface,
    soft: AppColors.surfaceSoft,
    softer: AppColors.surfaceSofter,
    border: AppColors.border,
    ink: AppColors.primary,
    textSecondary: AppColors.textSecondary,
    muted: AppColors.muted,
    placeholder: AppColors.placeholder,
    heroGradient: AppColors.heroGradient,
    success: AppColors.success,
    successTint: AppColors.successTint,
    error: AppColors.error,
    errorTint: AppColors.errorTint,
  );

  static const dark = AppSurfaces(
    surface: AppColors.darkSurface,
    soft: AppColors.darkSurfaceSoft,
    softer: AppColors.darkSurfaceSofter,
    border: AppColors.darkBorder,
    ink: AppColors.onDark,
    textSecondary: Color(0xFFAFAFAF),
    muted: Color(0xFF8A8A8A),
    placeholder: Color(0xFF6E6E6E),
    // Lifted off pure black so the hero still reads as a raised card.
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F1F1F), Color(0xFF333333)],
    ),
    success: Color(0xFF5FBF8B),
    successTint: Color(0xFF15301F),
    error: Color(0xFFF07171),
    errorTint: Color(0xFF3A1C1C),
  );

  static AppSurfaces of(BuildContext context) =>
      Theme.of(context).extension<AppSurfaces>() ?? light;

  @override
  AppSurfaces copyWith({
    Color? surface,
    Color? soft,
    Color? softer,
    Color? border,
    Color? ink,
    Color? textSecondary,
    Color? muted,
    Color? placeholder,
    LinearGradient? heroGradient,
    Color? success,
    Color? successTint,
    Color? error,
    Color? errorTint,
  }) =>
      AppSurfaces(
        surface: surface ?? this.surface,
        soft: soft ?? this.soft,
        softer: softer ?? this.softer,
        border: border ?? this.border,
        ink: ink ?? this.ink,
        textSecondary: textSecondary ?? this.textSecondary,
        muted: muted ?? this.muted,
        placeholder: placeholder ?? this.placeholder,
        heroGradient: heroGradient ?? this.heroGradient,
        success: success ?? this.success,
        successTint: successTint ?? this.successTint,
        error: error ?? this.error,
        errorTint: errorTint ?? this.errorTint,
      );

  @override
  AppSurfaces lerp(AppSurfaces? other, double t) {
    if (other == null) return this;
    return AppSurfaces(
      surface: Color.lerp(surface, other.surface, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      softer: Color.lerp(softer, other.softer, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      heroGradient:
          LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      success: Color.lerp(success, other.success, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorTint: Color.lerp(errorTint, other.errorTint, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => _build(AppSurfaces.light, Brightness.light);
  static ThemeData get dark => _build(AppSurfaces.dark, Brightness.dark);

  static ThemeData _build(AppSurfaces s, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: s.surface,
      canvasColor: s.surface,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: s.ink,
        onPrimary: isDark ? AppColors.primary : AppColors.onDark,
        secondary: s.ink,
        onSecondary: isDark ? AppColors.primary : AppColors.onDark,
        error: s.error,
        onError: AppColors.onDark,
        surface: s.surface,
        onSurface: s.ink,
      ),
      extensions: [s],
      textTheme: TextTheme(
        displayLarge: AppText.displayXxl,
        displayMedium: AppText.displayXl,
        displaySmall: AppText.displayLg,
        headlineMedium: AppText.displayMd,
        headlineSmall: AppText.displaySm,
        titleLarge: AppText.displaySm,
        bodyLarge: AppText.bodyMd,
        bodyMedium: AppText.bodySm,
        bodySmall: AppText.caption,
        labelLarge: AppText.buttonMd,
      ).apply(bodyColor: s.ink, displayColor: s.ink),

      // Inputs are square, flat and borderless — the surface tint is the only
      // affordance, with a 2px inset ring on focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.soft,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.none,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.none,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.none,
          borderSide: BorderSide(color: s.ink, width: 2),
        ),
        hintStyle: AppText.bodySm.copyWith(color: s.placeholder),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: s.ink,
        selectionColor: s.border,
        selectionHandleColor: s.ink,
      ),
      dividerTheme: DividerThemeData(
        color: s.softer,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
