// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'bdd76a73991d4d21e976c17fd4aedb14fec828aa';

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(habitDao)
final habitDaoProvider = HabitDaoProvider._();

final class HabitDaoProvider
    extends $FunctionalProvider<HabitDao, HabitDao, HabitDao>
    with $Provider<HabitDao> {
  HabitDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitDaoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitDaoHash();

  @$internal
  @override
  $ProviderElement<HabitDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HabitDao create(Ref ref) {
    return habitDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitDao>(value),
    );
  }
}

String _$habitDaoHash() => r'892f73680ea3bb12c9a457b8bbe7a4bb7e01b1ac';

/// A single habit's summary, derived from [habitListViewModelProvider]. Returns
/// null while loading or after the habit has been deleted.

@ProviderFor(habitDetail)
final habitDetailProvider = HabitDetailFamily._();

/// A single habit's summary, derived from [habitListViewModelProvider]. Returns
/// null while loading or after the habit has been deleted.

final class HabitDetailProvider
    extends $FunctionalProvider<HabitSummary?, HabitSummary?, HabitSummary?>
    with $Provider<HabitSummary?> {
  /// A single habit's summary, derived from [habitListViewModelProvider]. Returns
  /// null while loading or after the habit has been deleted.
  HabitDetailProvider._({
    required HabitDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'habitDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$habitDetailHash();

  @override
  String toString() {
    return r'habitDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<HabitSummary?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HabitSummary? create(Ref ref) {
    final argument = this.argument as int;
    return habitDetail(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitSummary? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitSummary?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HabitDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$habitDetailHash() => r'bb145620b88be621f660485ec1c186d3f41b4d6f';

/// A single habit's summary, derived from [habitListViewModelProvider]. Returns
/// null while loading or after the habit has been deleted.

final class HabitDetailFamily extends $Family
    with $FunctionalFamilyOverride<HabitSummary?, int> {
  HabitDetailFamily._()
    : super(
        retry: null,
        name: r'habitDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A single habit's summary, derived from [habitListViewModelProvider]. Returns
  /// null while loading or after the habit has been deleted.

  HabitDetailProvider call(int habitId) =>
      HabitDetailProvider._(argument: habitId, from: this);

  @override
  String toString() => r'habitDetailProvider';
}
