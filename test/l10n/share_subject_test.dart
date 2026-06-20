import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/l10n/app_localizations_en.dart';
import 'package:habbits/l10n/app_localizations_ru.dart';

void main() {
  test('backup share subject is localized per locale', () {
    expect(AppLocalizationsEn().backupShareSubject, 'Habbits backup');
    expect(AppLocalizationsRu().backupShareSubject, 'Резервная копия Habbits');
  });
}
