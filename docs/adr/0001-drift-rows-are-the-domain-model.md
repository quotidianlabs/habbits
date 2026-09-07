# Drift rows are the domain model

**Decision:** Drift's generated row classes are used directly as domain models; there is no
mapper layer and no parallel hierarchy of hand-written entities. The consequence is that
`lib/domain/` imports the generated database library, and the layer rule is therefore narrower
than the usual formulation: **`lib/domain/` takes no direct `package:flutter` or `package:drift`
dependency, and its only dependency from `lib/data/` is the generated database library. Nothing
under `lib/domain/` or `lib/data/` depends on `lib/ui/`.**

The alternative is a mapper layer: hand-written domain entities plus functions converting rows
to them and back. That would buy a `domain/` with no knowledge of the persistence library at
all, at the cost of a second definition of every field, a conversion at every boundary, and a
class of bug where the two definitions drift apart. For an app whose domain logic is a handful
of pure functions over dates and integers, the mapper would be almost the entire domain layer
by volume, and it would exist to satisfy a diagram rather than to answer a question anyone has.

The reason this is worth recording is that the decision quietly falsifies the layering claim it
sits next to. The dependency arrow between `domain/` and `data/` genuinely points backwards,
and a reader who finds `import '../../data/services/database/database.dart'` at the top of a
file in `lib/domain/models/` will reasonably read it as a mistake and try to "fix" it. It is not
a mistake; removing it means adopting the mapper. The narrow rule above is what is actually true
and is what `test/architecture_test.dart` enforces, so the boundary that still matters - no
Flutter and no Drift API reaching into pure logic, and no layer reaching up into the UI - stays
checked rather than merely asserted.

`lib/main.dart` is deliberately outside the rule. It is the composition root and imports `ui/`
by definition; a rule reading "nothing imports `ui/`" is false and always was.

**Revisit trigger:** a second import from `lib/data/` appears in `lib/domain/`, or domain logic
grows to where a row's shape and the logic's needs genuinely diverge - a field the database
stores that the logic must not see, or a value the logic needs that no column holds. Either
makes the mapper earn its keep.
