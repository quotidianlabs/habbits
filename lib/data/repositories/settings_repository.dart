import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_repository.g.dart';

/// The loaded SharedPreferences instance; overridden in `main()`.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
  'sharedPreferencesProvider must be overridden in main',
);

/// Persists app preferences (currently just the selected locale).
class SettingsRepository {
  SettingsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _localeKey = 'locale';

  String? readLocaleToken() => _prefs.getString(_localeKey);
  Future<void> writeLocaleToken(String token) =>
      _prefs.setString(_localeKey, token);

  static const _themeKey = 'theme';

  String? readThemeToken() => _prefs.getString(_themeKey);
  Future<void> writeThemeToken(String token) =>
      _prefs.setString(_themeKey, token);
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(sharedPreferencesProvider));
