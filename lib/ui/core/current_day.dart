import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/dates.dart';

part 'current_day.g.dart';

/// The current local calendar day (date-only), kept live so views derived from
/// "today" don't go stale across midnight. A timer fires at the next local
/// midnight (covers the app sitting open in the foreground); an app-resume
/// refresh corrects immediately when returning from the background. State only
/// changes when the day actually rolls over, so same-day resumes are no-ops.
@Riverpod(keepAlive: true)
class CurrentDay extends _$CurrentDay {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    _arm();
    return dateOnly(DateTime.now());
  }

  void _arm() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(nextLocalMidnight(now).difference(now), () {
      _refresh();
      _arm();
    });
  }

  void _refresh() {
    final today = dateOnly(DateTime.now());
    if (today != state) state = today;
  }
}
