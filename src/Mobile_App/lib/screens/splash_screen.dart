import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'role_selection_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SPLASH SCREEN — Premium Light Theme
// ═══════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _waveCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

    _logoScale = Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _textFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut)));
    _textSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOut)));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _entryCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ));
    });
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        // Soft gradient background
        Positioned.fill(
            child: DecoratedBox(
                decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F8FF), Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
            stops: [0.0, 0.5, 1.0],
          ),
        ))),
        // Signal waves
        Positioned.fill(
            child: AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) =>
              CustomPaint(painter: _LightWavesPainter(_waveCtrl.value)),
        )),
        // Dot grid
        Positioned.fill(child: CustomPaint(painter: _LightDotsPainter())),
        // Content
        SafeArea(
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo mark
          ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(opacity: _logoFade, child: _SplashLogo())),
          const SizedBox(height: 40),
          // Text
          SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(children: [
                  Text('SmartCity',
                      style: GoogleFonts.orbitron(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 2)),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                            colors: [Color(0xFF00B7FF), Color(0xFF8E44FF)])
                        .createShader(r),
                    child: Text('LPWAN',
                        style: GoogleFonts.orbitron(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4)),
                  ),
                  const SizedBox(height: 12),
                  Text('Real-time Infrastructure Monitoring',
                      style: GoogleFonts.rajdhani(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          letterSpacing: 1.5)),
                ]),
              )),
          const SizedBox(height: 64),
          FadeTransition(opacity: _textFade, child: const _LightLoadingDots()),
        ]))),
      ]),
    );
  }
}

class _SplashLogo extends StatefulWidget {
  @override
  State<_SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<_SplashLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00B7FF)
                          .withOpacity(0.18 + 0.12 * _c.value),
                      blurRadius: 40 + 20 * _c.value,
                      spreadRadius: 0),
                  BoxShadow(
                      color: const Color(0xFF8E44FF)
                          .withOpacity(0.10 + 0.08 * _c.value),
                      blurRadius: 60,
                      spreadRadius: 0),
                  const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, 8)),
                ],
                border: Border.all(
                    color: const Color(0xFF00B7FF)
                        .withOpacity(0.2 + 0.15 * _c.value),
                    width: 1.5),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFE8F7FF).withOpacity(0.8),
                    Colors.white,
                  ]),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: Color(0xFF00B7FF), size: 50),
              ),
            ));
  }
}

class _LightLoadingDots extends StatefulWidget {
  const _LightLoadingDots();
  @override
  State<_LightLoadingDots> createState() => _LightLoadingDotsState();
}

class _LightLoadingDotsState extends State<_LightLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
                final s = 0.5 + 0.5 * math.sin(t * math.pi);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00B7FF).withOpacity(0.25 + 0.75 * s),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF00B7FF).withOpacity(s * 0.3),
                          blurRadius: 8)
                    ],
                  ),
                );
              }),
            ));
  }
}

class _LightWavesPainter extends CustomPainter {
  final double phase;
  const _LightWavesPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 7; i++) {
      final prog = (phase + i * 0.14) % 1.0;
      final radius = 40 + prog * size.width * 0.7;
      p.color = const Color(0xFF00B7FF).withOpacity(0.10 * (1 - prog));
      canvas.drawCircle(Offset(cx, cy), radius, p);
    }
  }

  @override
  bool shouldRepaint(_LightWavesPainter o) => o.phase != phase;
}

class _LightDotsPainter extends CustomPainter {
  static final _rng = math.Random(42);
  static final _pts =
      List.generate(60, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final _sz = List.generate(60, (_) => 0.8 + _rng.nextDouble() * 1.4);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF00B7FF).withOpacity(0.08);
    for (int i = 0; i < _pts.length; i++) {
      canvas.drawCircle(
          Offset(_pts[i].dx * s.width, _pts[i].dy * s.height), _sz[i], p);
    }
  }

  @override
  bool shouldRepaint(_LightDotsPainter _) => false;
}
