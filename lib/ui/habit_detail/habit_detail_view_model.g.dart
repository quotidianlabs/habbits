// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// View model for a single habit's detail screen. Watches its own habit through
/// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
/// go through the repository. Independent of the home list view model.

@ProviderFor(HabitDetailViewModel)
final habitDetailViewModelProvider = HabitDetailViewModelFamily._();

/// View model for a single habit's detail screen. Watches its own habit through
/// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
/// go through the repository. Independent of the home list view model.
final class HabitDetailViewModelProvider
    extends $StreamNotifierProvider<HabitDetailViewModel, HabitSummary?> {
  /// View model for a single habit's detail screen. Watches its own habit through
  /// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
  /// go through the repository. Independent of the home list view model.
  HabitDetailViewModelProvider._({
    required HabitDetailViewModelFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'habitDetailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$habitDetailViewModelHash();

  @override
  String toString() {
    return r'habitDetailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HabitDetailViewModel create() => HabitDetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is HabitDetailViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$habitDetailViewModelHash() =>
    r'1b07bcdfb4ec2f91eaa308b8878cf1297370a3a1';

/// View model for a single habit's detail screen. Watches its own habit through
/// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
/// go through the repository. Independent of the home list view model.

final class HabitDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          HabitDetailViewModel,
          AsyncValue<HabitSummary?>,
          HabitSummary?,
          Stream<HabitSummary?>,
          int
        > {
  HabitDetailViewModelFamily._()
    : super(
        retry: null,
        name: r'habitDetailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// View model for a single habit's detail screen. Watches its own habit through
  /// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
  /// go through the repository. Independent of the home list view model.

  HabitDetailViewModelProvider call(int habitId) =>
      HabitDetailViewModelProvider._(argument: habitId, from: this);

  @override
  String toString() => r'habitDetailViewModelProvider';
}

/// View model for a single habit's detail screen. Watches its own habit through
/// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
/// go through the repository. Independent of the home list view model.

abstract class _$HabitDetailViewModel extends $StreamNotifier<HabitSummary?> {
  late final _$args = ref.$arg as int;
  int get habitId => _$args;

  Stream<HabitSummary?> build(int habitId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HabitSummary?>, HabitSummary?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HabitSummary?>, HabitSummary?>,
              AsyncValue<HabitSummary?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
