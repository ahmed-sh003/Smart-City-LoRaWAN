import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../providers/dashboard_provider.dart';
import 'mobile_home_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  LOGIN SCREEN — Premium Light Theme
// ═══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _cardCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  final _emailCtrl = TextEditingController(text: 'admin@smartcity.io');
  final _passCtrl = TextEditingController(text: '');
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _cardSlide = Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    context.read<UserRoleController>().setRole(UserRole.admin);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const MobileHomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final provider = context.read<DashboardProvider>();
    final signedIn =
        await provider.signInWithFirebase(_emailCtrl.text, _passCtrl.text);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _loading = false);
    if (!signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase Auth is unavailable. Opening secure demo session.',
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.read<DashboardProvider>().toggleMockData(true);
    }
    _goHome();
  }

  void _demo() {
    context.read<UserRoleController>().setRole(UserRole.admin);
    context.read<DashboardProvider>().toggleMockData(true);
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // Animated light gradient BG
        Positioned.fill(
            child: AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) =>
              CustomPaint(painter: _LoginBgPainter(_bgCtrl.value)),
        )),
        // Scroll body
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: SafeArea(
                child: Column(children: [
              const Spacer(flex: 2),
              // Brand section
              FadeTransition(opacity: _cardFade, child: _BrandHeader()),
              const SizedBox(height: 36),
              // Login card
              SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _LoginCard(
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      loading: _loading,
                      onToggle: () => setState(() => _obscure = !_obscure),
                      onLogin: _login,
                      onDemo: _demo,
                    ),
                  )),
              const Spacer(flex: 3),
              FadeTransition(
                  opacity: _cardFade,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text('© 2025 SmartCity LPWAN · Graduation Project',
                        style: GoogleFonts.rajdhani(
                            fontSize: 11, color: const Color(0xFFADB8C9))),
                  )),
            ])),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BRAND HEADER
// ─────────────────────────────────────────────────────────────
class _BrandHeader extends StatefulWidget {
  @override
  State<_BrandHeader> createState() => _BrandHeaderState();
}

class _BrandHeaderState extends State<_BrandHeader>
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
        builder: (_, __) => Column(children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00B7FF)
                            .withOpacity(0.2 + 0.12 * _c.value),
                        blurRadius: 32 + 16 * _c.value),
                    const BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 16,
                        offset: Offset(0, 6)),
                  ],
                  border: Border.all(
                      color: const Color(0xFF00B7FF)
                          .withOpacity(0.22 + 0.12 * _c.value),
                      width: 1.5),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: Color(0xFF00B7FF), size: 36),
              ),
              const SizedBox(height: 18),
              Text('SmartCity LPWAN',
                  style: GoogleFonts.orbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text('Infrastructure Monitoring Platform',
                  style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5)),
            ]));
  }
}

// ─────────────────────────────────────────────────────────────
//  LOGIN CARD
// ─────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading;
  final VoidCallback onToggle, onLogin, onDemo;
  const _LoginCard(
      {required this.emailCtrl,
      required this.passCtrl,
      required this.obscure,
      required this.loading,
      required this.onToggle,
      required this.onLogin,
      required this.onDemo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 40,
              spreadRadius: 0,
              offset: Offset(0, 16)),
          const BoxShadow(
              color: Color(0x06000000), blurRadius: 80, offset: Offset(0, 32)),
          BoxShadow(
              color: const Color(0xFF00B7FF).withOpacity(0.06), blurRadius: 40),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome Back',
            style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text('Sign in to your monitoring dashboard',
            style: GoogleFonts.rajdhani(
                fontSize: 14, color: const Color(0xFF64748B))),
        const SizedBox(height: 26),

        // Email
        _LightField(
            ctrl: emailCtrl,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded),
        const SizedBox(height: 14),

        // Password
        _LightField(
          ctrl: passCtrl,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: obscure,
          suffix: GestureDetector(
            onTap: onToggle,
            child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: Text('Forgot password?',
                style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    color: const Color(0xFF00B7FF),
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 26),

        // Login button
        SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B7FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: const Color(0xFF00B7FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ).copyWith(
                  elevation: MaterialStateProperty.resolveWith(
                      (s) => s.contains(MaterialState.pressed) ? 2 : 0)),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Sign In',
                      style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
            )),
        const SizedBox(height: 12),

        // Demo button
        SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onDemo,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00C853),
                side: const BorderSide(color: Color(0xFF00C853), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_circle_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text('Try Demo Mode',
                    style: GoogleFonts.rajdhani(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00C853))),
              ]),
            )),

        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Secure Connection',
                  style: GoogleFonts.rajdhani(
                      fontSize: 11, color: const Color(0xFFCBD5E1)))),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ]),
      ]),
    );
  }
}

class _LightField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  const _LightField(
      {required this.ctrl,
      required this.hint,
      required this.icon,
      this.obscure = false,
      this.suffix});
  @override
  State<_LightField> createState() => _LightFieldState();
}

class _LightFieldState extends State<_LightField> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? const Color(0xFF00B7FF) : const Color(0xFFE2E8F0),
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                      color: const Color(0xFF00B7FF).withOpacity(0.12),
                      blurRadius: 12)
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.ctrl,
          obscureText: widget.obscure,
          style: GoogleFonts.rajdhani(
              fontSize: 15,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: GoogleFonts.rajdhani(
                fontSize: 14, color: const Color(0xFFCBD5E1)),
            prefixIcon: Icon(widget.icon,
                color: _focused
                    ? const Color(0xFF00B7FF)
                    : const Color(0xFFCBD5E1),
                size: 19),
            suffixIcon: widget.suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: widget.suffix)
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BACKGROUND PAINTER
// ─────────────────────────────────────────────────────────────
class _LoginBgPainter extends CustomPainter {
  final double phase;
  const _LoginBgPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF5F7FB));
    final blobs = [
      [0.15, 0.15, const Color(0xFF00B7FF), 0.06],
      [0.88, 0.25, const Color(0xFF8E44FF), 0.05],
      [0.10, 0.80, const Color(0xFF00C853), 0.04],
      [0.85, 0.75, const Color(0xFF00B7FF), 0.04],
    ];
    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final x =
          (b[0] as double) * size.width + 20 * math.sin(phase * math.pi + i);
      final y = (b[1] as double) * size.height +
          15 * math.cos(phase * math.pi * 0.7 + i);
      final r = size.width * 0.55;
      final col = b[2] as Color;
      final op = b[3] as double;
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              col.withOpacity(op),
              Colors.transparent
            ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }
  }

  @override
  bool shouldRepaint(_LoginBgPainter o) => o.phase != phase;
}
