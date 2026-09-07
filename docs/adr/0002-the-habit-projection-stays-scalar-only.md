# The habit projection stays scalar-only

**Decision:** The per-habit projection composes only the *scalars* — streak, done-today,
completion percent, and the normalized completion-date set. The calendar builders that produce
the heatmap grid and the recent-days list stay pure functions called by the widgets; they are
**not** folded into the projection.

An architecture review proposed a single projection module owning the whole "completions plus
today to display shape" derivation — the scalars *and* the calendar grids — so that both screens
would cross one interface. The scalar half shipped and deliberately stopped there. This records
why, so that a later reader does not "finish the job".

The two halves have different shapes of input. The scalars take no view parameters: for a given
habit and today there is exactly one correct streak, one completion percent, one done-today.
That single-valuedness is what makes one home worthwhile — every caller wants the same answer,
and the normalization rule can live at the interface. The calendar builders are parameterized by
view-specific layout instead: the heatmap asks for a number of weeks, the home day-strip and the
detail list ask for different numbers of days. Those counts are properties of the *view*, not of
the habit.

Folding the builders in would force one of two things: a single fixed layout for every caller,
which is wrong because the strip and the list genuinely differ, or threading layout parameters
through the projection, which relocates the call without adding cohesion. Either way there is no
shared answer to concentrate. Kept pure, the builders also stay independently testable and
reusable by any widget without first constructing a projection. The seam is drawn at
single-valued-per-habit: scalars in, layout-parameterized grids out.

**Revisit trigger:** either a third caller needs the heatmap or recent-days with the *same*
layout parameters, so a shared default appears that is worth a home, or the scalar/calendar
split causes a real normalization bug — today normalized in two places and drifting. The first
makes a unified projection that accepts layout parameters earn its keep; the second makes it
necessary.
