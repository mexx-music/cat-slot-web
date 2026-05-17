import 'package:flutter/material.dart';

/// Dezenter Status-Ticker (z. B. "Try again") – kein Panel, nur Text.
class ResultLabel extends StatelessWidget {
  final String text;

  const ResultLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0x88FFFFFF),
        letterSpacing: 2.5,
      ),
    );
  }
}
