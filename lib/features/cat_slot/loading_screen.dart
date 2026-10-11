import 'package:flutter/material.dart';
import 'cat_slot_page.dart';
import 'cat_slot_styles.dart';
import 'widgets/cozy_cat_backdrop.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToGame();
      }
    });
  }

  void _navigateToGame() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CatSlotPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100A22),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CozyCatBackdrop(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xE61A122B),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x667ADDD5)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 34,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0x334FD7CD),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🐱', style: TextStyle(fontSize: 58)),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'CAT SLOT',
                        style: TextStyle(
                          fontSize: CatSlotStyles.titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'WARMING UP THE PAWS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9FE7E0),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.1,
                        ),
                      ),
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (_, __) => Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _progress.value,
                                minHeight: 7,
                                backgroundColor: const Color(0x332FD1C6),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFD778),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Katzen werden sortiert …',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xBFF8F2FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
