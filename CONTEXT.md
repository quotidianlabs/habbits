# Habbits

A local-first habit tracker for iOS and Android, in English and Russian. Habits and their
daily completions live in a SQLite database on the device; there is no backend and no cloud
sync.

## Language

A term is listed only when there is a synonym to reject, or a meaning subtle enough that code
and docs must agree on it. General programming vocabulary does not belong here.

**Habbits**:
The product, spelled with two b's. The entity it tracks is a **habit**, spelled normally. The
brand name is never localized and never appears in the ARB files.
_Avoid_: "habits" as a name for the app.

**Completion**:
The record that one habit was done on one local date. A day is either completed or not — there
is no partial mark and no duplicate: `(habit, local date)` identifies at most one completion.
Checking a habit off creates one; checking it off again deletes it.

**Local date**:
A calendar day in the device's local wall-clock zone, with no time of day. Every completion is
filed under one, and every date comparison in the app is a comparison of local dates — so a
daylight-saving transition never shifts a day count, and a completion never lands on the
neighbouring day because of a timestamp.

**Today**:
The local date the app is currently showing. It is a live value that advances at local midnight
and on resume, not a reading of the clock at render time. Every displayed figure and every
check-off derives from the same one, so a tap always records the day the user can see.

**Streak**:
The current unbroken run of completions ending at today, or at yesterday when today is not yet
done — a streak stays alive until a day actually lapses. It is derived on every render, never
stored. There is no best-ever or longest streak.

**Completion percent**:
The share of days completed in a rolling window of at most 30 days. The window is anchored at
the habit's **first completed day**, not the day it was created, so days before a habit was
started never dilute it and backfilled completions from before creation still count. A habit
with no completions has no window at all, and renders as "—" rather than 0%.

**Sort order**:
The explicit integer position of a habit in the home list. Values are always distinct, and
contiguous from zero immediately after a reorder — but deleting a habit leaves its number
unused, so a gap is normal and is not corruption. A new habit always takes a number past every
existing one.

**Reminder**:
A time of day at which one habit should notify, or its absence. What actually reaches the
operating system is a **scheduled reminder** — one habit's reminder expanded to one specific
future moment. The whole set is recomputed from scratch on every resync and is capped, so an
enabled reminder is not a promise that every one of its days is scheduled.

**Sync**:
Recomputing the scheduled reminders and handing them to the operating system. It never refers
to moving data off the device, which this app does not do.

**Backup**:
A single JSON document holding every habit and completion, written for the user to keep
wherever they choose. Importing one is replace-all: it discards the current contents entirely
rather than merging, and a file that fails validation changes nothing.
