# Changelog

All notable changes to this project will be documented in this file.

## [v0.1.0] - Beta (2026-06-20)

### Added

- Declarative component language with `.dtrx` source files and compiled `.dtrx.dart` outputs.
- Signal reactivity system (zero-boilerplate Signals) for fine-grained state updates.
- Virtual tag layer: high-level tags (e.g., `<Button>`) resolve to optimized widgets at compile time.
- Web-inspired layout primitives (`<div>`, `<span>`) and inline-style support compiling to Flutter layout trees.
- Pure-Dart compiler pipeline: Lexer → Parser → Resolver → Code Generator.
- CLI usage for transpiling:
  - Transpile single or multiple `.dtrx` files to `.dtrx.dart`.
  - Add as a dev dependency (`dart pub add dev:dtrx`) and run via `dart run dtrx`.
  - Direct execution via `dart run path/to/bin/dtrx.dart` and compiled executable usage.
- Documentation pointer to technical architecture and grammar: `doc/SPEC.md`.

### Known limitations / Not implemented

- `watch` directory live-reload compilation is not implemented (planned).
- `--check` diagnostic/type-check mode without disk emission is not implemented (planned).

### Notes

- Target Dart SDK: ^3.12.0.
- Compiler is intended to be a production-friendly transpiler producing standard Flutter widgets.
- See `README.md` for usage examples and `doc/SPEC.md` for the language grammar and deeper architecture.
