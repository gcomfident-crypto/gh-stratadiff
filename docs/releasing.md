# Release procedure

The extension version must be identical to a published immutable upstream StrataDiff version. The
upstream release must provide working `inbox` and `resume` commands before this repository is
tagged.

## One-time repository controls

1. Create the public `gcomfident-crypto/gh-stratadiff` repository with `main` as its default branch.
2. Enable immutable releases.
3. Add one active tag ruleset named `Protect immutable v* release tags` targeting only
   `refs/tags/v*`, with deletion and update restrictions, no exclusions, and no bypass actors.
4. Add the topics `gh-extension`, `code-review`, `pull-request`, `rebase`, `force-push`, and
   `stacked-pr`.

The local repository-policy gate requires Python 3 and an authenticated identity with repository
Administration write access. GitHub omits sensitive ruleset fields for insufficiently privileged
callers; missing, null, or nonempty `bypass_actors` all fail closed:

```console
scripts/check-repository-policy.sh
```

## Publish a version

From a clean checkout of the intended extension commit:

```console
scripts/ci.sh
scripts/check-repository-policy.sh
git tag -a v0.4.0 -m "gh-stratadiff v0.4.0"
git push origin v0.4.0
```

Use the actual upstream version instead of copying the example. The release workflow:

1. resolves both annotated tags to immutable commits;
2. rejects a draft, prerelease, mutable, or differently versioned upstream release;
3. runs the upstream release's own verified installer on native Linux/macOS x86-64/ARM64 runners;
4. proves `inbox` and `resume` exist before packaging;
5. creates checksums and GitHub build-provenance bundles for the renamed extension assets;
6. validates the exact twelve-file draft inventory and every attestation;
7. revalidates both tags and the upstream release immediately before publication;
8. requires GitHub to report the extension release as immutable; and
9. runs clean installation smoke tests on all four platforms and, when a preceding release exists,
   upgrades from it to the new release.

Reruns may replace only assets on a draft. A published release is never overwritten. Do not move or
reuse a version tag after any release attempt; publish a new patch version instead.

## Expected assets

Each release contains these four executable names plus same-name `.sha256` and
`.intoto.jsonl` files:

```text
gh-stratadiff-linux-amd64
gh-stratadiff-linux-arm64
gh-stratadiff-darwin-amd64
gh-stratadiff-darwin-arm64
```

These suffixes are the platform identifiers recognized by GitHub CLI. The upstream project uses
different CPU spelling (`x86_64` and `aarch64`); the promotion script performs and tests the exact
mapping.
