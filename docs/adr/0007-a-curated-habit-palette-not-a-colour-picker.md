# A curated habit palette, not a colour picker

**Decision:** A habit's colour is chosen from a fixed, curated swatch list. There is no
arbitrary colour picker - no hue wheel, no RGB sliders, no hex entry.

The app renders each habit's colour on two surfaces it does not control the pairing of: at full
strength for completed cells, and composited over the current surface colour at low alpha for
inactive ones, in both light and dark themes. An arbitrary colour makes that a user problem. Pale
yellow vanishes against a light surface; a near-black choice is indistinguishable from an empty
cell in dark mode. Every entry in the curated palette has been checked to stay legible in all
four combinations, which is a guarantee a picker cannot offer and which the user should not have
to discover by trial.

The secondary reason is that a picker is a dependency or a bespoke widget, and neither is worth
adding for a choice made once per habit. The cost is real but narrow: a user who wants a specific
brand colour cannot have it, and adding one means editing the palette rather than changing a
setting.

Two related refusals sit with this one. A habit keeps its single stored colour across theme
modes - only the surrounding chrome and the inactive-cell tint adapt to brightness - because a
habit's colour is its identity and should not change when the sun goes down. And existing habits
were not migrated when the palette was introduced; they keep whatever value they had stored.

**Revisit trigger:** the palette stops covering real demand - repeated requests for a specific
colour, or enough habits that users run out of distinguishable swatches. The answer then is a
larger vetted palette first, and a picker with an enforced contrast floor only if that fails.
