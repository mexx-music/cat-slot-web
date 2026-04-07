import 'package:flutter/material.dart';
import 'features/cat_slot/loading_screen.dart';

class CatSlotApp extends StatelessWidget {
  const CatSlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Slot',
      debugShowCheckedModeBanner: false,
      home: const LoadingScreen(),
    );
  }
}
