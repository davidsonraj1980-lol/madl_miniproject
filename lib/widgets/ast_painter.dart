// CompileLens — Interactive Compiler & Hardware Visualizer
// AST Interactive Canvas Painter with Curved Bézier Connectors & Glassmorphic Badges

import 'package:flutter/material.dart';
import '../compiler/models.dart';

/// Layout node containing computed canvas coordinates
class LayoutASTNode {
  final ASTNode node;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<LayoutASTNode> children;

  LayoutASTNode({
    required this.node,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.children,
  });

  Rect get rect => Rect.fromCenter(
        center: Offset(x, y),
        width: width,
        height: height,
      );
}

/// Helper to compute tree positions with non-overlapping subtrees
class ASTTreeLayoutEngine {
  static const double nodeWidth = 145.0;
  static const double nodeHeight = 65.0;
  static const double horizontalSpacing = 28.0;
  static const double verticalSpacing = 95.0;

  static LayoutResult computeLayout(ASTNode root) {
    double minX = double.infinity;
    double maxX = -double.infinity;
    double maxY = 0;

    double currentX = 50.0;

    LayoutASTNode buildLayout(ASTNode node, int depth) {
      final y = 60.0 + (depth * verticalSpacing);
      if (y + nodeHeight > maxY) maxY = y + nodeHeight;

      if (node.children.isEmpty) {
        final x = currentX + nodeWidth / 2;
        currentX += nodeWidth + horizontalSpacing;

        if (x - nodeWidth / 2 < minX) minX = x - nodeWidth / 2;
        if (x + nodeWidth / 2 > maxX) maxX = x + nodeWidth / 2;

        return LayoutASTNode(
          node: node,
          x: x,
          y: y,
          width: nodeWidth,
          height: nodeHeight,
          children: [],
        );
      }

      final layoutChildren = <LayoutASTNode>[];
      for (final child in node.children) {
        layoutChildren.add(buildLayout(child, depth + 1));
      }

      final firstChildX = layoutChildren.first.x;
      final lastChildX = layoutChildren.last.x;
      final x = (firstChildX + lastChildX) / 2;

      if (x - nodeWidth / 2 < minX) minX = x - nodeWidth / 2;
      if (x + nodeWidth / 2 > maxX) maxX = x + nodeWidth / 2;

      return LayoutASTNode(
        node: node,
        x: x,
        y: y,
        width: nodeWidth,
        height: nodeHeight,
        children: layoutChildren,
      );
    }

    final rootLayout = buildLayout(root, 0);

    final totalWidth = (maxX - minX) + 120;
    final totalHeight = maxY + 100;

    return LayoutResult(
      root: rootLayout,
      size: Size(totalWidth.clamp(360.0, 5000.0), totalHeight.clamp(400.0, 5000.0)),
      offsetX: minX < 30 ? (30 - minX) : 0.0,
    );
  }
}

class LayoutResult {
  final LayoutASTNode root;
  final Size size;
  final double offsetX;

  const LayoutResult({
    required this.root,
    required this.size,
    required this.offsetX,
  });
}

/// CustomPainter that renders hierarchical AST nodes and glowing Bézier connection curves
class ASTTreePainter extends CustomPainter {
  final LayoutASTNode root;
  final ASTNode? selectedNode;
  final double offsetX;

  ASTTreePainter({
    required this.root,
    this.selectedNode,
    this.offsetX = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offsetX, 0);

    // 1. Draw glowing grid background
    _drawGrid(canvas, size);

    // 2. Draw curved Bézier links first
    _drawLinks(canvas, root);

    // 3. Draw nodes
    _drawNodes(canvas, root);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.35)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawLinks(Canvas canvas, LayoutASTNode parent) {
    for (final child in parent.children) {
      final isSelectedBranch = selectedNode != null &&
          (parent.node.id == selectedNode!.id || child.node.id == selectedNode!.id);

      final pStart = Offset(parent.x, parent.y + parent.height / 2);
      final pEnd = Offset(child.x, child.y - child.height / 2);

      final path = Path()
        ..moveTo(pStart.dx, pStart.dy)
        ..cubicTo(
          pStart.dx,
          pStart.dy + 35,
          pEnd.dx,
          pEnd.dy - 35,
          pEnd.dx,
          pEnd.dy,
        );

      // Glow shadow
      final glowPaint = Paint()
        ..color = isSelectedBranch
            ? const Color(0xFF00E5FF).withOpacity(0.4)
            : const Color(0xFF6366F1).withOpacity(0.2)
        ..strokeWidth = isSelectedBranch ? 5.0 : 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, glowPaint);

      // Core curve
      final corePaint = Paint()
        ..color = isSelectedBranch
            ? const Color(0xFF00E5FF)
            : const Color(0xFF818CF8).withOpacity(0.7)
        ..strokeWidth = isSelectedBranch ? 2.5 : 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, corePaint);

      // Connection dots
      final dotPaint = Paint()
        ..color = isSelectedBranch ? const Color(0xFF00E5FF) : const Color(0xFF6366F1);
      canvas.drawCircle(pStart, 3.5, dotPaint);
      canvas.drawCircle(pEnd, 3.5, dotPaint);

      _drawLinks(canvas, child);
    }
  }

  void _drawNodes(Canvas canvas, LayoutASTNode layoutNode) {
    final node = layoutNode.node;
    final isSelected = selectedNode != null && node.id == selectedNode!.id;
    final rect = layoutNode.rect;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Outer Halo if selected
    if (isSelected) {
      final haloPaint = Paint()
        ..color = node.themeColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(16)),
        haloPaint,
      );
    }

    // Node Background
    final bgPaint = Paint()
      ..color = const Color(0xFF0D1424).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Subtle gradient overlay
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          node.themeColor.withOpacity(0.18),
          const Color(0xFF0F172A).withOpacity(0.4),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, gradPaint);

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : node.themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.4 : 1.6;
    canvas.drawRRect(rrect, borderPaint);

    // Node Type Pill Header
    final typeRect = Rect.fromLTWH(rect.left + 8, rect.top + 6, rect.width - 16, 16);
    final typeRRect = RRect.fromRectAndRadius(typeRect, const Radius.circular(4));
    final pillBgPaint = Paint()
      ..color = node.themeColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(typeRRect, pillBgPaint);

    // Type text
    final typePainter = TextPainter(
      text: TextSpan(
        text: node.nodeType.toUpperCase(),
        style: TextStyle(
          color: node.themeColor,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 20);
    typePainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - typePainter.width) / 2,
        rect.top + 8,
      ),
    );

    // Main Node Label (e.g. "Op: +", "let count", "10")
    final labelPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width - 16);
    labelPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - labelPainter.width) / 2,
        rect.top + 26,
      ),
    );

    // Subtitle / Constant folding badge
    final subText = node.isConstantFoldable && node.evaluatedConstantValue != null
        ? '⚡ = ${node.evaluatedConstantValue}'
        : (node.inferredType != DataType.unknown
            ? 'Type: ${node.inferredType.displayName}'
            : node.subtitle);

    final subPainter = TextPainter(
      text: TextSpan(
        text: subText,
        style: TextStyle(
          color: node.isConstantFoldable ? const Color(0xFFFFD54F) : const Color(0xFF94A3B8),
          fontSize: 9.5,
          fontWeight: node.isConstantFoldable ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '..',
    )..layout(maxWidth: rect.width - 16);
    subPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - subPainter.width) / 2,
        rect.top + 45,
      ),
    );

    // Recursively draw children
    for (final child in layoutNode.children) {
      _drawNodes(canvas, child);
    }
  }

  @override
  bool shouldRepaint(covariant ASTTreePainter oldDelegate) {
    return oldDelegate.root != root ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.offsetX != offsetX;
  }
}

/// Interactive AST Canvas with Pan & Zoom and tap hit detection
class InteractiveASTCanvas extends StatefulWidget {
  final ASTNode rootNode;
  final ValueChanged<ASTNode> onNodeSelected;
  final ASTNode? selectedNode;

  const InteractiveASTCanvas({
    super.key,
    required this.rootNode,
    required this.onNodeSelected,
    this.selectedNode,
  });

  @override
  State<InteractiveASTCanvas> createState() => _InteractiveASTCanvasState();
}

class _InteractiveASTCanvasState extends State<InteractiveASTCanvas> {
  final TransformationController _transformController = TransformationController();
  late LayoutResult _layoutResult;

  @override
  void initState() {
    super.initState();
    _layoutResult = ASTTreeLayoutEngine.computeLayout(widget.rootNode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitTreeToScreen());
  }

  void _fitTreeToScreen() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;
    final screenWidth = mediaQuery.size.width;
    if (_layoutResult.size.width > screenWidth && screenWidth > 0) {
      final scale = (screenWidth / (_layoutResult.size.width + 40)).clamp(0.45, 1.0);
      _transformController.value = Matrix4.identity()..scale(scale, scale, 1.0);
    } else {
      _transformController.value = Matrix4.identity();
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveASTCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootNode != widget.rootNode) {
      _layoutResult = ASTTreeLayoutEngine.computeLayout(widget.rootNode);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitTreeToScreen());
    }
  }

  LayoutASTNode? _hitTest(LayoutASTNode current, Offset tapPos) {
    // Check current node
    final adjustedPos = Offset(tapPos.dx - _layoutResult.offsetX, tapPos.dy);
    if (current.rect.contains(adjustedPos)) {
      return current;
    }
    for (final child in current.children) {
      final match = _hitTest(child, tapPos);
      if (match != null) return match;
    }
    return null;
  }

  void _onTapUp(TapUpDetails details) {
    final localPos = details.localPosition;
    final hit = _hitTest(_layoutResult.root, localPos);
    if (hit != null) {
      widget.onNodeSelected(hit.node);
    }
  }

  void _resetZoom() {
    _fitTreeToScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(300),
          minScale: 0.25,
          maxScale: 3.5,
          child: GestureDetector(
            onTapUp: _onTapUp,
            child: CustomPaint(
              size: _layoutResult.size,
              painter: ASTTreePainter(
                root: _layoutResult.root,
                selectedNode: widget.selectedNode,
                offsetX: _layoutResult.offsetX,
              ),
            ),
          ),
        ),

        // Floating Zoom Reset & Controls
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'ast_reset_zoom',
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF00E5FF),
                tooltip: 'Reset Zoom & Center',
                onPressed: _resetZoom,
                child: const Icon(Icons.center_focus_strong, size: 18),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'ast_zoom_in',
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                tooltip: 'Zoom In',
                onPressed: () {
                  _transformController.value = _transformController.value.scaled(1.2, 1.2, 1.0);
                },
                child: const Icon(Icons.add, size: 18),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'ast_zoom_out',
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                tooltip: 'Zoom Out',
                onPressed: () {
                  _transformController.value = _transformController.value.scaled(0.8, 0.8, 1.0);
                },
                child: const Icon(Icons.remove, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
