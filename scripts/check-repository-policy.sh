#!/usr/bin/env bash
set -euo pipefail

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

ruleset_valid="$(
  gh api --hostname github.com \
    "repos/${required_repository}/rulesets/${ruleset_id}" \
    --jq '
      if .name == "Protect immutable v* release tags"
        and .target == "tag"
        and .enforcement == "active"
        and has("bypass_actors")
        and ((.bypass_actors | type) == "array")
        and (.bypass_actors == [])
        and .conditions.ref_name.include == ["refs/tags/v*"]
        and .conditions.ref_name.exclude == []
        and ([.rules[].type] | sort) == ["deletion", "update"]
      then "true"
      else "false"
      end
    '
)"
[[ "${ruleset_valid}" == true ]] || {
  printf 'release tag ruleset is missing or does not match the fail-closed policy\n' >&2
  exit 1
}

printf 'Verified immutable releases and protected v* tags for %s\n' "${required_repository}"
