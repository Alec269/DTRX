# DarT Reactive Xml (DTRX)

## 1. Introduction & Design Philosophy

**DTRX (DarT Reactive Xml)** is a declarative, component-driven language extension engineered specifically for building highly reactive user interfaces. Positioned as a native extension to the Dart ecosystem—similar to how TSX extends TypeScript—DTRX smoothly bridges the gap between clean, web-inspired XML markup syntax and the robust component layout architecture of Flutter.

### Core Tenets

* **Declarative Reactivity:** Component state management is bound directly to markup primitives through zero-boilerplate *Signals*, minimizing explicit lifecycle tracking.
* **Layout Primitives:** Simplifies layout orchestration using web-standard structural `div` and `span` tags that compile cleanly down to performance-optimized native rendering systems.
* **Compile-time Virtual Abstractions:** Dynamically resolves high-level descriptive tags into target framework widgets based on local element property contexts.

---

## 2. Formal Grammar Specification (EBNF)

The formal syntactic composition of a DTRX compilation unit is strictly governed by the following Extended Backus-Naur Form (EBNF):

```ebnf
Program             ::= ( ComponentDecl | DartStatement )* EOF

ComponentDecl       ::= "component" Identifier ParameterList Block

ParameterList       ::= "(" ( Parameter ( "," Parameter )* )? ")"
Parameter           ::= ( "required" )? Type Identifier ( "=" Expression )?

Block               ::= "{" Statement* "}"
Statement           ::= SignalDecl ";"
                      | ReturnStmt ";"
                      | VarStmt ";"
                      | DartStatement ";"

SignalDecl          ::= "signal" Type Identifier "=" Expression
ReturnStmt          ::= "return" "(" MarkupNode ")"
VarStmt             ::= "var" Identifier "=" "(" MarkupNode ")"

MarkupNode          ::= SelfClosingTag | ParentTag
SelfClosingTag      ::= "<" Identifier Attribute* "/>"
ParentTag           ::= OpenTag MarkupChild* CloseTag
OpenTag             ::= "<" Identifier Attribute* ">"
CloseTag            ::= "</" Identifier ">"

Attribute           ::= Identifier "=" AttributeValue
AttributeValue      ::= StringLiteral
                      | NumberLiteral
                      | BooleanLiteral
                      | "{" DartExpression "}"

MarkupChild         ::= MarkupNode
                      | "if" "(" DartExpression ")" "..." "[" MarkupChild* "]"
                      | "{" DartExpression "}"
                      | TextNode

```

---

## 3. Compiler Pipeline Architecture

The implementation leverages a decoupled, single-pass pipeline architecture consisting of eight modular nodes written entirely in pure Dart:

```sh
src/
  token.dart        # Core vocabulary definition & location tokens
  lexer.dart        # Stream-based tokenization of raw .dtrx source text
  ast.dart          # Typed, sealed representation of syntactic constructs
  parser.dart       # Top-down recursive descent grammar analyzer
  resolver.dart     # Context validation, semantic auditing, & tag typing
  virtual_tags.dart # Structural property evaluation & tag lowering
  css_parser.dart   # Translates inline styling strings to layout configurations
  codegen.dart      # Programmatic widget-tree output code construction

```

### Architectural Component Flow

```log
[Raw Source (.dtrx)] ──> Lexer ──> [Tokens] ──> Parser ──> [AST]
                                                              │
[Target Code (.dtrx.dart)] <── Code Generator <── Resolver ◄─┘

```

---

## 4. Lexical Analysis & Tokenization

The Lexer isolates raw text streams into discrete strongly typed tokens while continually tracking positional state (`line`, `col`) for fine-grained compiler warnings and diagnostic reporting.

### Lexical Scope Rules

1. **Balanced Braces:** Expressions enclosed within `{}` (used in attribute values or markup text injectors) transition the lexer into a balanced brace-tracking state, yielding a contiguous `dartCode` token string.
2. **Style Isolations:** Text attributes bounded by a `style="..."` declaration are emitted entirely as isolated single `stringLit` instances to protect downstream inline CSS interpretation from core structural tokenizing rules.
3. **Implicit Nodes:** Text fragments positioned implicitly between open and close markup markers are cleanly captured as standalone `textNode` blocks.

---

## 5. Semantic Validation & Resolution

Before targeting compiler compilation outputs, the semantic analyzer (`resolver.dart`) sweeps the generated AST node tree to assert operational correctness:

* **Signal Scope Auditing:** Asserts that every variable mutation usage targeted by reactive updates correctly maps to a verified `signal` declaration registered within the parent lexical component scope.
* **Tag Group Classification:** Identifies structural open-close configurations and maps element tags into three semantic runtime classifications:

1. `TagKind.virtual`: High-level abstract tags evaluated at build-time by the virtual tag resolution pipeline (`Button`, `Image`, `Input`, `ScrollView`).
2. `TagKind.nativePassthrough`: Upper-camel-case identifiers compiled raw to target framework native widget elements.
3. `TagKind.layoutPrimitive`: Lowercase web-style layout primitives restricted to `div` and `span` keywords.

---

## 6. The Virtual Tag Resolution Layer

To isolate complex logic from concrete layouts, DTRX utilizes a compile-time **Virtual Tag Layer**. This system evaluates node properties inline, translating them into specific target implementation variants:

### `<Button>` Structural Layout Resolution

The compiler processes `<Button>` references, targeting the following layout logic layout matrices:

| Input Attribute Presence | Target Mapping | Parameter Rewrite Strategy |
| --- | --- | --- |
| `icon` present, **no** `text` | `IconButton` | Maps `icon` directly to the named parameter `icon:`. |
| `text` present, **no** `icon` | `ElevatedButton` | Wraps raw string values into a standard text container: `child: Text(...)`. |
| Both `text` and `icon` present | `ElevatedButton.icon` | Maps discrete components to layout fields: `label: Text(...)` and `icon: ...`. |
| **Neither** attribute present | `ElevatedButton` | Generates a clean empty default block accompanied by a compile-time warning. |

### Comprehensive Core Virtual Mappings

```md
  ┌──────────────┐     icon only      ┌──────────────┐
  │              ├───────────────────►│  IconButton  │
  │              │                    └──────────────┘
  │              │     text only      ┌────────────────┐
  │   <Button>   ├───────────────────►│ ElevatedButton │
  │              │                    └────────────────┘
  │              │    text + icon     ┌─────────────────────┐
  │              ├───────────────────►│ ElevatedButton.icon │
  └──────────────┘                    └─────────────────────┘

```

* **`<Image>` Resolution:** Automatically resolves targets, compiling to `Image.asset(src)` for local file paths, or fallback routing to `Image.network(url)` for global web URL patterns.
* **`<Input>` Decoration Extractions:** Maps component structures straight to user input controls like `TextField`. If a `label="..."` flag is passed, attributes transform automatically into standard decoration maps (`decoration: InputDecoration(labelText: "...")`).
* **`<ScrollView>` Wrappers:** Simplifies screen scrolling by generating `SingleChildScrollView` containers, consolidating nested deep sub-children structures into single scroll regions.

---

## 7. Direct Code Generation & Reactivity Mapping

When emitting generated source streams (all output artifacts are generated with a targeted `<name>.dtrx.dart` extension), the Code Generator maps reactive lifecycles seamlessly:

### Reactivity Mechanics via Signals

If a DTRX component is written without state modifications via a `signal` block, it compiles down to an immutable, performance-friendly `StatelessWidget`. When one or more reactive states (`signal Type Name = Init;`) are discovered:

1. The generator converts the target blueprint wrapper into a managed `StatefulWidget` class lifecycle.
2. The compilation pipeline watches event fields (attributes beginning with the prefix `on`) to spot variable adjustments (`=`, `++`, `--`) referencing active signals.
3. Mutations are captured and embedded into proper framework update hooks:

```dart
// Input DTRX Source Callback
onPressed={() => count++}

// Generated Dart Output Pipeline
onPressed: () => setState(() { count++; }),

```

### CSS Layout Primitive Mapping

Inline configurations inside a layout `style="..."` block invoke a dedicated CSS interpreter (`css_parser.dart`) that formats specifications directly into concrete `Container` configurations:

* **Box Modifiers:** Layout attributes like `width: Npx` and `height: Npx` translate straight to explicit double-precision layout constants.
* **Colors:** Target definitions using hex strings (`#RRGGBB`) or functional definitions (`rgba(r,g,b,a)`) are transformed into explicit framework color builders (`Color(0xFFRRGGBB)` or `Color.fromRGBO(r,g,b,a)`).
* **Layout Structuring:** Elements grouped together within standard layout containers (`div`) are automatically composed into vertical workflows (`Column`), while inline-block elements (`span`) partition children horizontally (`Row`).

---

## 8. Compiler Diagnostics & CLI Specification

The compiler utility exposes a CLI execution model through `bin/dtrx.dart` to cleanly handle build chains:

```sh
# Compile a standalone source module into <file>.dtrx.dart
dtrx <file.dtrx>

# Watch directory paths for real-time compilation
dtrx watch <dir>

# Perform deep type inspections and syntax validation without disk emission
dtrx --check <file.dtrx>

```

### Error Reporting Format

System-wide pipeline errors or styling warnings format parameters clearly to `stderr`, outputting file pathways, exact line flags, and column positions:

```text
[dtrx error] path/to/file.dtrx:12:5 — Undefined signal 'count'
[dtrx warn]  path/to/file.dtrx:8:3  — Unsupported CSS property 'display'

```
