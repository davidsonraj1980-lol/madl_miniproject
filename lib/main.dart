// CompileLens — Interactive Compiler & Hardware Visualizer
// Production-Ready Flutter Application teaching CS students source-to-hardware compilation

import 'dart:async';
import 'package:flutter/material.dart';

import 'compiler/models.dart';
import 'compiler/pipeline.dart';
import 'widgets/ast_painter.dart';
import 'widgets/hardware_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CompileLensApp());
}

class CompileLensApp extends StatelessWidget {
  const CompileLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CompileLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFD500F9),
          tertiary: Color(0xFF00FF88),
          surface: Color(0xFF131C31),
          error: Color(0xFFFF3366),
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF131C31),
          elevation: 2,
        ),
      ),
      home: const CompileLensScreen(),
    );
  }
}

/// Preset Code Snippets for CS Students
class CodePreset {
  final String title;
  final String code;
  final String description;
  final IconData icon;

  const CodePreset({
    required this.title,
    required this.code,
    required this.description,
    required this.icon,
  });
}

final List<CodePreset> kCodePresets = [
  const CodePreset(
    title: 'Basic Arithmetic',
    code: 'let x = 10 + 5 * 2;',
    description: 'Demonstrates operator precedence (* before +) and constant folding.',
    icon: Icons.calculate_outlined,
  ),
  const CodePreset(
    title: 'Multi-Variable',
    code: 'let a = 4;\nlet b = a * 3;\nlet c = b - 2;',
    description: 'Shows multi-symbol allocation, memory offset layout, and register loading.',
    icon: Icons.layers_outlined,
  ),
  const CodePreset(
    title: 'Semantic Type Error',
    code: 'let count = 10;\nlet total = count + "hello";',
    description: 'Triggers semantic type-check failure between numeric int and string literal.',
    icon: Icons.error_outline,
  ),
  const CodePreset(
    title: 'If / Else Logic',
    code: 'let a = 12;\nlet b = 5;\nif (a > b) {\n  let max = a;\n} else {\n  let max = b;\n}',
    description: 'Illustrates relational branching, conditional jumps, and block scopes.',
    icon: Icons.alt_route_outlined,
  ),
  const CodePreset(
    title: 'ALU Hardware Demo',
    code: 'let r0 = 10;\nlet r1 = 5;\nlet sum = r0 + r1;',
    description: 'Connects directly to Stage 5 8-bit ripple-carry adder and CMOS transistor switches.',
    icon: Icons.memory_outlined,
  ),
];

class CompileLensScreen extends StatefulWidget {
  const CompileLensScreen({super.key});

  @override
  State<CompileLensScreen> createState() => _CompileLensScreenState();
}

class _CompileLensScreenState extends State<CompileLensScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  // Collapsible Code Editor State
  bool _isEditorExpanded = true;

  // Compilation Pipeline State
  List<Token> _tokens = [];
  ProgramNode? _astRoot;
  SemanticResult? _semanticResult;
  CodeGenResult? _codeGenResult;
  VirtualMachineSimulator? _vmSimulator;
  VMStepState? _currentVmStep;
  HardwareState _hardwareState = const HardwareState();

  // Active Selections for Educational Inspector Cards
  Token? _selectedToken;
  ASTNode? _selectedAstNode;
  String _tokenFilterCategory = 'ALL';
  int _stage4MobileMode = 0; // 0: Split, 1: Instructions, 2: Operand Stack

  // VM Auto-step Timer
  Timer? _autoStepTimer;
  bool _isAutoStepping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _codeController.text = kCodePresets.first.code;
    _runFullCompilation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _autoStepTimer?.cancel();
    super.dispose();
  }

  /// Triggers entire 5-stage compilation and hardware state sync
  void _runFullCompilation() {
    final source = _codeController.text;

    // 1. Lexical Analysis
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();

    // 2. Syntax Analysis (Recursive Descent Parser)
    final parser = Parser(tokens);
    final ast = parser.parse();

    // 3. Semantic Analysis & Constant Folding
    final semanticAnalyzer = SemanticAnalyzer(ast);
    final semanticResult = semanticAnalyzer.analyze();

    // 4. Bytecode & Assembly Code Generation
    final compiler = BytecodeCompiler(ast);
    final codeGenResult = compiler.compile();

    // 5. Virtual Machine Simulator Setup
    final vm = VirtualMachineSimulator(codeGenResult.bytecode);
    final initialStep = vm.step(); // Execute first instruction

    void updateState() {
      _tokens = tokens;
      _astRoot = ast;
      _semanticResult = semanticResult;
      _codeGenResult = codeGenResult;
      _vmSimulator = vm;
      _currentVmStep = initialStep;
      _selectedToken = tokens.isNotEmpty ? tokens.first : null;
      _selectedAstNode = ast.statements.isNotEmpty ? ast.statements.first : ast;
      _hardwareState = vm.hardwareState;
    }

    if (mounted) {
      setState(updateState);
    } else {
      updateState();
    }
  }

  void _loadPreset(CodePreset preset) {
    _autoStepTimer?.cancel();
    _isAutoStepping = false;
    _codeController.text = preset.code;
    _runFullCompilation();
  }

  void _insertSymbol(String symbol) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, symbol)
        : '$text$symbol';
    final newOffset = selection.isValid ? selection.start + symbol.length : newText.length;

    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _codeFocusNode.requestFocus();
  }

  // --- VM Step Playback Actions ---

  void _stepVmNext() {
    if (_vmSimulator == null) return;
    if (_vmSimulator!.isHalted) {
      _vmSimulator!.reset();
    }
    final nextState = _vmSimulator!.step();
    setState(() {
      _currentVmStep = nextState;
      if (nextState != null) {
        _hardwareState = _vmSimulator!.hardwareState;
      }
    });
  }

  void _resetVm() {
    _autoStepTimer?.cancel();
    _isAutoStepping = false;
    _vmSimulator?.reset();
    final first = _vmSimulator?.step();
    setState(() {
      _currentVmStep = first;
      if (_vmSimulator != null) {
        _hardwareState = _vmSimulator!.hardwareState;
      }
    });
  }

  void _toggleAutoStep() {
    if (_isAutoStepping) {
      _autoStepTimer?.cancel();
      setState(() => _isAutoStepping = false);
    } else {
      setState(() => _isAutoStepping = true);
      _autoStepTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (_vmSimulator != null && _vmSimulator!.isHalted) {
          _vmSimulator!.reset();
        }
        _stepVmNext();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Collapsible Code Editor Drawer / Card
            _buildCodeEditorCard(),

            // 5-Stage Stepper / Pipeline Tab Bar
            _buildPipelineTabBar(),

            // 5-Stage Pipeline Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStage1LexerView(),
                  _buildStage2AstView(),
                  _buildStage3SemanticsView(),
                  _buildStage4BytecodeVmView(),
                  _buildStage5HardwareView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF090D16),
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
            ),
            child: const Icon(Icons.hub_outlined, color: Color(0xFF00E5FF), size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CompileLens',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              Text(
                'Source-to-Hardware Interactive Visualizer',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Compiler Architecture Info',
          icon: const Icon(Icons.help_outline, color: Color(0xFF94A3B8), size: 20),
          onPressed: _showCompilerInfoDialog,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildCodeEditorCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Editor Header & Preset Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF0D1424),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _isEditorExpanded = !_isEditorExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Icon(
                        _isEditorExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF00E5FF),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditorExpanded ? 'EDITOR' : 'EXPAND EDITOR',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Horizontal Presets list
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: kCodePresets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Icon(preset.icon, size: 13, color: const Color(0xFF94A3B8)),
                            label: Text(
                              preset.title,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                            backgroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFF334155), width: 0.8),
                            ),
                            onPressed: () => _loadPreset(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Editor Body
          if (_isEditorExpanded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              height: 100,
              color: const Color(0xFF090D16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  _buildLineNumbers(),
                  const VerticalDivider(width: 16, color: Color(0xFF1E293B), thickness: 1),
                  // Monospace Input Field
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        color: Color(0xFFE2E8F0),
                        height: 1.35,
                      ),
                      cursorColor: const Color(0xFF00E5FF),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '// Write toy language code...',
                        hintStyle: TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick-Insert Mobile Symbol Toolbar
            _buildQuickInsertToolbar(),

            // Action Buttons Bar: "Compile & Visualize" + Step Controls
            _buildPlaybackActionBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildLineNumbers() {
    final text = _codeController.text;
    final lines = text.split('\n').length;
    final lineNums = List.generate(lines, (i) => '${i + 1}').join('\n');

    return Container(
      width: 22,
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        lineNums,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFF475569),
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildQuickInsertToolbar() {
    final symbols = ['let', '=', '+', '-', '*', '/', ';', '{', '}', '(', ')', '>', '<', 'if', 'else'];

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF0D1424),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...symbols.map((sym) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => _insertSymbol(sym == 'let' || sym == 'if' || sym == 'else' ? '$sym ' : sym),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: Text(
                      sym,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: () => FocusScope.of(context).unfocus(),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF475569), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_hide, size: 13, color: Color(0xFF94A3B8)),
                      SizedBox(width: 4),
                      Text('Hide Keyboard', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF131C31),
      child: Row(
        children: [
          // "Compile & Visualize" Primary Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 4,
            ),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text(
              'Compile & Visualize',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _runFullCompilation();
            },
          ),
          const Spacer(),
          // Step Back
          IconButton(
            tooltip: 'Reset VM',
            icon: const Icon(Icons.replay, size: 18, color: Color(0xFF94A3B8)),
            onPressed: _resetVm,
          ),
          // Step Next
          IconButton(
            tooltip: 'Step Instruction',
            icon: const Icon(Icons.skip_next, size: 20, color: Color(0xFF00FF88)),
            onPressed: _stepVmNext,
          ),
          // Play / Pause auto step
          IconButton(
            tooltip: _isAutoStepping ? 'Pause Auto-Step' : 'Auto-Step VM',
            icon: Icon(
              _isAutoStepping ? Icons.pause_circle : Icons.play_circle_outline,
              size: 20,
              color: _isAutoStepping ? const Color(0xFFFFB300) : const Color(0xFF00E5FF),
            ),
            onPressed: _toggleAutoStep,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTabBar() {
    return Container(
      color: const Color(0xFF0A0F1D),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFF00E5FF),
        indicatorWeight: 3,
        labelColor: const Color(0xFF00E5FF),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: '1. Lexer (Tokens)'),
          Tab(text: '2. Parser (AST)'),
          Tab(text: '3. Semantics & Scope'),
          Tab(text: '4. Bytecode & VM'),
          Tab(text: '5. Hardware ALU'),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAGE 1: LEXICAL ANALYSIS (TOKENIZER) VIEW
  // ==========================================================================
  Widget _buildStage1LexerView() {
    final categories = ['ALL', 'KEYWORD', 'IDENTIFIER', 'NUMBER', 'STRING', 'OPERATOR', 'PUNCTUATION'];

    final filteredTokens = _tokens.where((t) {
      if (_tokenFilterCategory == 'ALL') return true;
      return t.typeName == _tokenFilterCategory;
    }).toList();

    return Column(
      children: [
        // Category Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F172A),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _tokenFilterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(cat, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white70)),
                    selectedColor: const Color(0xFF00E5FF),
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onSelected: (val) {
                      setState(() => _tokenFilterCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Tokens Grid / Wrap
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredTokens.map((token) {
                  final isSelected = _selectedToken == token;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedToken = token);
                      // Highlight span in text editor
                      _codeController.selection = TextSelection(
                        baseOffset: token.startIndex,
                        extentOffset: token.endIndex,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? token.categoryColor.withOpacity(0.2) : const Color(0xFF131C31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : token.categoryColor.withOpacity(0.8),
                          width: isSelected ? 2.0 : 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: token.categoryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                token.typeName,
                                style: TextStyle(
                                  color: token.categoryColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            token.lexeme,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'L${token.line}:C${token.column}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Token Inspector Bottom Card
        if (_selectedToken != null) _buildTokenInspectorCard(_selectedToken!),
      ],
    );
  }

  Widget _buildTokenInspectorCard(Token token) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: token.categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: token.categoryColor, width: 1),
                ),
                child: Text(
                  token.typeName,
                  style: TextStyle(
                    color: token.categoryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '"${token.lexeme}"',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'Line ${token.line}, Col ${token.column}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _selectedToken = null),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            token.explanation,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAGE 2: SYNTAX ANALYSIS (INTERACTIVE AST CANVAS)
  // ==========================================================================
  Widget _buildStage2AstView() {
    if (_astRoot == null) {
      return const Center(child: Text('No AST available'));
    }

    return Column(
      children: [
        // Pan & Pinch Canvas
        Expanded(
          child: InteractiveASTCanvas(
            rootNode: _astRoot!,
            selectedNode: _selectedAstNode,
            onNodeSelected: (node) {
              setState(() => _selectedAstNode = node);
            },
          ),
        ),

        // Bottom AST Explanation Card
        if (_selectedAstNode != null) _buildAstNodeDetailsCard(_selectedAstNode!),
      ],
    );
  }

  Widget _buildAstNodeDetailsCard(ASTNode node) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: node.themeColor, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: node.themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.nodeType.toUpperCase(),
                  style: TextStyle(
                    color: node.themeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                node.label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (node.isConstantFoldable) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFB300), width: 0.8),
                  ),
                  child: Text(
                    'Folded: ${node.evaluatedConstantValue}',
                    style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: () => setState(() => _selectedAstNode = null),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Grammar Rule Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Grammar Rule: ${node.grammarRule}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            node.explanation,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAGE 3: SEMANTIC VALIDATION & SYMBOL TABLE
  // ==========================================================================
  Widget _buildStage3SemanticsView() {
    final result = _semanticResult;
    if (result == null) {
      return const Center(child: Text('Run compilation to see semantic validation'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Validation Status Banner
          _buildSemanticStatusCard(result),
          const SizedBox(height: 14),

          // Diagnostic Checklist (Undeclared Vars, Type Compatibility, Constant Folding)
          const Text(
            'SEMANTIC PASS CHECKLIST',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildChecklistCards(result),
          const SizedBox(height: 16),

          // Symbol Table
          const Text(
            'RESOLVED SYMBOL TABLE (MEMORY ALLOCATION)',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildSymbolTable(result.symbolTable),
        ],
      ),
    );
  }

  Widget _buildSemanticStatusCard(SemanticResult result) {
    final isSuccess = !result.hasErrors;
    final color = isSuccess ? const Color(0xFF00FF88) : const Color(0xFFFF3366);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuccess ? 'Semantic Checks Passed' : 'Semantic Diagnostics Flagged',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  isSuccess
                      ? 'All variables declared, types verified compatible, and constants folded.'
                      : 'Errors detected before intermediate representation emission.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCards(SemanticResult result) {
    // 1. Undeclared Check
    final undeclaredErrors = result.diagnostics.where((d) => d.category == 'Undeclared Variable').toList();
    final hasUndeclared = undeclaredErrors.isNotEmpty;

    // 2. Type Mismatch Check
    final typeErrors = result.diagnostics.where((d) => d.category == 'Type Mismatch').toList();
    final hasTypeMismatch = typeErrors.isNotEmpty;

    // 3. Constant Folding Preview
    final foldingItems = result.diagnostics.where((d) => d.category == 'Constant Folding').toList();

    return Column(
      children: [
        _buildChecklistItem(
          title: 'Undeclared Variable Scope Check',
          passed: !hasUndeclared,
          description: hasUndeclared
              ? undeclaredErrors.first.message
              : 'All referenced identifiers exist in scope symbol table before usage.',
          remedy: hasUndeclared ? undeclaredErrors.first.remedy : null,
        ),
        const SizedBox(height: 8),
        _buildChecklistItem(
          title: 'Operand Type Compatibility Check',
          passed: !hasTypeMismatch,
          description: hasTypeMismatch
              ? typeErrors.first.message
              : 'Arithmetic operations evaluated between compatible numeric/string types.',
          remedy: hasTypeMismatch ? typeErrors.first.remedy : null,
        ),
        const SizedBox(height: 8),
        _buildChecklistItem(
          title: 'Constant Folding Optimization Preview',
          passed: true,
          isOptimization: true,
          description: foldingItems.isNotEmpty
              ? '${foldingItems.length} constant sub-expressions pre-computed at compile-time.'
              : 'No constant sub-expressions eligible for fold optimization.',
        ),
      ],
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required bool passed,
    required String description,
    String? remedy,
    bool isOptimization = false,
  }) {
    Color color;
    IconData icon;
    if (isOptimization) {
      color = const Color(0xFFFFB300);
      icon = Icons.bolt;
    } else if (passed) {
      color = const Color(0xFF00FF88);
      icon = Icons.check;
    } else {
      color = const Color(0xFFFF3366);
      icon = Icons.close;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131C31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (remedy != null) ...[
            const SizedBox(height: 4),
            Text(
              '💡 Remedy: $remedy',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymbolTable(List<SymbolEntry> symbols) {
    if (symbols.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131C31),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No variables declared in symbol table.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131C31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(0.8),
          3: FlexColumnWidth(1.1),
          4: FlexColumnWidth(1.0),
        },
        children: [
          // Header Row
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            children: ['Identifier', 'Type', 'Scope', 'Offset', 'Value'].map((h) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  h,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          // Data Rows
          ...symbols.map((sym) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    sym.name,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    sym.type.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: sym.type.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${sym.scopeLevel}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '[SP+${sym.memoryAddressHex}]',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    sym.value != null ? '${sym.value}' : '?',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF00FF88)),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAGE 4: BYTECODE & ASSEMBLY GENERATION + STEP VM
  // ==========================================================================
  Widget _buildStage4BytecodeVmView() {
    final codeGen = _codeGenResult;
    if (codeGen == null) {
      return const Center(child: Text('Compile source code to generate instructions.'));
    }

    return Column(
      children: [
        // VM Microarchitectural State (Registers & Stack Pointer)
        _buildVmRegistersBanner(),

        // Mobile View Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          color: const Color(0xFF0D1424),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStage4ModeChip('Split View', 0, Icons.view_column_outlined),
              const SizedBox(width: 6),
              _buildStage4ModeChip('Instructions', 1, Icons.code_outlined),
              const SizedBox(width: 6),
              _buildStage4ModeChip('Operand Stack', 2, Icons.layers_outlined),
            ],
          ),
        ),

        // Instructions List + Visual Stack (Responsive to Mobile Mode)
        Expanded(
          child: _stage4MobileMode == 1
              ? _buildInstructionsList(codeGen)
              : (_stage4MobileMode == 2
                  ? _buildOperandStackPanel()
                  : Row(
                      children: [
                        // Dual Instructions List (Bytecode + Assembly)
                        Expanded(
                          flex: 6,
                          child: _buildInstructionsList(codeGen),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
                        // Animated Operand Stack & Evaluation History
                        Expanded(
                          flex: 4,
                          child: _buildOperandStackPanel(),
                        ),
                      ],
                    )),
        ),

        // Step explanation card
        if (_currentVmStep != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0D1424),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentVmStep!.stepExplanation,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStage4ModeChip(String label, int mode, IconData icon) {
    final isSelected = _stage4MobileMode == mode;
    return InkWell(
      onTap: () => setState(() => _stage4MobileMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVmRegistersBanner() {
    final step = _currentVmStep;
    final pc = step?.pc ?? 0;
    final r0 = step?.registers['R0'] ?? 0;
    final r1 = step?.registers['R1'] ?? 0;
    final acc = step?.registers['ACC'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRegChip('PC', '$pc', const Color(0xFF00E5FF)),
          _buildRegChip('R0', '$r0', const Color(0xFF00FF88)),
          _buildRegChip('R1', '$r1', const Color(0xFFE040FB)),
          _buildRegChip('ACC', '$acc', const Color(0xFFFFB300)),
          _buildRegChip('SP', '${step?.stack.length ?? 0}', const Color(0xFF38BDF8)),
        ],
      ),
    );
  }

  Widget _buildRegChip(String name, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$name: ', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInstructionsList(CodeGenResult codeGen) {
    final activePc = _currentVmStep?.currentInstruction.address ?? -1;

    return ListView.builder(
      itemCount: codeGen.bytecode.length,
      itemBuilder: (context, index) {
        final byteInst = codeGen.bytecode[index];
        final asmInst = index < codeGen.assembly.length ? codeGen.assembly[index] : null;
        final isActive = byteInst.address == activePc;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00E5FF).withOpacity(0.18) : const Color(0xFF131C31),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
              width: isActive ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      byteInst.address.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Stack Bytecode
                  Expanded(
                    child: Text(
                      byteInst.formattedOp,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: isActive ? Colors.white : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  // Register Assembly
                  if (asmInst != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${asmInst.mnemonic} ${asmInst.operands.join(", ")}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: Color(0xFFFFB300),
                        ),
                      ),
                    ),
                ],
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    byteInst.description,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperandStackPanel() {
    final stack = _currentVmStep?.stack ?? [];

    return Container(
      color: const Color(0xFF0B1120),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Text(
            'OPERAND STACK',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stack.isEmpty
                ? const Center(
                    child: Text(
                      '[ Empty Stack ]\nSP = 0',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontFamily: 'monospace'),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // Top of stack at the top
                    itemCount: stack.length,
                    itemBuilder: (context, index) {
                      final val = stack[stack.length - 1 - index];
                      final isTop = index == 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isTop ? const Color(0xFF00FF88).withOpacity(0.2) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isTop ? const Color(0xFF00FF88) : const Color(0xFF334155),
                            width: isTop ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isTop ? 'TOP [SP]' : 'SLOT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isTop ? const Color(0xFF00FF88) : const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              '$val',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAGE 5: HARDWARE TRANSISTOR & ALU VISUALIZER VIEW
  // ==========================================================================
  Widget _buildStage5HardwareView() {
    return HardwareView(
      hardwareState: _hardwareState,
      onHardwareStateChanged: (newState) {
        setState(() => _hardwareState = newState);
      },
    );
  }

  void _showCompilerInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131C31),
          title: const Row(
            children: [
              Icon(Icons.hub_outlined, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Text('CompileLens Architecture', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CompileLens is a full-pipeline teaching compiler that transforms human-written code down to physical transistor switches:',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                SizedBox(height: 10),
                Text('• Stage 1: Lexer breaks text into typed tokens.', style: TextStyle(fontSize: 11.5, color: Color(0xFF00E5FF))),
                Text('• Stage 2: Recursive Descent Parser builds the AST.', style: TextStyle(fontSize: 11.5, color: Color(0xFFE040FB))),
                Text('• Stage 3: Semantic Analyzer verifies scope, types & folds constants.', style: TextStyle(fontSize: 11.5, color: Color(0xFF00FF88))),
                Text('• Stage 4: Code Gen emits Stack Bytecode & Register Assembly for the VM.', style: TextStyle(fontSize: 11.5, color: Color(0xFFFFB300))),
                Text('• Stage 5: Hardware ALU simulates full adders, ripple-carry lines, and CMOS switches.', style: TextStyle(fontSize: 11.5, color: Color(0xFFFF5252))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ],
        );
      },
    );
  }
}
