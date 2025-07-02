// lib/config/theme_config.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeConfig {
  // Color Constants
  static const Color _primaryPurple = Color(0xFF6A4C93);
  static const Color _secondaryRoyalBlue = Color(0xFF4169E1);
  static const Color _accentLavender = Color(0xFF9B7EBD);
  static const Color _deepPurple = Color(0xFF4A2C5A);
  static const Color _lightPurple = Color(0xFFE8DCF0);
  
  // Light Theme Colors
  static const Color _lightBackground = Color(0xFFFAF9FF);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightOnSurface = Color(0xFF1A1A1A);
  static const Color _lightOnBackground = Color(0xFF2D2D2D);
  static const Color _lightOnPrimary = Color(0xFFFFFFFF);
  
  // Dark Theme Colors
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkOnSurface = Color(0xFFE8E8E8);
  static const Color _darkOnBackground = Color(0xFFE0E0E0);
  static const Color _darkOnPrimary = Color(0xFFFFFFFF);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: _primaryPurple,
        onPrimary: _lightOnPrimary,
        secondary: _secondaryRoyalBlue,
        onSecondary: Colors.white,
        tertiary: _accentLavender,
        onTertiary: Colors.white,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        background: _lightBackground,
        onBackground: _lightOnBackground,
        error: Color(0xFFD32F2F),
        onError: Colors.white,
        outline: Color(0xFFB0B0B0),
        outlineVariant: Color(0xFFE0E0E0),
        shadow: Colors.black26,
        scrim: Colors.black54,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: _lightBackground,
        foregroundColor: _lightOnBackground,
        titleTextStyle: TextStyle(
          color: _lightOnBackground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _primaryPurple),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _lightSurface,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryPurple,
          foregroundColor: _lightOnPrimary,
          elevation: 2,
          shadowColor: _primaryPurple.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryPurple,
          side: const BorderSide(color: _primaryPurple, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        hintStyle: const TextStyle(color: Color(0xFF999999)),
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _secondaryRoyalBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _primaryPurple,
        unselectedItemColor: Color(0xFF666666),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: _lightPurple,
        selectedColor: _primaryPurple,
        labelStyle: const TextStyle(color: _deepPurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return _primaryPurple;
          }
          return const Color(0xFFBDBDBD);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return _primaryPurple.withOpacity(0.5);
          }
          return const Color(0xFFE0E0E0);
        }),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primaryPurple,
        linearTrackColor: Color(0xFFE0E0E0),
        circularTrackColor: Color(0xFFE0E0E0),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: _accentLavender,
        onPrimary: _darkOnPrimary,
        secondary: _secondaryRoyalBlue,
        onSecondary: Colors.white,
        tertiary: _primaryPurple,
        onTertiary: Colors.white,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        background: _darkBackground,
        onBackground: _darkOnBackground,
        error: Color(0xFFEF5350),
        onError: Colors.black,
        outline: Color(0xFF666666),
        outlineVariant: Color(0xFF333333),
        shadow: Colors.black87,
        scrim: Colors.black87,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: _darkBackground,
        foregroundColor: _darkOnBackground,
        titleTextStyle: TextStyle(
          color: _darkOnBackground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _accentLavender),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _darkSurface,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentLavender,
          foregroundColor: _darkOnPrimary,
          elevation: 3,
          shadowColor: _accentLavender.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentLavender,
          side: const BorderSide(color: _accentLavender, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accentLavender,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentLavender, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        hintStyle: const TextStyle(color: Color(0xFF666666)),
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _secondaryRoyalBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _accentLavender,
        unselectedItemColor: Color(0xFF888888),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: _deepPurple,
        selectedColor: _accentLavender,
        labelStyle: const TextStyle(color: _darkOnSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return _accentLavender;
          }
          return const Color(0xFF666666);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return _accentLavender.withOpacity(0.5);
          }
          return const Color(0xFF333333);
        }),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accentLavender,
        linearTrackColor: Color(0xFF333333),
        circularTrackColor: Color(0xFF333333),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFF333333),
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// Usage in your main.dart:
/*
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ThemeBloc(SharedPreferences.getInstance()),
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Your App',
            theme: ThemeConfig.lightTheme,
            darkTheme: ThemeConfig.darkTheme,
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: YourHomePage(),
          );
        },
      ),
    );
  }
}
*/