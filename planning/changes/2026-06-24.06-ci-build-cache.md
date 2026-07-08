---
summary: Cache the Gradle build and the emulator system image in the integration CI job (the measured bottleneck), skipping AVD snapshot caching as ineffective here.
---

# Change: Cache the integration job's Gradle build + system image

**Lane:** lightweight — three cache steps in the `integration` job of `ci.yml`.

## Goal

The `integration` job (added in #28) takes ~8 min, all of it inside the
emulator-runner step. Speed it up by caching the parts that dominate.

## Approach

**Measured the real breakdown first** (job 83210414425 step log), rather than
optimizing by assumption:

| Phase | Cold time |
|-------|-----------|
| System-image download + install + AVD create | ~42s |
| Emulator **cold boot** | 39s |
| **Gradle `assembleDebug`** (downloads Gradle/NDK/CMake/deps, compiles) | **330s** |
| Install APK + run test | ~12s |

So the Gradle build is ~76% of the job; the emulator boot is 39s. This inverts
the original "AVD snapshot caching" idea — a snapshot only turns the 39s cold
boot into a ~5s quick boot (and doesn't even cover the system-image download),
so it'd save <10% while adding snapshot-corruption/parallel-hang gotchas
([emulator-snapshots docs](https://developer.android.com/studio/run/emulator-snapshots),
[android-emulator-runner #362](https://github.com/ReactiveCircus/android-emulator-runner)).
**AVD snapshot caching is therefore deliberately not used.**

Instead, target the build:

- **Gradle cache** — `~/.gradle/caches` + `~/.gradle/wrapper`, keyed on the
  Gradle scripts + wrapper + `pubspec.lock`, with a `gradle-` restore-key for
  partial hits. Reuses downloaded deps/NDK/CMake and the build cache across runs.
- **System-image cache** — the specific `system-images/android-34/google_apis/
  x86_64` dir (path resolved from `$ANDROID_SDK_ROOT` at runtime, not hard-coded),
  keyed on api/target/arch. Scoped tightly to avoid the broken-SDK-path PANICs
  reported when the whole SDK is cached.

First (cold) run populates the caches; subsequent (warm) runs reuse them.

## Files

- `.github/workflows/ci.yml` — add `Gradle cache`, `Resolve system-image path`,
  and `System-image cache` steps to the `integration` job.

## Verification

- [ ] Cold run (cache miss) still green; caches saved.
- [ ] Warm run (cache hit) green and measurably faster — record the before/after
  job duration.
- [ ] If the system-image cache breaks emulator startup, drop it and keep only
  the Gradle cache (the high-value half).
