# No runtime schema self-check

**Decision:** The app does not call Drift's `validateDatabaseSchema()` when opening the
database. Schema drift is caught in CI instead, by re-dumping the schema and regenerating the
migration helpers and failing if either differs from what is committed.

The runtime check is attractive: it compares the live database against the declared schema at
startup and would catch a migration bug on a real device, where the CI gate only ever sees a
freshly built database. It was rejected on a dependency argument. `validateDatabaseSchema` is
exported from `drift_dev`, the code generator — not from the runtime `drift` package. Calling it
from `lib/` puts the analyzer and build stack into the application's *runtime* dependency graph,
for a check that runs once per launch and answers a question CI already answers before the code
ships.

The two are not equivalent, and it is worth being precise about the gap rather than pretending
the CI gate is a superset. The CI gate proves that the committed schema artifacts match the
declared tables; it cannot prove that a migration executed against a database with real user
data in it produces the declared shape. That is the case the runtime check would cover and the
one that stays uncovered. It is accepted because there are no migrations yet — the schema is at
version 1 — so there is currently no migration that could go wrong on a device.

**Revisit trigger:** a debug-build startup self-check becomes wanted — most likely right after a
migration bug reaches a device past CI — *and* a way is confirmed to invoke the validation
without adding `drift_dev` to runtime dependencies. Both halves are required; the first alone
does not justify the dependency.
