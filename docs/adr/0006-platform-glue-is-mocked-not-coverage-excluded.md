# Platform glue is mocked, not coverage-excluded

**Decision:** The notification and backup boundaries - the code that calls method-channel
plugins for local notifications, timezones, sharing, file picking and paths - are covered by
tests that inject doubles through the seams those plugins already expose. They are not excluded
from the coverage report as irreducible glue. This costs one dev-only dependency, `mocktail`.

The alternative, and the path the sibling repo took for its own database connection, is to
declare plugin-calling files untestable and glob them out of the coverage report. That keeps the
dependency list shorter and the 100% gate honest-looking, at the price of leaving real
sequencing logic unchecked: the order in which the schedule is cancelled and rebuilt, the
once-per-session permission prompt, and the decode-then-confirm-then-write path of an import all
live in files that touch a plugin. Excluding them exempts exactly the code where an ordering
mistake is invisible until a device misbehaves.

The seams were already there, which is what made this cheap: the notification service accepts an
optional plugin instance, and the share, file-picker and path-provider packages each expose a
settable platform instance. So the doubles are ordinary typed mocks rather than hand-written
method-channel handlers. The one exception is the static timezone lookup, which has no injection
seam and is covered with the test framework's built-in mock method-call handler.

`mocktail` was preferred over a no-dependency raw-channel approach for a specific reason rather
than familiarity: the notifications plugin cannot be subclassed, because its generative
constructor is private. Without a mocking library the no-dependency path means guessing the
plugin's channel method names and the exact shape of its permission reply map, and those are
undocumented internals that change between releases. Stubbing typed methods is both shorter and
less brittle.

The consequence is that the only file-level coverage exclusions beyond generated code are the
database connection and its provider wiring, and this reverses an earlier position that the
schedule-pushing plugin calls were not worth a test.

**Revisit trigger:** a plugin drops the injection seam this relies on, or a boundary appears
whose only test would be a hand-written method-channel handler. At that point excluding the file
is cheaper than the test that could be written for it.
