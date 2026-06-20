import 'token.dart';
import 'errors.dart';

class Lexer {
  final String file;
  final String source;
  int position = 0;
  int line = 1;
  int column = 1;

  final List<Token> tokens = [];
  final List<String> _tagStack = [];
  bool _inTagHeader = false;
  bool _isClosingTag = false;
  bool _inConditionalHeader = false;

  Lexer({required this.file, required this.source});

  List<Token> tokenize() {
    while (position < source.length) {
      _skipWhitespaceAndComments();
      if (position >= source.length) break;

      final tokenLine = line;
      final tokenColumn = column;

      if (_tagStack.isNotEmpty && !_inConditionalHeader) {
        _tokenizeMarkup(tokenLine, tokenColumn);
      } else {
        _tokenizeNormal(tokenLine, tokenColumn);
      }
    }

    tokens.add(Token(type: TokenType.eof, lexeme: '', line: line, column: column));

    return tokens;
  }

  void _skipWhitespaceAndComments() {
    while (position < source.length) {
      var char = _peek();
      if (char == ' ' || char == '\t' || char == '\r' || char == '\n') {
        _advance();
      } else if (char == '/' && _peekNext() == '/') {
        // Single-line comment
        _advance();
        _advance();
        while (position < source.length && _peek() != '\n') {
          _advance();
        }
      } else if (char == '/' && _peekNext() == '*') {
        // Multi-line comment
        _advance();
        _advance();
        while (position < source.length) {
          if (_peek() == '*' && _peekNext() == '/') {
            _advance();
            _advance();
            break;
          }
          _advance();
        }
      } else {
        break;
      }
    }
  }

  void _tokenizeMarkup(int tokenLine, int tokenColumn) {
    if (_inTagHeader) {
      var char = _peek();

      if (char == '/' && _peekNext() == '>') {
        _advance();
        _advance();
        tokens.add(
          Token(type: TokenType.tagSelfClose, lexeme: '/>', line: tokenLine, column: tokenColumn),
        );
        if (_tagStack.isNotEmpty) _tagStack.removeLast();
        _inTagHeader = false;
        _isClosingTag = false;
        return;
      }

      if (char == '>') {
        _advance();
        tokens.add(
          Token(type: TokenType.tagClose, lexeme: '>', line: tokenLine, column: tokenColumn),
        );
        _inTagHeader = false;
        if (_isClosingTag) {
          if (_tagStack.isNotEmpty) _tagStack.removeLast();
          _isClosingTag = false;
        }
        return;
      }

      if (char == '=') {
        _advance();
        tokens.add(
          Token(type: TokenType.equals, lexeme: '=', line: tokenLine, column: tokenColumn),
        );
        return;
      }

      if (char == '{') {
        _advance();
        tokens.add(
          Token(type: TokenType.lbrace, lexeme: '{', line: tokenLine, column: tokenColumn),
        );

        // Scan balanced braces content as dartCode
        final dartLine = line;
        final dartCol = column;
        final content = _scanBalancedBraces();
        tokens.add(
          Token(type: TokenType.dartCode, lexeme: content, line: dartLine, column: dartCol),
        );

        _skipWhitespaceAndComments();
        if (_peek() == '}') {
          final rLine = line;
          final rCol = column;
          _advance();
          tokens.add(Token(type: TokenType.rbrace, lexeme: '}', line: rLine, column: rCol));
        } else {
          throw DTRXError(
            file: file,
            line: line,
            column: column,
            message: "Expected closing '}' after Dart expression inside attribute",
          );
        }
        return;
      }

      if (char == '"' || char == "'") {
        var value = _scanStringLiteral();
        tokens.add(
          Token(
            type: TokenType.stringLit,
            lexeme: value,
            line: tokenLine,
            column: tokenColumn,
            literal: value,
          ),
        );
        return;
      }

      if (_isDigit(char)) {
        var numStr = _scanNumberLiteral();
        tokens.add(
          Token(
            type: TokenType.numberLit,
            lexeme: numStr,
            line: tokenLine,
            column: tokenColumn,
            literal: double.tryParse(numStr) ?? int.tryParse(numStr),
          ),
        );
        return;
      }

      if (char == '.') {
        _advance();
        tokens.add(Token(type: TokenType.dot, lexeme: '.', line: tokenLine, column: tokenColumn));
        return;
      }

      if (_isAlpha(char)) {
        var ident = _scanIdentifier();
        if (ident == 'true' || ident == 'false') {
          tokens.add(
            Token(
              type: TokenType.boolLit,
              lexeme: ident,
              line: tokenLine,
              column: tokenColumn,
              literal: ident == 'true',
            ),
          );
        } else {
          tokens.add(
            Token(type: TokenType.identifier, lexeme: ident, line: tokenLine, column: tokenColumn),
          );
        }
        return;
      }

      if (char == '(') {
        _advance();
        tokens.add(
          Token(type: TokenType.lparen, lexeme: '(', line: tokenLine, column: tokenColumn),
        );
        return;
      }

      if (char == ')') {
        _advance();
        tokens.add(
          Token(type: TokenType.rparen, lexeme: ')', line: tokenLine, column: tokenColumn),
        );
        return;
      }

      // If we see an operator or other character, consume it as identifier
      if (_isOperatorChar(char)) {
        var op = _scanOperator();
        tokens.add(
          Token(type: TokenType.identifier, lexeme: op, line: tokenLine, column: tokenColumn),
        );
        return;
      }

      throw DTRXError(
        file: file,
        line: tokenLine,
        column: tokenColumn,
        message: "Unexpected character '$char' in attribute list",
      );
    } else {
      // In tag content (parsing children)
      var char = _peek();

      if (char == ']') {
        _advance();
        tokens.add(
          Token(type: TokenType.rbracket, lexeme: ']', line: tokenLine, column: tokenColumn),
        );
        return;
      }

      if (char == '<') {
        if (_peekNext() == '/') {
          _advance();
          _advance();
          tokens.add(
            Token(type: TokenType.tagEndOpen, lexeme: '</', line: tokenLine, column: tokenColumn),
          );
          _inTagHeader = true;
          _isClosingTag = true;
          return;
        } else {
          _advance();
          tokens.add(
            Token(type: TokenType.tagOpen, lexeme: '<', line: tokenLine, column: tokenColumn),
          );
          _inTagHeader = true;
          _isClosingTag = false;
          _skipWhitespaceAndComments();
          if (_isAlpha(_peek())) {
            var startPos = position;
            var name = _scanIdentifier();
            position = startPos;
            _tagStack.add(name);
          } else {
            _tagStack.add('unknown');
          }
          return;
        }
      }

      if (char == '{') {
        _advance();
        tokens.add(
          Token(type: TokenType.lbrace, lexeme: '{', line: tokenLine, column: tokenColumn),
        );

        final dartLine = line;
        final dartCol = column;
        final content = _scanBalancedBraces();
        tokens.add(
          Token(type: TokenType.dartCode, lexeme: content, line: dartLine, column: dartCol),
        );

        _skipWhitespaceAndComments();
        if (_peek() == '}') {
          final rLine = line;
          final rCol = column;
          _advance();
          tokens.add(Token(type: TokenType.rbrace, lexeme: '}', line: rLine, column: rCol));
        } else {
          throw DTRXError(
            file: file,
            line: line,
            column: column,
            message: "Expected closing '}' after child Dart expression",
          );
        }
        return;
      }

      // Check if it starts a conditional child "if ("
      if (char == 'i' && _peekNext() == 'f') {
        int lookAhead = position + 2;
        while (lookAhead < source.length && _isWhitespace(source[lookAhead])) {
          lookAhead++;
        }
        if (lookAhead < source.length && source[lookAhead] == '(') {
          _advance(); // 'i'
          _advance(); // 'f'
          tokens.add(
            Token(type: TokenType.kwIf, lexeme: 'if', line: tokenLine, column: tokenColumn),
          );
          _inConditionalHeader = true;
          return;
        }
      }

      // It must be a textNode
      var text = _scanTextNode();
      if (text.isNotEmpty) {
        tokens.add(
          Token(type: TokenType.textNode, lexeme: text, line: tokenLine, column: tokenColumn),
        );
      }
    }
  }

  void _tokenizeNormal(int tokenLine, int tokenColumn) {
    var char = _peek();

    if (char == '<') {
      if (_shouldEnterMarkup()) {
        _advance();
        tokens.add(
          Token(type: TokenType.tagOpen, lexeme: '<', line: tokenLine, column: tokenColumn),
        );
        _inTagHeader = true;
        _isClosingTag = false;
        _skipWhitespaceAndComments();
        if (_isAlpha(_peek())) {
          var startPos = position;
          var name = _scanIdentifier();
          position = startPos;
          _tagStack.add(name);
        } else {
          _tagStack.add('unknown');
        }
        return;
      } else {
        _advance();
        tokens.add(
          Token(type: TokenType.tagOpen, lexeme: '<', line: tokenLine, column: tokenColumn),
        );
        return;
      }
    }

    if (char == '>') {
      _advance();
      tokens.add(
        Token(type: TokenType.tagClose, lexeme: '>', line: tokenLine, column: tokenColumn),
      );
      return;
    }

    if (char == '(') {
      _advance();
      tokens.add(Token(type: TokenType.lparen, lexeme: '(', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == ')') {
      _advance();
      tokens.add(Token(type: TokenType.rparen, lexeme: ')', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == '{') {
      _advance();
      tokens.add(Token(type: TokenType.lbrace, lexeme: '{', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == '}') {
      _advance();
      tokens.add(Token(type: TokenType.rbrace, lexeme: '}', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == '[') {
      _advance();
      tokens.add(
        Token(type: TokenType.lbracket, lexeme: '[', line: tokenLine, column: tokenColumn),
      );
      if (_inConditionalHeader) {
        _inConditionalHeader = false;
      }
      return;
    }

    if (char == ']') {
      _advance();
      tokens.add(
        Token(type: TokenType.rbracket, lexeme: ']', line: tokenLine, column: tokenColumn),
      );
      return;
    }

    if (char == '.' && _peekNext() == '.' && _peekNextNext() == '.') {
      _advance();
      _advance();
      _advance();
      tokens.add(
        Token(type: TokenType.spread, lexeme: '...', line: tokenLine, column: tokenColumn),
      );
      return;
    }

    if (char == '.') {
      _advance();
      tokens.add(Token(type: TokenType.dot, lexeme: '.', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == ';') {
      _advance();
      tokens.add(
        Token(type: TokenType.semicolon, lexeme: ';', line: tokenLine, column: tokenColumn),
      );
      return;
    }

    if (char == '=') {
      _advance();
      tokens.add(Token(type: TokenType.equals, lexeme: '=', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == ',') {
      _advance();
      tokens.add(Token(type: TokenType.comma, lexeme: ',', line: tokenLine, column: tokenColumn));
      return;
    }

    if (char == '"' || char == "'") {
      var value = _scanStringLiteral();
      tokens.add(
        Token(
          type: TokenType.stringLit,
          lexeme: value,
          line: tokenLine,
          column: tokenColumn,
          literal: value,
        ),
      );
      return;
    }

    if (_isDigit(char)) {
      var numStr = _scanNumberLiteral();
      tokens.add(
        Token(
          type: TokenType.numberLit,
          lexeme: numStr,
          line: tokenLine,
          column: tokenColumn,
          literal: double.tryParse(numStr) ?? int.tryParse(numStr),
        ),
      );
      return;
    }

    if (_isAlpha(char)) {
      var ident = _scanIdentifier();
      if (ident == 'component') {
        tokens.add(
          Token(type: TokenType.kwComponent, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      } else if (ident == 'signal') {
        tokens.add(
          Token(type: TokenType.kwSignal, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      } else if (ident == 'return') {
        tokens.add(
          Token(type: TokenType.kwReturn, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      } else if (ident == 'var') {
        tokens.add(
          Token(type: TokenType.kwVar, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      } else if (ident == 'if') {
        tokens.add(
          Token(type: TokenType.kwIf, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      } else if (ident == 'true' || ident == 'false') {
        tokens.add(
          Token(
            type: TokenType.boolLit,
            lexeme: ident,
            line: tokenLine,
            column: tokenColumn,
            literal: ident == 'true',
          ),
        );
      } else {
        tokens.add(
          Token(type: TokenType.identifier, lexeme: ident, line: tokenLine, column: tokenColumn),
        );
      }
      return;
    }

    if (_isOperatorChar(char)) {
      var op = _scanOperator();
      tokens.add(
        Token(type: TokenType.identifier, lexeme: op, line: tokenLine, column: tokenColumn),
      );
      return;
    }

    throw DTRXError(
      file: file,
      line: tokenLine,
      column: tokenColumn,
      message: "Unexpected character '$char'",
    );
  }

  bool _shouldEnterMarkup() {
    if (tokens.isEmpty) return false;
    // Walk back to find the last non-EOF token
    var last = tokens.last;
    if (last.type == TokenType.lparen) {
      if (tokens.length >= 2) {
        var prev = tokens[tokens.length - 2];
        if (prev.type == TokenType.kwReturn || prev.type == TokenType.equals) {
          return true;
        }
      }
    }
    return false;
  }

  String _scanBalancedBraces() {
    var startPos = position;
    int braceDepth = 1;
    while (position < source.length) {
      var char = _peek();
      if (char == '"' || char == "'") {
        var quote = char;
        _advance();
        while (position < source.length && _peek() != quote) {
          if (_peek() == '\\') {
            _advance();
          }
          _advance();
        }
        if (position < source.length) _advance();
      } else if (char == '{') {
        braceDepth++;
        _advance();
      } else if (char == '}') {
        braceDepth--;
        if (braceDepth == 0) {
          break;
        }
        _advance();
      } else {
        _advance();
      }
    }
    return source.substring(startPos, position);
  }

  String _scanStringLiteral() {
    var quote = _peek();
    var startPos = position;
    _advance(); // Consume open quote
    while (position < source.length && _peek() != quote) {
      if (_peek() == '\\') {
        _advance();
      }
      _advance();
    }
    if (position < source.length) {
      _advance(); // Consume close quote
    }
    return source.substring(startPos, position);
  }

  String _scanNumberLiteral() {
    var startPos = position;
    while (position < source.length && _isDigit(_peek())) {
      _advance();
    }
    if (position < source.length && _peek() == '.' && _isDigit(_peekNext())) {
      _advance(); // consume '.'
      while (position < source.length && _isDigit(_peek())) {
        _advance();
      }
    }
    return source.substring(startPos, position);
  }

  String _scanIdentifier() {
    var startPos = position;
    while (position < source.length && _isAlphaNumeric(_peek())) {
      _advance();
    }
    return source.substring(startPos, position);
  }

  String _scanOperator() {
    var startPos = position;
    while (position < source.length && _isOperatorChar(_peek())) {
      // Don't let operators consume comments or tag markup markers
      var nextChar = _peek();
      if (nextChar == '/' && _peekNext() == '/') break;
      if (nextChar == '/' && _peekNext() == '*') break;
      if (nextChar == '/' && _peekNext() == '>') break;
      if (nextChar == '<' && _peekNext() == '/') break;
      _advance();
    }
    return source.substring(startPos, position);
  }

  String _scanTextNode() {
    var startPos = position;
    while (position < source.length) {
      var char = _peek();
      if (char == '<' || char == '{' || char == ']') {
        break;
      }
      if (char == 'i' && _peekNext() == 'f') {
        int lookAhead = position + 2;
        while (lookAhead < source.length && _isWhitespace(source[lookAhead])) {
          lookAhead++;
        }
        if (lookAhead < source.length && source[lookAhead] == '(') {
          break; // Stop, it's a conditional child!
        }
      }
      _advance();
    }
    return source.substring(startPos, position);
  }

  String _peek() {
    if (position >= source.length) return '';
    return source[position];
  }

  String _peekNext() {
    if (position + 1 >= source.length) return '';
    return source[position + 1];
  }

  String _peekNextNext() {
    if (position + 2 >= source.length) return '';
    return source[position + 2];
  }

  void _advance() {
    if (position >= source.length) return;
    var char = source[position];
    position++;
    if (char == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }
  }

  bool _isDigit(String char) {
    if (char.isEmpty) return false;
    var code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isAlpha(String char) {
    if (char.isEmpty) return false;
    var code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        char == '_' ||
        char == '\$';
  }

  bool _isAlphaNumeric(String char) {
    return _isAlpha(char) || _isDigit(char);
  }

  bool _isWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\r' || char == '\n';
  }

  bool _isOperatorChar(String char) {
    return '+-*/%&|^!?:><'.contains(char);
  }
}
