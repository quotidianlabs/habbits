import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/dates.dart';

part 'current_day.g.dart';

/// The current local calendar day (date-only). Holds only state — the timer and
/// lifecycle wiring that keep it live live in [CurrentDayTicker], so the provider
/// itself is pure and safe to build in headless tests without overrides.
@Riverpod(keepAlive: true)
class CurrentDay extends _$CurrentDay {
  @override
  DateTime build() => dateOnly(DateTime.now());

  /// Recompute from the wall clock; emits only when the day actually changed, so
  /// a same-day refresh is a no-op (no spurious rebuild of dependents).
  void refresh() {
    final today = dateOnly(DateTime.now());
    if (today != state) state = today;
  }
}

/// Drives [currentDayProvider] from real time so views derived from "today"
/// don't go stale across midnight: re-arms a timer at the next local midnight
/// (covers the app open in the foreground) and refreshes on app resume (covers
/// returning from the background). Renders [child] unchanged.
class CurrentDayTicker extends ConsumerStatefulWidget {
  const CurrentDayTicker({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CurrentDayTicker> createState() => _CurrentDayTickerState();
}

class _CurrentDayTickerState extends ConsumerState<CurrentDayTicker> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(nextLocalMidnight(now).difference(now), () {
      _refresh();
      _arm();
    });
  }

  void _refresh() => ref.read(currentDayProvider.notifier).refresh();

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
