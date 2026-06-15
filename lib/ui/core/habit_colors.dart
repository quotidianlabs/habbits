import 'package:flutter/material.dart';

/// Default color for a newly created habit (Material teal).
const int kDefaultHabitColor = 0xFF009688;

/// Curated habit colors, each vetted to read on light and dark surfaces.
/// [kDefaultHabitColor] (teal) is first.
const List<int> kHabitPalette = [
  0xFF009688, // teal
  0xFF1E88E5, // blue
  0xFF5E35B1, // deep purple
  0xFFD81B60, // pink
  0xFFE53935, // red
  0xFFF4511E, // deep orange
  0xFFFB8C00, // orange
  0xFF43A047, // green
  0xFF00897B, // teal-green
  0xFF6D4C41, // brown
];

/// The color for a not-completed activity cell of a habit colored
/// [habitColor], composited over [scheme.surface] so it is opaque and
/// visible on either brightness. Dark surfaces use a stronger tint.
Color inactiveCellColor(Color habitColor, ColorScheme scheme) =>
    Color.alphaBlend(
      habitColor.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.30 : 0.15,
      ),
      scheme.surface,
    );
