import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/settings_repository.dart';

part 'theme_controller.g.dart';

/// The user's theme choice. [system] follows the device brightness.
enum AppThemeMode {
  system('system', ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const AppThemeMode(this.storage, this.themeMode);

  /// Stable token persisted to shared_preferences.
  final String storage;

  /// The Flutter [ThemeMode] this choice maps to.
  final ThemeMode themeMode;

  static AppThemeMode fromStorage(String? value) => AppThemeMode.values
      .firstWhere((e) => e.storage == value, orElse: () => AppThemeMode.system);
}

/// Holds the selected [AppThemeMode], backed by shared_preferences.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  AppThemeMode build() => AppThemeMode.fromStorage(
    ref.watch(settingsRepositoryProvider).readThemeToken(),
  );

  Future<void> set(AppThemeMode value) async {
    await ref.read(settingsRepositoryProvider).writeThemeToken(value.storage);
    state = value;
  }
}
