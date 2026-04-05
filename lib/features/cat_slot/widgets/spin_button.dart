import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

class SpinButton extends StatelessWidget {
  final bool isSpinning;
  final VoidCallback? onPressed;

  const SpinButton({
    super.key,
    required this.isSpinning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CatSlotStyles.buttonWidth,
      height: CatSlotStyles.buttonHeight,
      child: ElevatedButton(
        onPressed: isSpinning ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
          ),
        ),
        child: Text(
          isSpinning ? '...' : 'SPIN',
          style: const TextStyle(
            fontSize: CatSlotStyles.buttonFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
