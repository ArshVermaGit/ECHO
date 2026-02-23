# 14 — UI Design System
## ECHO AAC | Complete Visual Language

---

## Colors

```dart
// lib/core/constants/app_colors.dart
class AppColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceElevated = Color(0xFF1C2128);
  static const border = Color(0xFF30363D);
  static const borderFocus = Color(0xFF58A6FF);
  static const gazeBlue = Color(0xFF58A6FF);
  static const selectionGreen = Color(0xFF3FB950);
  static const emergencyRed = Color(0xFFF85149);
  static const speakPurple = Color(0xFFBC8CFF);
  static const amber = Color(0xFFF0A742);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);
}
```

## Typography

```dart
// lib/core/constants/app_typography.dart
class AppTypography {
  static TextStyle get keyLabel => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 18, color: AppColors.textPrimary);
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 16, color: AppColors.textSecondary);
  
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12, color: AppColors.textMuted);
}
```

## Spacing & Sizes

```dart
class AppDimensions {
  static const keyMinHeight = 70.0;     // WCAG AAA minimum touch target
  static const keyMinWidth = 60.0;
  static const borderRadius = 10.0;
  static const borderRadiusLarge = 16.0;
  static const padding = 12.0;
  static const paddingLarge = 24.0;
  static const cameraPreviewSize = 80.0;
}
```

## Theme

```dart
ThemeData get darkTheme => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.gazeBlue,
    secondary: AppColors.selectionGreen,
    error: AppColors.emergencyRed,
    surface: AppColors.surface,
    background: AppColors.background,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surface,
    elevation: 0,
    titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 18),
  ),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
);
```

## Animation Patterns

```dart
// Key selection bloom
widget.animate()
  .scale(begin: Offset(1.0, 1.0), end: Offset(1.15, 1.15), 
         duration: 75.ms, curve: Curves.easeOut)
  .then()
  .scale(begin: Offset(1.15, 1.15), end: Offset(1.0, 1.0), 
         duration: 75.ms);

// Prediction card entry
card.animate(delay: (index * 60).ms)
  .fadeIn(duration: 200.ms)
  .slideY(begin: 0.3, end: 0, duration: 200.ms, curve: Curves.easeOut);

// Emergency countdown scale
Text('$count').animate(key: ValueKey(count))
  .scale(begin: Offset(1.5, 1.5), end: Offset(1.0, 1.0), 
         duration: 300.ms, curve: Curves.elasticOut);
```

## Accessibility Checklist

- All interactive targets: minimum 70x70px ✓
- Text contrast: minimum 4.5:1 against backgrounds ✓
- High contrast mode toggle in settings ✓
- All icons paired with text labels ✓
- Screen always stays on during session ✓
- Font minimum size 14sp ✓

## 🤖 AI IDE Prompt — Design System

```
Apply the ECHO design system across all screens.

1. Create AppColors, AppTypography, AppDimensions constants files
2. Create darkTheme in app.dart using all constants
3. Apply to every screen: background #0D1117, surface #161B22, 
   all text using Inter, all buttons minimum 70x70px
4. Add flutter_animate to: key selection (bloom), prediction cards (slide),
   emergency countdown (scale), gaze cursor (smooth resize)
5. Add "High Contrast Mode" to Settings that bumps all text to white
   and increases border widths to 2px
```
