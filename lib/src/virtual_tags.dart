import 'ast.dart';
import 'errors.dart';

const Set<String> virtualTagNames = {'Button', 'Image', 'Input', 'ScrollView'};

AttributeNode? _findAttribute(List<AttributeNode> attributes, String key) {
  for (final a in attributes) {
    if (a.key == key) return a;
  }
  return null;
}

String _formatAttributeValue(AttributeValue val) {
  if (val is LiteralAttributeValue) {
    if (val.value is String) {
      final str = val.value as String;
      return str.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => '\${${m.group(1)}}');
    }
    return val.value.toString();
  }
  if (val is ExpressionAttributeValue) {
    return val.dartExpr;
  }
  return '';
}

class ResolvedWidget {
  final String flutterWidgetName; // e.g. "IconButton", "ElevatedButton.icon"
  final List<AttributeNode> remappedAttributes;
  final MarkupNode? syntheticChild; // e.g. Text("Add") for ElevatedButton

  ResolvedWidget({
    required this.flutterWidgetName,
    required this.remappedAttributes,
    this.syntheticChild,
  });
}

ResolvedWidget? resolveVirtualTag(
  String tagName,
  List<AttributeNode> attributes, {
  List<DTRXError>? warnings,
  String? file,
  int line = 1,
  int column = 1,
}) {
  if (tagName == 'Button') {
    final textAttr = _findAttribute(attributes, 'text');
    final iconAttr = _findAttribute(attributes, 'icon');

    if (iconAttr != null && textAttr == null) {
      // icon only -> IconButton
      final remapped = attributes.where((a) => a.key != 'text').toList();
      return ResolvedWidget(flutterWidgetName: 'IconButton', remappedAttributes: remapped);
    } else if (textAttr != null && iconAttr == null) {
      // text only -> ElevatedButton
      final remapped = attributes.where((a) => a.key != 'text').toList();
      final syntheticChild =
          SelfClosingTagNode(
              tagName: 'Text',
              attributes: [
                AttributeNode(key: 'value', value: textAttr.value)
                  ..line = line
                  ..column = column,
              ],
            )
            ..line = line
            ..column = column;
      return ResolvedWidget(
        flutterWidgetName: 'ElevatedButton',
        remappedAttributes: remapped,
        syntheticChild: syntheticChild,
      );
    } else if (textAttr != null && iconAttr != null) {
      // text + icon -> ElevatedButton.icon
      final textExpr = _formatAttributeValue(textAttr.value);
      final labelExpr = 'Text($textExpr)';
      final remapped = attributes.where((a) => a.key != 'text' && a.key != 'icon').toList();

      // We keep the icon attribute as named parameter icon:
      remapped.add(
        AttributeNode(key: 'icon', value: iconAttr.value)
          ..line = iconAttr.line
          ..column = iconAttr.column,
      );

      remapped.add(
        AttributeNode(key: 'label', value: ExpressionAttributeValue(labelExpr))
          ..line = line
          ..column = column,
      );

      return ResolvedWidget(flutterWidgetName: 'ElevatedButton.icon', remappedAttributes: remapped);
    } else {
      // neither
      if (warnings != null && file != null) {
        warnings.add(
          DTRXError(
            file: file,
            line: line,
            column: column,
            message: 'Button has neither text nor icon',
            isWarning: true,
          ),
        );
      }
      return ResolvedWidget(flutterWidgetName: 'ElevatedButton', remappedAttributes: attributes);
    }
  }

  if (tagName == 'Image') {
    final srcAttr = _findAttribute(attributes, 'src');
    final urlAttr = _findAttribute(attributes, 'url');

    if (srcAttr != null) {
      return ResolvedWidget(flutterWidgetName: 'Image.asset', remappedAttributes: attributes);
    } else if (urlAttr != null) {
      return ResolvedWidget(flutterWidgetName: 'Image.network', remappedAttributes: attributes);
    } else {
      return ResolvedWidget(flutterWidgetName: 'Image', remappedAttributes: attributes);
    }
  }

  if (tagName == 'Input') {
    final labelAttr = _findAttribute(attributes, 'label');
    if (labelAttr != null) {
      final labelExpr = _formatAttributeValue(labelAttr.value);
      final decorationExpr = 'InputDecoration(labelText: $labelExpr)';
      final remapped = attributes.where((a) => a.key != 'label').toList();
      remapped.add(
        AttributeNode(key: 'decoration', value: ExpressionAttributeValue(decorationExpr))
          ..line = line
          ..column = column,
      );
      return ResolvedWidget(flutterWidgetName: 'TextField', remappedAttributes: remapped);
    } else {
      return ResolvedWidget(flutterWidgetName: 'TextField', remappedAttributes: attributes);
    }
  }

  if (tagName == 'ScrollView') {
    return ResolvedWidget(
      flutterWidgetName: 'SingleChildScrollView',
      remappedAttributes: attributes,
    );
  }

  return null;
}
