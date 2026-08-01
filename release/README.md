# Sanad release contract

`release-contract.json` is the version, channel, artifact-name, platform, and
signature source of truth for the first stable release. The agent and client
pubspec versions, Git tag, build number, workflow outputs, installers, updater,
Appcast, checksums, and release documentation must agree with it.

The checked-in contract contains no generated hashes, signatures, timestamps,
or credentials. Release automation creates `release-manifest.json`,
`SHA256SUMS`, SBOMs, attestations, and `appcast.xml` only after every required
artifact has been built and signed. Generated release outputs are immutable and
must not be committed.

Public GitHub release assets use:

`<component>-<version>-<platform>-<architecture>.<extension>`

The stable channel never overwrites an existing tag or asset. Rollback means
promoting a previously verified immutable release; it never mutates an existing
release.
