# Completion percent anchors at the first completed day

**Decision:** The rolling completion-percent window is anchored at a habit's earliest completed
day, not at the date the habit was created. A habit with no completions has no window and
renders as "-" rather than 0%.

The creation date was the original anchor and it broke in two ways once retroactive editing let
a user check off days *earlier* than the habit existed. Those completions fell outside the
window and never counted at all. And the denominator measured how long ago the habit was created
rather than how long it had actually been running, so a habit created months ago and started
last week was diluted by its own empty prehistory.

Anchoring at the first completed day fixes both, and it changes what the metric means: it now
answers "how consistent have you been since you started" rather than "since you created this".
The 30-day cap is unchanged, so an established habit sees exactly what it saw before; only the
anchor of a shorter-than-30-day window moves. The creation date remains on the habit for backup
and ordering - it simply stops feeding this metric.

The visible consequence was accepted deliberately: a habit created some days ago with zero
completions used to show 0% and now shows "-". With nothing completed there is no first day and
therefore no window, so "no window yet" is the truthful rendering, and it avoids opening with a
zero score against a habit nobody has started.

**Revisit trigger:** a second metric appears that must be comparable with this one across habits
a leaderboard, a cross-habit average, or an export consumed by something that cannot represent
"no window". A shared denominator matters more than a truthful one as soon as two numbers are
placed side by side.
