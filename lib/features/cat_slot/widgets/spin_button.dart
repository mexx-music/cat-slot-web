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
    final bool disabled = isSpinning || onPressed == null;
    return Container(
      width: CatSlotStyles.buttonWidth,
      height: CatSlotStyles.buttonHeight,
      decoration: BoxDecoration(
        gradient: disabled
            ? const LinearGradient(
                colors: [Color(0xFF555568), Color(0xFF333345)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFFFFE566),
                  Color(0xFFD4AF37),
                  Color(0xFF8B6914),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
              ),
        borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
        border: Border.all(
          color: disabled ? const Color(0x44FFFFFF) : const Color(0xFFFFD700),
          width: 1.5,
        ),
        boxShadow: disabled
            ? []
            : const [
                BoxShadow(
                  color: Color(0xAAFFD700),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Color(0x55FFD700),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
          splashColor: const Color(0x33FFFFFF),
          highlightColor: const Color(0x22FFFFFF),
          child: Center(
            child: Text(
              isSpinning ? '· · ·' : 'SPIN',
              style: TextStyle(
                fontSize: CatSlotStyles.buttonFontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: disabled ? Colors.white54 : const Color(0xFF1A0A00),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
