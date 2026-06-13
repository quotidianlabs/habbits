// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

@ProviderFor(habitSummaries)
final habitSummariesProvider = HabitSummariesProvider._();

final class HabitSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HabitSummary>>,
          List<HabitSummary>,
          Stream<List<HabitSummary>>
        >
    with
        $FutureModifier<List<HabitSummary>>,
        $StreamProvider<List<HabitSummary>> {
  HabitSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<HabitSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HabitSummary>> create(Ref ref) {
    return habitSummaries(ref);
  }
}

String _$habitSummariesHash() => r'be870af222c16ead97f4efdb557d89cdf0108985';

/// A single habit's summary, derived from [habitSummariesProvider]. Returns null
/// while loading or after the habit has been deleted.

@ProviderFor(habitDetail)
final habitDetailProvider = HabitDetailFamily._();

/// A single habit's summary, derived from [habitSummariesProvider]. Returns null
/// while loading or after the habit has been deleted.

final class HabitDetailProvider
    extends $FunctionalProvider<HabitSummary?, HabitSummary?, HabitSummary?>
    with $Provider<HabitSummary?> {
  /// A single habit's summary, derived from [habitSummariesProvider]. Returns null
  /// while loading or after the habit has been deleted.
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

String _$habitDetailHash() => r'454d42bf7d6d831e396fba3d40eea71aabe5558b';

/// A single habit's summary, derived from [habitSummariesProvider]. Returns null
/// while loading or after the habit has been deleted.

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

  /// A single habit's summary, derived from [habitSummariesProvider]. Returns null
  /// while loading or after the habit has been deleted.

  HabitDetailProvider call(int habitId) =>
      HabitDetailProvider._(argument: habitId, from: this);

  @override
  String toString() => r'habitDetailProvider';
}
