# The notification cap is not platform-gated

**Decision:** The 64-item ceiling on pending scheduled reminders is applied on every platform,
including Android, which has no such limit.

The ceiling exists because iOS refuses more than 64 pending local notifications per app. The
obvious refinement is to apply it only where it is real, letting Android schedule the full
14-day runway for every habit. That was rejected. The cap lives inside the pure scheduling
function, which is the single place the whole schedule is derived and which has no platform
knowledge by construction - it takes dates and reminders and returns scheduled reminders.
Teaching it the host platform means either passing a flag through from the caller or importing
a platform check into pure logic, and both trade a function that behaves identically everywhere
for one that has two behaviours and needs testing on both paths.

What the universal cap costs is bounded and small: it only binds on a user who has more than 64
reminder-enabled habits, or who wants a runway longer than the budget allows across many habits.
At that point Android users get the same soonest-first truncation iOS users get. Sixty-four
daily reminders is already far past the point where the notifications are useful, and the
Settings warning that fires at the threshold is written to be platform-neutral for the same
reason - it does not name iOS.

**Revisit trigger:** Android-only behaviour becomes a goal in its own right - a widget, a
longer-horizon planning surface, or a user report that the cap is binding on real Android
usage. At that point the platform belongs in the caller, which chooses a budget and passes it
in, not in the scheduling function.
