import 'token.dart';
import 'ast.dart';
import 'errors.dart';

class Parser {
  final String file;
  final List<Token> _tokens;
  int _current = 0;
  final List<DTRXError> errors = [];

  Parser({required this.file, required this._tokens});

  T _loc<T extends AstNode>(Token token, T node) {
    node.line = token.line;
    node.column = token.column;
    return node;
  }

  ProgramNode parse() {
    final body = <AstNode>[];
    final startToken = _peek();
    while (!_isAtEnd()) {
      try {
        if (_peek().type == TokenType.kwComponent) {
          body.add(_parseComponentDecl());
        } else {
          body.add(_parseTopLevelDartStatement());
        }
      } on DTRXError catch (e) {
        errors.add(e);
        _recoverTopLevel();
      } catch (e) {
        errors.add(
          DTRXError(file: file, line: _peek().line, column: _peek().column, message: e.toString()),
        );
        _recoverTopLevel();
      }
    }
    return _loc(startToken, ProgramNode(body));
  }

  ComponentNode _parseComponentDecl() {
    final compToken = _consume(TokenType.kwComponent, "Expected 'component'");
    final nameToken = _consume(TokenType.identifier, "Expected component name");
    final params = _parseParameterList();
    final body = _parseBlock();
    return _loc(compToken, ComponentNode(name: nameToken.lexeme, params: params, body: body));
  }

  List<ParameterNode> _parseParameterList() {
    _consume(TokenType.lparen, "Expected '('");
    final params = <ParameterNode>[];
    if (_peek().type != TokenType.rparen) {
      do {
        params.add(_parseParameter());
      } while (_match(TokenType.comma));
    }
    _consume(TokenType.rparen, "Expected ')'");
    return params;
  }

  ParameterNode _parseParameter() {
    final startToken = _peek();
    bool isRequired = false;
    if (_peek().type == TokenType.identifier && _peek().lexeme == 'required') {
      _advance();
      isRequired = true;
    }
    final type = _parseTypeString();
    final nameToken = _consume(TokenType.identifier, "Expected parameter name");

    String? defaultValue;
    if (_match(TokenType.equals)) {
      final startPos = _current;
      while (!_isAtEnd()) {
        final t = _peek();
        if (t.type == TokenType.comma || t.type == TokenType.rparen) {
          break;
        }
        _advance();
      }
      defaultValue = _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join(' ');
    }

    return _loc(
      startToken,
      ParameterNode(
        required: isRequired,
        type: type,
        name: nameToken.lexeme,
        defaultValue: defaultValue,
      ),
    );
  }

  String _parseTypeString() {
    final startPos = _current;
    _consume(TokenType.identifier, "Expected type identifier");
    if (_match(TokenType.tagOpen)) {
      // <
      int angleDepth = 1;
      while (!_isAtEnd() && angleDepth > 0) {
        if (_peek().type == TokenType.tagOpen) {
          angleDepth++;
        } else if (_peek().type == TokenType.tagClose) {
          angleDepth--;
        }
        _advance();
      }
    }
    if (_peek().lexeme == '?') {
      _advance();
    }
    return _tokens.sublist(startPos, _current).map((t) => t.lexeme).join('');
  }

  List<AstNode> _parseBlock() {
    _consume(TokenType.lbrace, "Expected '{'");
    final statements = <AstNode>[];
    while (!_isAtEnd() && _peek().type != TokenType.rbrace) {
      try {
        statements.add(_parseStatement());
      } on DTRXError catch (e) {
        errors.add(e);
        _recoverStatement();
      } catch (e) {
        errors.add(
          DTRXError(file: file, line: _peek().line, column: _peek().column, message: e.toString()),
        );
        _recoverStatement();
      }
    }
    _consume(TokenType.rbrace, "Expected '}'");
    return statements;
  }

  AstNode _parseStatement() {
    if (_peek().type == TokenType.kwSignal) {
      final node = _parseSignalDecl();
      _consume(TokenType.semicolon, "Expected ';' after signal declaration");
      return node;
    } else if (_peek().type == TokenType.kwReturn) {
      final node = _parseReturnStmt();
      _consume(TokenType.semicolon, "Expected ';' after return statement");
      return node;
    } else if (_peek().type == TokenType.kwVar) {
      final node = _parseVarStmt();
      _consume(TokenType.semicolon, "Expected ';' after var statement");
      return node;
    } else {
      final node = _parseDartStatement();
      _consume(TokenType.semicolon, "Expected ';' after Dart statement");
      return node;
    }
  }

  SignalDeclNode _parseSignalDecl() {
    final sigToken = _consume(TokenType.kwSignal, "Expected 'signal'");
    final type = _parseTypeString();
    final nameToken = _consume(TokenType.identifier, "Expected signal name");
    _consume(TokenType.equals, "Expected '=' after signal name");

    final startPos = _current;
    int braceDepth = 0;
    while (!_isAtEnd()) {
      final t = _peek();
      if (t.type == TokenType.lbrace) {
        braceDepth++;
      } else if (t.type == TokenType.rbrace) {
        if (braceDepth == 0) break;
        braceDepth--;
      } else if (t.type == TokenType.semicolon) {
        if (braceDepth == 0) break;
      }
      _advance();
    }
    final initializer = _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join(' ');
    return _loc(
      sigToken,
      SignalDeclNode(type: type, name: nameToken.lexeme, initializer: initializer),
    );
  }

  ReturnNode _parseReturnStmt() {
    final retToken = _consume(TokenType.kwReturn, "Expected 'return'");
    _consume(TokenType.lparen, "Expected '('");
    final markup = _parseMarkupNode();
    _consume(TokenType.rparen, "Expected ')'");
    return _loc(retToken, ReturnNode(markup));
  }

  VarNode _parseVarStmt() {
    final varToken = _consume(TokenType.kwVar, "Expected 'var'");
    final nameToken = _consume(TokenType.identifier, "Expected variable name");
    _consume(TokenType.equals, "Expected '='");
    _consume(TokenType.lparen, "Expected '('");
    final markup = _parseMarkupNode();
    _consume(TokenType.rparen, "Expected ')'");
    return _loc(varToken, VarNode(name: nameToken.lexeme, markup: markup));
  }

  DartStatementNode _parseDartStatement() {
    final startToken = _peek();
    int braceDepth = 0;
    while (!_isAtEnd()) {
      final t = _peek();
      if (t.type == TokenType.lbrace) {
        braceDepth++;
      } else if (t.type == TokenType.rbrace) {
        if (braceDepth == 0) break;
        braceDepth--;
      } else if (t.type == TokenType.semicolon) {
        if (braceDepth == 0) break;
      }
      _advance();
    }
    final rawCode = _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join(' ');
    return _loc(startToken, DartStatementNode(rawCode));
  }

  int get startPos => _current; // helper inside block

  DartStatementNode _parseTopLevelDartStatement() {
    final startToken = _peek();
    final startPos = _current;
    while (!_isAtEnd() && _peek().type != TokenType.kwComponent) {
      _advance();
    }
    final rawCode = _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join(' ');
    return _loc(startToken, DartStatementNode(rawCode));
  }

  MarkupNode _parseMarkupNode() {
    final openToken = _peek();
    try {
      _consume(TokenType.tagOpen, "Expected '<'");
      final nameToken = _consume(TokenType.identifier, "Expected tag name");
      final tagName = nameToken.lexeme;

      final attributes = <AttributeNode>[];
      while (_peek().type == TokenType.identifier) {
        try {
          attributes.add(_parseAttribute());
        } on DTRXError catch (e) {
          errors.add(e);
          _recoverFromMalformedTagOrAttribute();
          if (_peek().type == TokenType.tagSelfClose) {
            _advance();
            return _loc(openToken, SelfClosingTagNode(tagName: tagName, attributes: attributes));
          } else if (_peek().type == TokenType.tagClose) {
            _advance();
            break;
          }
        }
      }

      if (_match(TokenType.tagSelfClose)) {
        return _loc(openToken, SelfClosingTagNode(tagName: tagName, attributes: attributes));
      }

      _consume(TokenType.tagClose, "Expected '>' or '/>'");

      final children = <MarkupChild>[];
      while (!_isAtEnd() && _peek().type != TokenType.tagEndOpen) {
        try {
          children.add(_parseMarkupChild());
        } on DTRXError catch (e) {
          errors.add(e);
          _recoverToNextMarkupChild();
        }
      }

      _consume(TokenType.tagEndOpen, "Expected '</'");
      final closeNameToken = _consume(TokenType.identifier, "Expected closing tag name");
      final closeTagName = closeNameToken.lexeme;
      _consume(TokenType.tagClose, "Expected '>' after closing tag name");

      if (closeTagName != tagName) {
        throw DTRXError(
          file: file,
          line: closeNameToken.line,
          column: closeNameToken.column,
          message: "Mismatched closing tag: expected '</$tagName>' but got '</$closeTagName>'",
        );
      }

      return _loc(
        openToken,
        ParentTagNode(tagName: tagName, attributes: attributes, children: children),
      );
    } catch (e) {
      final error = e is DTRXError
          ? e
          : DTRXError(
              file: file,
              line: openToken.line,
              column: openToken.column,
              message: e.toString(),
            );
      errors.add(error);
      _recoverFromMalformedTagOrAttribute();
      return _loc(openToken, SelfClosingTagNode(tagName: 'error', attributes: []));
    }
  }

  AttributeNode _parseAttribute() {
    final keyToken = _consume(TokenType.identifier, "Expected attribute name");
    _consume(TokenType.equals, "Expected '='");
    final value = _parseAttributeValue();
    return _loc(keyToken, AttributeNode(key: keyToken.lexeme, value: value));
  }

  AttributeValue _parseAttributeValue() {
    final t = _peek();
    if (t.type == TokenType.stringLit) {
      _advance();
      return LiteralAttributeValue(t.literal);
    }
    if (t.type == TokenType.numberLit) {
      _advance();
      return LiteralAttributeValue(t.literal);
    }
    if (t.type == TokenType.boolLit) {
      _advance();
      return LiteralAttributeValue(t.literal);
    }
    if (t.type == TokenType.lbrace) {
      _advance(); // consume '{'
      final exprToken = _consume(TokenType.dartCode, "Expected Dart expression");
      _consume(TokenType.rbrace, "Expected '}'");
      return ExpressionAttributeValue(exprToken.lexeme);
    }

    final startPos = _current;
    while (!_isAtEnd()) {
      final next = _peek();
      if (next.type == TokenType.tagClose || next.type == TokenType.tagSelfClose) {
        break;
      }
      if (next.type == TokenType.identifier) {
        if (_peekNext().type == TokenType.equals) {
          break;
        }
      }
      _advance();
    }
    if (_current == startPos) {
      throw DTRXError(
        file: file,
        line: t.line,
        column: t.column,
        message: "Expected attribute value",
      );
    }
    final rawExpr = _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join('');
    return ExpressionAttributeValue(rawExpr);
  }

  MarkupChild _parseMarkupChild() {
    final t = _peek();
    if (t.type == TokenType.tagOpen) {
      final node = _parseMarkupNode();
      return _loc(t, MarkupNodeChild(node));
    }
    if (t.type == TokenType.lbrace) {
      final lbraceToken = _advance();
      final exprToken = _consume(TokenType.dartCode, "Expected Dart expression");
      _consume(TokenType.rbrace, "Expected '}'");
      return _loc(lbraceToken, ExpressionChild(exprToken.lexeme));
    }
    if (t.type == TokenType.kwIf) {
      final ifToken = _advance();
      _consume(TokenType.lparen, "Expected '('");
      final condition = _parseParenthesizedExpression();
      _consume(TokenType.rparen, "Expected ')'");
      _consume(TokenType.spread, "Expected '...'");
      _consume(TokenType.lbracket, "Expected '['");

      final children = <MarkupChild>[];
      while (!_isAtEnd() && _peek().type != TokenType.rbracket) {
        try {
          children.add(_parseMarkupChild());
        } on DTRXError catch (e) {
          errors.add(e);
          _recoverToNextMarkupChild();
        }
      }
      _consume(TokenType.rbracket, "Expected ']'");
      return _loc(ifToken, ConditionalChild(condition: condition, children: children));
    }
    if (t.type == TokenType.textNode) {
      final textToken = _advance();
      return _loc(textToken, TextNodeChild(t.lexeme));
    }

    throw DTRXError(
      file: file,
      line: t.line,
      column: t.column,
      message: "Unexpected child inside markup: ${t.lexeme}",
    );
  }

  String _parseParenthesizedExpression() {
    int parenDepth = 1;
    final startPos = _current;
    while (!_isAtEnd() && parenDepth > 0) {
      final t = _peek();
      if (t.type == TokenType.lparen) {
        parenDepth++;
      } else if (t.type == TokenType.rparen) {
        parenDepth--;
        if (parenDepth == 0) {
          break;
        }
      }
      _advance();
    }
    return _tokens.sublist(startPos, _current).map((tk) => tk.lexeme).join(' ');
  }

  void _recoverFromMalformedTagOrAttribute() {
    while (!_isAtEnd()) {
      final t = _peek();
      if (t.type == TokenType.tagClose || t.type == TokenType.tagSelfClose) {
        break;
      }
      _advance();
    }
  }

  void _recoverToNextMarkupChild() {
    while (!_isAtEnd()) {
      final t = _peek();
      if (t.type == TokenType.tagOpen ||
          t.type == TokenType.tagEndOpen ||
          t.type == TokenType.lbrace ||
          t.type == TokenType.kwIf) {
        break;
      }
      _advance();
    }
  }

  void _recoverTopLevel() {
    while (!_isAtEnd() && _peek().type != TokenType.kwComponent) {
      _advance();
    }
  }

  void _recoverStatement() {
    while (!_isAtEnd()) {
      final t = _peek();
      if (t.type == TokenType.semicolon || t.type == TokenType.rbrace) {
        if (t.type == TokenType.semicolon) _advance();
        break;
      }
      _advance();
    }
  }

  bool _isAtEnd() {
    return _peek().type == TokenType.eof;
  }

  Token _peek() {
    if (_current >= _tokens.length) return _tokens.last;
    return _tokens[_current];
  }

  Token _peekNext() {
    if (_current + 1 >= _tokens.length) return _tokens.last;
    return _tokens[_current + 1];
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _tokens[_current - 1];
  }

  bool _match(TokenType type) {
    if (_peek().type == type) {
      _advance();
      return true;
    }
    return false;
  }

  Token _consume(TokenType type, String message) {
    if (_peek().type == type) {
      return _advance();
    }
    throw DTRXError(file: file, line: _peek().line, column: _peek().column, message: message);
  }
}
