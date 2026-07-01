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
  late AnimationController _buttonController;

  late Animation<double> _characterFade;
  late Animation<Offset> _characterSlide;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();

    // ── personagem ───────────────────────────────────────────────────────────
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

    // ── texto ────────────────────────────────────────────────────────────────
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

    // ── botão ────────────────────────────────────────────────────────────────
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _buttonFade = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutCubic,
    ));

    // ── pulso suave ──────────────────────────────────────────────────────────
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
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // ── gradiente de fundo ─────────────────────────────────────────────
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
                      height: size.height * 0.58,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── texto + botão ─────────────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.06,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── nome e subtítulo ─────────────────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
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
                        Text(
                          'Seu organizador pessoal',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 13,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── botão iniciar ─────────────────────────────────────────────
                FadeTransition(
                  opacity: _buttonFade,
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _goToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3D6FFF),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor:
                                const Color(0xFF3D6FFF).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Iniciar',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}