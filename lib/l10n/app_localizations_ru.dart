// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get settings => 'Настройки';

  @override
  String get exportTitle => 'Экспорт данных';

  @override
  String get exportSubtitle => 'Сохранить все привычки и историю в JSON-файл';

  @override
  String get importTitle => 'Импорт данных';

  @override
  String get importSubtitle => 'Заменить все данные из резервной копии JSON';

  @override
  String get exportFailed => 'Не удалось выполнить экспорт.';

  @override
  String get couldntReadFile => 'Не удалось прочитать файл.';

  @override
  String get invalidBackupFile => 'Это не похоже на резервную копию Habbits.';

  @override
  String get replaceTitle => 'Заменить все данные?';

  @override
  String replaceBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count привычки',
      many: '$count привычек',
      few: '$count привычки',
      one: '$count привычка',
    );
    return 'Все текущие привычки и история будут заменены содержимым файла ($_temp0). Это действие необратимо.';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get replace => 'Заменить';

  @override
  String get importFailed =>
      'Не удалось импортировать. Ваши данные не изменены.';

  @override
  String importedHabits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count привычки',
      many: 'Импортировано $count привычек',
      few: 'Импортированы $count привычки',
      one: 'Импортирована $count привычка',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный язык';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get color => 'Цвет';

  @override
  String get noHabits => 'Пока нет привычек. Нажмите +, чтобы добавить.';

  @override
  String homeError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String streakLabel(int count) {
    return 'Серия: $count';
  }

  @override
  String dragToReorder(String name) {
    return 'Перетащить для изменения порядка: $name';
  }

  @override
  String thirtyDayLabel(String value) {
    return '30 дней: $value';
  }

  @override
  String get reminderTitle => 'Напоминание';

  @override
  String get reminderOff => 'Отключено';

  @override
  String get delete => 'Удалить';

  @override
  String get newHabit => 'Новая привычка';

  @override
  String get editHabit => 'Изменить привычку';

  @override
  String get nameLabel => 'Название';

  @override
  String get save => 'Сохранить';

  @override
  String deleteHabitTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteHabitBody =>
      'Привычка и вся история отметок будут удалены без возможности восстановления.';

  @override
  String todayPrefix(String date) {
    return 'Сегодня · $date';
  }

  @override
  String get reminderBody => 'Пора отметиться';

  @override
  String get reminderLimitTitle => 'Слишком много напоминаний';

  @override
  String reminderLimitBody(int count) {
    return 'Одновременно можно запланировать не более $count напоминаний, поэтому часть привычек не будет уведомлять. Отключите напоминания у нескольких привычек.';
  }

  @override
  String get backupShareSubject => 'Резервная копия Habbits';
}
