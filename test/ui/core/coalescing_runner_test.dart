import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/core/coalescing_runner.dart';

void main() {
  test('runs never overlap and a single follow-up is coalesced', () async {
    final runner = CoalescingRunner();
    var active = 0, maxActive = 0, calls = 0;
    final gate = Completer<void>();

    Future<void> task() async {
      calls++;
      active++;
      maxActive = max(maxActive, active);
      if (calls == 1) await gate.future; // hold the first run in flight
      active--;
    }

    final first = runner.run(task); // starts, awaits the gate
    runner.run(task); // in-flight -> mark pending
    runner.run(task); // already pending -> no extra run
    gate.complete();
    await first;

    expect(maxActive, 1); // never two at once
    expect(calls, 2); // the first run plus exactly one coalesced re-run
  });

  test('a later run after completion executes normally', () async {
    final runner = CoalescingRunner();
    var calls = 0;
    Future<void> task() async => calls++;

    await runner.run(task);
    await runner.run(task);

    expect(calls, 2);
  });
}
