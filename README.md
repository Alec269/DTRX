
# DarT Reactive Xml (DTRX)

DTRX is a declarative, component-driven language extension built specifically for building user interfaces in Dart. It brings an elegant, web-inspired XML markup syntax and fine-grained, zero-boilerplate **Signals** reactivity straight to the Flutter framework—functioning as a natural extension to Dart, much like TSX is to TypeScript.

## Version

`v0.1.0` - `Beta`

## Core Features

- ⚛️ **Signal Reactivity:** Bind component state to layout nodes with absolute zero boilerplate.
- 📦 **Virtual Tag Layer:** High-level tags like `<Button>` dynamically resolve to specific optimized widgets at compile time based on your passing attributes.
- 🎨 **Web-Inspired Layouts:** Familiar `<div>` and `<span>` primitive blocks coupled with semantic inline CSS styles compile straight to production-ready layout trees.
- 🛠️ **Pure Dart Pipeline:** Built entirely with a custom, handwritten compiler pipeline (Lexer ──> Parser ──> Resolver ──> Code Generator).

---

## File Extensions

- **Source Files:** `<filename>.dtrx`
- **Compiled Output Artifacts:** `<filename>.dtrx.dart`

---

## Example Syntax

```dtrx
// UserProfile.dtrx
component UserProfile(required String name, int age = 18) {
  return (
    <Center>
      <div style="width: 200px; height: 150px;">
        <Text value="Hello" />
        <Button icon={Icon(Icons.ac_unit)} onPressed={() => print("Hello")} />
      </div>
    </Center>
  );
}

// Clicker.dtrx
component Clicker() {
  signal int count = 0;

  return (
    <Column>
      <Text value="Count: {count}" />
      <Button text="Add" onPressed={() => count++} />
    </Column>
  );
}

```

---

## Getting Started

### Prerequisites

Ensure you have the Dart SDK installed on your system:

- Dart SDK `^3.12.0`

### Installation & Dependency Setup

Add DTRX to your Dart/Flutter project environment configuration:

```sh

flutter pub add dev:dtrx

```

---

## CLI Usage

### As Dev_Dependency (**Recommended**)

run

```sh
dart pub add dev:dtrx

dart run dtrx path\to\component.dtrx
# do not write dtrx.dart
```

### Direct

Run the `dtrx` compiler binary straight via the Dart CLI to transpile your components into standard Flutter widgets. Though, for this you'll have git clone DTRX from <https://github.com/Alec269/DTRX.git>

```bash
dart run path/to/bin/dtrx.dart path/to/component.dtrx

```

### Compiled

```pwsh
dart compile exe .\bin\dtrx.dart -o .\out\dtrx.exe

.\out\dtrx.exe path\to\component.dtrx

```

### Transpile a Single File

```bash
dart run dtrx path/to/component.dtrx

```

*This generates a `path/to/component.dtrx.dart` production source file.*

### Watch a Directory for Live Reload Compilation

```bash
dart run dtrx watch lib/components/

```

**warning**: *Currently, this feature has not been correctly implemented*.

### Run Diagnostic Type Checks Without Disk Emission

```bash
dart run dtrx --check path/to/component.dtrx

```

**warning**: *Currently, this feature has not been correctly implemented*.

---

## Technical Architecture & Grammar Specification

For deep structural details regarding the hand-written compilation pipeline, semantic validation passes, or the complete language context grammar, please see the core documentation file:
→ **[docs/spec.md](./docs/SPEC.md)**
