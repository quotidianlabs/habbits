// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].

@ProviderFor(HabitDetailViewModel)
final habitDetailViewModelProvider = HabitDetailViewModelFamily._();

/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].
final class HabitDetailViewModelProvider
    extends $NotifierProvider<HabitDetailViewModel, HabitSummary?> {
  /// View model for a single habit's detail screen. State derives from the list
  /// view model; commands go through [HabitRepository].
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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitSummary? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitSummary?>(value),
    );
  }

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
    r'd3facb4692a329a604ba96ad085648df4b28605e';

/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].

final class HabitDetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          HabitDetailViewModel,
          HabitSummary?,
          HabitSummary?,
          HabitSummary?,
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

  /// View model for a single habit's detail screen. State derives from the list
  /// view model; commands go through [HabitRepository].

  HabitDetailViewModelProvider call(int habitId) =>
      HabitDetailViewModelProvider._(argument: habitId, from: this);

  @override
  String toString() => r'habitDetailViewModelProvider';
}

/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].

abstract class _$HabitDetailViewModel extends $Notifier<HabitSummary?> {
  late final _$args = ref.$arg as int;
  int get habitId => _$args;

  HabitSummary? build(int habitId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HabitSummary?, HabitSummary?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HabitSummary?, HabitSummary?>,
              HabitSummary?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
