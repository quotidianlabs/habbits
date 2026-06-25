// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get exportTitle => 'Export data';

  @override
  String get exportSubtitle => 'Save all habits and history to a JSON file';

  @override
  String get importTitle => 'Import data';

  @override
  String get importSubtitle => 'Replace all data from a JSON backup';

  @override
  String get exportFailed => 'Export failed.';

  @override
  String get couldntReadFile => 'Couldn\'t read that file.';

  @override
  String get invalidBackupFile => 'That file isn\'t a valid Habbits backup.';

  @override
  String get replaceTitle => 'Replace all data?';

  @override
  String replaceBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habits',
      one: '$count habit',
    );
    return 'This will replace all current habits and history with the file\'s contents ($_temp0). This cannot be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get replace => 'Replace';

  @override
  String get importFailed =>
      'Import failed. Your existing data was not changed.';

  @override
  String importedHabits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count habits',
      one: 'Imported $count habit',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get color => 'Color';

  @override
  String get noHabits => 'No habits yet. Tap + to add one.';

  @override
  String homeError(String error) {
    return 'Error: $error';
  }

  @override
  String streakLabel(int count) {
    return 'Streak: $count';
  }

  @override
  String dragToReorder(String name) {
    return 'Drag to reorder $name';
  }

  @override
  String thirtyDayLabel(String value) {
    return '30-day: $value';
  }

  @override
  String get reminderTitle => 'Reminder';

  @override
  String get reminderOff => 'Off';

  @override
  String get delete => 'Delete';

  @override
  String get newHabit => 'New habit';

  @override
  String get editHabit => 'Edit habit';

  @override
  String get nameLabel => 'Name';

  @override
  String get save => 'Save';

  @override
  String deleteHabitTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteHabitBody =>
      'This permanently deletes the habit and all its check-off history. This cannot be undone.';

  @override
  String todayPrefix(String date) {
    return 'Today · $date';
  }

  @override
  String get reminderBody => 'Time to check in';

  @override
  String get reminderChannelName => 'Habit reminders';

  @override
  String get reminderLimitTitle => 'Too many reminders';

  @override
  String reminderLimitBody(int count) {
    return 'No more than $count reminders can be scheduled at once, so some habits won\'t notify. Turn off reminders on a few habits.';
  }

  @override
  String get backupShareSubject => 'Habbits backup';

  @override
  String get notificationsOffTitle => 'Notifications are off';

  @override
  String get notificationsOffBody =>
      'Reminders won\'t fire until you enable notifications for Habbits in system settings.';
}
