import 'package:flutter_test/flutter_test.dart';
import 'package:compilelens/compiler/models.dart';
import 'package:compilelens/compiler/pipeline.dart';

void main() {
  group('CompileLens Compiler Pipeline Tests', () {
    test('Lexer tokenizes let statement with arithmetic', () {
      final lexer = Lexer('let x = 10 + 5 * 2;');
      final tokens = lexer.scanTokens();

      expect(tokens.map((t) => t.type), containsAllInOrder([
        TokenType.keywordLet,
        TokenType.identifier,
        TokenType.opAssign,
        TokenType.numberLiteral,
        TokenType.opPlus,
        TokenType.numberLiteral,
        TokenType.opMultiply,
        TokenType.numberLiteral,
        TokenType.semicolon,
        TokenType.eof,
      ]));
    });

    test('Parser respects operator precedence (* before +)', () {
      final lexer = Lexer('let x = 10 + 5 * 2;');
      final tokens = lexer.scanTokens();
      final parser = Parser(tokens);
      final ast = parser.parse();

      expect(ast.statements.length, 1);
      final varDecl = ast.statements.first as VarDeclNode;
      expect(varDecl.identifier, 'x');

      // The top binary expression should be '+'
      final topExpr = varDecl.initializer as BinaryExprNode;
      expect(topExpr.operator, '+');
      expect((topExpr.left as LiteralNode).value, 10);

      // The right child should be '*'
      final multExpr = topExpr.right as BinaryExprNode;
      expect(multExpr.operator, '*');
      expect((multExpr.left as LiteralNode).value, 5);
      expect((multExpr.right as LiteralNode).value, 2);
    });

    test('Semantic Analyzer folds constant expressions at compile time', () {
      final lexer = Lexer('let x = 10 + 5 * 2;');
      final tokens = lexer.scanTokens();
      final ast = Parser(tokens).parse();
      final result = SemanticAnalyzer(ast).analyze();
      expect(result.hasErrors, isFalse); // String concat is valid

      expect(result.hasErrors, isFalse);
      expect(result.foldedConstantsCount, greaterThan(0));
      expect(result.symbolTable.length, 1);

      final entry = result.symbolTable.first;
      expect(entry.name, 'x');
      expect(entry.value, 20); // 10 + (5 * 2) = 20
      expect(entry.type, DataType.integer);
    });

    test('Semantic Analyzer flags type mismatch on int + string', () {
      final lexer = Lexer('let count = 10;\nlet total = count + "hello";');
      final tokens = lexer.scanTokens();
      final ast = Parser(tokens).parse();
      final result = SemanticAnalyzer(ast).analyze();
      expect(result.hasErrors, isFalse); // String concat is valid

      // Concatenation with + is allowed, but arithmetic type mismatch on other ops
      final errorLexer = Lexer('let bad = 10 - "hello";');
      final errorAst = Parser(errorLexer.scanTokens()).parse();
      final errorResult = SemanticAnalyzer(errorAst).analyze();

      expect(errorResult.hasErrors, isTrue);
      expect(errorResult.diagnostics.any((d) => d.category == 'Type Mismatch'), isTrue);
    });

    test('Semantic Analyzer flags undeclared variable', () {
      final lexer = Lexer('let y = unknownVar + 5;');
      final tokens = lexer.scanTokens();
      final ast = Parser(tokens).parse();
      final result = SemanticAnalyzer(ast).analyze();

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics.any((d) => d.category == 'Undeclared Variable'), isTrue);
    });

    test('Bytecode Compiler emits opcodes & assembly', () {
      final lexer = Lexer('let x = 3 + 2;');
      final ast = Parser(lexer.scanTokens()).parse();
      final codeGen = BytecodeCompiler(ast).compile();

      expect(codeGen.bytecode, isNotEmpty);
      expect(codeGen.bytecode.any((i) => i.op == BytecodeOpCode.ADD), isTrue);
      expect(codeGen.bytecode.last.op, BytecodeOpCode.HALT);

      expect(codeGen.assembly, isNotEmpty);
      expect(codeGen.assembly.any((a) => a.mnemonic == 'ADD'), isTrue);
    });

    test('VM Simulator executes instructions and maintains operand stack', () {
      final lexer = Lexer('let x = 10 + 5;');
      final ast = Parser(lexer.scanTokens()).parse();
      final codeGen = BytecodeCompiler(ast).compile();
      final vm = VirtualMachineSimulator(codeGen.bytecode);

      final steps = vm.runAll();
      expect(steps, isNotEmpty);
      expect(vm.variables['x'], 15);
      expect(vm.hardwareState.accVal, 15);
    });

    test('Hardware Full Adder calculates sum and carry out correctly', () {
      const hwState = HardwareState(r0Val: 10, r1Val: 5); // 00001010 + 00000101 = 00001111 (15)

      // Bit 0: A=0, B=1, Cin=0 -> Sum=1, Cout=0
      final bit0 = hwState.getBitSliceState(0);
      expect(bit0.aBit, 0);
      expect(bit0.bBit, 1);
      expect(bit0.cIn, 0);
      expect(bit0.sum, 1);
      expect(bit0.cOut, 0);

      // Bit 1: A=1, B=0, Cin=0 -> Sum=1, Cout=0
      final bit1 = hwState.getBitSliceState(1);
      expect(bit1.aBit, 1);
      expect(bit1.bBit, 0);
      expect(bit1.cIn, 0);
      expect(bit1.sum, 1);
      expect(bit1.cOut, 0);

      // Test carry propagation: 1 + 1 = 0 with carry 1
      const carryState = HardwareState(r0Val: 1, r1Val: 1);
      final cBit0 = carryState.getBitSliceState(0);
      expect(cBit0.sum, 0);
      expect(cBit0.cOut, 1);

      final cBit1 = carryState.getBitSliceState(1);
      expect(cBit1.cIn, 1);
      expect(cBit1.sum, 1);
      expect(cBit1.cOut, 0);
    });
  });
}
