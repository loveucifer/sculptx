import 'package:flutter/material.dart';
import 'screens/sculpture_screen.dart';

/// The root widget of the SculptX application.
class SculptXApp extends StatelessWidget {
  /// Creates a const [SculptXApp].
  const SculptXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SculptX',
      debugShowCheckedModeBanner: false,

      // Defines the  theme.
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF111111), // Off-black background
        primaryColor: const Color(0xFFFAFAFA), // Off-white for primary elements
        fontFamily:
            'monospace', // Using monospace the weird glyph feel that i lyke

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFAFAFA),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF888888), // Muted gray for body text
            fontSize: 14,
          ),
        ),
      ),

      home: const SculptureScreen(),
    );
  }
}
