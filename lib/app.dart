import 'package:flutter/material.dart';
import 'features/cat_slot/loading_screen.dart';

class CatSlotApp extends StatelessWidget {
  const CatSlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Slot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66D8CF),
          brightness: Brightness.dark,
          primary: const Color(0xFF8CE4DC),
          secondary: const Color(0xFFFFD778),
          surface: const Color(0xFF1A122B),
        ),
        splashFactory: InkSparkle.splashFactory,
        textTheme: const TextTheme(bodyMedium: TextStyle(height: 1.25)),
      ),
      home: const LoadingScreen(),
    );
  }
}
