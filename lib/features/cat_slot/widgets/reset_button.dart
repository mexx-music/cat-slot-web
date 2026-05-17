import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

/// Einfacher "Play Again"-Button.
/// Wird nur angezeigt, wenn keine Coins mehr vorhanden sind.
/// Rein visuell – keine Logik außer onPressed.
class ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ResetButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CatSlotStyles.buttonWidth,
      height: CatSlotStyles.buttonHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
        border: Border.all(color: const Color(0xAAFFD700), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x6666BB6A), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
          splashColor: const Color(0x33FFFFFF),
          child: const Center(
            child: Text(
              'PLAY AGAIN',
              style: TextStyle(
                fontSize: CatSlotStyles.buttonFontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
