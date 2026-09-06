#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'resolve-tag: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 2 ]]; then
  printf 'usage: scripts/resolve-tag.sh OWNER/REPOSITORY vMAJOR.MINOR.PATCH\n' >&2
  exit 2
fi

repository=$1
release_tag=$2

[[ "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || \
  die 'repository must use OWNER/REPOSITORY form'
[[ "${release_tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || \
  die 'release tag must be a stable vMAJOR.MINOR.PATCH tag'
command -v gh >/dev/null 2>&1 || die 'gh is required'

object="$(
  gh api --hostname github.com \
    "repos/${repository}/git/ref/tags/${release_tag}" \
    --jq '.object.type + "\t" + .object.sha'
)"

for _ in 1 2 3 4 5 6 7 8; do
  object_type=${object%%$'\t'*}
  object_sha=${object#*$'\t'}
  if [[ "${object_type}" == "${object}" || ! "${object_sha}" =~ ^[0-9a-f]{40}$ ]]; then
    die "GitHub returned an invalid object for tag ${release_tag}"
  fi

  case "${object_type}" in
    commit)
      printf '%s\n' "${object_sha}"
      exit 0
      ;;
    tag)
      object="$(
        gh api --hostname github.com \
          "repos/${repository}/git/tags/${object_sha}" \
          --jq '.object.type + "\t" + .object.sha'
      )"
      ;;
    *) die "tag ${release_tag} points to unsupported object type ${object_type}" ;;
  esac
done

die "tag ${release_tag} exceeds the eight-object dereference limit"
