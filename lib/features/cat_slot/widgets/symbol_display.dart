import 'package:flutter/material.dart';
import '../models/slot_symbol.dart';
import '../cat_slot_styles.dart';

/// Zeigt ein einzelnes Slot-Symbol an.
///
/// Emojis und Bilder werden in einer identisch großen Box ([symbolDisplaySize])
/// zentriert, damit alle Sets optisch gleich groß wirken.
///
/// - assetPath gesetzt → Image.asset mit BoxFit.contain
/// - sonst            → Emoji-Text
class SymbolDisplay extends StatelessWidget {
  final SlotSymbol symbol;

  const SymbolDisplay({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    const s = CatSlotStyles.symbolDisplaySize;
    final path = symbol.assetPath;
    final cacheWidth = (s * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(96, 384)
        .toInt();

    return SizedBox(
      width: s,
      height: s,
      child: Center(
        child: path != null
            ? Image.asset(
                path,
                width: s,
                height: s,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                semanticLabel: symbol.label,
                errorBuilder: (_, __, ___) => _emoji(),
              )
            : _emoji(),
      ),
    );
  }

  Widget _emoji() => Text(
    symbol.emoji,
    style: const TextStyle(
      fontSize: CatSlotStyles.symbolEmojiFontSize,
      height: 1.0,
    ),
  );
}
