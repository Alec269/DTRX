// lib\src\errors.dart

const String errRed = "\x1b[31m";
const String warnYellow = "\x1b[33m";
const String okGreen = "\x1b[32m";
const String ansiReset = "\x1b[0m";

class DTRXError implements Exception {
  final String file;
  final int line;
  final int column;
  final String message;
  final bool isWarning;

  DTRXError({
    required this.file,
    required this.line,
    required this.column,
    required this.message,
    this.isWarning = false,
  });

  @override
  String toString() {
    final prefix = isWarning ? '$warnYellow[dtrx warn] ' : '$errRed[dtrx error]';
    // Ensure we use the exact em-dash character ' — ' specified in the prompt
    return '$prefix$ansiReset $file:$line:$column —$warnYellow $message $ansiReset';
  }
}
