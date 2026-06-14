import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The loaded SharedPreferences instance. Overridden in `main()` after the async
/// load, mirroring how `notificationServiceProvider` is overridden.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main');

/// Holds the selected [AppLocale], backed by shared_preferences.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  static const _key = 'locale';

  @override
  AppLocale build() => AppLocale.fromStorage(
      ref.watch(sharedPreferencesProvider).getString(_key));

  Future<void> set(AppLocale value) async {
    await ref.read(sharedPreferencesProvider).setString(_key, value.storage);
    state = value;
  }
}
