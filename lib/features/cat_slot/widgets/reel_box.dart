import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

class ReelBox extends StatelessWidget {
  final String emoji;
  final Key animateKey;

  const ReelBox({
    super.key,
    required this.emoji,
    required this.animateKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CatSlotStyles.reelWidth,
      height: CatSlotStyles.reelHeight,
      decoration: BoxDecoration(
        color: CatSlotStyles.reelBackground,
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        border: Border.all(color: CatSlotStyles.reelBorder),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: CatSlotStyles.reelShadow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatSlotStyles.reelBorderRadius),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x11FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x11FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, -1.2),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );

                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  emoji,
                  key: animateKey,
                  style: const TextStyle(fontSize: CatSlotStyles.reelEmojiFontSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
