import 'package:dtrx/dtrx.dart';
import 'package:test/test.dart';

void main() {
  group('Code Generator Tests', () {
    test('Generates StatelessWidget for signal-free component', () {
      const source = '''
component UserProfile(required String name, int age = 18) {
  return (
    <Center>
      <Text value="Hello" />
    </Center>
  );
}
''';
      final tokens = Lexer(file: 'user_profile.dtrx', source: source).tokenize();
      final program = Parser(file: 'user_profile.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'user_profile.dtrx').generate(program);

      expect(output, contains('class UserProfile extends StatelessWidget {'));
      expect(output, contains('final String name;'));
      expect(output, contains('final int age;'));
      expect(
        output,
        contains('const UserProfile({super.key, required this.name, this.age = 18});'),
      );
      expect(output, contains('Widget build(BuildContext context) {'));
    });

    test('Generates StatefulWidget with setState wrapping for signal components', () {
      const source = '''
component Clicker() {
  signal int count = 0;
  return (
    <Button text="Add" onPressed={() => count++} />
  );
}
''';
      final tokens = Lexer(file: 'clicker.dtrx', source: source).tokenize();
      final program = Parser(file: 'clicker.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'clicker.dtrx').generate(program);

      expect(output, contains('class Clicker extends StatefulWidget {'));
      expect(output, contains('class _ClickerState extends State<Clicker> {'));
      expect(output, contains('int count = 0;'));
      expect(output, contains('setState(() {\n        count++;\n      })'));
    });

    test('Maps Text value to a positional constructor', () {
      const source = '''
component SimpleText() {
  return (
    <Text value="Greeting: {name}" style=TextStyle() />
  );
}
''';
      final tokens = Lexer(file: 'simple_text.dtrx', source: source).tokenize();
      final program = Parser(file: 'simple_text.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'simple_text.dtrx').generate(program);

      expect(output, contains('Text("Greeting: \${name}", style: TextStyle())'));
      expect(output, isNot(contains('value:')));
    });

    test('Wraps div with multiple children inside Column', () {
      const source = '''
component Layout() {
  return (
    <div style="width: 100px; height: 100px;">
      <Text value="1" />
      <Text value="2" />
    </div>
  );
}
''';
      final tokens = Lexer(file: 'layout.dtrx', source: source).tokenize();
      final program = Parser(file: 'layout.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'layout.dtrx').generate(program);

      expect(output, contains('Container('));
      expect(output, contains('width: 100.0'));
      expect(output, contains('height: 100.0'));
      expect(output, contains('child: Column(\n        children: ['));
      expect(output, contains('Text("1")'));
      expect(output, contains('Text("2")'));
    });

    test('Button with text only → ElevatedButton with Text child', () {
      const source = '''
component Comp() {
  return (
    <Button text="Add" onPressed={handlePress} />
  );
}
''';
      final tokens = Lexer(file: 'comp.dtrx', source: source).tokenize();
      final program = Parser(file: 'comp.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'comp.dtrx').generate(program);

      expect(output, contains('ElevatedButton('));
      expect(output, contains('onPressed: handlePress'));
      expect(output, contains('child: Text("Add")'));
    });

    test('Button with icon only → IconButton', () {
      const source = '''
component Comp() {
  return (
    <Button icon={Icon(Icons.ac_unit)} onPressed={handlePress} />
  );
}
''';
      final tokens = Lexer(file: 'comp.dtrx', source: source).tokenize();
      final program = Parser(file: 'comp.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'comp.dtrx').generate(program);

      expect(output, contains('IconButton('));
      expect(output, contains('icon: Icon(Icons.ac_unit)'));
      expect(output, contains('onPressed: handlePress'));
    });

    test('Button with text and icon → ElevatedButton.icon', () {
      const source = '''
component Comp() {
  return (
    <Button text="Save" icon={Icon(Icons.save)} onPressed={handlePress} />
  );
}
''';
      final tokens = Lexer(file: 'comp.dtrx', source: source).tokenize();
      final program = Parser(file: 'comp.dtrx', tokens: tokens).parse();
      final output = CodeGen(file: 'comp.dtrx').generate(program);

      expect(output, contains('ElevatedButton.icon('));
      expect(output, contains('icon: Icon(Icons.save)'));
      expect(output, contains('label: Text("Save")'));
      expect(output, contains('onPressed: handlePress'));
    });
  });
}
