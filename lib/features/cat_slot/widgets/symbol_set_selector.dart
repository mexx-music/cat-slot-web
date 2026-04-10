import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';
import '../data/slot_symbol_sets.dart';
import '../models/symbol_set.dart';

/// Kompaktes Dropdown zur Auswahl des aktiven Symbol-Sets.
///
/// Gibt das gewählte [SymbolSet] via [onChanged] zurück.
/// Kann später einfach aus dem Widget-Tree entfernt werden.
class SymbolSetSelector extends StatelessWidget {
  final SymbolSet activeSet;
  final ValueChanged<SymbolSet> onChanged;

  const SymbolSetSelector({
    super.key,
    required this.activeSet,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Set: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: CatSlotStyles.balanceColor,
          ),
        ),
        DropdownButton<SymbolSet>(
          value: activeSet,
          isDense: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CatSlotStyles.balanceColor,
          ),
          items: kAllSymbolSets
              .map(
                (set) => DropdownMenuItem(
                  value: set,
                  child: Text(set.label),
                ),
              )
              .toList(),
          onChanged: (set) {
            if (set != null) onChanged(set);
          },
        ),
      ],
    );
  }
}
