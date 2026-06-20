import 'dart:io';
import 'package:dtrx/dtrx.dart';

void main(List<String> arguments) {
  //
  String? outDir;
  final List<String> filePaths = [];

  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--out') {
      if (i + 1 < arguments.length) {
        outDir = arguments[i + 1];
        i++;
      }
    } else {
      filePaths.add(arguments[i]);
    }
  }

  if (filePaths.isEmpty) {
    print('Usage:$warnYellow dtrx [--out <dir>] <file.dtrx> [more_files.dtrx...]$ansiReset');
    exit(1);
  }

  bool hasErrors = false;

  String getBasename(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  for (final arg in filePaths) {
    final file = File(arg);
    if (!file.existsSync()) {
      print("$errRed[dtrx error]$ansiReset $arg:0:0 — File does not exist");
      hasErrors = true;
      continue;
    }

    try {
      final source = file.readAsStringSync();

      // 1. Lexer
      final lexer = Lexer(file: arg, source: source);
      final tokens = lexer.tokenize();

      // 2. Parser
      final parser = Parser(file: arg, tokens: tokens);
      final program = parser.parse();

      if (parser.errors.isNotEmpty) {
        for (final err in parser.errors) {
          print(err.toString());
        }
        hasErrors = true;
        continue;
      }

      // 3. Resolver
      final resolver = Resolver(file: arg);
      final resolverErrors = resolver.resolve(program);

      // Print resolver errors and warnings
      for (final err in resolverErrors) {
        print(err.toString());
        if (!err.isWarning) {
          hasErrors = true;
        }
      }

      if (hasErrors) {
        continue;
      }

      // 4. Codegen
      final codegen = CodeGen(file: arg);
      final generatedCode = codegen.generate(program);

      // Print codegen/CSS warnings if any
      for (final warn in codegen.warnings) {
        print(warn.toString());
      }

      // 5. Write Output
      String outputPath;
      if (outDir != null) {
        final baseName = getBasename(arg);
        final newBaseName = baseName.endsWith('.dtrx')
            ? baseName.replaceAll(RegExp(r'\.dtrx$'), '.dtrx.dart')
            : '$baseName.dtrx.dart';
        outputPath = outDir.endsWith('/') || outDir.endsWith('\\')
            ? '$outDir$newBaseName'
            : '$outDir/$newBaseName';
      } else {
        outputPath = arg.endsWith('.dtrx')
            ? arg.replaceAll(RegExp(r'\.dtrx$'), '.dtrx.dart')
            : '$arg.dtrx.dart';
      }

      final outputFile = File(outputPath);
      final parentDir = outputFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
      outputFile.writeAsStringSync(generatedCode);
    } catch (e) {
      if (e is DTRXError) {
        print(e.toString());
      } else {
        print("$errRed[dtrx error]$ansiReset $arg:0:0 — Unexpected compilation error: $e");
      }
      hasErrors = true;
    }
  }

  if (hasErrors) {
    exit(1);
  } else {
    print("Current ${Directory.current}");
    print("${okGreen}Compile Successful$ansiReset");
    exit(0);
  }
}
