import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível entrar com Google: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF11182D);
    const primaryColor = Color(0xFF3F6DF6);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = constraints.maxHeight > 700 ? 410.0 : 300.0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                children: [
                  const Spacer(),

                  Image.asset(
                    'assets/images/alfred_splash.png',
                    height: imageHeight,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _PageIndicator(active: false),
                      SizedBox(width: 10),
                      _PageIndicator(active: true),
                      SizedBox(width: 10),
                      _PageIndicator(active: false),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'A L F R E D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Seu organizador pessoal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryColor.withOpacity(0.55),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 21),
                                SizedBox(width: 10),
                                Text(
                                  'Entrar com Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward_rounded, size: 21),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool active;

  const _PageIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 8 : 38,
      height: active ? 8 : 1,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF3F6DF6)
            : Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}