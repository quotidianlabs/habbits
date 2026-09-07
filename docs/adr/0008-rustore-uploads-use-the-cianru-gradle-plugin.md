# RuStore uploads use the cianru Gradle plugin

**Decision:** CI uploads the release APK to RuStore with
`ru.cian.rustore-publish-gradle-plugin`, applied unconditionally in the Android app's Gradle
`plugins {}` block and fed a credential from the `RUSTORE_CREDENTIALS` secret.

RuStore has no first-party GitHub Action, and its public API authenticates by RSA-signing a
timestamp with a private key to mint a short-lived token. Three options were on the table: the
maintained Gradle plugin, a hand-written shell or Python script calling the API directly, or no
automation at all.

The plugin was chosen because the authentication is exactly the sort of fiddly cryptography a
maintained dependency should own. Re-implementing the signing, the token handling and the
multi-call upload-and-submit flow by hand is fragile and buys nothing. Manual upload was rejected
because releases are frequent enough to be worth automating and the automation already exists on
the other side of the pipeline.

The plugin's one real cost is that it couples publishing into the Gradle build. That is mitigated
by how it is applied: it registers only **inert** `publishRustore*` tasks and changes no build
output, and the upload runs solely in the guarded stable-tag release step. Applying it
conditionally behind a Gradle property was considered and rejected - configuring its extension
that way requires naming the plugin's extension class, which is undocumented. Neither
`flutter analyze` nor `flutter test` touches Gradle at all, so the plugin is resolved only by an
actual `flutter build`.

**Revisit trigger:** the plugin becomes unmaintained or breaks against a RuStore API change, or
RuStore ships a first-party Action or a simple token-exchange auth needing no local key signing.
Either makes a thin CI script the lighter option.
