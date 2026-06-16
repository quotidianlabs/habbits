import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/ui/core/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromStorage falls back to system on null/unknown', () {
    expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
    expect(AppThemeMode.fromStorage('xx'), AppThemeMode.system);
    expect(AppThemeMode.fromStorage('light'), AppThemeMode.light);
    expect(AppThemeMode.fromStorage('dark'), AppThemeMode.dark);
  });

  test('maps to Flutter ThemeMode', () {
    expect(AppThemeMode.system.themeMode, ThemeMode.system);
    expect(AppThemeMode.light.themeMode, ThemeMode.light);
    expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
  });

  test('defaults to system when nothing stored', () async {
    final c = await _container({});
    expect(c.read(themeControllerProvider), AppThemeMode.system);
  });

  test('reads a persisted value', () async {
    final c = await _container({'theme': 'dark'});
    expect(c.read(themeControllerProvider), AppThemeMode.dark);
  });

  test('set persists to prefs and updates state', () async {
    final c = await _container({});
    await c.read(themeControllerProvider.notifier).set(AppThemeMode.dark);
    expect(c.read(themeControllerProvider), AppThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme'), 'dark');
  });
}
