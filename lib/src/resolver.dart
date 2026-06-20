import 'ast.dart';
import 'errors.dart';
import 'virtual_tags.dart';

class Resolver {
  final String file;
  final List<DTRXError> errors = [];

  Resolver({required this.file});

  List<DTRXError> resolve(ProgramNode program) {
    for (var node in program.body) {
      if (node is ComponentNode) {
        _resolveComponent(node);
      }
    }
    return errors;
  }

  void _resolveComponent(ComponentNode component) {
    final params = component.params.map((p) => p.name).toList();

    // Collect signals and local variables
    final signals = <String>[];
    final locals = <String>[];
    for (var node in component.body) {
      if (node is SignalDeclNode) {
        signals.add(node.name);
      } else if (node is VarNode) {
        locals.add(node.name);
      }
    }

    // Resolve component body
    for (var node in component.body) {
      if (node is ReturnNode) {
        _resolveMarkup(node.markup, signals, params, locals);
      } else if (node is VarNode) {
        _resolveMarkup(node.markup, signals, params, locals);
      }
    }
  }

  void _resolveMarkup(
    MarkupNode node,
    List<String> signals,
    List<String> params,
    List<String> locals,
  ) {
    if (node is SelfClosingTagNode) {
      _resolveTag(node.tagName, node.attributes, signals, params, locals, node.line, node.column);
    } else if (node is ParentTagNode) {
      _resolveTag(node.tagName, node.attributes, signals, params, locals, node.line, node.column);
      for (var child in node.children) {
        _resolveMarkupChild(child, signals, params, locals);
      }
    }
  }

  void _resolveTag(
    String tagName,
    List<AttributeNode> attributes,
    List<String> signals,
    List<String> params,
    List<String> locals,
    int line,
    int column,
  ) {
    // Rule 2: Tag classification
    if (virtualTagNames.contains(tagName)) {
      // Valid virtual tag
    } else if (tagName.isNotEmpty && tagName[0] == tagName[0].toUpperCase()) {
      // Valid native passthrough
    } else if (tagName == 'div' || tagName == 'span') {
      // Valid layout primitive
      for (var attr in attributes) {
        if (attr.key != 'style') {
          errors.add(
            DTRXError(
              file: file,
              line: attr.line,
              column: attr.column,
              message: "Unsupported attribute '${attr.key}' on layout primitive '$tagName'.",
              isWarning: true,
            ),
          );
        }
      }
    } else {
      errors.add(
        DTRXError(
          file: file,
          line: line,
          column: column,
          message: "Invalid tag: '$tagName'. Lowercase tags must be 'div' or 'span'.",
        ),
      );
    }

    // Resolve attributes
    for (var attr in attributes) {
      _resolveAttributeValue(attr.value, signals, params, locals, attr.line, attr.column);
    }
  }

  void _resolveMarkupChild(
    MarkupChild child,
    List<String> signals,
    List<String> params,
    List<String> locals,
  ) {
    if (child is MarkupNodeChild) {
      _resolveMarkup(child.node, signals, params, locals);
    } else if (child is ConditionalChild) {
      _validateExpression(child.condition, signals, params, locals, child.line, child.column);
      for (var subChild in child.children) {
        _resolveMarkupChild(subChild, signals, params, locals);
      }
    } else if (child is ExpressionChild) {
      _validateExpression(child.dartExpr, signals, params, locals, child.line, child.column);
    } else if (child is TextNodeChild) {
      _validateStringInterpolations(child.text, signals, params, locals, child.line, child.column);
    }
  }

  void _resolveAttributeValue(
    AttributeValue val,
    List<String> signals,
    List<String> params,
    List<String> locals,
    int line,
    int column,
  ) {
    if (val is ExpressionAttributeValue) {
      final cbParams = _extractCallbackParams(val.dartExpr);
      final activeLocals = [...locals, ...cbParams];
      _validateExpression(val.dartExpr, signals, params, activeLocals, line, column);
    } else if (val is LiteralAttributeValue) {
      if (val.value is String) {
        _validateStringInterpolations(val.value as String, signals, params, locals, line, column);
      }
    }
  }

  void _validateExpression(
    String expr,
    List<String> signals,
    List<String> params,
    List<String> locals,
    int line,
    int column,
  ) {
    final idents = _extractIdentifiers(expr);
    for (var ident in idents) {
      if (ident.isEmpty) continue;
      // If it starts with uppercase, it's a type, enum, or class, which is allowed
      if (ident[0].toUpperCase() == ident[0] && ident[0].toLowerCase() != ident[0]) {
        continue;
      }
      if (_allowedIdentifiers.contains(ident)) {
        continue;
      }
      if (signals.contains(ident) || params.contains(ident) || locals.contains(ident)) {
        continue;
      }
      // If not found in component scope, it's an undefined signal
      errors.add(
        DTRXError(file: file, line: line, column: column, message: "Undefined signal '$ident'"),
      );
    }
  }

  void _validateStringInterpolations(
    String text,
    List<String> signals,
    List<String> params,
    List<String> locals,
    int line,
    int column,
  ) {
    final interpolations = _extractInterpolations(text);
    for (var expr in interpolations) {
      _validateExpression(expr, signals, params, locals, line, column);
    }
  }

  List<String> _extractIdentifiers(String code) {
    final regex = RegExp(r'(?<!\.)\b[a-zA-Z_$][a-zA-Z0-9_$]*\b');
    return regex.allMatches(code).map((m) => m.group(0)!).toList();
  }

  List<String> _extractInterpolations(String text) {
    final regex = RegExp(r'\{([^}]+)\}');
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  List<String> _extractCallbackParams(String code) {
    final trimmed = code.trim();
    final arrowMatch = RegExp(r'^\s*\(([^)]*)\)\s*=>').firstMatch(trimmed);
    if (arrowMatch != null) {
      final paramsStr = arrowMatch.group(1)!;
      return paramsStr
          .split(',')
          .map((p) {
            final parts = p.trim().split(RegExp(r'\s+'));
            return parts.last;
          })
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return [];
  }

  static const _allowedIdentifiers = {
    'print',
    'setState',
    'double',
    'int',
    'String',
    'bool',
    'dynamic',
    'var',
    'final',
    'const',
    'return',
    'if',
    'else',
    'true',
    'false',
    'null',
    'this',
    'super',
    'context',
    'void',
    'main',
    'event',
    'value',
  };
}
