#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "${repository_root}"

while IFS= read -r script; do
  bash -n "${script}"
done < <(find scripts tests -type f -name '*.sh' -print | LC_ALL=C sort)

if command -v shellcheck >/dev/null 2>&1; then
  shell_scripts=()
  while IFS= read -r script; do
    shell_scripts+=("${script}")
  done < <(find scripts tests -type f -name '*.sh' -print | LC_ALL=C sort)
  shellcheck "${shell_scripts[@]}"
fi

bash tests/release_contract_test.sh
bash tests/native_entrypoint_test.sh

printf 'gh-stratadiff CI checks passed\n'
