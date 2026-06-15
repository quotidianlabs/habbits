import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/settings_repository.dart';

part 'locale_controller.g.dart';

/// The user's language choice. [system] follows the device locale.
enum AppLocale {
  system('system', null),
  en('en', Locale('en')),
  ru('ru', Locale('ru'));

  const AppLocale(this.storage, this.locale);

  /// Stable token persisted to shared_preferences.
  final String storage;

  /// The forced locale, or null for [system] (let Flutter resolve the device).
  final Locale? locale;

  static AppLocale fromStorage(String? value) => AppLocale.values
      .firstWhere((e) => e.storage == value, orElse: () => AppLocale.system);
}

/// Holds the selected [AppLocale], backed by shared_preferences.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  AppLocale build() => AppLocale.fromStorage(
      ref.watch(settingsRepositoryProvider).readLocaleToken());

  Future<void> set(AppLocale value) async {
    await ref.read(settingsRepositoryProvider).writeLocaleToken(value.storage);
    state = value;
  }
}
