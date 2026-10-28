// CompileLens — Interactive Compiler & Hardware Visualizer
// Hardware Transistor, CMOS Switches, and ALU Logic Gates Visualizer with CustomPainter

// ignore_for_file: prefer_const_constructors, prefer_const_declarations

import 'package:flutter/material.dart';
import '../compiler/models.dart';

enum HardwareVisualizerMode {
  logicGates,
  cmosTransistors,
  rippleCarryDataPath,
}

/// CustomPainter for ANSI Standard Logic Gates (XOR, AND, OR) and animated circuit wires
class FullAdderCircuitPainter extends CustomPainter {
  final FullAdderState state;
  final double animationValue;

  FullAdderCircuitPainter({
    required this.state,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background Grid
    _drawCircuitGrid(canvas, size);

    // Dynamic signal values
    final a = state.aBit;
    final b = state.bBit;
    final cIn = state.cIn;
    final ha1Sum = state.halfAdder1Sum;
    final ha1Carry = state.halfAdder1Carry;
    final ha2Carry = state.halfAdder2Carry;
    final sum = state.sum;
    final cOut = state.cOut;

    // Coordinate Anchors
    const inAX = 50.0;
    const inAY = 80.0;

    const inBX = 50.0;
    const inBY = 140.0;

    const inCinX = 50.0;
    const inCinY = 250.0;

    // Half Adder 1 Gate Centers
    const xor1Center = Offset(210, 100);
    const and1Center = Offset(210, 180);

    // Half Adder 2 Gate Centers
    const xor2Center = Offset(390, 120);
    const and2Center = Offset(390, 240);

    // Final OR Gate Center
    const orCenter = Offset(520, 280);

    // Output Terminals
    const sumOut = Offset(560, 120);
    const cOutOut = Offset(600, 280);

    // -------------------------------------------------------------
    // 1. Draw Wires with Signal Glow (Neon cyan if 1, dim if 0)
    // -------------------------------------------------------------

    // Wire A -> XOR1 and AND1
    _drawWire(canvas, [
      Offset(inAX, inAY),
      Offset(110, inAY),
      Offset(110, xor1Center.dy - 12),
      Offset(xor1Center.dx - 35, xor1Center.dy - 12),
    ], a);
    _drawWire(canvas, [
      Offset(110, inAY),
      Offset(110, and1Center.dy - 12),
      Offset(and1Center.dx - 35, and1Center.dy - 12),
    ], a);

    // Wire B -> XOR1 and AND1
    _drawWire(canvas, [
      Offset(inBX, inBY),
      Offset(130, inBY),
      Offset(130, xor1Center.dy + 12),
      Offset(xor1Center.dx - 35, xor1Center.dy + 12),
    ], b);
    _drawWire(canvas, [
      Offset(130, inBY),
      Offset(130, and1Center.dy + 12),
      Offset(and1Center.dx - 35, and1Center.dy + 12),
    ], b);

    // Wire Cin -> XOR2 and AND2
    _drawWire(canvas, [
      Offset(inCinX, inCinY),
      Offset(290, inCinY),
      Offset(290, xor2Center.dy + 12),
      Offset(xor2Center.dx - 35, xor2Center.dy + 12),
    ], cIn);
    _drawWire(canvas, [
      Offset(290, inCinY),
      Offset(290, and2Center.dy + 12),
      Offset(and2Center.dx - 35, and2Center.dy + 12),
    ], cIn);

    // Wire XOR1 Out (HA1 Sum) -> XOR2 and AND2
    _drawWire(canvas, [
      Offset(xor1Center.dx + 35, xor1Center.dy),
      Offset(310, xor1Center.dy),
      Offset(310, xor2Center.dy - 12),
      Offset(xor2Center.dx - 35, xor2Center.dy - 12),
    ], ha1Sum);
    _drawWire(canvas, [
      Offset(310, xor1Center.dy),
      Offset(310, and2Center.dy - 12),
      Offset(and2Center.dx - 35, and2Center.dy - 12),
    ], ha1Sum);

    // Wire AND1 Out (HA1 Carry) -> OR Gate
    _drawWire(canvas, [
      Offset(and1Center.dx + 35, and1Center.dy),
      Offset(440, and1Center.dy),
      Offset(440, orCenter.dy - 12),
      Offset(orCenter.dx - 35, orCenter.dy - 12),
    ], ha1Carry);

    // Wire AND2 Out (HA2 Carry) -> OR Gate
    _drawWire(canvas, [
      Offset(and2Center.dx + 35, and2Center.dy),
      Offset(450, and2Center.dy),
      Offset(450, orCenter.dy + 12),
      Offset(orCenter.dx - 35, orCenter.dy + 12),
    ], ha2Carry);

    // Output Wire: Sum
    _drawWire(canvas, [
      Offset(xor2Center.dx + 35, xor2Center.dy),
      sumOut,
    ], sum);

    // Output Wire: Cout
    _drawWire(canvas, [
      Offset(orCenter.dx + 35, orCenter.dy),
      cOutOut,
    ], cOut);

    // -------------------------------------------------------------
    // 2. Draw ANSI Logic Gate Symbols
    // -------------------------------------------------------------
    _drawXORGate(canvas, xor1Center, 'XOR 1', ha1Sum == 1);
    _drawANDGate(canvas, and1Center, 'AND 1', ha1Carry == 1);
    _drawXORGate(canvas, xor2Center, 'XOR 2', sum == 1);
    _drawANDGate(canvas, and2Center, 'AND 2', ha2Carry == 1);
    _drawORGate(canvas, orCenter, 'OR', cOut == 1);

    // -------------------------------------------------------------
    // 3. Draw Input / Output Terminals & Pins
    // -------------------------------------------------------------
    _drawTerminal(canvas, const Offset(inAX, inAY), 'A', a, true);
    _drawTerminal(canvas, const Offset(inBX, inBY), 'B', b, true);
    _drawTerminal(canvas, const Offset(inCinX, inCinY), 'Cin', cIn, true);

    _drawTerminal(canvas, sumOut, 'Sum (S)', sum, false);
    _drawTerminal(canvas, cOutOut, 'Cout', cOut, false);

    // Intermediate probe labels
    _drawProbeLabel(canvas, const Offset(315, 88), 'A ⊕ B', ha1Sum);
    _drawProbeLabel(canvas, const Offset(335, 172), 'A · B', ha1Carry);
  }

  void _drawCircuitGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.25)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _drawWire(Canvas canvas, List<Offset> points, int signal) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final isHigh = signal == 1;

    // Outer Glow if HIGH (1)
    if (isHigh) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.4)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, glowPaint);
    }

    // Core Wire
    final wirePaint = Paint()
      ..color = isHigh ? const Color(0xFF00FF88) : const Color(0xFF475569)
      ..strokeWidth = isHigh ? 2.6 : 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, wirePaint);

    // Junction nodes
    for (final pt in points) {
      canvas.drawCircle(
        pt,
        isHigh ? 3.0 : 2.0,
        Paint()..color = isHigh ? const Color(0xFF00FF88) : const Color(0xFF64748B),
      );
    }
  }

  void _drawTerminal(Canvas canvas, Offset pos, String name, int val, bool isInput) {
    final isHigh = val == 1;
    final rect = Rect.fromCenter(center: pos, width: 44, height: 32);

    // Pill background
    final bgPaint = Paint()
      ..color = isHigh ? const Color(0xFF064E3B) : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = isHigh ? const Color(0xFF00FF88) : const Color(0xFF64748B)
      ..strokeWidth = isHigh ? 2.0 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Label & Bit Value
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$name\n',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '$val',
            style: TextStyle(
              color: isHigh ? const Color(0xFF00FF88) : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 44);

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  void _drawProbeLabel(Canvas canvas, Offset pos, String text, int val) {
    final isHigh = val == 1;
    final tp = TextPainter(
      text: TextSpan(
        text: '$text = $val',
        style: TextStyle(
          color: isHigh ? const Color(0xFF00FF88) : const Color(0xFF94A3B8),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  // --- ANSI Logic Gate Renderers ---

  void _drawANDGate(Canvas canvas, Offset center, String label, bool active) {
    const w = 55.0;
    const h = 44.0;
    final path = Path()
      ..moveTo(center.dx - w / 2, center.dy - h / 2)
      ..lineTo(center.dx, center.dy - h / 2)
      ..arcToPoint(
        Offset(center.dx, center.dy + h / 2),
        radius: const Radius.circular(h / 2),
      )
      ..lineTo(center.dx - w / 2, center.dy + h / 2)
      ..close();

    _paintGateBody(canvas, path, center, label, active, const Color(0xFF00E5FF));
  }

  void _drawORGate(Canvas canvas, Offset center, String label, bool active) {
    const w = 60.0;
    const h = 46.0;
    final left = center.dx - w / 2;
    final right = center.dx + w / 2;
    final top = center.dy - h / 2;
    final bottom = center.dy + h / 2;

    final path = Path()
      ..moveTo(left, top)
      ..quadraticBezierTo(left + w * 0.45, top, right, center.dy)
      ..quadraticBezierTo(left + w * 0.45, bottom, left, bottom)
      ..quadraticBezierTo(left + 14, center.dy, left, top)
      ..close();

    _paintGateBody(canvas, path, center, label, active, const Color(0xFFFFB300));
  }

  void _drawXORGate(Canvas canvas, Offset center, String label, bool active) {
    const w = 62.0;
    const h = 46.0;
    final left = center.dx - w / 2;
    final right = center.dx + w / 2;
    final top = center.dy - h / 2;
    final bottom = center.dy + h / 2;

    // Secondary curved input arc
    final arcPath = Path()
      ..moveTo(left - 7, top)
      ..quadraticBezierTo(left + 7, center.dy, left - 7, bottom);

    final arcPaint = Paint()
      ..color = active ? const Color(0xFFD500F9) : const Color(0xFF64748B)
      ..strokeWidth = active ? 2.5 : 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arcPath, arcPaint);

    final path = Path()
      ..moveTo(left, top)
      ..quadraticBezierTo(left + w * 0.45, top, right, center.dy)
      ..quadraticBezierTo(left + w * 0.45, bottom, left, bottom)
      ..quadraticBezierTo(left + 14, center.dy, left, top)
      ..close();

    _paintGateBody(canvas, path, center, label, active, const Color(0xFFD500F9));
  }

  void _paintGateBody(Canvas canvas, Path path, Offset center, String label, bool active, Color accent) {
    // Fill
    final bg = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bg);

    if (active) {
      final glow = Paint()
        ..color = accent.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, glow);
    }

    // Border
    final border = Paint()
      ..color = active ? accent : const Color(0xFF475569)
      ..strokeWidth = active ? 2.2 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, border);

    // Center Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FullAdderCircuitPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.animationValue != animationValue;
  }
}

/// CustomPainter for CMOS Transistor Inverter & Logic Switches (PMOS Pull-Up, NMOS Pull-Down)
class CMOSTransistorPainter extends CustomPainter {
  final int gateInput; // 0 or 1
  final double animationValue;

  CMOSTransistorPainter({
    required this.gateInput,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Center schematic horizontally
    final midX = size.width / 2;
    const topY = 40.0;
    final botY = size.height - 40.0;

    final isInputHigh = gateInput == 1;
    // PMOS conducts when Gate is 0 (LOW), OFF when 1
    final pmosConducting = !isInputHigh;
    // NMOS conducts when Gate is 1 (HIGH), OFF when 0
    final nmosConducting = isInputHigh;
    // Inverter Output: Opposite of Gate input
    final outputVal = isInputHigh ? 0 : 1;

    // VDD (+5V) Rail
    final vddPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(midX - 70, topY), Offset(midX + 70, topY), vddPaint);
    _drawText(canvas, Offset(midX + 80, topY - 8), 'VDD (+5V / Logic 1)', const Color(0xFFFF5252));

    // GND Rail
    final gndPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(midX - 70, botY), Offset(midX + 70, botY), gndPaint);
    _drawGNDSymbol(canvas, Offset(midX, botY));
    _drawText(canvas, Offset(midX + 80, botY - 8), 'GND (0V / Logic 0)', const Color(0xFF64748B));

    // PMOS Center: Y ~ 120
    const pmosY = 120.0;
    // NMOS Center: Y ~ 240
    const nmosY = 240.0;
    const outY = 180.0;

    // Input line from left
    final inX = midX - 110;
    final inputPaint = Paint()
      ..color = isInputHigh ? const Color(0xFF00FF88) : const Color(0xFF475569)
      ..strokeWidth = isInputHigh ? 2.5 : 1.5;

    // Split input wire to PMOS and NMOS gates
    canvas.drawLine(Offset(inX, outY), Offset(midX - 50, outY), inputPaint);
    canvas.drawLine(Offset(midX - 50, pmosY), Offset(midX - 50, nmosY), inputPaint);
    canvas.drawLine(Offset(midX - 50, pmosY), Offset(midX - 35, pmosY), inputPaint);
    canvas.drawLine(Offset(midX - 50, nmosY), Offset(midX - 25, nmosY), inputPaint);

    // Input Terminal Box
    _drawInputToggleBox(canvas, Offset(inX, outY), gateInput);

    // Draw PMOS Transistor (Pull-Up Network)
    _drawMOSFET(canvas, Offset(midX, pmosY), true, pmosConducting);

    // Draw NMOS Transistor (Pull-Down Network)
    _drawMOSFET(canvas, Offset(midX, nmosY), false, nmosConducting);

    // Channel Wires: VDD -> PMOS -> Output Node -> NMOS -> GND
    // 1. VDD to PMOS Source
    final vddToPmosPaint = Paint()
      ..color = pmosConducting ? const Color(0xFFFF5252) : const Color(0xFF475569)
      ..strokeWidth = pmosConducting ? 2.5 : 1.5;
    canvas.drawLine(Offset(midX, topY), Offset(midX, pmosY - 20), vddToPmosPaint);

    // 2. PMOS Drain to Center Out
    final pmosToOutPaint = Paint()
      ..color = pmosConducting ? const Color(0xFF00FF88) : const Color(0xFF475569)
      ..strokeWidth = pmosConducting ? 3.0 : 1.5;
    canvas.drawLine(Offset(midX, pmosY + 20), Offset(midX, outY), pmosToOutPaint);

    // 3. Center Out to NMOS Drain
    final nmosToOutPaint = Paint()
      ..color = nmosConducting ? const Color(0xFF00E5FF) : const Color(0xFF475569)
      ..strokeWidth = nmosConducting ? 3.0 : 1.5;
    canvas.drawLine(Offset(midX, outY), Offset(midX, nmosY - 20), nmosToOutPaint);

    // 4. NMOS Source to GND
    final nmosToGndPaint = Paint()
      ..color = nmosConducting ? const Color(0xFF00E5FF) : const Color(0xFF475569)
      ..strokeWidth = nmosConducting ? 2.5 : 1.5;
    canvas.drawLine(Offset(midX, nmosY + 20), Offset(midX, botY), nmosToGndPaint);

    // Center Output Wire
    final outWirePaint = Paint()
      ..color = outputVal == 1 ? const Color(0xFF00FF88) : const Color(0xFF475569)
      ..strokeWidth = outputVal == 1 ? 3.0 : 1.5;
    canvas.drawLine(Offset(midX, outY), Offset(midX + 110, outY), outWirePaint);
    canvas.drawCircle(Offset(midX, outY), 4.0, Paint()..color = outputVal == 1 ? const Color(0xFF00FF88) : const Color(0xFF94A3B8));

    // Output Terminal Box
    _drawOutputBox(canvas, Offset(midX + 110, outY), outputVal);

    // Educational Callouts
    _drawStateBadge(
      canvas,
      Offset(midX + 30, pmosY - 5),
      'PMOS: ${pmosConducting ? "CONDUCTING (ON)" : "CUT-OFF (OFF)"}',
      pmosConducting ? const Color(0xFF00FF88) : const Color(0xFFFF5252),
    );
    _drawStateBadge(
      canvas,
      Offset(midX + 30, nmosY - 5),
      'NMOS: ${nmosConducting ? "CONDUCTING (ON)" : "CUT-OFF (OFF)"}',
      nmosConducting ? const Color(0xFF00E5FF) : const Color(0xFFFF5252),
    );
  }

  void _drawMOSFET(Canvas canvas, Offset center, bool isPMOS, bool conducting) {
    final x = center.dx;
    final y = center.dy;

    // Gate plate (vertical line)
    final gateX = x - 18;
    final platePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(gateX, y - 16), Offset(gateX, y + 16), platePaint);

    // Channel plate (parallel line with gap)
    final chanX = x - 10;
    final chanPaint = Paint()
      ..color = conducting ? (isPMOS ? const Color(0xFF00FF88) : const Color(0xFF00E5FF)) : const Color(0xFF475569)
      ..strokeWidth = conducting ? 3.0 : 1.8;
    canvas.drawLine(Offset(chanX, y - 20), Offset(chanX, y + 20), chanPaint);

    // Source & Drain horizontal connectors
    canvas.drawLine(Offset(chanX, y - 16), Offset(x, y - 16), chanPaint);
    canvas.drawLine(Offset(chanX, y + 16), Offset(x, y + 16), chanPaint);
    canvas.drawLine(Offset(x, y - 20), Offset(x, y - 16), chanPaint);
    canvas.drawLine(Offset(x, y + 16), Offset(x, y + 20), chanPaint);

    // Gate bubble for PMOS
    if (isPMOS) {
      final bubblePaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(Offset(gateX - 5, y), 4.0, bubblePaint);
    }
  }

  void _drawGNDSymbol(Canvas canvas, Offset pos) {
    final p = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(pos.dx - 18, pos.dy + 8), Offset(pos.dx + 18, pos.dy + 8), p);
    canvas.drawLine(Offset(pos.dx - 12, pos.dy + 14), Offset(pos.dx + 12, pos.dy + 14), p);
    canvas.drawLine(Offset(pos.dx - 6, pos.dy + 20), Offset(pos.dx + 6, pos.dy + 20), p);
  }

  void _drawInputToggleBox(Canvas canvas, Offset pos, int val) {
    final rect = Rect.fromCenter(center: pos, width: 60, height: 38);
    final isHigh = val == 1;

    final bg = Paint()
      ..color = isHigh ? const Color(0xFF064E3B) : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bg);

    final border = Paint()
      ..color = isHigh ? const Color(0xFF00FF88) : const Color(0xFF64748B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), border);

    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(text: 'IN (Gate)\n', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8)),
          TextSpan(
            text: '$val',
            style: TextStyle(
              color: isHigh ? const Color(0xFF00FF88) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 60);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawOutputBox(Canvas canvas, Offset pos, int val) {
    final rect = Rect.fromCenter(center: pos, width: 68, height: 38);
    final isHigh = val == 1;

    final bg = Paint()
      ..color = isHigh ? const Color(0xFF064E3B) : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bg);

    final border = Paint()
      ..color = isHigh ? const Color(0xFF00FF88) : const Color(0xFF64748B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), border);

    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(text: 'OUT (Vout)\n', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8)),
          TextSpan(
            text: '$val (${isHigh ? "HIGH" : "LOW"})',
            style: TextStyle(
              color: isHigh ? const Color(0xFF00FF88) : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 68);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawStateBadge(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawText(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant CMOSTransistorPainter oldDelegate) {
    return oldDelegate.gateInput != gateInput || oldDelegate.animationValue != animationValue;
  }
}

/// CustomPainter for 8-Bit Ripple Carry ALU Datapath (8 parallel 1-bit full adders with rippling carry)
class RippleCarryDatapathPainter extends CustomPainter {
  final HardwareState state;
  final int activeSlice;

  RippleCarryDatapathPainter({
    required this.state,
    required this.activeSlice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const sliceWidth = 85.0;
    const sliceHeight = 160.0;
    const startX = 25.0;
    const startY = 60.0;

    int cIn = 0;

    // Draw from MSB (Bit 7, left) to LSB (Bit 0, right) or LSB to MSB
    // In hardware layout, LSB is usually right, but let's draw Bits 7 down to 0:
    for (int i = 7; i >= 0; i--) {
      final colIndex = 7 - i;
      final x = startX + (colIndex * (sliceWidth + 14));
      final rect = Rect.fromLTWH(x, startY, sliceWidth, sliceHeight);

      final aBit = (state.r0Val >> i) & 1;
      final bBit = (state.r1Val >> i) & 1;

      // Carry for this bit
      final ha1Sum = aBit ^ bBit;
      final ha1Carry = aBit & bBit;
      final sum = ha1Sum ^ cIn;
      final ha2Carry = ha1Sum & cIn;
      final cOut = ha1Carry | ha2Carry;

      final isSelected = i == activeSlice;

      // Slice Box
      final bg = Paint()
        ..color = isSelected ? const Color(0xFF1E3A8A).withOpacity(0.4) : const Color(0xFF0F172A).withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), bg);

      final border = Paint()
        ..color = isSelected ? const Color(0xFF00E5FF) : const Color(0xFF334155)
        ..strokeWidth = isSelected ? 2.4 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), border);

      // Title Pill
      _drawSliceText(canvas, Offset(x + sliceWidth / 2, startY + 12), 'BIT $i', isSelected ? const Color(0xFF00E5FF) : Colors.white70);

      // Inputs A and B
      _drawSliceBit(canvas, Offset(x + 22, startY + 45), 'A$i', aBit);
      _drawSliceBit(canvas, Offset(x + sliceWidth - 22, startY + 45), 'B$i', bBit);

      // Carry In / Carry Out indicators
      _drawSliceText(canvas, Offset(x + sliceWidth / 2, startY + 80), 'Cin=$cIn', cIn == 1 ? const Color(0xFF00FF88) : const Color(0xFF64748B));
      _drawSliceText(canvas, Offset(x + sliceWidth / 2, startY + 100), 'Cout=$cOut', cOut == 1 ? const Color(0xFFFFB300) : const Color(0xFF64748B));

      // Output Sum
      _drawSliceBit(canvas, Offset(x + sliceWidth / 2, startY + 132), 'SUM', sum, isSum: true);

      // Ripple carry link wire to next bit (to the left in display)
      if (colIndex > 0) {
        final linkPaint = Paint()
          ..color = cIn == 1 ? const Color(0xFFFFB300) : const Color(0xFF334155)
          ..strokeWidth = cIn == 1 ? 2.0 : 1.0;
        canvas.drawLine(
          Offset(x, startY + 90),
          Offset(x - 14, startY + 90),
          linkPaint,
        );
      }

      cIn = cOut;
    }

    // Final Carry Flag Flagging
    const carryRect = Rect.fromLTWH(startX, startY + sliceHeight + 25, 240, 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(carryRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF1E293B),
    );
    _drawSliceText(
      canvas,
      carryRect.center,
      'Final Carry Flag (CF): ${state.carryFlag ? "1 (Overflow/Carry Out)" : "0"}',
      state.carryFlag ? const Color(0xFFFFB300) : const Color(0xFF94A3B8),
    );
  }

  void _drawSliceBit(Canvas canvas, Offset center, String label, int bit, {bool isSum = false}) {
    final isHigh = bit == 1;
    final dotPaint = Paint()
      ..color = isHigh ? (isSum ? const Color(0xFF00E5FF) : const Color(0xFF00FF88)) : const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, dotPaint);

    final border = Paint()
      ..color = isHigh ? Colors.white : const Color(0xFF475569)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 12, border);

    final tp = TextPainter(
      text: TextSpan(
        text: '$bit',
        style: TextStyle(
          color: isHigh ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 7.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(center.dx - labelTp.width / 2, center.dy - 22));
  }

  void _drawSliceText(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant RippleCarryDatapathPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.activeSlice != activeSlice;
  }
}
