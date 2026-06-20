import 'package:dtrx/dtrx.dart';
import 'package:test/test.dart';

void main() {
  group('Lexer Tests', () {
    test('Tokenizes basic component structure and keywords', () {
      const source = '''
component Clicker() {
  signal int count = 0;
  return (
    <Column spacing=10>
      <Text value="Count" />
    </Column>
  );
}
''';
      final lexer = Lexer(file: 'test.dtrx', source: source);
      final tokens = lexer.tokenize();

      // Check first few tokens
      expect(tokens[0].type, equals(TokenType.kwComponent));
      expect(tokens[0].lexeme, equals('component'));

      expect(tokens[1].type, equals(TokenType.identifier));
      expect(tokens[1].lexeme, equals('Clicker'));

      expect(tokens[2].type, equals(TokenType.lparen));
      expect(tokens[3].type, equals(TokenType.rparen));

      expect(tokens[4].type, equals(TokenType.lbrace));

      expect(tokens[5].type, equals(TokenType.kwSignal));
      expect(tokens[5].lexeme, equals('signal'));
    });

    test('Handles style="..." attribute as a single stringLit', () {
      const source = '''
return (
  <div style="width: 200px; height: 100px; background-color: #ffffff;" />
);
''';
      final lexer = Lexer(file: 'test.dtrx', source: source);
      final tokens = lexer.tokenize();

      // Find the tagOpen, tag name, style identifier, equals, then the stringLit
      final styleValToken = tokens.firstWhere((t) => t.type == TokenType.stringLit);
      expect(
        styleValToken.lexeme,
        equals('"width: 200px; height: 100px; background-color: #ffffff;"'),
      );
    });

    test('Handles nested braces {} in attribute expressions', () {
      const source = '''
return (
  <Button onPressed={() => {
    if (true) {
      count++;
    }
  }} />
);
''';
      final lexer = Lexer(file: 'test.dtrx', source: source);
      final tokens = lexer.tokenize();

      // The token inside onPressed={...} should be a single dartCode token
      final dartCodeToken = tokens.firstWhere((t) => t.type == TokenType.dartCode);
      expect(dartCodeToken.lexeme, contains('if (true) {'));
      expect(dartCodeToken.lexeme, contains('count++;'));
    });

    test('Lexes textNode child between tags', () {
      const source = '''
return (
  <Text>Hello, world! This is DTRX</Text>
);
''';
      final lexer = Lexer(file: 'test.dtrx', source: source);
      final tokens = lexer.tokenize();

      final textToken = tokens.firstWhere((t) => t.type == TokenType.textNode);
      expect(textToken.lexeme.trim(), equals('Hello, world! This is DTRX'));
    });
  });
}
