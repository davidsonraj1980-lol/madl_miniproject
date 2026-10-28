// CompileLens — Interactive Compiler & Hardware Visualizer
// Pure Dart Compiler Pipeline: Lexer -> Parser -> Semantic Analyzer -> Bytecode/Assembly Emitter -> VM Simulator

import 'models.dart';

// ============================================================================
// STAGE 1: LEXICAL ANALYZER (TOKENIZER)
// ============================================================================

class Lexer {
  final String source;
  final List<Token> tokens = [];
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;

  Lexer(this.source);

  List<Token> scanTokens() {
    tokens.clear();
    _start = 0;
    _current = 0;
    _line = 1;
    _column = 1;

    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }

    tokens.add(Token(
      type: TokenType.eof,
      lexeme: '<EOF>',
      literal: null,
      line: _line,
      column: _column,
      startIndex: _current,
      endIndex: _current,
      explanation: 'End of file indicator signifying input stream completion.',
    ));

    return tokens;
  }

  bool _isAtEnd() => _current >= source.length;

  void _scanToken() {
    final c = _advance();
    switch (c) {
      case ' ':
      case '\r':
      case '\t':
        // Whitespace ignored
        break;
      case '\n':
        _line++;
        _column = 1;
        break;
      case '(':
        _addToken(TokenType.openParen, 'Groups sub-expressions to override normal operator precedence.');
        break;
      case ')':
        _addToken(TokenType.closeParen, 'Closes grouped expression or parameter list.');
        break;
      case '{':
        _addToken(TokenType.openBrace, 'Opens a new lexical code block and scope frame.');
        break;
      case '}':
        _addToken(TokenType.closeBrace, 'Closes the current lexical code block and unwinds local scope.');
        break;
      case ',':
        _addToken(TokenType.comma, 'Separates argument elements or list values.');
        break;
      case ';':
        _addToken(TokenType.semicolon, 'Explicit statement terminator telling the parser a statement has ended.');
        break;
      case '+':
        _addToken(TokenType.opPlus, 'Arithmetic addition operator or string concatenation.');
        break;
      case '-':
        _addToken(TokenType.opMinus, 'Arithmetic subtraction or unary negation.');
        break;
      case '*':
        _addToken(TokenType.opMultiply, 'Arithmetic multiplication operator (higher precedence than + and -).');
        break;
      case '/':
        if (_peek() == '/') {
          // Single-line comment //
          while (_peek() != '\n' && !_isAtEnd()) {
            _advance();
          }
        } else {
          _addToken(TokenType.opDivide, 'Arithmetic division operator (higher precedence than + and -).');
        }
        break;
      case '#':
        // Python style single-line comment
        while (_peek() != '\n' && !_isAtEnd()) {
          _advance();
        }
        break;
      case '=':
        if (_match('=')) {
          _addToken(TokenType.opEqual, 'Relational equality comparison operator (yields boolean true/false).');
        } else {
          _addToken(TokenType.opAssign, 'Assignment operator binding computed expression value to an identifier.');
        }
        break;
      case '!':
        if (_match('=')) {
          _addToken(TokenType.opNotEqual, 'Relational inequality comparison operator (yields true if operands differ).');
        } else {
          _addToken(TokenType.opNot, 'Logical NOT inversion operator.');
        }
        break;
      case '<':
        if (_match('=')) {
          _addToken(TokenType.opLessEqual, 'Less-than-or-equal comparison operator.');
        } else {
          _addToken(TokenType.opLessThan, 'Strict less-than comparison operator.');
        }
        break;
      case '>':
        if (_match('=')) {
          _addToken(TokenType.opGreaterEqual, 'Greater-than-or-equal comparison operator.');
        } else {
          _addToken(TokenType.opGreaterThan, 'Strict greater-than comparison operator.');
        }
        break;
      case '&':
        if (_match('&')) {
          _addToken(TokenType.opAnd, 'Logical AND operator with short-circuit evaluation semantics.');
        }
        break;
      case '|':
        if (_match('|')) {
          _addToken(TokenType.opOr, 'Logical OR operator.');
        }
        break;
      case '"':
      case "'":
        _string(c);
        break;
      default:
        if (_isDigit(c)) {
          _number();
        } else if (_isAlpha(c)) {
          _identifier();
        } else {
          _addToken(TokenType.unknown, 'Unrecognized character outside language grammar.');
        }
        break;
    }
  }

  void _identifier() {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }

    final text = source.substring(_start, _current);
    TokenType type;
    String explanation;

    switch (text) {
      case 'let':
      case 'var':
        type = TokenType.keywordLet;
        explanation = 'Reserved keyword introducing a new variable declaration in the current scope.';
        break;
      case 'if':
        type = TokenType.keywordIf;
        explanation = 'Control-flow keyword that evaluates a condition to direct conditional branching.';
        break;
      case 'else':
        type = TokenType.keywordElse;
        explanation = 'Control-flow keyword specifying fallback execution path when condition fails.';
        break;
      case 'true':
        type = TokenType.keywordTrue;
        explanation = 'Boolean literal representing logical truth (1).';
        break;
      case 'false':
        type = TokenType.keywordFalse;
        explanation = 'Boolean literal representing logical false (0).';
        break;
      default:
        type = TokenType.identifier;
        explanation = 'User-defined identifier referencing variable or storage memory slot "$text".';
        break;
    }

    dynamic literal;
    if (type == TokenType.keywordTrue) literal = true;
    if (type == TokenType.keywordFalse) literal = false;

    _addToken(type, explanation, literal: literal);
  }

  void _number() {
    bool isFloat = false;
    while (_isDigit(_peek())) {
      _advance();
    }

    if (_peek() == '.' && _isDigit(_peekNext())) {
      isFloat = true;
      _advance(); // Consume '.'
      while (_isDigit(_peek())) {
        _advance();
      }
    }

    final text = source.substring(_start, _current);
    final value = isFloat ? double.parse(text) : int.parse(text);
    final explanation = isFloat
        ? 'Floating-point numeric constant literal ($value).'
        : 'Integer constant literal ($value), represented as 2s-complement binary on hardware.';

    _addToken(TokenType.numberLiteral, explanation, literal: value);
  }

  void _string(String quoteChar) {
    while (_peek() != quoteChar && !_isAtEnd()) {
      if (_peek() == '\n') _line++;
      _advance();
    }

    if (_isAtEnd()) {
      _addToken(TokenType.unknown, 'Unterminated string literal missing closing quote.');
      return;
    }

    _advance(); // Closing quote
    final value = source.substring(_start + 1, _current - 1);
    _addToken(
      TokenType.stringLiteral,
      'String constant literal enclosed in quotes ($value).',
      literal: value,
    );
  }

  String _advance() {
    _column++;
    return source[_current++];
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (source[_current] != expected) return false;
    _current++;
    _column++;
    return true;
  }

  String _peek() {
    if (_isAtEnd()) return '\x00';
    return source[_current];
  }

  String _peekNext() {
    if (_current + 1 >= source.length) return '\x00';
    return source[_current + 1];
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == '_';
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);

  void _addToken(TokenType type, String explanation, {dynamic literal}) {
    final lexeme = source.substring(_start, _current);
    tokens.add(Token(
      type: type,
      lexeme: lexeme,
      literal: literal,
      line: _line,
      column: _column - lexeme.length,
      startIndex: _start,
      endIndex: _current,
      explanation: explanation,
    ));
  }
}


// ============================================================================
// STAGE 2: RECURSIVE DESCENT SYNTAX ANALYZER (PARSER)
// ============================================================================

class Parser {
  final List<Token> tokens;
  int _current = 0;
  int _nodeIdCounter = 0;
  final List<String> parseErrors = [];

  Parser(this.tokens);

  String _nextId() => 'ast_node_${_nodeIdCounter++}';

  ProgramNode parse() {
    _current = 0;
    _nodeIdCounter = 0;
    parseErrors.clear();

    final statements = <ASTNode>[];

    while (!_isAtEnd()) {
      // Skip stray semicolons
      if (_match([TokenType.semicolon])) continue;

      try {
        final stmt = _declaration();
        if (stmt != null) {
          statements.add(stmt);
        }
      } catch (e) {
        parseErrors.add(e.toString());
        _synchronize();
      }
    }

    return ProgramNode(
      id: _nextId(),
      line: 1,
      column: 1,
      statements: statements,
    );
  }

  ASTNode? _declaration() {
    if (_match([TokenType.keywordLet])) {
      return _varDeclaration();
    }
    return _statement();
  }

  ASTNode _varDeclaration() {
    final letToken = _previous();
    final nameToken = _consume(TokenType.identifier, 'Expected variable name after "let".');

    ASTNode? initializer;
    if (_match([TokenType.opAssign])) {
      initializer = _expression();
    }

    // Optional semicolon for mobile friendliness
    _match([TokenType.semicolon]);

    return VarDeclNode(
      id: _nextId(),
      line: letToken.line,
      column: letToken.column,
      identifier: nameToken.lexeme,
      initializer: initializer,
    );
  }

  ASTNode _statement() {
    if (_match([TokenType.keywordIf])) {
      return _ifStatement();
    }
    if (_match([TokenType.openBrace])) {
      return _block();
    }
    return _assignmentOrExpressionStatement();
  }

  ASTNode _ifStatement() {
    final ifToken = _previous();
    _consume(TokenType.openParen, 'Expected "(" after "if".');
    final condition = _expression();
    _consume(TokenType.closeParen, 'Expected ")" after if condition.');

    final thenBranch = _statement();
    ASTNode? elseBranch;
    if (_match([TokenType.keywordElse])) {
      elseBranch = _statement();
    }

    return IfNode(
      id: _nextId(),
      line: ifToken.line,
      column: ifToken.column,
      condition: condition,
      thenBranch: thenBranch,
      elseBranch: elseBranch,
    );
  }

  ASTNode _block() {
    final braceToken = _previous();
    final statements = <ASTNode>[];

    while (!_check(TokenType.closeBrace) && !_isAtEnd()) {
      if (_match([TokenType.semicolon])) continue;
      final stmt = _declaration();
      if (stmt != null) {
        statements.add(stmt);
      }
    }

    _consume(TokenType.closeBrace, 'Expected "}" after block.');
    return BlockNode(
      id: _nextId(),
      line: braceToken.line,
      column: braceToken.column,
      statements: statements,
    );
  }

  ASTNode _assignmentOrExpressionStatement() {
    // Check for assignment: identifier = expr
    if (_check(TokenType.identifier) && _checkNext(TokenType.opAssign)) {
      final nameToken = _advance();
      _advance(); // consume '='
      final value = _expression();
      _match([TokenType.semicolon]);
      return AssignmentNode(
        id: _nextId(),
        line: nameToken.line,
        column: nameToken.column,
        identifier: nameToken.lexeme,
        value: value,
      );
    }

    final expr = _expression();
    _match([TokenType.semicolon]);
    return expr;
  }

  ASTNode _expression() => _equality();

  ASTNode _equality() {
    var expr = _comparison();

    while (_match([TokenType.opEqual, TokenType.opNotEqual])) {
      final operatorToken = _previous();
      final right = _comparison();
      expr = BinaryExprNode(
        id: _nextId(),
        line: operatorToken.line,
        column: operatorToken.column,
        left: expr,
        operator: operatorToken.lexeme,
        right: right,
      );
    }

    return expr;
  }

  ASTNode _comparison() {
    var expr = _term();

    while (_match([
      TokenType.opGreaterThan,
      TokenType.opGreaterEqual,
      TokenType.opLessThan,
      TokenType.opLessEqual,
    ])) {
      final operatorToken = _previous();
      final right = _term();
      expr = BinaryExprNode(
        id: _nextId(),
        line: operatorToken.line,
        column: operatorToken.column,
        left: expr,
        operator: operatorToken.lexeme,
        right: right,
      );
    }

    return expr;
  }

  ASTNode _term() {
    var expr = _factor();

    while (_match([TokenType.opPlus, TokenType.opMinus])) {
      final operatorToken = _previous();
      final right = _factor();
      expr = BinaryExprNode(
        id: _nextId(),
        line: operatorToken.line,
        column: operatorToken.column,
        left: expr,
        operator: operatorToken.lexeme,
        right: right,
      );
    }

    return expr;
  }

  ASTNode _factor() {
    var expr = _unary();

    while (_match([TokenType.opMultiply, TokenType.opDivide])) {
      final operatorToken = _previous();
      final right = _unary();
      expr = BinaryExprNode(
        id: _nextId(),
        line: operatorToken.line,
        column: operatorToken.column,
        left: expr,
        operator: operatorToken.lexeme,
        right: right,
      );
    }

    return expr;
  }

  ASTNode _unary() {
    if (_match([TokenType.opMinus, TokenType.opNot])) {
      final operatorToken = _previous();
      final right = _unary();
      return UnaryExprNode(
        id: _nextId(),
        line: operatorToken.line,
        column: operatorToken.column,
        operator: operatorToken.lexeme,
        operand: right,
      );
    }

    return _primary();
  }

  ASTNode _primary() {
    if (_match([TokenType.keywordTrue])) {
      return LiteralNode(
        id: _nextId(),
        line: _previous().line,
        column: _previous().column,
        value: true,
        type: DataType.boolean,
      );
    }

    if (_match([TokenType.keywordFalse])) {
      return LiteralNode(
        id: _nextId(),
        line: _previous().line,
        column: _previous().column,
        value: false,
        type: DataType.boolean,
      );
    }

    if (_match([TokenType.numberLiteral])) {
      final token = _previous();
      final isFloat = token.literal is double;
      return LiteralNode(
        id: _nextId(),
        line: token.line,
        column: token.column,
        value: token.literal,
        type: isFloat ? DataType.float : DataType.integer,
      );
    }

    if (_match([TokenType.stringLiteral])) {
      final token = _previous();
      return LiteralNode(
        id: _nextId(),
        line: token.line,
        column: token.column,
        value: token.literal,
        type: DataType.string,
      );
    }

    if (_match([TokenType.identifier])) {
      final token = _previous();
      return IdentifierNode(
        id: _nextId(),
        line: token.line,
        column: token.column,
        name: token.lexeme,
      );
    }

    if (_match([TokenType.openParen])) {
      final expr = _expression();
      _consume(TokenType.closeParen, 'Expected ")" after expression.');
      return expr;
    }

    final badToken = _peek();
    final errMsg = 'Unexpected token "${badToken.lexeme}" at line ${badToken.line}, col ${badToken.column}.';
    _advance();
    return ErrorNode(
      id: _nextId(),
      line: badToken.line,
      column: badToken.column,
      errorMessage: errMsg,
    );
  }

  bool _match(List<TokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  bool _checkNext(TokenType type) {
    if (_current + 1 >= tokens.length) return false;
    return tokens[_current + 1].type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _peek().type == TokenType.eof;

  Token _peek() => tokens[_current];

  Token _previous() => tokens[_current - 1];

  Token _consume(TokenType type, String message) {
    if (_check(type)) return _advance();
    final current = _peek();
    throw FormatException('$message (found "${current.lexeme}" at line ${current.line}:${current.column})');
  }

  void _synchronize() {
    _advance();
    while (!_isAtEnd()) {
      if (_previous().type == TokenType.semicolon) return;
      switch (_peek().type) {
        case TokenType.keywordLet:
        case TokenType.keywordIf:
          return;
        default:
          _advance();
      }
    }
  }
}

// ============================================================================
// STAGE 3: SEMANTIC ANALYZER & CONSTANT FOLDING
// ============================================================================

class SemanticResult {
  final List<SymbolEntry> symbolTable;
  final List<SemanticDiagnostic> diagnostics;
  final bool hasErrors;
  final int foldedConstantsCount;

  const SemanticResult({
    required this.symbolTable,
    required this.diagnostics,
    required this.hasErrors,
    required this.foldedConstantsCount,
  });
}

class SemanticAnalyzer {
  final ProgramNode program;
  final List<SemanticDiagnostic> diagnostics = [];
  final Map<String, SymbolEntry> symbols = {};
  int _currentScopeLevel = 0;
  int _memoryOffsetCounter = 0;
  int _foldedConstantsCount = 0;

  SemanticAnalyzer(this.program);

  SemanticResult analyze() {
    diagnostics.clear();
    symbols.clear();
    _currentScopeLevel = 0;
    _memoryOffsetCounter = 0;
    _foldedConstantsCount = 0;

    for (final stmt in program.statements) {
      _visitNode(stmt);
    }

    final hasErrors = diagnostics.any((d) => d.isError);

    return SemanticResult(
      symbolTable: symbols.values.toList(),
      diagnostics: diagnostics,
      hasErrors: hasErrors,
      foldedConstantsCount: _foldedConstantsCount,
    );
  }

  void _visitNode(ASTNode node) {
    if (node is VarDeclNode) {
      _visitVarDecl(node);
    } else if (node is AssignmentNode) {
      _visitAssignment(node);
    } else if (node is BinaryExprNode) {
      _visitBinaryExpr(node);
    } else if (node is UnaryExprNode) {
      _visitUnaryExpr(node);
    } else if (node is LiteralNode) {
      // Literal node already has type and constant value
      node.inferredType = node.type;
      node.isConstantFoldable = true;
      node.evaluatedConstantValue = node.value;
    } else if (node is IdentifierNode) {
      _visitIdentifier(node);
    } else if (node is IfNode) {
      _visitIfNode(node);
    } else if (node is BlockNode) {
      _currentScopeLevel++;
      for (final child in node.statements) {
        _visitNode(child);
      }
      _currentScopeLevel--;
    } else if (node is ErrorNode) {
      diagnostics.add(SemanticDiagnostic(
        isError: true,
        category: 'Syntax Recovery',
        message: node.errorMessage,
        line: node.line,
        column: node.column,
        remedy: 'Fix syntax error before compiler proceeds to code generation.',
      ));
    }
  }

  void _visitVarDecl(VarDeclNode node) {
    // Check if already declared in same scope
    if (symbols.containsKey(node.identifier) &&
        symbols[node.identifier]!.scopeLevel == _currentScopeLevel) {
      diagnostics.add(SemanticDiagnostic(
        isError: true,
        category: 'Redeclaration',
        message: 'Identifier "${node.identifier}" already declared in current scope level $_currentScopeLevel.',
        line: node.line,
        column: node.column,
        remedy: 'Use assignment operator without "let" or declare under a unique name.',
      ));
    }

    dynamic initialVal;
    DataType inferred = DataType.unknown;

    if (node.initializer != null) {
      _visitNode(node.initializer!);
      inferred = node.initializer!.inferredType;
      initialVal = node.initializer!.evaluatedConstantValue;

      if (node.initializer!.isConstantFoldable) {
        _foldedConstantsCount++;
        diagnostics.add(SemanticDiagnostic(
          isError: false,
          category: 'Constant Folding',
          message: 'Initializer for "${node.identifier}" folded into immediate constant value $initialVal.',
          line: node.line,
          column: node.column,
          remedy: 'Compiler pre-computes constant expressions during optimization pass.',
        ));
      }
    }

    final entry = SymbolEntry(
      name: node.identifier,
      type: inferred,
      scopeLevel: _currentScopeLevel,
      memoryOffset: _memoryOffsetCounter,
      value: initialVal,
      declaredLine: node.line,
    );
    _memoryOffsetCounter += 4; // 32-bit (4-byte) aligned stack slots

    symbols[node.identifier] = entry;
    node.inferredType = inferred;
  }

  void _visitAssignment(AssignmentNode node) {
    if (!symbols.containsKey(node.identifier)) {
      diagnostics.add(SemanticDiagnostic(
        isError: true,
        category: 'Undeclared Variable',
        message: 'Cannot assign to undeclared identifier "${node.identifier}".',
        line: node.line,
        column: node.column,
        remedy: 'Declare variable with "let ${node.identifier} = ..." before assigning.',
      ));
    }

    _visitNode(node.value);
    final valType = node.value.inferredType;

    if (symbols.containsKey(node.identifier)) {
      final existing = symbols[node.identifier]!;
      if (existing.type != DataType.unknown && existing.type != valType) {
        diagnostics.add(SemanticDiagnostic(
          isError: true,
          category: 'Type Mismatch',
          message:
              'Cannot assign ${valType.displayName} value to variable "${node.identifier}" of type ${existing.type.displayName}.',
          line: node.line,
          column: node.column,
          remedy: 'Ensure assigned expression matches variable declared type.',
        ));
      }

      // Update value in symbol table if constant
      if (node.value.isConstantFoldable) {
        symbols[node.identifier] = SymbolEntry(
          name: existing.name,
          type: existing.type == DataType.unknown ? valType : existing.type,
          scopeLevel: existing.scopeLevel,
          memoryOffset: existing.memoryOffset,
          value: node.value.evaluatedConstantValue,
          declaredLine: existing.declaredLine,
        );
      }
    }

    node.inferredType = valType;
  }

  void _visitBinaryExpr(BinaryExprNode node) {
    _visitNode(node.left);
    _visitNode(node.right);

    final leftType = node.left.inferredType;
    final rightType = node.right.inferredType;

    // Type Compatibility Checks
    if (node.operator == '+' ||
        node.operator == '-' ||
        node.operator == '*' ||
        node.operator == '/') {
      // String + String or String + Number (concat)
      if (node.operator == '+' &&
          (leftType == DataType.string || rightType == DataType.string)) {
        node.inferredType = DataType.string;
        if (node.left.isConstantFoldable && node.right.isConstantFoldable) {
          node.isConstantFoldable = true;
          node.evaluatedConstantValue =
              '${node.left.evaluatedConstantValue}${node.right.evaluatedConstantValue}';
        }
      } else if (leftType == DataType.string || rightType == DataType.string) {
        // String with -, *, / is invalid!
        diagnostics.add(SemanticDiagnostic(
          isError: true,
          category: 'Type Mismatch',
          message:
              'Arithmetic operator "${node.operator}" cannot be applied to type "${DataType.string.displayName}".',
          line: node.line,
          column: node.column,
          remedy: 'Convert operands to numeric integers or floats before arithmetic operations.',
        ));
        node.inferredType = DataType.error;
      } else if ((leftType == DataType.integer || leftType == DataType.float) &&
          (rightType == DataType.integer || rightType == DataType.float)) {
        // Numeric arithmetic
        final hasFloat = leftType == DataType.float || rightType == DataType.float;
        node.inferredType = hasFloat ? DataType.float : DataType.integer;

        // Constant folding
        if (node.left.isConstantFoldable && node.right.isConstantFoldable) {
          final lVal = node.left.evaluatedConstantValue;
          final rVal = node.right.evaluatedConstantValue;
          if (lVal is num && rVal is num) {
            node.isConstantFoldable = true;
            switch (node.operator) {
              case '+':
                node.evaluatedConstantValue = hasFloat ? lVal.toDouble() + rVal.toDouble() : lVal.toInt() + rVal.toInt();
                break;
              case '-':
                node.evaluatedConstantValue = hasFloat ? lVal.toDouble() - rVal.toDouble() : lVal.toInt() - rVal.toInt();
                break;
              case '*':
                node.evaluatedConstantValue = hasFloat ? lVal.toDouble() * rVal.toDouble() : lVal.toInt() * rVal.toInt();
                break;
              case '/':
                if (rVal == 0) {
                  diagnostics.add(SemanticDiagnostic(
                    isError: true,
                    category: 'Division by Zero',
                    message: 'Constant evaluation results in division by zero at compile time.',
                    line: node.line,
                    column: node.column,
                    remedy: 'Check denominator expression to avoid division by zero.',
                  ));
                  node.isConstantFoldable = false;
                } else {
                  node.evaluatedConstantValue = hasFloat || (lVal % rVal != 0)
                      ? lVal.toDouble() / rVal.toDouble()
                      : lVal.toInt() ~/ rVal.toInt();
                }
                break;
            }
          }
        }
      } else if (leftType != DataType.unknown && rightType != DataType.unknown) {
        diagnostics.add(SemanticDiagnostic(
          isError: true,
          category: 'Type Mismatch',
          message:
              'Incompatible operand types for "${node.operator}": ${leftType.displayName} and ${rightType.displayName}.',
          line: node.line,
          column: node.column,
          remedy: 'Ensure both sides of arithmetic expression are compatible numbers.',
        ));
        node.inferredType = DataType.error;
      }
    } else {
      // Comparison operator (==, !=, <, <=, >, >=)
      node.inferredType = DataType.boolean;
      if (node.left.isConstantFoldable && node.right.isConstantFoldable) {
        final lVal = node.left.evaluatedConstantValue;
        final rVal = node.right.evaluatedConstantValue;
        node.isConstantFoldable = true;
        switch (node.operator) {
          case '==':
            node.evaluatedConstantValue = lVal == rVal;
            break;
          case '!=':
            node.evaluatedConstantValue = lVal != rVal;
            break;
          case '<':
            node.evaluatedConstantValue = (lVal is num && rVal is num) ? lVal < rVal : false;
            break;
          case '<=':
            node.evaluatedConstantValue = (lVal is num && rVal is num) ? lVal <= rVal : false;
            break;
          case '>':
            node.evaluatedConstantValue = (lVal is num && rVal is num) ? lVal > rVal : false;
            break;
          case '>=':
            node.evaluatedConstantValue = (lVal is num && rVal is num) ? lVal >= rVal : false;
            break;
        }
      }
    }
  }

  void _visitUnaryExpr(UnaryExprNode node) {
    _visitNode(node.operand);
    final opType = node.operand.inferredType;

    if (node.operator == '-') {
      if (opType != DataType.integer && opType != DataType.float && opType != DataType.unknown) {
        diagnostics.add(SemanticDiagnostic(
          isError: true,
          category: 'Type Mismatch',
          message: 'Unary negation "-" requires numeric operand, found ${opType.displayName}.',
          line: node.line,
          column: node.column,
          remedy: 'Apply unary negation only to numbers.',
        ));
      }
      node.inferredType = opType;
      if (node.operand.isConstantFoldable && node.operand.evaluatedConstantValue is num) {
        node.isConstantFoldable = true;
        node.evaluatedConstantValue = -node.operand.evaluatedConstantValue;
      }
    } else if (node.operator == '!') {
      node.inferredType = DataType.boolean;
      if (node.operand.isConstantFoldable && node.operand.evaluatedConstantValue is bool) {
        node.isConstantFoldable = true;
        node.evaluatedConstantValue = !node.operand.evaluatedConstantValue;
      }
    }
  }

  void _visitIdentifier(IdentifierNode node) {
    if (!symbols.containsKey(node.name)) {
      diagnostics.add(SemanticDiagnostic(
        isError: true,
        category: 'Undeclared Variable',
        message: 'Identifier "${node.name}" used before declaration.',
        line: node.line,
        column: node.column,
        remedy: 'Define "let ${node.name} = ..." prior to referencing it.',
      ));
      node.inferredType = DataType.unknown;
    } else {
      final entry = symbols[node.name]!;
      node.inferredType = entry.type;
      if (entry.value != null) {
        node.isConstantFoldable = true;
        node.evaluatedConstantValue = entry.value;
      }
    }
  }

  void _visitIfNode(IfNode node) {
    _visitNode(node.condition);
    if (node.condition.inferredType != DataType.boolean &&
        node.condition.inferredType != DataType.integer &&
        node.condition.inferredType != DataType.unknown) {
      diagnostics.add(SemanticDiagnostic(
        isError: false,
        category: 'Condition Warning',
        message: 'Condition expression evaluated with type "${node.condition.inferredType.displayName}". Implicit truthiness applied.',
        line: node.line,
        column: node.column,
        remedy: 'Prefer explicit boolean comparisons inside if statement conditions.',
      ));
    }

    _visitNode(node.thenBranch);
    if (node.elseBranch != null) {
      _visitNode(node.elseBranch!);
    }
  }
}

// ============================================================================
// STAGE 4: BYTECODE & ASSEMBLY CODE GENERATOR
// ============================================================================

class CodeGenResult {
  final List<BytecodeInstruction> bytecode;
  final List<AssemblyInstruction> assembly;

  const CodeGenResult({
    required this.bytecode,
    required this.assembly,
  });
}

class BytecodeCompiler {
  final ProgramNode program;
  final List<BytecodeInstruction> bytecode = [];
  final List<AssemblyInstruction> assembly = [];
  int _addressCounter = 0;
  int _regCounter = 0;
  final Map<String, int> _varOffsets = {};

  BytecodeCompiler(this.program);

  CodeGenResult compile() {
    bytecode.clear();
    assembly.clear();
    _addressCounter = 0;
    _regCounter = 0;
    _varOffsets.clear();

    assembly.add(const AssemblyInstruction(
      label: '_start',
      mnemonic: '.text',
      operands: [],
      comment: 'Begin CompileLens target machine code',
    ));

    for (final stmt in program.statements) {
      _emitStatement(stmt);
    }

    // Append HALT
    _emitBytecode(
      BytecodeOpCode.HALT,
      null,
      'Terminates execution and halts VM clock cycle.',
      'HLT',
      assemblyMnemonic: 'HLT',
      assemblyOperands: [],
      assemblyComment: 'Stop execution cycle',
    );

    return CodeGenResult(
      bytecode: bytecode,
      assembly: assembly,
    );
  }

  void _emitStatement(ASTNode node) {
    if (node is VarDeclNode) {
      if (node.initializer != null) {
        _emitExpression(node.initializer!);
      } else {
        // Default 0
        _emitBytecode(
          BytecodeOpCode.LOAD_CONST,
          0,
          'Pushes default value 0 for uninitialized variable "${node.identifier}".',
          'MOV R0, #0',
          assemblyMnemonic: 'MOV',
          assemblyOperands: ['R0', '#0'],
          assemblyComment: 'Initialize ${node.identifier} = 0',
        );
      }

      final offset = _varOffsets.length * 4;
      _varOffsets[node.identifier] = offset;

      _emitBytecode(
        BytecodeOpCode.STORE_VAR,
        node.identifier,
        'Pops top of stack and stores into local variable "${node.identifier}".',
        'STR R0, [SP, #$offset]',
        assemblyMnemonic: 'STR',
        assemblyOperands: ['R0', '[SP, #$offset]'],
        assemblyComment: 'Store value in memory slot of ${node.identifier}',
      );
    } else if (node is AssignmentNode) {
      _emitExpression(node.value);
      final offset = _varOffsets[node.identifier] ?? 0;
      _emitBytecode(
        BytecodeOpCode.STORE_VAR,
        node.identifier,
        'Updates variable "${node.identifier}" with evaluated stack result.',
        'STR R0, [SP, #$offset]',
        assemblyMnemonic: 'STR',
        assemblyOperands: ['R0', '[SP, #$offset]'],
        assemblyComment: 'Update ${node.identifier}',
      );
    } else if (node is IfNode) {
      _emitIf(node);
    } else if (node is BlockNode) {
      for (final child in node.statements) {
        _emitStatement(child);
      }
    } else {
      _emitExpression(node);
      _emitBytecode(
        BytecodeOpCode.POP,
        null,
        'Discards unused expression statement result from stack.',
        'SUB SP, SP, #4',
        assemblyMnemonic: 'SUB',
        assemblyOperands: ['SP', 'SP', '#4'],
        assemblyComment: 'Discard top of stack',
      );
    }
  }

  void _emitIf(IfNode node) {
    _emitExpression(node.condition);

    final jumpFalseIndex = bytecode.length;
    _emitBytecode(
      BytecodeOpCode.JUMP_IF_FALSE,
      -1, // placeholder
      'Checks condition: if 0 (false), jumps to else/end label.',
      'CMP R0, #0 ; BEQ .L_else',
      assemblyMnemonic: 'BEQ',
      assemblyOperands: ['.L_else'],
      assemblyComment: 'Jump if condition evaluated to false (0)',
    );

    _emitStatement(node.thenBranch);

    if (node.elseBranch != null) {
      final jumpEndIndex = bytecode.length;
      _emitBytecode(
        BytecodeOpCode.JUMP,
        -1, // placeholder
        'Skips else block after completing then branch.',
        'B .L_end',
        assemblyMnemonic: 'B',
        assemblyOperands: ['.L_end'],
        assemblyComment: 'Skip else branch',
      );

      final elseAddr = _addressCounter;
      // Patch jumpFalse
      bytecode[jumpFalseIndex] = BytecodeInstruction(
        address: bytecode[jumpFalseIndex].address,
        op: BytecodeOpCode.JUMP_IF_FALSE,
        arg: elseAddr,
        description: 'Conditional jump to address $elseAddr if false.',
        assemblyEquivalent: 'BEQ .L_else (addr $elseAddr)',
      );

      _emitStatement(node.elseBranch!);

      final endAddr = _addressCounter;
      bytecode[jumpEndIndex] = BytecodeInstruction(
        address: bytecode[jumpEndIndex].address,
        op: BytecodeOpCode.JUMP,
        arg: endAddr,
        description: 'Unconditional jump to address $endAddr.',
        assemblyEquivalent: 'B .L_end (addr $endAddr)',
      );
    } else {
      final endAddr = _addressCounter;
      bytecode[jumpFalseIndex] = BytecodeInstruction(
        address: bytecode[jumpFalseIndex].address,
        op: BytecodeOpCode.JUMP_IF_FALSE,
        arg: endAddr,
        description: 'Conditional jump to address $endAddr if false.',
        assemblyEquivalent: 'BEQ .L_end (addr $endAddr)',
      );
    }
  }

  void _emitExpression(ASTNode node) {
    if (node is LiteralNode) {
      final reg = 'R${_regCounter++ % 4}';
      _emitBytecode(
        BytecodeOpCode.LOAD_CONST,
        node.value,
        'Pushes constant literal ${node.value} onto operand stack.',
        'MOV $reg, #${node.value}',
        assemblyMnemonic: 'MOV',
        assemblyOperands: [reg, '#${node.value}'],
        assemblyComment: 'Load immediate constant',
      );
    } else if (node is IdentifierNode) {
      final offset = _varOffsets[node.name] ?? 0;
      final reg = 'R${_regCounter++ % 4}';
      _emitBytecode(
        BytecodeOpCode.LOAD_VAR,
        node.name,
        'Fetches variable "${node.name}" from memory and pushes onto stack.',
        'LDR $reg, [SP, #$offset]',
        assemblyMnemonic: 'LDR',
        assemblyOperands: [reg, '[SP, #$offset]'],
        assemblyComment: 'Load variable ${node.name}',
      );
    } else if (node is BinaryExprNode) {
      // Post-order: left, right, op
      _emitExpression(node.left);
      _emitExpression(node.right);

      BytecodeOpCode op;
      String asmOp;
      String desc;

      switch (node.operator) {
        case '+':
          op = BytecodeOpCode.ADD;
          asmOp = 'ADD';
          desc = 'Pops two operands, adds via ALU, pushes sum to stack.';
          break;
        case '-':
          op = BytecodeOpCode.SUB;
          asmOp = 'SUB';
          desc = 'Pops two operands, subtracts via ALU 2s-complement, pushes difference.';
          break;
        case '*':
          op = BytecodeOpCode.MUL;
          asmOp = 'MUL';
          desc = 'Pops two operands, multiplies via ALU hardware multiplier, pushes product.';
          break;
        case '/':
          op = BytecodeOpCode.DIV;
          asmOp = 'SDIV';
          desc = 'Pops two operands, divides via ALU integer divider, pushes quotient.';
          break;
        case '==':
          op = BytecodeOpCode.CMP_EQ;
          asmOp = 'CMP_EQ';
          desc = 'Compares top two values; pushes 1 if equal, 0 otherwise.';
          break;
        case '!=':
          op = BytecodeOpCode.CMP_NE;
          asmOp = 'CMP_NE';
          desc = 'Compares top two values; pushes 1 if not equal, 0 otherwise.';
          break;
        case '<':
          op = BytecodeOpCode.CMP_LT;
          asmOp = 'CMP_LT';
          desc = 'Compares top two values; pushes 1 if left < right, 0 otherwise.';
          break;
        case '<=':
          op = BytecodeOpCode.CMP_LE;
          asmOp = 'CMP_LE';
          desc = 'Compares top two values; pushes 1 if left <= right, 0 otherwise.';
          break;
        case '>':
          op = BytecodeOpCode.CMP_GT;
          asmOp = 'CMP_GT';
          desc = 'Compares top two values; pushes 1 if left > right, 0 otherwise.';
          break;
        case '>=':
          op = BytecodeOpCode.CMP_GE;
          asmOp = 'CMP_GE';
          desc = 'Compares top two values; pushes 1 if left >= right, 0 otherwise.';
          break;
        default:
          op = BytecodeOpCode.ADD;
          asmOp = 'ADD';
          desc = 'ALU operation';
      }

      _emitBytecode(
        op,
        null,
        desc,
        '$asmOp R0, R1, R0',
        assemblyMnemonic: asmOp,
        assemblyOperands: ['R0', 'R1', 'R0'],
        assemblyComment: 'ALU computation: result placed in R0',
      );
    } else if (node is UnaryExprNode) {
      _emitExpression(node.operand);
      if (node.operator == '-') {
        _emitBytecode(
          BytecodeOpCode.LOAD_CONST,
          -1,
          'Pushes -1 to stack.',
          'MOV R1, #-1',
          assemblyMnemonic: 'MOV',
          assemblyOperands: ['R1', '#-1'],
          assemblyComment: 'Prepare negation factor',
        );
        _emitBytecode(
          BytecodeOpCode.MUL,
          null,
          'Multiplies top operand by -1 to negate.',
          'MUL R0, R0, R1',
          assemblyMnemonic: 'MUL',
          assemblyOperands: ['R0', 'R0', 'R1'],
          assemblyComment: 'Two\'s complement negation',
        );
      }
    }
  }

  void _emitBytecode(
    BytecodeOpCode op,
    dynamic arg,
    String desc,
    String asmEq, {
    required String assemblyMnemonic,
    required List<String> assemblyOperands,
    required String assemblyComment,
  }) {
    bytecode.add(BytecodeInstruction(
      address: _addressCounter++,
      op: op,
      arg: arg,
      description: desc,
      assemblyEquivalent: asmEq,
    ));

    assembly.add(AssemblyInstruction(
      mnemonic: assemblyMnemonic,
      operands: assemblyOperands,
      comment: assemblyComment,
    ));
  }
}

// ============================================================================
// STAGE 5: VIRTUAL MACHINE & HARDWARE SIMULATOR
// ============================================================================

class VirtualMachineSimulator {
  final List<BytecodeInstruction> bytecode;
  int pc = 0;
  final List<dynamic> stack = [];
  final Map<String, dynamic> variables = {};
  final Map<String, int> registers = {'R0': 0, 'R1': 0, 'R2': 0, 'ACC': 0};
  HardwareState hardwareState = const HardwareState();

  final List<VMStepState> executionHistory = [];

  VirtualMachineSimulator(this.bytecode);

  void reset() {
    pc = 0;
    stack.clear();
    variables.clear();
    registers['R0'] = 0;
    registers['R1'] = 0;
    registers['R2'] = 0;
    registers['ACC'] = 0;
    hardwareState = const HardwareState();
    executionHistory.clear();
  }

  bool get isHalted => pc >= bytecode.length || (pc > 0 && bytecode[pc - 1].op == BytecodeOpCode.HALT);

  /// Executes one instruction and records the step snapshot
  VMStepState? step() {
    if (isHalted || pc >= bytecode.length) return null;

    final inst = bytecode[pc];
    String explanation = '';

    switch (inst.op) {
      case BytecodeOpCode.LOAD_CONST:
        stack.add(inst.arg);
        registers['R0'] = inst.arg is num ? inst.arg.toInt() : 0;
        explanation = 'Pushed constant [${inst.arg}] onto operand stack.';
        pc++;
        break;

      case BytecodeOpCode.LOAD_VAR:
        final val = variables[inst.arg] ?? 0;
        stack.add(val);
        registers['R1'] = val is num ? val.toInt() : 0;
        explanation = 'Loaded variable "${inst.arg}" (value: $val) onto operand stack.';
        pc++;
        break;

      case BytecodeOpCode.STORE_VAR:
        if (stack.isNotEmpty) {
          final val = stack.removeLast();
          variables[inst.arg] = val;
          registers['R0'] = val is num ? val.toInt() : 0;
          explanation = 'Popped [$val] from stack and stored in variable "${inst.arg}".';
        } else {
          explanation = 'Stack empty during store to "${inst.arg}".';
        }
        pc++;
        break;

      case BytecodeOpCode.ADD:
      case BytecodeOpCode.SUB:
      case BytecodeOpCode.MUL:
      case BytecodeOpCode.DIV:
        if (stack.length >= 2) {
          final b = stack.removeLast();
          final a = stack.removeLast();
          dynamic result = 0;
          String opName = 'ADD';

          if (a is num && b is num) {
            final aInt = a.toInt();
            final bInt = b.toInt();

            if (inst.op == BytecodeOpCode.ADD) {
              result = a + b;
              opName = 'ADD';
            } else if (inst.op == BytecodeOpCode.SUB) {
              result = a - b;
              opName = 'SUB';
            } else if (inst.op == BytecodeOpCode.MUL) {
              result = a * b;
              opName = 'MUL';
            } else if (inst.op == BytecodeOpCode.DIV) {
              result = b != 0 ? (a is double || b is double ? a / b : a ~/ b) : 0;
              opName = 'DIV';
            }

            // Sync with hardware state
            final resInt = result is num ? result.toInt() : 0;
            registers['R0'] = aInt;
            registers['R1'] = bInt;
            registers['ACC'] = resInt;

            final carry = (aInt + bInt) > 255;
            final zero = resInt == 0;
            final overflow = (resInt > 127 || resInt < -128);

            hardwareState = hardwareState.copyWith(
              r0Val: aInt & 0xFF,
              r1Val: bInt & 0xFF,
              accVal: resInt & 0xFF,
              carryFlag: carry,
              zeroFlag: zero,
              overflowFlag: overflow,
              operation: opName,
            );

            explanation = 'ALU executed $opName on $a and $b -> result $result pushed to stack.';
          } else {
            // String concat fallback
            result = '$a$b';
            explanation = 'Concatenated "$a" + "$b" -> "$result" on stack.';
          }

          stack.add(result);
        }
        pc++;
        break;

      case BytecodeOpCode.CMP_EQ:
      case BytecodeOpCode.CMP_NE:
      case BytecodeOpCode.CMP_LT:
      case BytecodeOpCode.CMP_LE:
      case BytecodeOpCode.CMP_GT:
      case BytecodeOpCode.CMP_GE:
        if (stack.length >= 2) {
          final b = stack.removeLast();
          final a = stack.removeLast();
          bool cmp = false;
          if (inst.op == BytecodeOpCode.CMP_EQ) cmp = a == b;
          if (inst.op == BytecodeOpCode.CMP_NE) cmp = a != b;
          if (inst.op == BytecodeOpCode.CMP_LT && a is num && b is num) cmp = a < b;
          if (inst.op == BytecodeOpCode.CMP_LE && a is num && b is num) cmp = a <= b;
          if (inst.op == BytecodeOpCode.CMP_GT && a is num && b is num) cmp = a > b;
          if (inst.op == BytecodeOpCode.CMP_GE && a is num && b is num) cmp = a >= b;

          final res = cmp ? 1 : 0;
          stack.add(res);
          registers['ACC'] = res;
          explanation = 'Evaluated comparison ($a vs $b) -> pushed boolean $cmp ($res).';
        }
        pc++;
        break;

      case BytecodeOpCode.JUMP_IF_FALSE:
        final condition = stack.isNotEmpty ? stack.removeLast() : 0;
        final isFalse = condition == 0 || condition == false;
        if (isFalse && inst.arg is int) {
          pc = inst.arg as int;
          explanation = 'Condition was false/0. Jumped PC to address $pc.';
        } else {
          pc++;
          explanation = 'Condition was true. Branch not taken, PC incremented.';
        }
        break;

      case BytecodeOpCode.JUMP:
        if (inst.arg is int) {
          pc = inst.arg as int;
          explanation = 'Unconditional jump to address $pc.';
        } else {
          pc++;
        }
        break;

      case BytecodeOpCode.POP:
        if (stack.isNotEmpty) {
          final val = stack.removeLast();
          explanation = 'Popped unused expression result [$val].';
        }
        pc++;
        break;

      case BytecodeOpCode.HALT:
        explanation = 'Program HALT reached. Execution ended successfully.';
        pc++;
        break;
    }

    final stepSnapshot = VMStepState(
      pc: pc,
      stack: List.unmodifiable(stack),
      variables: Map.unmodifiable(variables),
      registers: Map.unmodifiable(registers),
      currentInstruction: inst,
      stepExplanation: explanation,
    );

    executionHistory.add(stepSnapshot);
    return stepSnapshot;
  }

  /// Run all remaining instructions to completion
  List<VMStepState> runAll() {
    final steps = <VMStepState>[];
    int safetyLimit = 500;
    while (!isHalted && safetyLimit-- > 0) {
      final s = step();
      if (s != null) steps.add(s);
    }
    return steps;
  }
}
