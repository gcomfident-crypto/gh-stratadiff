#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: scripts/check-release-tag.sh vMAJOR.MINOR.PATCH EXPECTED_COMMIT\n' >&2
  exit 2
fi

release_tag=$1
expected_commit=$2
[[ "${release_tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  printf 'release tag must be a stable vMAJOR.MINOR.PATCH tag\n' >&2
  exit 1
}
[[ "${expected_commit}" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'expected commit must be a full lowercase SHA-1\n' >&2
  exit 1
}

resolved_commit="$(git rev-parse --verify "refs/tags/${release_tag}^{commit}")"
[[ "${resolved_commit}" == "${expected_commit}" ]] || {
  printf 'release tag resolves to %s, expected %s\n' "${resolved_commit}" "${expected_commit}" >&2
  exit 1
}
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || {
  printf 'release checkout is dirty\n' >&2
  git status --short --untracked-files=all >&2
  exit 1
}

printf '%s\n' "${release_tag#v}"
