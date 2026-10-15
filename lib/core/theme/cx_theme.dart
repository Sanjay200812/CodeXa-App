import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CxColors {
  // Brand Backgrounds
  static const Color background = Color(0xFF070707);
  static const Color card = Color(0xFF0C0C0C);
  static const Color cardElevated = Color(0xFF111111);
  static const Color secondaryDark = Color(0xFF141414);
  static const Color surfaceMuted = Color(0xFF191919);
  static const Color surface = Color(0xFF191919);
  static const Color accent = Color(0xFFFF1E3C);

  // Brand Accents
  static const Color crimson = Color(0xFFD90429);
  static const Color brightRed = Color(0xFFFF1E3C);
  static const Color deepRed = Color(0xFF63000F);

  // Text
  static const Color textPrimary = Color(0xFFF7F7F7);
  static const Color textSecondary = Color(0xFFA5A5A5);
  static const Color textMuted = Color(0xFF6B7280);

  // Status & System
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Borders & Glows
  static const Color borderDefault = Color(0x2ED90429); // rgba(217,4,41,0.18)
  static const Color borderActive = Color(0x8CFF1E3C); // rgba(255,30,60,0.55)
  static const Color borderSubtle = Color(0x1AFFFFFF);

  // Gradients
  static const LinearGradient crimsonGradient = LinearGradient(
    colors: [crimson, brightRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF141414), Color(0xFF0C0C0C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CxShadows {
  static const List<BoxShadow> neonGlow = [
    BoxShadow(color: Color(0x40FF1E3C), blurRadius: 16, spreadRadius: -2),
  ];

  static const List<BoxShadow> subtle = subtleCard;
  static const List<BoxShadow> subtleCard = [
    BoxShadow(color: Color(0x60000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

class CxSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double section = 28.0;

  static const double cardRadius = 18.0;
  static const double buttonRadius = 14.0;
  static const double inputRadius = 14.0;

  static const double primaryButtonHeight = 52.0;
  static const double minTouchTarget = 48.0;
  static const double bottomNavHeight = 72.0;
}

class CxTheme {
  static ThemeData get darkTheme {
    final textTheme = TextTheme(
      // Orbitron for display & brand titles
      displayLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: CxColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: CxColors.textPrimary,
      ),
      displaySmall: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: CxColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.orbitron(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CxColors.textPrimary,
        letterSpacing: 0.5,
      ),
      headlineSmall: GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CxColors.textPrimary,
      ),

      // Inter for functional UI, body, labels, inputs
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CxColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: CxColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: CxColors.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: CxColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: CxColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: CxColors.textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CxColors.textPrimary,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: CxColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CxColors.background,
      primaryColor: CxColors.crimson,
      cardColor: CxColors.card,
      canvasColor: CxColors.background,
      colorScheme: const ColorScheme.dark(
        primary: CxColors.crimson,
        secondary: CxColors.brightRed,
        surface: CxColors.card,
        error: CxColors.error,
        onPrimary: CxColors.textPrimary,
        onSecondary: CxColors.textPrimary,
        onSurface: CxColors.textPrimary,
        onError: CxColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: CxColors.borderSubtle,
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CxPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class CxPageTransitionsBuilder extends PageTransitionsBuilder {
  const CxPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.025), // 8px subtle translateY
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.995, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      ),
    );
  }
}
