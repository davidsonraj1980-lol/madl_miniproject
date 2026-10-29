// CompileLens — Interactive Compiler & Hardware Visualizer
// Hardware View: 8-bit LED Register Bit Strips, CMOS Switches & Logic Gates Interface

import 'package:flutter/material.dart';
import '../compiler/models.dart';
import 'transistor_alu_painter.dart';

class HardwareView extends StatefulWidget {
  final HardwareState hardwareState;
  final ValueChanged<HardwareState> onHardwareStateChanged;

  const HardwareView({
    super.key,
    required this.hardwareState,
    required this.onHardwareStateChanged,
  });

  @override
  State<HardwareView> createState() => _HardwareViewState();
}

class _HardwareViewState extends State<HardwareView> with SingleTickerProviderStateMixin {
  HardwareVisualizerMode _mode = HardwareVisualizerMode.logicGates;
  int _activeBitIndex = 0;
  int _cmosGateInput = 0;
  late AnimationController _pulseController;
  final TransformationController _hwTransformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _activeBitIndex = widget.hardwareState.activeBitSlice;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitHardwareView());
  }

  void _fitHardwareView() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;
    final screenWidth = mediaQuery.size.width;
    if (screenWidth < 680 && screenWidth > 0) {
      final scale = (screenWidth / 700).clamp(0.45, 0.95);
      _hwTransformController.value = Matrix4.identity()..scale(scale, scale, 1.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hwTransformController.dispose();
    super.dispose();
  }

  void _toggleR0Bit(int bitIndex) {
    final currentVal = widget.hardwareState.r0Val;
    final newVal = currentVal ^ (1 << bitIndex);
    _updateValues(newVal, widget.hardwareState.r1Val);
  }

  void _toggleR1Bit(int bitIndex) {
    final currentVal = widget.hardwareState.r1Val;
    final newVal = currentVal ^ (1 << bitIndex);
    _updateValues(widget.hardwareState.r0Val, newVal);
  }

  void _updateValues(int r0, int r1) {
    final r0Clamped = r0 & 0xFF;
    final r1Clamped = r1 & 0xFF;
    final sum = (r0Clamped + r1Clamped);
    final acc = sum & 0xFF;
    final carry = sum > 255;
    final zero = acc == 0;
    final overflow = (acc > 127 || acc < -128);

    widget.onHardwareStateChanged(widget.hardwareState.copyWith(
      r0Val: r0Clamped,
      r1Val: r1Clamped,
      accVal: acc,
      carryFlag: carry,
      zeroFlag: zero,
      overflowFlag: overflow,
      activeBitSlice: _activeBitIndex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.hardwareState;
    final activeSliceState = state.getBitSliceState(_activeBitIndex);

    return Column(
      children: [
        // Mode Selector Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  HardwareVisualizerMode.logicGates,
                  Icons.account_tree_outlined,
                  'Logic Gates',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  HardwareVisualizerMode.cmosTransistors,
                  Icons.electric_bolt_outlined,
                  'CMOS Transistor',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  HardwareVisualizerMode.rippleCarryDataPath,
                  Icons.memory,
                  '8-Bit Datapath',
                ),
              ),
            ],
          ),
        ),

        // Bit Registers Bar (R0, R1, ACC, Flags)
        _buildBitRegistersCard(state),

        // Canvas Area inside InteractiveViewer
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _hwTransformController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(200),
                    minScale: 0.3,
                    maxScale: 3.5,
                    child: Container(
                      color: const Color(0xFF0A0F1D),
                      padding: const EdgeInsets.all(24),
                      child: _buildActiveCanvas(state, activeSliceState),
                    ),
                  ),

                  // Floating Bit Slice Selector (for Logic Gates mode)
                  if (_mode == HardwareVisualizerMode.logicGates)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _buildBitSliceSelector(),
                    ),

                  // Info card on top right
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _buildHardwareStatusBadge(state),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(HardwareVisualizerMode mode, IconData icon, String label) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.18) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitRegistersCard(HardwareState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131C31),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '8-BIT REGISTERS (TAP TO TOGGLE BITS)',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  _buildFlagChip('CF (Carry)', state.carryFlag, const Color(0xFFFFB300)),
                  const SizedBox(width: 6),
                  _buildFlagChip('ZF (Zero)', state.zeroFlag, const Color(0xFF00E5FF)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // R0 Register
          _buildRegisterStrip(
            'R0',
            state.r0Val,
            state.r0Bits,
            const Color(0xFF00FF88),
            _toggleR0Bit,
          ),
          const SizedBox(height: 6),
          // R1 Register
          _buildRegisterStrip(
            'R1',
            state.r1Val,
            state.r1Bits,
            const Color(0xFF00E5FF),
            _toggleR1Bit,
          ),
          const SizedBox(height: 6),
          // ACC Result Register
          _buildRegisterStrip(
            'ACC',
            state.accVal,
            state.accBits,
            const Color(0xFFFFB300),
            null, // Read-only
          ),
        ],
      ),
    );
  }

  Widget _buildFlagChip(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.2) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? color : const Color(0xFF334155), width: 1),
      ),
      child: Text(
        '$label: ${active ? "1" : "0"}',
        style: TextStyle(
          color: active ? color : const Color(0xFF94A3B8),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildRegisterStrip(
    String regName,
    int decValue,
    List<int> bits,
    Color activeColor,
    ValueChanged<int>? onToggleBit,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            '$regName ($decValue)',
            style: TextStyle(
              color: activeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(8, (index) {
                // Show Bit 7 (MSB) on left down to Bit 0 (LSB) on right
                final bitIdx = 7 - index;
                final bitVal = bits[bitIdx];
                final isHigh = bitVal == 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: onToggleBit != null ? () => onToggleBit(bitIdx) : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 28,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isHigh ? activeColor.withOpacity(0.25) : const Color(0xFF0B1120),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isHigh ? activeColor : const Color(0xFF334155),
                          width: isHigh ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$bitVal',
                          style: TextStyle(
                            color: isHigh ? activeColor : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCanvas(HardwareState state, FullAdderState activeSliceState) {
    switch (_mode) {
      case HardwareVisualizerMode.logicGates:
        return CustomPaint(
          size: const Size(680, 360),
          painter: FullAdderCircuitPainter(
            state: activeSliceState,
            animationValue: _pulseController.value,
          ),
        );

      case HardwareVisualizerMode.cmosTransistors:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive Inverter Input Button
            InkWell(
              onTap: () {
                setState(() => _cmosGateInput = _cmosGateInput == 1 ? 0 : 1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, size: 16, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    Text(
                      'Toggle Gate Voltage Input: $_cmosGateInput (Tap to switch)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            CustomPaint(
              size: const Size(540, 340),
              painter: CMOSTransistorPainter(
                gateInput: _cmosGateInput,
                animationValue: _pulseController.value,
              ),
            ),
          ],
        );

      case HardwareVisualizerMode.rippleCarryDataPath:
        return CustomPaint(
          size: const Size(820, 320),
          painter: RippleCarryDatapathPainter(
            state: state,
            activeSlice: _activeBitIndex,
          ),
        );
    }
  }

  Widget _buildBitSliceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131C31).withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SLICE: ',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          ...List.generate(8, (i) {
            final isSel = i == _activeBitIndex;
            return InkWell(
              onTap: () => setState(() => _activeBitIndex = i),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF00E5FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'B$i',
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusBadge(HardwareState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'ALU Op: ${state.operation}',
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '${state.r0Val} + ${state.r1Val} = ${state.accVal}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
