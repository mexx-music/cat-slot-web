import 'package:flutter/material.dart';
import '../cat_slot_styles.dart';

class ResultLabel extends StatelessWidget {
  final String text;

  const ResultLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: CatSlotStyles.resultFontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
