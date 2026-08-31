#!/usr/bin/env bash
# Sync only community-registry pack files into a registry checkout.
# Usage: sync-community-registry.sh <source-pack-dir> <dest-pack-dir>
# Example: ./sync-community-registry.sh packs/nomatron community-registry/packs/nomatron
#          ./sync-community-registry.sh packs/nomatron-agent community-registry/packs/nomatron-agent
set -euo pipefail

SOURCE_DIR="${1:?source pack directory required (e.g. packs/nomatron)}"
DEST_DIR="${2:?destination directory required (e.g. community-registry/packs/nomatron)}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

# Registry pack layout only — templates/, CHANGELOG.md, README.md, metadata.hcl, outputs.tpl, variables.hcl
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

mkdir -p "$DEST_DIR"
rsync -a --delete "$staging/" "$DEST_DIR/"

echo "Synced registry pack files from $SOURCE_DIR -> $DEST_DIR"
