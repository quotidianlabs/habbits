/// Serializes an async task so two runs never overlap. If [run] is called while
/// a task is in flight, a single follow-up run is coalesced to execute once the
/// current one finishes — so the latest request is always honored without
/// interleaving (e.g. a `cancelAll()` + reschedule sequence).
class CoalescingRunner {
  bool _running = false;
  bool _pending = false;

  Future<void> run(Future<void> Function() task) async {
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      _pending = false;
      await task();
      while (_pending) {
        _pending = false;
        await task();
      }
    } finally {
      _running = false;
    }
  }
}
