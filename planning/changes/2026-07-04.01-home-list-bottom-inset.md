---
summary: Pad the home list's scroll extent past the Android system nav bar and the FAB so the last habit card is fully reachable.
---

# Change: Home list clears the system nav bar and FAB

**Lane:** lightweight — ~3 LOC in one source file, one widget test added to the
existing screen test, no new file, no public-API change.

## Goal

On Android edge-to-edge the home list scrolls, but its scroll extent ends flush
with the screen bottom. The last habit card ends up underneath the system
navigation buttons (and the FAB), with no way to lift it clear. Add bottom
padding so the final card scrolls fully into the safe region.

## Approach

`HabitListScreen` builds the list with
`padding: const EdgeInsets.symmetric(vertical: 6)`, which ignores the bottom
system inset. Replace the constant bottom with the system inset plus FAB
clearance so scroll content can clear both obstructions while the list
background still renders edge-to-edge (the modern Android pattern; a `SafeArea`
wrap was rejected because it shrinks the viewport and stops content scrolling
under the translucent bar).

```dart
// _fabClearance = 88 (56 FAB + 16 margin + 16 breathing room)
padding: EdgeInsets.only(
  top: 6,
  bottom: 6 + _fabClearance + MediaQuery.viewPaddingOf(context).bottom,
),
```

During implementation, confirm which `MediaQuery` property (`viewPaddingOf` vs
`paddingOf`) reflects the nav bar inside the Scaffold body and use that one.

No capability contract moves; this is a home-list rendering fix. Add a one-line
note to `architecture/habit-tracking.md` "Known edges".

## Files

- `lib/ui/habit_list/habit_list_screen.dart` — inset- and FAB-aware bottom padding
- `test/ui/habit_list/habit_list_screen_test.dart` — new widget test
- `architecture/habit-tracking.md` — Known edges note

## Verification

- [ ] Failing test first: with a faked bottom `viewPadding` and enough habits to
  overflow, scroll to the end and assert the last card's bottom is within the
  safe region — fails against current code.
- [ ] Apply the padding change.
- [ ] Test passes.
- [ ] `just test` — full suite green.
- [ ] `just lint` — clean.
