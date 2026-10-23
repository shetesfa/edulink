import 'package:flutter/material.dart';
import 'lab_webview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LABS LIST SCREEN — beautiful subject cards, correct navigation
// ─────────────────────────────────────────────────────────────────────────────
class LabsListScreen extends StatefulWidget {
  const LabsListScreen({super.key});

  @override
  State<LabsListScreen> createState() => _LabsListScreenState();
}

class _LabsListScreenState extends State<LabsListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  String _filter = 'All';

  static const _filters = ['All', 'Chemistry', 'Biology', 'Physics', 'Mathematics'];

  static final _labs = [
    _LabCard(
      id: 'chem_periodic_table',
      subject: 'Chemistry',
      title: 'Periodic Table',
      subtitle: 'Interactive · All 118 Elements',
      description: 'Explore all elements with animated electron orbitals, category filtering, and detailed properties.',
      icon: '⚗️',
      gradient: [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
      glowColor: const Color(0xFF7C3AED),
      assetPath: 'web_assets/chemistry/periodic_table/index.html',
      extraTabs: [
        LabTab(label: 'Molecules', assetPath: 'web_assets/chemistry/molecules/viewer.html'),
      ],
      badge: 'CSS + HTML',
    ),
    _LabCard(
      id: 'chem_molecules',
      subject: 'Chemistry',
      title: '3D Molecule Viewer',
      subtitle: '3D Interactive · 12 Molecules',
      description: 'Rotate real 3D molecular structures. H₂O, CO₂, Glucose, Sulphuric Acid and more.',
      icon: '🔬',
      gradient: [const Color(0xFF9333EA), const Color(0xFF7C3AED)],
      glowColor: const Color(0xFF9333EA),
      assetPath: 'web_assets/chemistry/molecules/viewer.html',
      badge: '3Dmol.js',
    ),
    _LabCard(
      id: 'bio_human_body',
      subject: 'Biology',
      title: 'Human Body 3D',
      subtitle: '3D Interactive · Skeleton · Organs · DNA',
      description: 'Explore the human skeleton, organs, cells, and DNA double helix in real 3D. Click parts for details.',
      icon: '🧬',
      gradient: [const Color(0xFF059669), const Color(0xFF047857)],
      glowColor: const Color(0xFF059669),
      assetPath: 'web_assets/biology/human_body/viewer.html',
      badge: 'Three.js',
    ),
    _LabCard(
      id: 'phys_simulations',
      subject: 'Physics',
      title: 'Physics Simulations',
      subtitle: 'Interactive · 5 Experiments',
      description: 'Pendulum, Projectile motion, Wave types, Gravity simulation, and Optics (convex lens).',
      icon: '⚡',
      gradient: [const Color(0xFFD97706), const Color(0xFFB45309)],
      glowColor: const Color(0xFFD97706),
      assetPath: 'web_assets/physics/simulations/viewer.html',
      badge: 'Canvas 2D',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<_LabCard> get _filteredLabs =>
      _filter == 'All' ? _labs : _labs.where((l) => l.subject == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060612),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D24),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1a0533), Color(0xFF060612)],
                  ),
                ),
                child: Stack(children: [
                  // Glowing orbs
                  Positioned(top: 10, right: 30,
                    child: _GlowOrb(color: const Color(0xFF7C3AED), size: 80)),
                  Positioned(top: 40, right: 120,
                    child: _GlowOrb(color: const Color(0xFF059669), size: 50)),
                  Positioned(bottom: 20, left: 20,
                    child: _GlowOrb(color: const Color(0xFFD97706), size: 40)),
                  // Title
                  const Positioned(bottom: 20, left: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🔬 Science Labs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Interactive 3D experiments — tap to explore',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: f,
                      active: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Lab cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final labs = _filteredLabs;
                  if (i >= labs.length) return null;
                  final lab = labs[i];
                  return AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (_, child) {
                      final delay = (i * 0.15).clamp(0.0, 1.0);
                      final t = Curves.easeOutCubic.transform(
                          ((_animCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0));
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - t)),
                          child: child,
                        ),
                      );
                    },
                    child: _LabCardWidget(lab: lab),
                  );
                },
                childCount: _filteredLabs.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Lab Card Widget ──────────────────────────────────────────────────────────
class _LabCardWidget extends StatefulWidget {
  final _LabCard lab;
  const _LabCardWidget({required this.lab});

  @override
  State<_LabCardWidget> createState() => _LabCardWidgetState();
}

class _LabCardWidgetState extends State<_LabCardWidget> {
  bool _hovered = false;

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LabWebViewScreen(
        labId: widget.lab.id,
        title: widget.lab.title,
        subject: widget.lab.subject,
        assetPath: widget.lab.assetPath,
        extraTabs: widget.lab.extraTabs?.map((t) =>
          LabTab(label: t.label, assetPath: t.assetPath)).toList(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0, _hovered ? 1.02 : 1.0),
          child: GestureDetector(
            onTap: () => _open(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF111127),
                    const Color(0xFF0D0D1E),
                  ],
                ),
                border: Border.all(
                  color: lab.glowColor.withValues(alpha: _hovered ? 0.6 : 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: lab.glowColor.withValues(alpha: _hovered ? 0.25 : 0.08),
                    blurRadius: _hovered ? 24 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // Icon container
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: lab.gradient),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: lab.glowColor.withValues(alpha: 0.4),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Center(child: Text(lab.icon, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(lab.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: lab.glowColor.withValues(alpha: 0.15),
                            border: Border.all(color: lab.glowColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(lab.badge,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: lab.glowColor)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(lab.subtitle,
                        style: TextStyle(fontSize: 11, color: lab.glowColor, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Text(lab.description,
                    style: const TextStyle(fontSize: 13, color: Colors.white54, height: 1.5)),
                  const SizedBox(height: 14),
                  Row(children: [
                    // Subject chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: lab.glowColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(lab.subject,
                        style: TextStyle(fontSize: 11, color: lab.glowColor, fontWeight: FontWeight.w600)),
                    ),
                    if (lab.extraTabs != null && lab.extraTabs!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('+${lab.extraTabs!.length} view${lab.extraTabs!.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const Spacer(),
                    // Launch button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: lab.gradient),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: lab.glowColor.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 2),
                        )],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Open Lab', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ───────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withValues(alpha: 0.3),
        color.withValues(alpha: 0.0),
      ]),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7C3AED) : const Color(0xFF111127),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFF7C3AED) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: active ? [const BoxShadow(
          color: Color(0x557C3AED), blurRadius: 10, offset: Offset(0, 2),
        )] : null,
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: active ? Colors.white : Colors.white38,
      )),
    ),
  );
}

// ── Data models ──────────────────────────────────────────────────────────────
class _LabCard {
  final String id, subject, title, subtitle, description, icon, assetPath, badge;
  final List<Color> gradient;
  final Color glowColor;
  final List<LabTab>? extraTabs;

  const _LabCard({
    required this.id, required this.subject, required this.title,
    required this.subtitle, required this.description, required this.icon,
    required this.gradient, required this.glowColor, required this.assetPath,
    required this.badge, this.extraTabs,
  });
}
