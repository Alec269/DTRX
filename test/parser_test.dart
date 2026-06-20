import 'package:dtrx/dtrx.dart';
import 'package:test/test.dart';

void main() {
  group('Parser Tests', () {
    test('Parses a component with signals', () {
      const source = '''
component Clicker() {
  signal int count = 0;
  return (
    <Column>
      <Text value="Hello" />
    </Column>
  );
}
''';
      final lexer = Lexer(file: 'clicker.dtrx', source: source);
      final tokens = lexer.tokenize();
      final parser = Parser(file: 'clicker.dtrx', tokens: tokens);
      final program = parser.parse();

      expect(parser.errors, isEmpty);
      expect(program.body.length, equals(1));

      final comp = program.body.first as ComponentNode;
      expect(comp.name, equals('Clicker'));
      expect(comp.body.length, equals(2)); // signal decl + return stmt

      final signal = comp.body[0] as SignalDeclNode;
      expect(signal.name, equals('count'));
      expect(signal.type, equals('int'));
      expect(signal.initializer, equals('0'));

      final ret = comp.body[1] as ReturnNode;
      expect(ret.markup, isA<ParentTagNode>());
    });

    test('Parses conditional children in markup', () {
      const source = '''
component Clicker() {
  return (
    <Column>
      if (count > 5) ...[
        <Text value="High" />
      ]
    </Column>
  );
}
''';
      final lexer = Lexer(file: 'conditional.dtrx', source: source);
      final tokens = lexer.tokenize();
      final parser = Parser(file: 'conditional.dtrx', tokens: tokens);
      final program = parser.parse();

      expect(parser.errors, isEmpty);
      final comp = program.body.first as ComponentNode;
      final ret = comp.body.first as ReturnNode;
      final column = ret.markup as ParentTagNode;

      expect(column.children.length, equals(1));
      expect(column.children.first, isA<ConditionalChild>());

      final condChild = column.children.first as ConditionalChild;
      expect(condChild.condition.trim(), equals('count > 5'));
      expect(condChild.children.length, equals(1));
      expect(condChild.children.first, isA<MarkupNodeChild>());
    });

    test('Reports error on mismatched close tag', () {
      const source = '''
component Clicker() {
  return (
    <Column>
      <Text value="Hello" />
    </Row>
  );
}
''';
      final lexer = Lexer(file: 'mismatch.dtrx', source: source);
      final tokens = lexer.tokenize();
      final parser = Parser(file: 'mismatch.dtrx', tokens: tokens);
      parser.parse();

      expect(parser.errors, isNotEmpty);
      final firstError = parser.errors.first;
      expect(firstError.message, contains("Mismatched closing tag"));
      expect(firstError.message, contains("Column"));
      expect(firstError.message, contains("Row"));
    });
  });
}
