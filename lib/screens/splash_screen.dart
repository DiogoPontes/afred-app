import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _characterController;
  late AnimationController _textController;
  late AnimationController _pulseController;

  late Animation<double> _characterFade;
  late Animation<Offset> _characterSlide;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // ── animação do personagem ───────────────────────────────────────────────
    _characterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _characterFade = CurvedAnimation(
      parent: _characterController,
      curve: Curves.easeIn,
    );
    _characterSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _characterController,
      curve: Curves.easeOutCubic,
    ));

    // ── animação do texto ────────────────────────────────────────────────────
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    // ── pulso suave no personagem ────────────────────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── sequência de entrada ─────────────────────────────────────────────────
    _characterController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _textController.forward();
    });

    // ── navegar para home após 3.5s ──────────────────────────────────────────
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // ── fundo com gradiente sutil ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF1A2340),
                  Color(0xFF0A0E1A),
                ],
              ),
            ),
          ),

          // ── brilho atrás do personagem ─────────────────────────────────────
          Positioned(
            top: size.height * 0.1,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _characterFade,
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3D6FFF).withOpacity(0.15),
                        blurRadius: 120,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── personagem ────────────────────────────────────────────────────
          Positioned(
            top: size.height * 0.04,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _characterFade,
              child: SlideTransition(
                position: _characterSlide,
                child: ScaleTransition(
                  scale: _pulse,
                  child: Center(
                    child: Image.asset(
                      'assets/images/alfred_splash.png',
                      height: size.height * 0.62,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── texto e subtítulo ─────────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.08,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // linha decorativa
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40, height: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3D6FFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40, height: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // nome do app
                    const Text(
                      'ALFRED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // subtítulo
                    Text(
                      'Seu organizador pessoal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // indicador de carregamento
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3D6FFF),
                        ),
                        minHeight: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}