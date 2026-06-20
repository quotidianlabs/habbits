// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_day.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current local calendar day (date-only). Holds only state — the timer and
/// lifecycle wiring that keep it live live in [CurrentDayTicker], so the provider
/// itself is pure and safe to build in headless tests without overrides.

@ProviderFor(CurrentDay)
final currentDayProvider = CurrentDayProvider._();

/// The current local calendar day (date-only). Holds only state — the timer and
/// lifecycle wiring that keep it live live in [CurrentDayTicker], so the provider
/// itself is pure and safe to build in headless tests without overrides.
final class CurrentDayProvider extends $NotifierProvider<CurrentDay, DateTime> {
  /// The current local calendar day (date-only). Holds only state — the timer and
  /// lifecycle wiring that keep it live live in [CurrentDayTicker], so the provider
  /// itself is pure and safe to build in headless tests without overrides.
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

String _$currentDayHash() => r'df5bd4b66c8e111ebc792a56ebdc38aba5f72d60';

/// The current local calendar day (date-only). Holds only state — the timer and
/// lifecycle wiring that keep it live live in [CurrentDayTicker], so the provider
/// itself is pure and safe to build in headless tests without overrides.

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
