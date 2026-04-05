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
    return SizedBox(
      width: CatSlotStyles.buttonWidth,
      height: CatSlotStyles.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: CatSlotStyles.resetButtonColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
          ),
        ),
        child: const Text(
          'PLAY AGAIN',
          style: TextStyle(
            fontSize: CatSlotStyles.buttonFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
