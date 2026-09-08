#!/usr/bin/env bash
set -euo pipefail

native_binary=${STRATADIFF_NATIVE_TEST_BINARY:-}
if [[ -z "${native_binary}" && -x /home/zene/stratadiff/target/debug/stratadiff ]]; then
  native_binary=/home/zene/stratadiff/target/debug/stratadiff
fi
if [[ -z "${native_binary}" ]]; then
  printf 'native entrypoint test skipped; set STRATADIFF_NATIVE_TEST_BINARY to a v0.5+ binary\n'
  exit 0
fi
[[ -x "${native_binary}" ]] || {
  printf 'native test binary is not executable: %s\n' "${native_binary}" >&2
  exit 1
}

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/gh-stratadiff-native-XXXXXX")"
trap 'rm -r -- "${temporary_directory}"' EXIT
extension_binary=${temporary_directory}/gh-stratadiff
cp "${native_binary}" "${extension_binary}"
chmod 0755 "${extension_binary}"

"${extension_binary}" doctor --help >/dev/null
"${extension_binary}" inbox --help >/dev/null
"${extension_binary}" resume --help >/dev/null
"${extension_binary}" --version | grep -E '^stratadiff [0-9]+\.[0-9]+\.[0-9]+$' >/dev/null

if command -v gh >/dev/null 2>&1; then
  extension_directory=${temporary_directory}/data/gh/extensions/gh-stratadiff
  mkdir -p "${extension_directory}" "${temporary_directory}/config"
  cp "${native_binary}" "${extension_directory}/gh-stratadiff"
  chmod 0755 "${extension_directory}/gh-stratadiff"
  GH_CONFIG_DIR=${temporary_directory}/config \
    XDG_DATA_HOME=${temporary_directory}/data \
    gh stratadiff doctor --help >/dev/null
  GH_CONFIG_DIR=${temporary_directory}/config \
    XDG_DATA_HOME=${temporary_directory}/data \
    gh stratadiff inbox --help >/dev/null
  GH_CONFIG_DIR=${temporary_directory}/config \
    XDG_DATA_HOME=${temporary_directory}/data \
    gh stratadiff resume --help >/dev/null
fi

printf 'renamed native entrypoint test passed\n'
