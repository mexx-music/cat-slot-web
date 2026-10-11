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
                colors: [Color(0xFF554C67), Color(0xFF302A40)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFFFFEDAE),
                  Color(0xFFF3C36D),
                  Color(0xFFC97858),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.52, 1.0],
              ),
        borderRadius: BorderRadius.circular(CatSlotStyles.buttonBorderRadius),
        border: Border.all(
          color: disabled ? const Color(0x33FFFFFF) : const Color(0xFFFFE9A4),
          width: 1.5,
        ),
        boxShadow: disabled
            ? []
            : const [
                BoxShadow(
                  color: Color(0x66F3C36D),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: Offset(0, 7),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: isSpinning
                  ? const Row(
                      key: ValueKey('spinning'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Color(0xFFB7EEE8),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'PURRING',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('ready'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐾', style: TextStyle(fontSize: 21)),
                        const SizedBox(width: 12),
                        Text(
                          'SPIN',
                          style: TextStyle(
                            fontSize: CatSlotStyles.buttonFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: disabled
                                ? Colors.white54
                                : const Color(0xFF29142D),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
