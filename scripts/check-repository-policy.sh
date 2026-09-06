#!/usr/bin/env bash
set -euo pipefail

readonly script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly required_repository=gcomfident-crypto/gh-stratadiff
readonly ruleset_name='Protect immutable v* release tags'

if [[ $# -ne 0 ]]; then
  printf 'usage: scripts/check-repository-policy.sh\n' >&2
  exit 2
fi
command -v gh >/dev/null 2>&1 || {
  printf 'gh is required to verify repository policy\n' >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  printf 'python3 is required to verify repository policy\n' >&2
  exit 1
}

immutable_enabled="$(
  gh api --hostname github.com \
    "repos/${required_repository}/immutable-releases" \
    --jq '.enabled'
)"
[[ "${immutable_enabled}" == true ]] || {
  printf 'immutable releases are not enabled for %s\n' "${required_repository}" >&2
  exit 1
}

ruleset_id="$(
  gh api --hostname github.com \
    "repos/${required_repository}/rulesets" \
    --jq ".[] | select(.name == \"${ruleset_name}\") | .id"
)"
[[ "${ruleset_id}" =~ ^[1-9][0-9]*$ ]] || {
  printf 'exactly one %s ruleset is required\n' "${ruleset_name}" >&2
  exit 1
}

if ! gh api --hostname github.com \
  "repos/${required_repository}/rulesets/${ruleset_id}" |
  python3 "${script_directory}/validate-release-ruleset.py"
then
  printf 'release tag ruleset is missing or does not match the fail-closed policy\n' >&2
  exit 1
fi

printf 'Verified immutable releases and protected v* tags for %s\n' "${required_repository}"
