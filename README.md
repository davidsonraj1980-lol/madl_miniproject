# CompileLens — Interactive Compiler & Hardware Visualizer

[![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5.4-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Analysis](https://img.shields.io/badge/flutter%20analyze-0%20issues-brightgreen.svg)](#)
[![Tests](https://img.shields.io/badge/tests-9%20passed-brightgreen.svg)](#)

> **CompileLens** is an interactive educational mobile application engineered for Computer Science students and software engineers to visualize how high-level human source code transforms step-by-step into machine bytecode, CPU registers, and physical CMOS transistor switching circuits.

---

## 🌟 Key Features

### 1. Mobile-First Code Editor & Preset Toolbar
- **Collapsible Editor**: Collapses into a thin bar to grant 100% of the mobile screen height to interactive visualizers.
- **Quick-Insert Symbol Toolbar**: Fast mobile chip toolbar (`let`, `=`, `+`, `-`, `*`, `/`, `;`, `{`, `}`, `(`, `)`, `>`, `<`, `if`, `else`) with one-tap keyboard dismissal.
- **Interactive Presets**:
  - `⚡ Basic Arithmetic`: `let x = 10 + 5 * 2;`
  - `📦 Multi-Variable`: `let a = 4; let b = a * 3; let c = b - 2;`
  - `⚠️ Semantic Type Error Demo`: `let count = 10; let total = count + "hello";`
  - `🔀 If / Else Branching`: `let a = 12; let b = 5; if (a > b) { ... } else { ... }`
  - `🔬 ALU Hardware Addition`: `let r0 = 10; let r1 = 5; let sum = r0 + r1;`

### 2. 5-Stage Interactive Compilation Pipeline
- **Stage 1: Lexical Analysis (Tokenizer)**
  - Breaks source text into `Token` objects (`KEYWORD`, `IDENTIFIER`, `OPERATOR`, `NUMBER`, `STRING`, `PUNCTUATION`).
  - Interactive chips with line:column tracking. Tapping a token highlights its exact source span and explains the lexer's classification reasoning.
- **Stage 2: Syntax Analysis (Interactive AST Canvas)**
  - Recursive Descent Parser building an Abstract Syntax Tree.
  - Rendered with `CustomPainter` inside `InteractiveViewer` with smooth cubic Bézier glowing links.
  - Auto-fits to phone width on load.
  - Tapping any node displays grammar production rules (`Expr -> Term (+ | -) Term`) and explains operator precedence.
- **Stage 3: Semantic Validation & Symbol Table**
  - Undeclared variable checks.
  - Type compatibility validation.
  - **Constant Folding**: Pre-computes constant sub-expressions at compile time (e.g., `10 + 5 * 2` $\to$ `20`).
  - Detailed Symbol Table showing byte-aligned memory stack offsets (`[SP+0x00]`, `[SP+0x04]`).
- **Stage 4: Bytecode & Assembly Generation + Step-by-Step VM**
  - Dual instruction stream: Stack-based Bytecode and Register-based Assembly.
  - Mobile segmented view (`Split`, `Instructions`, `Operand Stack`).
  - Animated visual operand stack with Stack Pointer (`SP`) indicator and CPU register file ($R_0, R_1, R_2, ACC$).
- **Stage 5: Hardware Transistor & ALU Visualizer**
  - **ANSI Logic Gates Diagram**: Live vector circuit showing $XOR$, $AND$, $OR$ full adder logic ($S = A \oplus B \oplus C_{in}$, $C_{out} = (A \cdot B) + C_{in}(A \oplus B)$).
  - **CMOS Transistor Switches**: Interactive schematic with $V_{DD}$ (+5V), PMOS pull-up network, NMOS pull-down network, and $GND$ with conducting channel glow.
  - **8-Bit Ripple-Carry Datapath**: 8 parallel bit slices ($B_0 \dots B_7$) with propagating carry line.
  - **Live LED Bit Strips**: Users can tap any bit in $R_0$ or $R_1$ to watch the full-adder circuit, carry flags, and transistor switches recalculate instantly in real time!

---

## 🏗️ Architecture

```
CompileLens Architecture
│
├── lib/
│   ├── main.dart                       # App entry, Material 3 Dark theme, Tab orchestrator
│   ├── compiler/
│   │   ├── models.dart                 # Token, ASTNode, SymbolEntry, BytecodeInstruction, HardwareState
│   │   └── pipeline.dart               # Lexer, Parser, SemanticAnalyzer, BytecodeCompiler, VM Simulator
│   └── widgets/
│       ├── ast_painter.dart            # CustomPainter for Bézier AST with hit-testing & auto-fit
│       ├── transistor_alu_painter.dart # CustomPainter for Logic Gates, CMOS switches & Ripple Carry
│       └── hardware_view.dart          # 8-bit LED bit strips, Mode switches & Bit slice inspector
└── test/
    ├── compiler_test.dart              # Comprehensive test suite (Lexer, Parser, Semantics, VM, Adder)
    └── widget_test.dart                # Smoke test
```

---

## 🧪 Verification & Quality

- **`flutter analyze lib test`**: **0 issues found** (clean static analysis, full null-safety).
- **`flutter test`**: **9 of 9 unit and widget tests passing**.
- **`flutter build apk --debug`**: **Successfully built `app-debug.apk`**.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.2.0 <4.0.0`
- Dart SDK `>=3.5.0`

### Run on Mobile / Emulator
```bash
# Run on connected Android device or emulator
flutter run

# Build Android Debug APK
flutter build apk --debug
```

### Run on Web or Desktop
```bash
# Google Chrome
flutter run -d chrome

# Windows Desktop
flutter run -d windows
```

### Run Tests
```bash
flutter test
```
