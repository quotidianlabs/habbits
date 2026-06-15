// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The loaded SharedPreferences instance. Overridden in `main()` after the async
/// load, mirroring how `notificationServiceProvider` is overridden.

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

/// The loaded SharedPreferences instance. Overridden in `main()` after the async
/// load, mirroring how `notificationServiceProvider` is overridden.

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          SharedPreferences,
          SharedPreferences,
          SharedPreferences
        >
    with $Provider<SharedPreferences> {
  /// The loaded SharedPreferences instance. Overridden in `main()` after the async
  /// load, mirroring how `notificationServiceProvider` is overridden.
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'8b8609a69f8bca672db9335195daeb53193372ec';

/// Holds the selected [AppLocale], backed by shared_preferences.

@ProviderFor(LocaleController)
final localeControllerProvider = LocaleControllerProvider._();

/// Holds the selected [AppLocale], backed by shared_preferences.
final class LocaleControllerProvider
    extends $NotifierProvider<LocaleController, AppLocale> {
  /// Holds the selected [AppLocale], backed by shared_preferences.
  LocaleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeControllerHash();

  @$internal
  @override
  LocaleController create() => LocaleController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLocale value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLocale>(value),
    );
  }
}

String _$localeControllerHash() => r'57ada211e14c3b81d3291e12d8d3d383d4b4a5ca';

/// Holds the selected [AppLocale], backed by shared_preferences.

abstract class _$LocaleController extends $Notifier<AppLocale> {
  AppLocale build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLocale, AppLocale>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLocale, AppLocale>,
              AppLocale,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
