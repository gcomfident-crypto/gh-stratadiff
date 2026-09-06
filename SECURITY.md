# Security policy

## Distribution boundary

`gh-stratadiff` publishes renamed copies of binaries from one fixed upstream repository:
`gcomfident-crypto/stratadiff`. Release tags must be stable semantic versions and must match the
upstream tag exactly. Forks, alternate repositories, mutable releases, drafts, prereleases,
unverifiable tags, self-hosted attestation runners, unexpected assets, and version mismatches fail
closed.

The upstream release installer owns checksum and upstream build-attestation verification. This
repository fetches that installer from the fully dereferenced immutable upstream commit instead of
copying its logic. The extension workflow then attests the renamed bytes again so consumers can
verify both the upstream build and this distribution step.

The standard `gh extension install` command downloads the matching release asset over GitHub's API
but does not automatically evaluate adjacent checksum or provenance files for third-party
extensions. Users who need an independent verification step should follow the release-integrity
commands in the README before installation.

`inbox` retrieves review metadata through GitHub CLI authentication. `resume` may fetch exact Git
objects required for local analysis. Source analysis and the Workbench run locally; the extension
does not grant itself approval authority or carry GitHub approval state forward.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for this repository. If the issue is in the review
engine rather than its extension packaging, report it privately to
[`gcomfident-crypto/stratadiff`](https://github.com/gcomfident-crypto/stratadiff/security).

Do not include access tokens, private source, or private pull-request metadata in a public issue.
