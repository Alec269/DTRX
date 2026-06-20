import 'package:dtrx/dtrx.dart';
import 'package:test/test.dart';

void main() {
  group('CSS Parser Tests', () {
    test('Parses width and height', () {
      final warnings = <DTRXError>[];
      final props = CssParser.parse(
        'width: 200px; height: 150px;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );

      expect(warnings, isEmpty);
      expect(props.width, equals(200.0));
      expect(props.height, equals(150.0));
    });

    test('Parses hex and rgba colors', () {
      final warnings = <DTRXError>[];
      final propsHex = CssParser.parse(
        'background-color: #332E3E;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(propsHex.backgroundColor?.toFlutterCode(), equals('Color(0xFF332E3E)'));

      final propsRgba = CssParser.parse(
        'background-color: rgba(255, 0, 128, 0.5);',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(
        propsRgba.backgroundColor?.toFlutterCode(),
        equals('Color.fromRGBO(255, 0, 128, 0.5)'),
      );
    });

    test('Parses border-radius', () {
      final warnings = <DTRXError>[];
      final props = CssParser.parse(
        'border-radius: 12px;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(props.borderRadius?.toFlutterCode(), equals('BorderRadius.circular(12.0)'));
    });

    test('Parses padding and margin mappings', () {
      final warnings = <DTRXError>[];

      // 1 value: all
      final props1 = CssParser.parse(
        'padding: 8px;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(props1.padding?.toFlutterCode(), equals('EdgeInsets.all(8.0)'));

      // 2 values: symmetric (vertical, horizontal)
      final props2 = CssParser.parse(
        'padding: 10px 20px;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(
        props2.padding?.toFlutterCode(),
        equals('EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0)'),
      );

      // 4 values: fromLTRB(B, A, D, C)
      final props4 = CssParser.parse(
        'padding: 5px 10px 15px 20px;',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(props4.padding?.toFlutterCode(), equals('EdgeInsets.fromLTRB(10.0, 5.0, 20.0, 15.0)'));
    });

    test('Parses box-shadow', () {
      final warnings = <DTRXError>[];
      final props = CssParser.parse(
        'box-shadow: 2px 4px 8px rgba(0, 0, 0, 0.2);',
        file: 'test.css',
        line: 1,
        column: 1,
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(
        props.boxShadow?.toFlutterCode(),
        equals(
          'BoxShadow(offset: Offset(2.0, 4.0), blurRadius: 8.0, color: Color.fromRGBO(0, 0, 0, 0.2))',
        ),
      );
    });

    test('Emits warning on unsupported properties', () {
      final warnings = <DTRXError>[];
      final props = CssParser.parse(
        'display: flex; width: 100px;',
        file: 'test.css',
        line: 10,
        column: 5,
        warnings: warnings,
      );

      expect(warnings, isNotEmpty);
      expect(warnings.first.isWarning, isTrue);
      expect(warnings.first.message, contains("Unsupported CSS property 'display'"));
      expect(warnings.first.line, equals(10));
      expect(warnings.first.column, equals(5));
      expect(props.width, equals(100.0));
    });
  });
}
