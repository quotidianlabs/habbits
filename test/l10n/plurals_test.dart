import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/l10n/app_localizations_ru.dart';

/// Guards the Russian CLDR plural categories (one/few/many) for the
/// counted-noun strings — the most fragile part of the ARB translations.
void main() {
  final ru = AppLocalizationsRu();

  test('importedHabits picks the right Russian plural form', () {
    expect(ru.importedHabits(1), 'Импортирована 1 привычка'); // one
    expect(ru.importedHabits(2), 'Импортированы 2 привычки'); // few
    expect(ru.importedHabits(5), 'Импортировано 5 привычек'); // many
    expect(ru.importedHabits(21), 'Импортирована 21 привычка'); // one (21)
    expect(ru.importedHabits(11), 'Импортировано 11 привычек'); // many (11)
  });

  test('replaceBody count phrase uses the right Russian plural noun', () {
    expect(ru.replaceBody(1), contains('1 привычка')); // one
    expect(ru.replaceBody(3), contains('3 привычки')); // few
    expect(ru.replaceBody(5), contains('5 привычек')); // many
  });
}
