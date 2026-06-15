import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/core/habit_colors.dart';

void main() {
  const habit = Color(0xFF009688);

  test('inactive cell is opaque on both brightnesses', () {
    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    expect(inactiveCellColor(habit, light).a, 1.0);
    expect(inactiveCellColor(habit, dark).a, 1.0);
  });

  test('inactive cell differs between light and dark surfaces', () {
    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    expect(
      inactiveCellColor(habit, light),
      isNot(inactiveCellColor(habit, dark)),
    );
  });
}
