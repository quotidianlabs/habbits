import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/ui/core/locale_controller.dart';
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
    expect(AppLocale.fromStorage(null), AppLocale.system);
    expect(AppLocale.fromStorage('xx'), AppLocale.system);
    expect(AppLocale.fromStorage('ru'), AppLocale.ru);
    expect(AppLocale.fromStorage('en'), AppLocale.en);
  });

  test('defaults to system when nothing stored', () async {
    final c = await _container({});
    expect(c.read(localeControllerProvider), AppLocale.system);
  });

  test('reads a persisted value', () async {
    final c = await _container({'locale': 'ru'});
    expect(c.read(localeControllerProvider), AppLocale.ru);
  });

  test('set persists to prefs and updates state', () async {
    final c = await _container({});
    await c.read(localeControllerProvider.notifier).set(AppLocale.en);
    expect(c.read(localeControllerProvider), AppLocale.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'en');
  });

  test('set overwrites an existing persisted value', () async {
    final c = await _container({'locale': 'ru'});
    expect(c.read(localeControllerProvider), AppLocale.ru);
    await c.read(localeControllerProvider.notifier).set(AppLocale.en);
    expect(c.read(localeControllerProvider), AppLocale.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'en');
  });
}
