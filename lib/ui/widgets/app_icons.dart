import 'package:flutter/widgets.dart';

/// The mockups' icons, kept as the exact SVG `d` strings from
/// `expenso-design/screens/` and drawn through a small path parser.
///
/// Transcribing the geometry by hand would invite drift; this way the source of
/// truth stays byte-identical to the approved artwork. All icons share the
/// 24×24 viewBox, 2px stroke, round caps and joins, no fill.
@immutable
class IconSpec {
  const IconSpec({
    this.paths = const [],
    this.rects = const [],
    this.circles = const [],
    this.strokeWidth = 2,
  });

  final List<String> paths;

  /// `<rect x y width height rx>` elements.
  final List<({double x, double y, double w, double h, double r})> rects;

  /// `<circle cx cy r>` elements.
  final List<({double cx, double cy, double r})> circles;

  final double strokeWidth;
}

abstract final class AppIcons {
  static const home = IconSpec(paths: [
    'M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z',
  ]);

  static const calendar = IconSpec(
    paths: ['M16 3v4M8 3v4M3 10h18'],
    rects: [(x: 3, y: 5, w: 18, h: 16, r: 2)],
  );

  static const stats = IconSpec(paths: [
    'M21 12A9 9 0 1 1 12 3v9z',
    'M15 3.5A9 9 0 0 1 20.5 9H15z',
  ]);

  static const budget = IconSpec(paths: [
    'M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-4',
    'M3 5a2 2 0 0 0 2 2h15a1 1 0 0 1 1 1v4h-4a2 2 0 0 0 0 4h4',
  ]);

  static const settings = IconSpec(
    paths: ['M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12'],
    circles: [
      (cx: 16, cy: 6, r: 2),
      (cx: 10, cy: 12, r: 2),
      (cx: 18, cy: 18, r: 2),
    ],
  );

  static const lock = IconSpec(
    paths: ['M8 11V7a4 4 0 0 1 8 0v4'],
    rects: [(x: 4, y: 11, w: 16, h: 10, r: 2)],
  );

  static const plus = IconSpec(paths: ['M12 5v14M5 12h14'], strokeWidth: 2);
  static const plusBold =
      IconSpec(paths: ['M12 5v14M5 12h14'], strokeWidth: 2.2);
  static const close = IconSpec(paths: ['M6 6l12 12M18 6 6 18']);
  static const chevronLeft = IconSpec(paths: ['M15 6l-6 6 6 6']);
  static const chevronRight = IconSpec(paths: ['M9 6l6 6-6 6']);
  static const chevronDown = IconSpec(paths: ['M6 9l6 6 6-6']);
  static const check = IconSpec(paths: ['M5 12l5 5 9-10'], strokeWidth: 2.2);
  static const export =
      IconSpec(paths: ['M12 3v12M7 10l5 5 5-5M5 21h14']);
  static const import =
      IconSpec(paths: ['M12 15V3M7 8l5-5 5 5M5 21h14']);
  /// Not in the mockups — Add entry needs it in edit mode. Drawn in the same
  /// lucide-style language as the rest: 24 viewBox, 2px stroke, round caps.
  static const trash = IconSpec(paths: [
    'M4 7h16',
    'M10 11v6M14 11v6',
    'M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13',
    'M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3',
  ]);

  static const backspace = IconSpec(paths: [
    'M9 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9l-6-7z',
    'M17 9l-5 5M12 9l5 5',
  ]);
}

/// Draws an [IconSpec] at [size], scaling the 24×24 viewBox and its stroke
/// width together so the icon keeps its drawn weight at any size.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.spec, {
    super.key,
    this.size = 24,
    required this.color,
  });

  final IconSpec spec;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _IconPainter(spec, color)),
      );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.spec, this.color);

  final IconSpec spec;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = spec.strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final matrix = Matrix4.diagonal3Values(scale, scale, 1).storage;

    for (final rect in spec.rects) {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.x, rect.y, rect.w, rect.h),
          Radius.circular(rect.r),
        ));
      canvas.drawPath(path.transform(matrix), paint);
    }

    for (final circle in spec.circles) {
      final path = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(circle.cx, circle.cy),
          radius: circle.r,
        ));
      canvas.drawPath(path.transform(matrix), paint);
    }

    for (final d in spec.paths) {
      canvas.drawPath(SvgPath.parse(d).transform(matrix), paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.spec != spec;
}

/// Parses the subset of SVG path syntax the mockups' icons use:
/// `M m L l H h V v A a Z z`, with implicit command repetition and
/// comma-or-space separated, optionally signed decimal numbers.
abstract final class SvgPath {
  static final _token = RegExp(r'[MmLlHhVvAaZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?');

  static Path parse(String d) {
    final path = Path();
    final tokens =
        _token.allMatches(d).map((m) => m.group(0)!).toList(growable: false);

    var i = 0;
    var cursor = Offset.zero;
    var subpathStart = Offset.zero;
    String? command;

    double next() => double.parse(tokens[i++]);
    bool hasNumber() =>
        i < tokens.length && !RegExp(r'^[A-Za-z]$').hasMatch(tokens[i]);

    while (i < tokens.length) {
      if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[i])) {
        command = tokens[i++];
      } else if (command == null) {
        break; // Malformed: numbers before any command.
      } else if (command == 'M') {
        // A repeated moveto parameter pair is an implicit lineto.
        command = 'L';
      } else if (command == 'm') {
        command = 'l';
      }

      switch (command) {
        case 'M':
          final x = next(), y = next();
          cursor = Offset(x, y);
          subpathStart = cursor;
          path.moveTo(x, y);

        case 'm':
          cursor += Offset(next(), next());
          subpathStart = cursor;
          path.moveTo(cursor.dx, cursor.dy);

        case 'L':
          final x = next(), y = next();
          cursor = Offset(x, y);
          path.lineTo(x, y);

        case 'l':
          cursor += Offset(next(), next());
          path.lineTo(cursor.dx, cursor.dy);

        case 'H':
          cursor = Offset(next(), cursor.dy);
          path.lineTo(cursor.dx, cursor.dy);

        case 'h':
          cursor += Offset(next(), 0);
          path.lineTo(cursor.dx, cursor.dy);

        case 'V':
          cursor = Offset(cursor.dx, next());
          path.lineTo(cursor.dx, cursor.dy);

        case 'v':
          cursor += Offset(0, next());
          path.lineTo(cursor.dx, cursor.dy);

        case 'A':
        case 'a':
          final rx = next(), ry = next();
          final rotation = next();
          final largeArc = next() != 0;
          final sweep = next() != 0;
          final ex = next(), ey = next();
          final end = command == 'A'
              ? Offset(ex, ey)
              : cursor + Offset(ex, ey);
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            // SVG's sweep flag is positive-angle, which is clockwise in a
            // y-down coordinate system — the same convention Flutter uses.
            clockwise: sweep,
          );
          cursor = end;

        case 'Z':
        case 'z':
          path.close();
          cursor = subpathStart;

        default:
          // Unsupported command: skip its numbers rather than loop forever.
          while (hasNumber()) {
            i++;
          }
      }
    }
    return path;
  }
}
