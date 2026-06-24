// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_list_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].

@ProviderFor(HabitListViewModel)
final habitListViewModelProvider = HabitListViewModelProvider._();

/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].
final class HabitListViewModelProvider
    extends $StreamNotifierProvider<HabitListViewModel, List<HabitSummary>> {
  /// View model for the home list: the summaries stream + check-off / reorder /
  /// create commands. Depends only on [HabitRepository].
  HabitListViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitListViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitListViewModelHash();

  @$internal
  @override
  HabitListViewModel create() => HabitListViewModel();
}

String _$habitListViewModelHash() =>
    r'c3a6293cae8a4ad1d42a9cb024a4d2dbc512e31c';

/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].

abstract class _$HabitListViewModel
    extends $StreamNotifier<List<HabitSummary>> {
  Stream<List<HabitSummary>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<HabitSummary>>, List<HabitSummary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<HabitSummary>>, List<HabitSummary>>,
              AsyncValue<List<HabitSummary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
