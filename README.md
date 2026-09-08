# gh-stratadiff

Resume a GitHub review after rebase, force-push, restack, or new commits without reconstructing
the old range by hand.

```console
gh extension install gcomfident-crypto/gh-stratadiff
gh stratadiff inbox
gh stratadiff resume https://github.com/OWNER/REPOSITORY/pull/123
```

`inbox` finds open pull requests whose current head differs from your latest completed review
checkpoint. `resume` binds that checkpoint to exact Git objects and opens the local Review Resume
Workbench. When the evidence cannot justify carrying review coverage forward, StrataDiff exposes
the uncertainty instead of hiding code.

## Pull Request Doctor in `v0.5.0`

The upcoming `v0.5.0` release adds a read-only incident path for a pull request blocked by required
checks:

```console
gh stratadiff doctor https://github.com/OWNER/REPOSITORY/pull/123
```

Doctor binds the report to GitHub's selected PR-head, test-merge, or merge-queue candidate and
distinguishes missing, pending, failed, wrong-App, and unknown required-check evidence. It returns
the smallest evidence-backed next action without claiming that the pull request is otherwise
mergeable. The latest published extension is still `v0.4.1`, which does not contain Doctor; use the
command above only after matching immutable `v0.5.0` releases are published here and upstream.

This repository is the precompiled GitHub CLI distribution surface for
[`gcomfident-crypto/stratadiff`](https://github.com/gcomfident-crypto/stratadiff). It does not
contain a second implementation of the review engine.

## Requirements and supported platforms

- GitHub CLI authenticated for the GitHub host containing the pull request
- Git for `resume`
- A browser, unless `--no-open` is used

Release assets are published for:

| Runtime | GitHub CLI asset |
| --- | --- |
| Linux x86-64 | `gh-stratadiff-linux-amd64` |
| Linux ARM64 | `gh-stratadiff-linux-arm64` |
| macOS x86-64 | `gh-stratadiff-darwin-amd64` |
| macOS ARM64 | `gh-stratadiff-darwin-arm64` |

Linux assets originate from upstream musl builds. The macOS binaries are not currently signed with
an Apple Developer ID or notarized. Windows is not supported yet; installation fails explicitly
when no matching release asset exists.

## Use

Scan your cross-repository queue:

```console
gh stratadiff inbox
```

Narrow the queue or select a reviewer explicitly:

```console
gh stratadiff inbox -R OWNER/REPOSITORY
gh stratadiff inbox --reviewer LOGIN --format json
```

Resume from a canonical pull request URL from any directory:

```console
gh stratadiff resume https://github.com/OWNER/REPOSITORY/pull/123
```

Use `--repo-dir PATH` to reuse a local object store, or `--no-open` to print the Workbench URL.
After `v0.5.0` is published, run `gh stratadiff doctor --help` for its complete contract. Run
`gh stratadiff inbox --help` and `gh stratadiff resume --help` for the commands available today.

## Versions and upgrades

Every extension release tag maps one-to-one to the same immutable upstream StrataDiff tag. The
extension asset is the verified upstream executable with only its filename changed for GitHub CLI
dispatch. Confirm the installed engine version with:

```console
gh stratadiff --version
gh stratadiff build-info
```

Upgrade an unpinned installation:

```console
gh extension upgrade stratadiff
```

Install a specific immutable version when reproducibility matters:

```console
gh extension install gcomfident-crypto/gh-stratadiff --pin v0.4.1
```

GitHub CLI intentionally does not upgrade pinned extensions. Remove and reinstall without `--pin`
to return to the latest-release channel.

## Release integrity

The release workflow accepts only a stable `vMAJOR.MINOR.PATCH` tag and a published, stable,
immutable release with the identical tag in the fixed upstream repository. On each native runner
it fetches the upstream installer from the fully dereferenced release commit. That installer fixes
the upstream repository and signer workflow, verifies the upstream checksum and bundled build
attestation, checks the binary version, and resolves the tag both before and after download.

Only then does this repository rename the exact bytes, create a new checksum, generate a build
provenance attestation for the extension workflow, verify the complete twelve-file inventory, and
publish its own immutable release. A clean-install matrix exercises installation, `doctor`,
`inbox`, and `resume` on all four platforms after publication. Starting with the second extension
release, it also installs the preceding immutable version and exercises the real
`gh extension upgrade` transition.

GitHub CLI selects and downloads a matching third-party extension asset, but `gh extension install`
does not itself consume the adjacent checksum or provenance bundle. To independently inspect a
release before installation, use GitHub's release attestation and the checked-in verifier:

```console
tag=v0.4.0
gh release verify "$tag" -R gcomfident-crypto/gh-stratadiff

mkdir release-assets
gh release download "$tag" -R gcomfident-crypto/gh-stratadiff --dir release-assets
scripts/verify-release-assets.sh \
  release-assets \
  gcomfident-crypto/gh-stratadiff \
  "refs/tags/$tag" \
  "$(gh api "repos/gcomfident-crypto/gh-stratadiff/commits/$tag" --jq .sha)" \
  gcomfident-crypto/gh-stratadiff/.github/workflows/release.yml
```

Checksums establish byte integrity; attestations bind those bytes to the repository, exact source
tag and commit, signer workflow, and GitHub-hosted runner. Immutable releases lock the associated
tag and assets after publication. This is a third-party extension and is not certified or endorsed
by GitHub.

## Development

This repository deliberately has no root `gh-stratadiff` script. Without a release, GitHub CLI
would otherwise clone and run that script as an interpreted extension, bypassing the verified
binary distribution path.

Run the offline contract suite:

```console
scripts/ci.sh
```

To additionally prove that a local native build remains executable after the filename change:

```console
STRATADIFF_NATIVE_TEST_BINARY=/absolute/path/to/stratadiff \
  tests/native_entrypoint_test.sh
```

See [SECURITY.md](SECURITY.md) for the trust boundary and
[docs/releasing.md](docs/releasing.md) for the maintainer release procedure.

## Official references

- [Creating GitHub CLI extensions](https://docs.github.com/en/github-cli/github-cli/creating-github-cli-extensions)
- [`gh extension install`](https://cli.github.com/manual/gh_extension_install)
- [`gh extension upgrade`](https://cli.github.com/manual/gh_extension_upgrade)
- [Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
- [Using artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

## License

MIT
