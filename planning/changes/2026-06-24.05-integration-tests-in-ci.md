---
summary: Run the critical-flow integration test in CI on a KVM-accelerated Android emulator, so on-device regressions can't rot unnoticed.
---

# Change: Run integration tests in CI

**Lane:** lightweight — one CI job in `ci.yml` + a `deferred.md` removal. No source
or test change (the test itself was fixed in #27).

## Goal

`integration_test/critical_flow_test.dart` runs only locally; CI's `just test` is
`flutter test` (unit/widget only). That gap let the critical-flow test rot red for
~10 days after i18n localized the home screen, caught only by a manual run (#27).
Add a CI job that runs it on an emulator so the regression surfaces automatically.

## Approach

A new `integration` job in `.github/workflows/ci.yml`, on `ubuntu-latest`, using
[`reactivecircus/android-emulator-runner@v2`](https://github.com/ReactiveCircus/android-emulator-runner)
with KVM hardware acceleration. Steps: checkout → `subosito/flutter-action` →
enable KVM (udev rule) → `flutter pub get` → emulator-runner whose `script` is
`flutter test integration_test/critical_flow_test.dart`. Config: `api-level: 34`,
`target: google_apis`, `arch: x86_64`, headless emulator options, `timeout-minutes: 20`.

Runs on the existing triggers (PRs + push to main), in parallel with lint/test —
so it catches rot *before* merge without slowing unit feedback.

### Why this shape (rejected alternatives)

- **`ubuntu-latest`, not a macOS runner.** GitHub gave standard 2-vCPU Linux
  runners KVM hardware acceleration in [April 2024](https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/);
  the action's own docs now recommend Ubuntu as "2–3× faster than the macOS ones."
  macOS runners cost ~10× the minutes for no benefit here.
- **`integration_test`, not Patrol.** Patrol earns its keep only for *native*
  interactions (permission dialogs, system UI); the critical-flow test needs none,
  and multiple 2025–26 sources flag Patrol as CI-unstable / debugging-heavy.
- **Self-hosted emulator-runner, not Firebase Test Lab.** FTL adds an external
  service, auth, and cost for a single test — disproportionate.
- **No AVD snapshot caching in v1.** It's the canonical speed optimization but adds
  an `actions/cache` + a second runner step. Start with the simplest reliable
  version; add caching only if the ~5–8 min job time warrants it.
- **Only `critical_flow_test.dart`.** `screenshots_test.dart` is a screenshot
  *generator* (see `docs/screenshots.md`), not a pass/fail test — kept out of CI.

## Files

- `.github/workflows/ci.yml` — add the `integration` job.
- `planning/deferred.md` — remove the now-resolved "Integration tests don't run in
  CI" item (added in #27).

## Verification

- [ ] Push the branch; the `integration` job appears and **passes** on the real
  runner (the only true test of a CI workflow — can't be run locally).
- [ ] Confirm the emulator boots with KVM accel and `flutter test
  integration_test/critical_flow_test.dart` is green in the job log.
- [ ] `lint` + `test` jobs unaffected.
