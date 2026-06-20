enum TokenType {
  // Keywords
  kwComponent, // component
  kwSignal, // signal
  kwReturn, // return
  kwVar, // var
  kwIf, // if
  // Markup
  tagOpen, // <
  tagClose, // >
  tagSelfClose, // />
  tagEndOpen, // </
  identifier, // widget/tag names and attribute keys
  dot, // .
  // Delimiters
  lparen,
  rparen, // ( )
  lbrace,
  rbrace, // { }
  lbracket,
  rbracket, // [ ]
  spread, // ...
  semicolon,
  equals,
  comma,

  // Literals
  stringLit, // "..." or '...'
  numberLit, // 300.0, 4, 150
  boolLit, // true / false
  // Dart passthrough
  dartCode, // anything inside { } that isn't a markup block
  textNode, // bare text content between tags

  eof,
}

class Token {
  final TokenType type;
  final String lexeme;
  final int line;
  final int column;
  final dynamic literal;

  Token({
    required this.type,
    required this.lexeme,
    required this.line,
    required this.column,
    this.literal,
  });

  @override
  String toString() {
    return 'Token(type: $type, lexeme: "$lexeme", line: $line, col: $column)';
  }
}
