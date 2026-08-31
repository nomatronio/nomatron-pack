#!/usr/bin/env bash
# Sync only community-registry pack files into a registry checkout at packs/nomatron/.
set -euo pipefail

SOURCE_DIR="${1:-packs/nomatron}"
DEST_DIR="${2:?destination directory required (e.g. community-registry/packs/nomatron)}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Registry pack layout — templates/, CHANGELOG.md, README.md, metadata.hcl, outputs.tpl, variables.hcl
PACK_ITEMS=(
  templates
  CHANGELOG.md
  README.md
  metadata.hcl
  outputs.tpl
  variables.hcl
)

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

for item in "${PACK_ITEMS[@]}"; do
  if [[ -e "$SOURCE_DIR/$item" ]]; then
    rsync -a "$SOURCE_DIR/$item" "$staging/"
  fi
done

# HashiCorp validate.sh renders with packs/<name>/.ci/vars-*.hcl when that directory exists.
if compgen -G "${REPO_ROOT}/.ci/vars-*.hcl" > /dev/null; then
  mkdir -p "$staging/.ci"
  cp "${REPO_ROOT}/.ci"/vars-*.hcl "$staging/.ci/"
fi

mkdir -p "$DEST_DIR"
rsync -a --delete "$staging/" "$DEST_DIR/"

echo "Synced registry pack files from $SOURCE_DIR -> $DEST_DIR"
