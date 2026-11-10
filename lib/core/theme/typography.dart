import 'package:flutter/widgets.dart';

/// Inter at 400 body / 500 buttons and labels / 700 numbers and titles.
/// Letter-spacing is 0 everywhere — Flutter's Material defaults apply tracking
/// to several styles, so every style here sets it explicitly.
abstract final class AppText {
  static const _family = 'Inter';

  static TextStyle _s(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: 0,
      );

  // Display / titles
  static final displayXxl = _s(52, 64, FontWeight.w700);
  static final displayXl = _s(36, 44, FontWeight.w700);
  static final displayLg = _s(32, 40, FontWeight.w700);
  static final displayMd = _s(24, 32, FontWeight.w700);
  static final displaySm = _s(20, 28, FontWeight.w700);

  // Body
  static final bodyLg = _s(18, 24, FontWeight.w500);
  static final bodyMd = _s(16, 24, FontWeight.w400);
  static final bodyMdStrong = _s(16, 20, FontWeight.w500);
  static final bodySm = _s(14, 20, FontWeight.w400);
  static final bodySmStrong = _s(14, 16, FontWeight.w500);
  static final caption = _s(12, 20, FontWeight.w400);

  // Buttons
  static final buttonLarge = _s(18, 24, FontWeight.w500);
  static final buttonMd = _s(16, 20, FontWeight.w500);

  // ── Sizes the mockups use that sit between the system's named steps.
  // Transcribed from the screen HTML rather than rounded to the nearest token.

  /// Home header "Expenso", 24/30.
  static final screenTitle = _s(24, 30, FontWeight.w700);

  /// Today card figure, 44/50.
  static final heroFigure = _s(44, 50, FontWeight.w700);

  /// AddEntry amount, 48/56.
  static final amountFigure = _s(48, 56, FontWeight.w700);

  /// Stats hero figure, 40/46.
  static final statFigure = _s(40, 46, FontWeight.w700);

  /// List row titles and inline labels, 15px.
  static final row = _s(15, 20, FontWeight.w500);
  static final rowRegular = _s(15, 22, FontWeight.w400);

  /// Secondary row text and metadata, 13px.
  static final meta = _s(13, 18, FontWeight.w400);
  static final metaStrong = _s(13, 18, FontWeight.w500);

  /// Section eyebrow — uppercase, 13/500.
  static final eyebrow = _s(13, 18, FontWeight.w500);

  /// Bottom-nav labels, 11px.
  static final navLabel = _s(11, 14, FontWeight.w500);
  static final navLabelActive = _s(11, 14, FontWeight.w700);

  /// AddEntry sheet title, 17px.
  static final sheetTitle = _s(17, 22, FontWeight.w700);
}
