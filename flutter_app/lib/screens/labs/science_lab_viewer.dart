import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScienceLabViewer extends StatefulWidget {
  const ScienceLabViewer({super.key});

  @override
  State<ScienceLabViewer> createState() => _ScienceLabViewerState();
}

class _ScienceLabViewerState extends State<ScienceLabViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  String _model = 'H₂O Molecule';
  double _yaw = .45, _pitch = -.2, _fov = 400;
  bool _autoRotate = true;

  @override
  void dispose() { _animation.dispose(); super.dispose(); }

  void _reset() => setState(() { _yaw = .45; _pitch = -.2; _fov = 400; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1529),
        foregroundColor: Colors.white,
        title: const Text('Science Lab • 3D Explorer', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Reset camera', onPressed: _reset, icon: const Icon(Icons.restart_alt)),
          IconButton(tooltip: 'Auto rotate', onPressed: () => setState(() => _autoRotate = !_autoRotate), icon: Icon(_autoRotate ? Icons.motion_photos_on : Icons.motion_photos_off)),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;
        final controls = _controls(desktop);
        final viewer = Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: RepaintBoundary(
              child: Listener(
                onPointerMove: (e) => setState(() { _yaw += e.delta.dx * .012; _pitch = (_pitch + e.delta.dy * .012).clamp(-1.3, 1.3).toDouble(); }),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (_, __) => Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _LabPainter(model: _model, yaw: _yaw + (_autoRotate ? _animation.value * math.pi * 2 : 0), pitch: _pitch, fov: _fov, time: _animation.value))),
                    Positioned(top: 16, left: 16, child: _hud('$_model\nRotation ${(_yaw * 180 / math.pi).toStringAsFixed(0)}°  •  Zoom ${(_fov / 400).toStringAsFixed(1)}×')),
                    Positioned(bottom: 16, right: 16, child: Column(children: [
                      _roundButton(Icons.add, () => setState(() => _fov = (_fov + 45).clamp(230, 700).toDouble())),
                      const SizedBox(height: 10),
                      _roundButton(Icons.remove, () => setState(() => _fov = (_fov - 45).clamp(230, 700).toDouble())),
                    ])),
                    const Positioned(bottom: 18, left: 20, child: Text('Drag to rotate', style: TextStyle(color: Color(0xFF9BB0D0), fontSize: 12))),
                  ]),
                ),
              ),
            ),
          ),
        );
        return desktop ? Row(children: [SizedBox(width: 290, child: controls), viewer]) : Column(children: [viewer, controls]);
      }),
    );
  }

  Widget _controls(bool desktop) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(color: Color(0xFF0D1529), border: Border(right: BorderSide(color: Color(0xFF1F3152)))),
    child: Column(mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LAB MODEL', style: TextStyle(color: Color(0xFF00FFFF), letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 11)),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(initialValue: _model, dropdownColor: const Color(0xFF15223B), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0xFF15223B), border: OutlineInputBorder()), items: const ['H₂O Molecule', 'DNA Double Helix', 'Human Heart', 'Platonic Solids', 'Solar System'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _model = v!)),
      const SizedBox(height: 24),
      _toggle('Auto rotate', _autoRotate, (v) => setState(() => _autoRotate = v)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.center_focus_strong), label: const Text('Reset camera'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00FFFF))),
      if (desktop) const Spacer() else const SizedBox(height: 14),
      const Text('CUSTOM PAINTER ENGINE\nPerspective projection • depth sorting\nNo external 3D packages', style: TextStyle(color: Color(0xFF7083A5), fontSize: 11, height: 1.6)),
    ]),
  );
  Widget _toggle(String text, bool value, ValueChanged<bool> changed) => Row(children: [Expanded(child: Text(text, style: const TextStyle(color: Colors.white))), Switch(value: value, activeThumbColor: const Color(0xFF00FFFF), onChanged: changed)]);
  Widget _hud(String text) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF07101F).withValues(alpha: .88), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00FFFF).withValues(alpha: .45))), child: Text(text, style: const TextStyle(color: Color(0xFFBFFBFF), fontSize: 12, height: 1.5)));
  Widget _roundButton(IconData icon, VoidCallback tap) => Material(color: const Color(0xFF15223B), shape: const CircleBorder(), child: IconButton(onPressed: tap, icon: Icon(icon, color: const Color(0xFF00FFFF))));
}

class _V { const _V(this.x, this.y, this.z); final double x, y, z; _V operator +( _V o) => _V(x + o.x, y + o.y, z + o.z); _V operator *(double s) => _V(x*s,y*s,z*s); }
class _P { const _P(this.point, this.depth); final Offset point; final double depth; }

class _LabPainter extends CustomPainter {
  const _LabPainter({required this.model, required this.yaw, required this.pitch, required this.fov, required this.time});
  final String model; final double yaw, pitch, fov, time;
  static const cyan = Color(0xFF00FFFF), magenta = Color(0xFFFF00FF), amber = Color(0xFFFFB800);
  _V _rotate(_V v) { final x = v.x * math.cos(yaw) - v.z * math.sin(yaw); final z = v.x * math.sin(yaw) + v.z * math.cos(yaw); return _V(x, v.y * math.cos(pitch) - z * math.sin(pitch), v.y * math.sin(pitch) + z * math.cos(pitch)); }
  _P _project(_V v, Offset c) { final q = _rotate(v); final scale = fov / (fov + q.z + 500); return _P(Offset(c.dx + q.x * scale, c.dy + q.y * scale), q.z); }
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0F1E));
    final r = math.Random(13); for (var i=0;i<100;i++) { final a=.18+r.nextDouble()*.7; canvas.drawCircle(Offset(r.nextDouble()*size.width,r.nextDouble()*size.height), r.nextDouble()*1.4+.2, Paint()..color=Colors.white.withValues(alpha:a)); }
    final c = size.center(Offset.zero);
    switch (model) { case 'H₂O Molecule': _water(canvas,c); break; case 'DNA Double Helix': _dna(canvas,c); break; case 'Human Heart': _heart(canvas,c); break; case 'Platonic Solids': _solids(canvas,c); break; default: _solar(canvas,c); }
  }
  void _line(Canvas c, _V a, _V b, Color color, Offset center, {double width=4}) {
    final p = _project(a, center), q = _project(b, center);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width * ((fov / (fov + p.depth + 500) + fov / (fov + q.depth + 500)) / 2)
      ..strokeCap = StrokeCap.round;
    c.drawLine(p.point, q.point, paint);
  }
  void _sphere(Canvas c, _V v, double radius, Color color, Offset center) { final p=_project(v,center); final s=fov/(fov+p.depth+500); c.drawCircle(p.point, radius*s*1.6, Paint()..color=color.withValues(alpha:.16)..maskFilter=const MaskFilter.blur(BlurStyle.normal,18)); c.drawCircle(p.point,radius*s,Paint()..shader=RadialGradient(colors:[Colors.white.withValues(alpha:.85),color]).createShader(Rect.fromCircle(center:p.point,radius:radius*s))); }
  void _water(Canvas c, Offset o) { const oxygen=_V(0,0,0), h1=_V(-112,-55,25), h2=_V(112,-55,25); _line(c,oxygen,h1,Colors.white,o,width:8); _line(c,oxygen,h2,Colors.white,o,width:8); for(var i=0;i<3;i++) { final rect=Rect.fromCenter(center:_project(oxygen,o).point,width:150+i*22,height:65+i*12); c.drawOval(rect,Paint()..color=cyan.withValues(alpha:.15)..style=PaintingStyle.stroke..strokeWidth=1); } _sphere(c,oxygen,48,const Color(0xFFFF3B4E),o); _sphere(c,h1,28,Colors.white,o); _sphere(c,h2,28,Colors.white,o); }
  void _dna(Canvas c, Offset o) { final a=<_V>[]; for(var i=0;i<38;i++){ final t=i*.48; a.add(_V(math.cos(t)*82,(i-19)*11,math.sin(t)*82)); } for(var i=0;i<a.length-1;i++){ final t=(i*.48)+math.pi; final b1=_V(math.cos(t)*82,(i-19)*11,math.sin(t)*82); final b2=_V(math.cos(t+.48)*82,(i-18)*11,math.sin(t+.48)*82); _line(c,a[i],a[i+1],cyan,o,width:5); _line(c,b1,b2,Colors.greenAccent,o,width:5); if(i%2==0)_line(c,a[i],b1,i%4==0?magenta:cyan,o,width:4); } }
  void _heart(Canvas c, Offset o) { final pulse=1+math.sin(time*math.pi*8)*.05; for(final x in [-38.0,38.0]) _sphere(c,_V(x* pulse,15,0),65*pulse,const Color(0xFFFF3157),o); _sphere(c,_V(-36,-68,5),43*pulse,const Color(0xFFFF5B79),o); _sphere(c,_V(35,-66,5),40*pulse,const Color(0xFFBE1740),o); final arch=[_V(-20,-110,0),_V(0,-175,15),_V(80,-140,0),_V(75,-68,0)]; for(var i=0;i<3;i++)_line(c,arch[i],arch[i+1],amber,o,width:14); _line(c,_V(-75,-70,-10),_V(-120,-135,-10),cyan,o,width:11); }
  void _solids(Canvas c, Offset o) { final vs=[const _V(-90,-90,-90),const _V(90,-90,-90),const _V(90,90,-90),const _V(-90,90,-90),const _V(-90,-90,90),const _V(90,-90,90),const _V(90,90,90),const _V(-90,90,90)]; final faces=[[0,1,2,3],[4,5,6,7],[0,1,5,4],[2,3,7,6],[0,3,7,4],[1,2,6,5]]..sort((a,b)=>_project(vs[a[0]],o).depth.compareTo(_project(vs[b[0]],o).depth)); for(final f in faces){ final path=Path(); for(var i=0;i<f.length;i++){final p=_project(vs[f[i]],o).point;i==0?path.moveTo(p.dx,p.dy):path.lineTo(p.dx,p.dy);}path.close(); c.drawPath(path,Paint()..color=(f[0].isEven?cyan:magenta).withValues(alpha:.2)); c.drawPath(path,Paint()..color=amber.withValues(alpha:.8)..style=PaintingStyle.stroke..strokeWidth=2); } }
  void _solar(Canvas c, Offset o) { _sphere(c,const _V(0,0,0),58,amber,o); final rings=[100.0,145,195,255]; final colors=[const Color(0xFFACB6C5),cyan,const Color(0xFFFF6545),const Color(0xFF8C6CFF)]; for(var j=0;j<4;j++){ final path=Path(); for(var i=0;i<=64;i++){ final a=i*math.pi*2/64; final p=_project(_V(math.cos(a)*rings[j],0,math.sin(a)*rings[j]),o).point;i==0?path.moveTo(p.dx,p.dy):path.lineTo(p.dx,p.dy);}c.drawPath(path,Paint()..color=colors[j].withValues(alpha:.35)..style=PaintingStyle.stroke); final a=time*math.pi*2*(.3+j*.13)+j;_sphere(c,_V(math.cos(a)*rings[j],0,math.sin(a)*rings[j]),14+j*3,colors[j],o); } }
  @override bool shouldRepaint(covariant _LabPainter old) => old.yaw != yaw || old.pitch != pitch || old.fov != fov || old.time != time || old.model != model;
}
