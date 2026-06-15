import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/core/theme.dart';

void main() {
  test('light theme is Material 3 and light', () {
    final t = habbitsLightTheme();
    expect(t.useMaterial3, isTrue);
    expect(t.brightness, Brightness.light);
  });

  test('dark theme is Material 3 and dark', () {
    final t = habbitsDarkTheme();
    expect(t.useMaterial3, isTrue);
    expect(t.brightness, Brightness.dark);
  });
}
