import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads and writes the locale token', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.readLocaleToken(), isNull);
    await repo.writeLocaleToken('ru');
    expect(repo.readLocaleToken(), 'ru');
  });

  test('reads a preexisting token', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.readLocaleToken(), 'en');
  });

  test('overwrites an existing token', () async {
    SharedPreferences.setMockInitialValues({'locale': 'ru'});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    await repo.writeLocaleToken('en');
    expect(repo.readLocaleToken(), 'en');
  });

  test('reads and writes the theme token', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.readThemeToken(), isNull);
    await repo.writeThemeToken('dark');
    expect(repo.readThemeToken(), 'dark');
  });

  test('sharedPreferencesProvider throws until overridden in main', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(sharedPreferencesProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
