// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Commands for the settings screen's data-management actions. The view keeps
/// ownership of snackbars/dialogs; this exposes the operations they call.

@ProviderFor(SettingsViewModel)
final settingsViewModelProvider = SettingsViewModelProvider._();

/// Commands for the settings screen's data-management actions. The view keeps
/// ownership of snackbars/dialogs; this exposes the operations they call.
final class SettingsViewModelProvider
    extends $NotifierProvider<SettingsViewModel, void> {
  /// Commands for the settings screen's data-management actions. The view keeps
  /// ownership of snackbars/dialogs; this exposes the operations they call.
  SettingsViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsViewModelHash();

  @$internal
  @override
  SettingsViewModel create() => SettingsViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$settingsViewModelHash() => r'2ab54a75750bbc74c87258450c5bcb7413320886';

/// Commands for the settings screen's data-management actions. The view keeps
/// ownership of snackbars/dialogs; this exposes the operations they call.

abstract class _$SettingsViewModel extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
