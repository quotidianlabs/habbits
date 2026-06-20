// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_day.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current local calendar day (date-only), kept live so views derived from
/// "today" don't go stale across midnight. A timer fires at the next local
/// midnight (covers the app sitting open in the foreground); an app-resume
/// refresh corrects immediately when returning from the background. State only
/// changes when the day actually rolls over, so same-day resumes are no-ops.

@ProviderFor(CurrentDay)
final currentDayProvider = CurrentDayProvider._();

/// The current local calendar day (date-only), kept live so views derived from
/// "today" don't go stale across midnight. A timer fires at the next local
/// midnight (covers the app sitting open in the foreground); an app-resume
/// refresh corrects immediately when returning from the background. State only
/// changes when the day actually rolls over, so same-day resumes are no-ops.
final class CurrentDayProvider extends $NotifierProvider<CurrentDay, DateTime> {
  /// The current local calendar day (date-only), kept live so views derived from
  /// "today" don't go stale across midnight. A timer fires at the next local
  /// midnight (covers the app sitting open in the foreground); an app-resume
  /// refresh corrects immediately when returning from the background. State only
  /// changes when the day actually rolls over, so same-day resumes are no-ops.
  CurrentDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentDayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentDayHash();

  @$internal
  @override
  CurrentDay create() => CurrentDay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$currentDayHash() => r'5230b163df76aaa7f81fa2fe3085e8501df0f7b1';

/// The current local calendar day (date-only), kept live so views derived from
/// "today" don't go stale across midnight. A timer fires at the next local
/// midnight (covers the app sitting open in the foreground); an app-resume
/// refresh corrects immediately when returning from the background. State only
/// changes when the day actually rolls over, so same-day resumes are no-ops.

abstract class _$CurrentDay extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
