// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LabViewerScreen extends StatefulWidget {
  final String labId;
  final String title;
  final String subject;

  const LabViewerScreen({
    super.key,
    required this.labId,
    required this.title,
    required this.subject,
  });

  @override
  State<LabViewerScreen> createState() => _LabViewerScreenState();
}

class _LabViewerScreenState extends State<LabViewerScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _orbitAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;

  String _selectedItem = '';
  double _rotationX = 0.3;
  double _rotationY = 0.5;
  double _zoom = 1.0;
  bool _isSimulating = false;

  // Chemical element data (realistic electron shell structure)
  final Map<String, _AtomData> _elements = {
    'Hydrogen (H)': _AtomData(symbol: 'H', number: 1, mass: '1.008',
        type: 'Nonmetal', color: const Color(0xFF38BDF8),
        electronShells: [1], glowColor: const Color(0xFF38BDF8)),
    'Helium (He)': _AtomData(symbol: 'He', number: 2, mass: '4.003',
        type: 'Noble Gas', color: const Color(0xFFA78BFA),
        electronShells: [2], glowColor: const Color(0xFFA78BFA)),
    'Carbon (C)': _AtomData(symbol: 'C', number: 6, mass: '12.011',
        type: 'Nonmetal', color: const Color(0xFF34D399),
        electronShells: [2, 4], glowColor: const Color(0xFF34D399)),
    'Oxygen (O)': _AtomData(symbol: 'O', number: 8, mass: '15.999',
        type: 'Nonmetal', color: const Color(0xFFF87171),
        electronShells: [2, 6], glowColor: const Color(0xFFF87171)),
    'Sodium (Na)': _AtomData(symbol: 'Na', number: 11, mass: '22.990',
        type: 'Alkali Metal', color: const Color(0xFFFBBF24),
        electronShells: [2, 8, 1], glowColor: const Color(0xFFFBBF24)),
    'Gold (Au)': _AtomData(symbol: 'Au', number: 79, mass: '196.97',
        type: 'Transition Metal', color: const Color(0xFFF59E0B),
        electronShells: [2, 8, 18, 32, 18, 1], glowColor: const Color(0xFFF59E0B)),
  };

  final Map<String, _OrganData> _organs = {
    'Brain': _OrganData(icon: '🧠', system: 'Nervous System',
        func: 'Controls body functions & cognitive processing',
        cells: '86 Billion Neurons', color: const Color(0xFFF87171)),
    'Heart': _OrganData(icon: '❤️', system: 'Circulatory System',
        func: 'Pumps oxygenated blood at ~70 beats/min',
        cells: 'Cardiomyocytes (3 Billion)', color: const Color(0xFFEF4444)),
    'Lungs': _OrganData(icon: '🫁', system: 'Respiratory System',
        func: 'Gas exchange (O₂ intake / CO₂ release)',
        cells: 'Alveolar Epithelium', color: const Color(0xFF60A5FA)),
    'DNA Helix': _OrganData(icon: '🧬', system: 'Genetics',
        func: '3 billion base pairs encoding life instructions',
        cells: 'Adenine, Thymine, Guanine, Cytosine', color: const Color(0xFF34D399)),
  };

  final List<String> _shapes = ['Cube', 'Sphere', 'Tetrahedron', 'Octahedron'];

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _rotateController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    _orbitAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_orbitController);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_rotateController);

    if (widget.labId == 'chem_periodic_table') {
      _selectedItem = 'Hydrogen (H)';
    } else if (widget.labId == 'bio_human_body') {
      _selectedItem = 'Heart';
    } else {
      _selectedItem = 'Cube';
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.subject,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        backgroundColor: const Color(0xFF0F1B2D),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text('🔬 Lab Controls', style: TextStyle(color: Colors.white)),
                content: const Text(
                  '• Drag on canvas to rotate the 3D model\n'
                  '• Pinch or use zoom slider to zoom in/out\n'
                  '• Select different elements or organs below\n'
                  '• Press "Start Simulation" to animate reactions',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it', style: TextStyle(color: Color(0xFF7C3AED))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 3D Viewport
          Expanded(
            flex: 5,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _rotationY += details.delta.dx * 0.012;
                  _rotationX += details.delta.dy * 0.012;
                  _rotationX = _rotationX.clamp(-1.5, 1.5);
                });
              },
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E3A5F), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _getLabColor().withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Starfield background
                      const _StarfieldBackground(),
                      // 3D Model
                      Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_orbitAnim, _pulseAnim, _rotateAnim]),
                          builder: (context, _) => _build3DScene(),
                        ),
                      ),
                      // Labels
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _glowChip(Icons.view_in_ar, '3D Interactive Lab'),
                      ),
                      if (_isSimulating)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _glowChip(Icons.electric_bolt, 'Simulating...', color: const Color(0xFFF59E0B)),
                        ),
                      // Zoom slider
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.zoom_out, color: Colors.white38, size: 16),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _zoom,
                                  min: 0.4,
                                  max: 2.5,
                                  activeColor: _getLabColor(),
                                  inactiveColor: Colors.white12,
                                  onChanged: (v) => setState(() => _zoom = v),
                                ),
                              ),
                            ),
                            const Icon(Icons.zoom_in, color: Colors.white38, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Control Panel
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1B2D),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Selector chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select to Explore:',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        _buildSelectorChips(),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 20),
                  // Detail panel
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          _buildDetailPanel(),
                          const SizedBox(height: 12),
                          _buildSimulateButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DScene() {
    if (widget.labId == 'chem_periodic_table') {
      final elem = _elements[_selectedItem] ?? _elements['Hydrogen (H)']!;
      return _AtomRenderer(
        element: elem,
        orbitAngle: _orbitAnim.value,
        rotX: _rotationX,
        rotY: _rotationY,
        zoom: _zoom,
        isSimulating: _isSimulating,
      );
    } else if (widget.labId == 'bio_human_body') {
      if (_selectedItem == 'DNA Helix') {
        return _DnaHelixRenderer(
          rotY: _rotationY,
          orbitAngle: _orbitAnim.value,
          zoom: _zoom,
          isSimulating: _isSimulating,
        );
      } else if (_selectedItem == 'Heart') {
        return _HeartRenderer(
          pulse: _pulseAnim.value,
          rotY: _rotationY,
          zoom: _zoom,
          isSimulating: _isSimulating,
        );
      } else {
        final organ = _organs[_selectedItem]!;
        return _OrganRenderer(
          organ: organ,
          orbitAngle: _orbitAnim.value,
          rotX: _rotationX,
          rotY: _rotationY,
          zoom: _zoom,
        );
      }
    } else {
      return _GeometryRenderer(
        shape: _selectedItem,
        rotAngle: _rotateAnim.value + _rotationY,
        rotX: _rotationX,
        zoom: _zoom,
        isSimulating: _isSimulating,
        color: const Color(0xFF3B82F6),
      );
    }
  }

  Widget _glowChip(IconData icon, String label, {Color? color}) {
    final c = color ?? _getLabColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getLabColor() {
    if (widget.labId == 'chem_periodic_table') {
      return _elements[_selectedItem]?.color ?? const Color(0xFF38BDF8);
    } else if (widget.labId == 'bio_human_body') {
      return _organs[_selectedItem]?.color ?? const Color(0xFFF87171);
    } else {
      return const Color(0xFF3B82F6);
    }
  }

  Widget _buildSelectorChips() {
    final keys = widget.labId == 'chem_periodic_table'
        ? _elements.keys.toList()
        : widget.labId == 'bio_human_body'
            ? _organs.keys.toList()
            : _shapes;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: keys.map((key) {
          final isSelected = _selectedItem == key;
          final c = _getLabColorForKey(key);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => setState(() => _selectedItem = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? c.withValues(alpha: 0.2) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected ? c : const Color(0xFF334155),
                        width: isSelected ? 2 : 1),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                        color: isSelected ? c : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getLabColorForKey(String key) {
    if (widget.labId == 'chem_periodic_table') {
      return _elements[key]?.color ?? const Color(0xFF38BDF8);
    } else if (widget.labId == 'bio_human_body') {
      return _organs[key]?.color ?? const Color(0xFFF87171);
    }
    return const Color(0xFF3B82F6);
  }

  Widget _buildDetailPanel() {
    if (widget.labId == 'chem_periodic_table') {
      final elem = _elements[_selectedItem] ?? _elements['Hydrogen (H)']!;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: elem.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: elem.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: elem.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: elem.color, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${elem.number}',
                          style: TextStyle(color: elem.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(elem.symbol,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedItem.replaceAll('(${elem.symbol})', '').trim(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: elem.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(elem.type,
                            style: TextStyle(color: elem.color, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBox('Atomic #', '${elem.number}', elem.color),
                const SizedBox(width: 8),
                _statBox('Atomic Mass', elem.mass, elem.color),
                const SizedBox(width: 8),
                _statBox('Shells', '${elem.electronShells.length}', elem.color),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.bubble_chart, color: elem.color, size: 16),
                  const SizedBox(width: 8),
                  Text('Electron config: ${elem.electronShells.join(', ')} (shells)',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (widget.labId == 'bio_human_body') {
      final organ = _organs[_selectedItem] ?? _organs['Heart']!;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: organ.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: organ.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(organ.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedItem,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: organ.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(organ.system,
                            style: TextStyle(color: organ.color, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.functions, 'Function', organ.func, organ.color),
            const SizedBox(height: 8),
            _infoRow(Icons.science, 'Cell Type', organ.cells, organ.color),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedItem,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._getShapeInfo(_selectedItem).entries.map((e) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _infoRow(Icons.calculate, e.key, e.value, const Color(0xFF3B82F6)),
                )),
          ],
        ),
      );
    }
  }

  Map<String, String> _getShapeInfo(String shape) {
    switch (shape) {
      case 'Cube':
        return {'Faces': '6 (squares)', 'Edges': '12', 'Vertices': '8', 'Volume': 'V = a³'};
      case 'Sphere':
        return {'Surface Area': 'A = 4πr²', 'Volume': 'V = 4/3 πr³', 'Dimensions': '3D', 'Edges': 'Infinite'};
      case 'Tetrahedron':
        return {'Faces': '4 (triangles)', 'Edges': '6', 'Vertices': '4', 'Volume': 'V = a³/(6√2)'};
      case 'Octahedron':
        return {'Faces': '8 (triangles)', 'Edges': '12', 'Vertices': '6', 'Volume': 'V = (√2/3)a³'};
      default:
        return {};
    }
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$label: ',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                TextSpan(text: value,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulateButton() {
    return GestureDetector(
      onTap: () => setState(() => _isSimulating = !_isSimulating),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSimulating
                ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                : [const Color(0xFF7C3AED), const Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (_isSimulating ? const Color(0xFFDC2626) : const Color(0xFF7C3AED))
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSimulating ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              _isSimulating ? 'Stop Simulation' : '▶  Run 3D Simulation',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────
class _AtomData {
  final String symbol;
  final int number;
  final String mass;
  final String type;
  final Color color;
  final Color glowColor;
  final List<int> electronShells;
  const _AtomData({
    required this.symbol, required this.number, required this.mass,
    required this.type, required this.color, required this.glowColor,
    required this.electronShells,
  });
}

class _OrganData {
  final String icon, system, func, cells;
  final Color color;
  const _OrganData({
    required this.icon, required this.system, required this.func,
    required this.cells, required this.color,
  });
}

// ─────────────────────────────────────────────────────────────
//  ATOM RENDERER — proper 3D electron orbits with projection
// ─────────────────────────────────────────────────────────────
class _AtomRenderer extends StatelessWidget {
  final _AtomData element;
  final double orbitAngle, rotX, rotY, zoom;
  final bool isSimulating;
  const _AtomRenderer({
    required this.element, required this.orbitAngle,
    required this.rotX, required this.rotY, required this.zoom,
    required this.isSimulating,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 300),
      painter: _AtomPainter(
        element: element,
        orbitAngle: orbitAngle + (isSimulating ? orbitAngle : 0),
        rotX: rotX,
        rotY: rotY,
        zoom: zoom,
      ),
    );
  }
}

class _AtomPainter extends CustomPainter {
  final _AtomData element;
  final double orbitAngle, rotX, rotY, zoom;
  _AtomPainter({
    required this.element, required this.orbitAngle,
    required this.rotX, required this.rotY, required this.zoom,
  });

  Offset _project(double x, double y, double z, Offset center) {
    // Rotation around Y axis
    final cosY = math.cos(rotY), sinY = math.sin(rotY);
    final x1 = x * cosY - z * sinY;
    final z1 = x * sinY + z * cosY;
    // Rotation around X axis
    final cosX = math.cos(rotX), sinX = math.sin(rotX);
    final y1 = y * cosX - z1 * sinX;
    final z2 = y * sinX + z1 * cosX;
    // Perspective projection
    final fov = 400.0;
    final depth = fov / (fov + z2 + 200);
    return Offset(
      center.dx + x1 * depth * zoom,
      center.dy + y1 * depth * zoom,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shells = element.electronShells;
    final baseRadius = 50.0;

    // Draw nucleus glow
    for (double r = 40; r > 0; r -= 8) {
      canvas.drawCircle(
        center,
        r * zoom * 0.5,
        Paint()
          ..color = element.glowColor.withValues(alpha: 0.04 + (40 - r) * 0.003)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // Draw nucleus
    final nucleusPaint = Paint()
      ..shader = RadialGradient(
        colors: [element.color, element.color.withValues(alpha: 0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: 22 * zoom));
    canvas.drawCircle(center, 22 * zoom * 0.5, nucleusPaint);

    // Nucleus label
    final textPainter = TextPainter(
      text: TextSpan(
        text: element.symbol,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14 * zoom,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // Draw each electron shell as elliptical orbit
    for (int s = 0; s < shells.length; s++) {
      final shellRadius = (baseRadius + s * 45) * zoom * 0.6;
      final electronCount = shells[s];
      final shellTilt = (s % 3) * (math.pi / 5) + s * 0.4;

      // Draw orbit ellipse as a series of points
      _drawOrbitEllipse(canvas, center, shellRadius, shellTilt, s);

      // Draw electrons for this shell
      for (int e = 0; e < electronCount; e++) {
        final angle = orbitAngle + (2 * math.pi * e / electronCount);
        final speed = 1.0 + s * 0.2;
        final ex = math.cos(angle * speed) * shellRadius;
        final ey = math.sin(angle * speed) * shellRadius * math.cos(shellTilt);
        final ez = math.sin(angle * speed) * shellRadius * math.sin(shellTilt);

        final ePos = _project(ex, ey, ez, center);
        final depth = 0.5 + (ez / (shellRadius + 20)) * 0.5;
        final eSize = (5 + depth * 3) * zoom * 0.5;

        // Electron glow
        canvas.drawCircle(
          ePos, eSize * 2.5,
          Paint()
            ..color = element.color.withValues(alpha: 0.15 * depth)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        // Electron dot
        canvas.drawCircle(
          ePos, eSize,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6 + depth * 0.4)
            ..style = PaintingStyle.fill,
        );
        // Electron inner bright dot
        canvas.drawCircle(
          ePos, eSize * 0.4,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawOrbitEllipse(Canvas canvas, Offset center, double radius, double tilt, int shellIndex) {
    final paint = Paint()
      ..color = element.color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    bool first = true;
    for (int i = 0; i <= 60; i++) {
      final angle = (i / 60) * 2 * math.pi;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius * math.cos(tilt);
      final z = math.sin(angle) * radius * math.sin(tilt);
      final projected = _project(x, y, z, center);
      if (first) {
        path.moveTo(projected.dx, projected.dy);
        first = false;
      } else {
        path.lineTo(projected.dx, projected.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AtomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  DNA DOUBLE HELIX RENDERER
// ─────────────────────────────────────────────────────────────
class _DnaHelixRenderer extends StatelessWidget {
  final double rotY, orbitAngle, zoom;
  final bool isSimulating;
  const _DnaHelixRenderer({
    required this.rotY, required this.orbitAngle,
    required this.zoom, required this.isSimulating,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 360),
      painter: _DnaHelixPainter(
        rotY: rotY,
        angle: orbitAngle * (isSimulating ? 2 : 1),
        zoom: zoom,
      ),
    );
  }
}

class _DnaHelixPainter extends CustomPainter {
  final double rotY, angle, zoom;
  final List<Color> _basePairColors = const [
    Color(0xFF38BDF8), Color(0xFF34D399),
    Color(0xFFF87171), Color(0xFFFBBF24),
  ];

  _DnaHelixPainter({required this.rotY, required this.angle, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final steps = 40;
    final heightStep = size.height * 0.8 / steps;
    final helixRadius = 70.0 * zoom;

    final strand1Points = <Offset>[];
    final strand2Points = <Offset>[];

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = angle + t * 4 * math.pi + rotY;
      final y = size.height * 0.1 + i * heightStep;

      final x1 = cx + math.cos(a) * helixRadius;
      final x2 = cx + math.cos(a + math.pi) * helixRadius;
      strand1Points.add(Offset(x1, y));
      strand2Points.add(Offset(x2, y));
    }

    // Draw strand 1 backbone
    _drawStrand(canvas, strand1Points, const Color(0xFF3B82F6));
    // Draw strand 2 backbone
    _drawStrand(canvas, strand2Points, const Color(0xFF10B981));

    // Draw base pairs (rungs)
    for (int i = 0; i <= steps; i += 2) {
      final p1 = strand1Points[i];
      final p2 = strand2Points[i];
      final color = _basePairColors[i % _basePairColors.length];

      final paint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);

      // Nucleotide dots
      canvas.drawCircle(p1, 5 * zoom, Paint()..color = const Color(0xFF3B82F6));
      canvas.drawCircle(p2, 5 * zoom, Paint()..color = const Color(0xFF10B981));
      canvas.drawCircle(
        Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2),
        4 * zoom,
        Paint()..color = color.withValues(alpha: 0.9),
      );
    }
  }

  void _drawStrand(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DnaHelixPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  HEART RENDERER with anatomically shaped beating heart
// ─────────────────────────────────────────────────────────────
class _HeartRenderer extends StatelessWidget {
  final double pulse, rotY, zoom;
  final bool isSimulating;
  const _HeartRenderer({
    required this.pulse, required this.rotY,
    required this.zoom, required this.isSimulating,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: _HeartPainter(pulse: pulse, zoom: zoom, isSimulating: isSimulating),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final double pulse, zoom;
  final bool isSimulating;
  _HeartPainter({required this.pulse, required this.zoom, required this.isSimulating});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final scale = pulse * zoom * 0.9;

    // Outer glow
    for (double g = 60; g > 0; g -= 10) {
      canvas.drawCircle(
        Offset(cx, cy),
        g * scale,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.03)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // Heart shape path
    final path = _heartPath(cx, cy, 90 * scale);

    // Heart fill gradient
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          const Color(0xFFFF6B6B),
          const Color(0xFFEF4444),
          const Color(0xFF991B1B),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 100 * scale));
    canvas.drawPath(path, paint);

    // Heart highlight
    final highlightPath = _heartPath(cx - 8 * scale, cy - 8 * scale, 40 * scale);
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Veins/arteries
    if (isSimulating) {
      final veinPaint = Paint()
        ..color = const Color(0xFF60A5FA).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(cx, cy - 90 * scale * 0.5),
        Offset(cx, cy - 120 * scale * 0.5),
        veinPaint,
      );
      canvas.drawLine(
        Offset(cx, cy - 90 * scale * 0.5),
        Offset(cx - 30 * scale * 0.5, cy - 110 * scale * 0.5),
        veinPaint,
      );
    }

    // BPM label
    if (isSimulating) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '♥  72 BPM',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 80 * scale * 0.5));
    }
  }

  Path _heartPath(double cx, double cy, double r) {
    final path = Path();
    // Parametric heart curve
    final points = <Offset>[];
    for (int i = 0; i <= 100; i++) {
      final t = (i / 100) * 2 * math.pi;
      final x = cx + r * 0.7 * (16 * math.pow(math.sin(t), 3)) / 16;
      final y = cy - r * 0.7 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16;
      points.add(Offset(x, y));
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HeartPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  ORGAN RENDERER (Brain, Lungs with glow nodes)
// ─────────────────────────────────────────────────────────────
class _OrganRenderer extends StatelessWidget {
  final _OrganData organ;
  final double orbitAngle, rotX, rotY, zoom;
  const _OrganRenderer({
    required this.organ, required this.orbitAngle,
    required this.rotX, required this.rotY, required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: _OrganPainter(organ: organ, angle: orbitAngle, zoom: zoom),
    );
  }
}

class _OrganPainter extends CustomPainter {
  final _OrganData organ;
  final double angle, zoom;
  _OrganPainter({required this.organ, required this.angle, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = 90.0 * zoom * 0.7;

    // Glowing background blob
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = organ.color.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // Main shape
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.75,
      Paint()
        ..color = organ.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.75,
      Paint()
        ..color = organ.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Orbiting activity nodes
    for (int i = 0; i < 6; i++) {
      final a = angle + i * (math.pi / 3);
      final nx = cx + r * 0.9 * math.cos(a);
      final ny = cy + r * 0.9 * math.sin(a) * 0.6;
      canvas.drawCircle(Offset(nx, ny), 6 * zoom,
          Paint()..color = organ.color.withValues(alpha: 0.8));
      canvas.drawCircle(Offset(nx, ny), 3 * zoom,
          Paint()..color = Colors.white);
      // Connecting line to center
      canvas.drawLine(
        Offset(cx, cy), Offset(nx, ny),
        Paint()
          ..color = organ.color.withValues(alpha: 0.2)
          ..strokeWidth = 1,
      );
    }

    // Organ icon in center
    final tp = TextPainter(
      text: TextSpan(
        text: organ.icon,
        style: TextStyle(fontSize: 56 * zoom * 0.6),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _OrganPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  GEOMETRY RENDERER — wireframe 3D shapes with real projection
// ─────────────────────────────────────────────────────────────
class _GeometryRenderer extends StatelessWidget {
  final String shape;
  final double rotAngle, rotX, zoom;
  final bool isSimulating;
  final Color color;
  const _GeometryRenderer({
    required this.shape, required this.rotAngle, required this.rotX,
    required this.zoom, required this.isSimulating, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 300),
      painter: _GeometryPainter(
        shape: shape, rotAngle: rotAngle, rotX: rotX,
        zoom: zoom, isSimulating: isSimulating, color: color,
      ),
    );
  }
}

class _GeometryPainter extends CustomPainter {
  final String shape;
  final double rotAngle, rotX, zoom;
  final bool isSimulating;
  final Color color;
  _GeometryPainter({
    required this.shape, required this.rotAngle, required this.rotX,
    required this.zoom, required this.isSimulating, required this.color,
  });

  List<List<double>> _getVertices() {
    switch (shape) {
      case 'Cube':
        final s = 80.0;
        return [
          [-s, -s, -s], [s, -s, -s], [s, s, -s], [-s, s, -s],
          [-s, -s, s], [s, -s, s], [s, s, s], [-s, s, s],
        ];
      case 'Tetrahedron':
        const a = 100.0;
        return [
          [0, -a, 0],
          [a * 0.943, a * 0.333, 0],
          [-a * 0.471, a * 0.333, a * 0.816],
          [-a * 0.471, a * 0.333, -a * 0.816],
        ];
      case 'Octahedron':
        const r = 90.0;
        return [
          [0, r, 0], [0, -r, 0],
          [r, 0, 0], [-r, 0, 0],
          [0, 0, r], [0, 0, -r],
        ];
      default: // Sphere approximation
        final pts = <List<double>>[];
        for (int i = 0; i <= 8; i++) {
          final lat = -math.pi / 2 + i * math.pi / 8;
          for (int j = 0; j <= 8; j++) {
            final lon = j * 2 * math.pi / 8;
            pts.add([
              80 * math.cos(lat) * math.cos(lon),
              80 * math.cos(lat) * math.sin(lon),
              80 * math.sin(lat),
            ]);
          }
        }
        return pts;
    }
  }

  List<List<int>> _getEdges(List<List<double>> v) {
    switch (shape) {
      case 'Cube':
        return [
          [0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],
          [0,4],[1,5],[2,6],[3,7],
        ];
      case 'Tetrahedron':
        return [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]];
      case 'Octahedron':
        return [
          [0,2],[0,3],[0,4],[0,5],[1,2],[1,3],[1,4],[1,5],
          [2,4],[2,5],[3,4],[3,5],
        ];
      default:
        return [];
    }
  }

  Offset _project(List<double> v, Offset center) {
    final cosY = math.cos(rotAngle), sinY = math.sin(rotAngle);
    final cosX = math.cos(rotX), sinX = math.sin(rotX);

    final x1 = v[0] * cosY - v[2] * sinY;
    final z1 = v[0] * sinY + v[2] * cosY;
    final y1 = v[1] * cosX - z1 * sinX;
    final z2 = v[1] * sinX + z1 * cosX;

    final fov = 400.0;
    final depth = fov / (fov + z2 + 300);
    return Offset(
      center.dx + x1 * depth * zoom,
      center.dy + y1 * depth * zoom,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (shape == 'Sphere') {
      // Draw sphere as latitude/longitude lines
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      // Latitude circles
      for (int i = 0; i <= 6; i++) {
        final lat = -math.pi / 2 + i * math.pi / 6;
        final path = Path();
        bool first = true;
        for (int j = 0; j <= 36; j++) {
          final lon = j * 2 * math.pi / 36;
          final v = [
            80 * math.cos(lat) * math.cos(lon),
            80 * math.sin(lat),
            80 * math.cos(lat) * math.sin(lon),
          ];
          final p = _project(v, center);
          if (first) { path.moveTo(p.dx, p.dy); first = false; }
          else { path.lineTo(p.dx, p.dy); }
        }
        canvas.drawPath(path, linePaint);
      }
      // Longitude lines
      for (int j = 0; j < 8; j++) {
        final lon = j * math.pi / 4;
        final path = Path();
        bool first = true;
        for (int i = 0; i <= 36; i++) {
          final lat = -math.pi / 2 + i * math.pi / 36;
          final v = [
            80 * math.cos(lat) * math.cos(lon),
            80 * math.sin(lat),
            80 * math.cos(lat) * math.sin(lon),
          ];
          final p = _project(v, center);
          if (first) { path.moveTo(p.dx, p.dy); first = false; }
          else { path.lineTo(p.dx, p.dy); }
        }
        canvas.drawPath(path, linePaint);
      }
    } else {
      final vertices = _getVertices();
      final edges = _getEdges(vertices);
      final projected = vertices.map((v) => _project(v, center)).toList();

      // Draw filled faces with translucency
      final facePaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      List<List<int>> faces = [];
      switch (shape) {
        case 'Cube':
          faces = [[0,1,2,3],[4,5,6,7],[0,1,5,4],[2,3,7,6],[0,3,7,4],[1,2,6,5]];
          break;
        case 'Tetrahedron':
          faces = [[0,1,2],[0,1,3],[0,2,3],[1,2,3]];
          break;
        case 'Octahedron':
          faces = [[0,2,4],[0,2,5],[0,3,4],[0,3,5],[1,2,4],[1,2,5],[1,3,4],[1,3,5]];
          break;
      }

      for (final face in faces) {
        final path = Path();
        path.moveTo(projected[face[0]].dx, projected[face[0]].dy);
        for (int i = 1; i < face.length; i++) {
          path.lineTo(projected[face[i]].dx, projected[face[i]].dy);
        }
        path.close();
        canvas.drawPath(path, facePaint);
      }

      // Draw edges (wireframe)
      final edgePaint = Paint()
        ..color = color.withValues(alpha: isSimulating ? 0.9 : 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSimulating ? 2.5 : 2.0
        ..strokeCap = StrokeCap.round;

      for (final edge in edges) {
        canvas.drawLine(projected[edge[0]], projected[edge[1]], edgePaint);
      }

      // Draw vertex dots
      for (final p in projected) {
        canvas.drawCircle(p, 5 * zoom * 0.6,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
        canvas.drawCircle(p, 3 * zoom * 0.6,
            Paint()..color = color);
      }
    }

    // Glow effect when simulating
    if (isSimulating) {
      canvas.drawCircle(
        center, 90 * zoom * 0.7,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }

    // Shape label
    final tp = TextPainter(
      text: TextSpan(
        text: shape,
        style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, size.height - 30));
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  STARFIELD BACKGROUND
// ─────────────────────────────────────────────────────────────
class _StarfieldBackground extends StatelessWidget {
  const _StarfieldBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _StarfieldPainter(),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final _rand = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 80; i++) {
      final x = _rand.nextDouble() * size.width;
      final y = _rand.nextDouble() * size.height;
      final r = _rand.nextDouble() * 1.5 + 0.3;
      final alpha = _rand.nextDouble() * 0.6 + 0.2;
      canvas.drawCircle(
        Offset(x, y), r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
