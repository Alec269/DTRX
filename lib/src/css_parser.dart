import 'errors.dart';

class Color {
  final int? hexValue; // e.g. 0xFF332E3E
  final int? r, g, b;
  final double? a;

  Color.hex(this.hexValue) : r = null, g = null, b = null, a = null;
  Color.rgba(this.r, this.g, this.b, this.a) : hexValue = null;

  String toFlutterCode() {
    if (hexValue != null) {
      return 'Color(0x${hexValue!.toRadixString(16).toUpperCase()})';
    } else {
      return 'Color.fromRGBO($r, $g, $b, $a)';
    }
  }
}

class BorderRadius {
  final double radius;
  BorderRadius.circular(this.radius);

  String toFlutterCode() {
    return 'BorderRadius.circular($radius)';
  }
}

class EdgeInsets {
  final double? all;
  final double? vertical;
  final double? horizontal;
  final double? left, top, right, bottom;

  EdgeInsets.all(this.all)
    : vertical = null,
      horizontal = null,
      left = null,
      top = null,
      right = null,
      bottom = null;
  EdgeInsets.symmetric({this.vertical, this.horizontal})
    : all = null,
      left = null,
      top = null,
      right = null,
      bottom = null;
  EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom)
    : all = null,
      vertical = null,
      horizontal = null;

  String toFlutterCode() {
    if (all != null) {
      return 'EdgeInsets.all($all)';
    } else if (vertical != null || horizontal != null) {
      final v = vertical ?? 0.0;
      final h = horizontal ?? 0.0;
      return 'EdgeInsets.symmetric(vertical: $v, horizontal: $h)';
    } else {
      return 'EdgeInsets.fromLTRB($left, $top, $right, $bottom)';
    }
  }
}

class BoxShadow {
  final double dx;
  final double dy;
  final double blurRadius;
  final Color color;

  BoxShadow({required this.dx, required this.dy, required this.blurRadius, required this.color});

  String toFlutterCode() {
    return 'BoxShadow(offset: Offset($dx, $dy), blurRadius: $blurRadius, color: ${color.toFlutterCode()})';
  }
}

class CssProperties {
  double? width;
  double? height;
  Color? backgroundColor;
  BorderRadius? borderRadius;
  EdgeInsets? padding;
  EdgeInsets? margin;
  BoxShadow? boxShadow;
}

class CssParser {
  static CssProperties parse(
    String cssLiteral, {
    required String file,
    required int line,
    required int column,
    required List<DTRXError> warnings,
  }) {
    final props = CssProperties();
    var css = cssLiteral.trim();
    if ((css.startsWith('"') && css.endsWith('"')) || (css.startsWith("'") && css.endsWith("'"))) {
      css = css.substring(1, css.length - 1).trim();
    }

    final declarations = css.split(';');
    for (var decl in declarations) {
      decl = decl.trim();
      if (decl.isEmpty) continue;
      final colonIndex = decl.indexOf(':');
      if (colonIndex == -1) continue;
      final key = decl.substring(0, colonIndex).trim();
      final val = decl.substring(colonIndex + 1).trim();

      switch (key) {
        case 'width':
          props.width = double.tryParse(val.replaceAll('px', '').trim());
          break;
        case 'height':
          props.height = double.tryParse(val.replaceAll('px', '').trim());
          break;
        case 'background-color':
          if (val.startsWith('#')) {
            props.backgroundColor = _parseHexColor(val);
          } else if (val.startsWith('rgba')) {
            props.backgroundColor = _parseRgbaColor(val);
          }
          break;
        case 'border-radius':
          final r = double.tryParse(val.replaceAll('px', '').trim());
          if (r != null) {
            props.borderRadius = BorderRadius.circular(r);
          }
          break;
        case 'padding':
          props.padding = _parseEdgeInsets(val);
          break;
        case 'margin':
          props.margin = _parseEdgeInsets(val);
          break;
        case 'box-shadow':
          props.boxShadow = _parseBoxShadow(val);
          break;
        default:
          warnings.add(
            DTRXError(
              file: file,
              line: line,
              column: column,
              message: "Unsupported CSS property '$key'",
              isWarning: true,
            ),
          );
          break;
      }
    }

    return props;
  }

  static Color? _parseHexColor(String val) {
    var hex = val.substring(1).trim();
    if (hex.length == 3) {
      hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    }
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color.hex(0xFF000000 | parsed);
      }
    }
    return null;
  }

  static Color? _parseRgbaColor(String val) {
    final match = RegExp(
      r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)',
    ).firstMatch(val);
    if (match != null) {
      final r = int.tryParse(match.group(1)!);
      final g = int.tryParse(match.group(2)!);
      final b = int.tryParse(match.group(3)!);
      final a = double.tryParse(match.group(4)!);
      if (r != null && g != null && b != null && a != null) {
        return Color.rgba(r, g, b, a);
      }
    }
    return null;
  }

  static EdgeInsets? _parseEdgeInsets(String val) {
    final parts = val
        .split(RegExp(r'\s+'))
        .map((p) => p.replaceAll('px', '').trim())
        .map(double.tryParse)
        .toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 1) {
      return EdgeInsets.all(parts[0]!);
    } else if (parts.length == 2) {
      return EdgeInsets.symmetric(vertical: parts[0]!, horizontal: parts[1]!);
    } else if (parts.length == 4) {
      // The table: padding: Apx Bpx Cpx Dpx -> EdgeInsets.fromLTRB(B, A, D, C)
      return EdgeInsets.fromLTRB(parts[1]!, parts[0]!, parts[3]!, parts[2]!);
    }
    return null;
  }

  static BoxShadow? _parseBoxShadow(String val) {
    final match = RegExp(
      r'(-?[\d.]+)px\s+(-?[\d.]+)px\s+(-?[\d.]+)px\s+(rgba\s*\(.+?\))',
    ).firstMatch(val);
    if (match != null) {
      final dx = double.tryParse(match.group(1)!);
      final dy = double.tryParse(match.group(2)!);
      final blur = double.tryParse(match.group(3)!);
      final colorStr = match.group(4)!;
      final color = _parseRgbaColor(colorStr);
      if (dx != null && dy != null && blur != null && color != null) {
        return BoxShadow(dx: dx, dy: dy, blurRadius: blur, color: color);
      }
    }
    return null;
  }
}
