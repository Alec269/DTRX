sealed class AstNode {
  int line = 0;
  int column = 0;
}

class ProgramNode extends AstNode {
  final List<AstNode> body;
  ProgramNode(this.body);
}

class ComponentNode extends AstNode {
  final String name;
  final List<ParameterNode> params;
  final List<AstNode> body; // signal decls + return stmt + dart statements

  ComponentNode({required this.name, required this.params, required this.body});
}

class ParameterNode extends AstNode {
  final bool required;
  final String type;
  final String name;
  final String? defaultValue; // raw Dart expression string

  ParameterNode({
    required this.required,
    required this.type,
    required this.name,
    this.defaultValue,
  });
}

class SignalDeclNode extends AstNode {
  final String type;
  final String name;
  final String initializer; // raw Dart expression string

  SignalDeclNode({required this.type, required this.name, required this.initializer});
}

class ReturnNode extends AstNode {
  final MarkupNode markup;
  ReturnNode(this.markup);
}

class VarNode extends AstNode {
  final String name;
  final MarkupNode markup;

  VarNode({required this.name, required this.markup});
}

class DartStatementNode extends AstNode {
  final String rawCode;
  DartStatementNode(this.rawCode);
}

sealed class MarkupNode extends AstNode {}

class SelfClosingTagNode extends MarkupNode {
  final String tagName;
  final List<AttributeNode> attributes;

  SelfClosingTagNode({required this.tagName, required this.attributes});
}

class ParentTagNode extends MarkupNode {
  final String tagName;
  final List<AttributeNode> attributes;
  final List<MarkupChild> children;

  ParentTagNode({required this.tagName, required this.attributes, required this.children});
}

sealed class AttributeValue {}

class LiteralAttributeValue extends AttributeValue {
  final dynamic value;
  LiteralAttributeValue(this.value);
}

class ExpressionAttributeValue extends AttributeValue {
  final String dartExpr;
  ExpressionAttributeValue(this.dartExpr);
}

class AttributeNode extends AstNode {
  final String key;
  final AttributeValue value;

  AttributeNode({required this.key, required this.value});
}

sealed class MarkupChild extends AstNode {}

class MarkupNodeChild extends MarkupChild {
  final MarkupNode node;
  MarkupNodeChild(this.node);
}

class ConditionalChild extends MarkupChild {
  final String condition; // raw dart expression
  final List<MarkupChild> children;

  ConditionalChild({required this.condition, required this.children});
}

class ExpressionChild extends MarkupChild {
  final String dartExpr;
  ExpressionChild(this.dartExpr);
}

class TextNodeChild extends MarkupChild {
  final String text;
  TextNodeChild(this.text);
}
