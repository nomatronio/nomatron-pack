#!/usr/bin/env bash
# Sync nomatron/ into a community-registry checkout at packs/nomatron/.
set -euo pipefail

SOURCE_DIR="${1:-nomatron}"
DEST_DIR="${2:?destination directory required (e.g. community-registry/packs/nomatron)}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST_DIR")"

rsync -a --delete \
  --exclude='homelab.vars.hcl' \
  --exclude='mac-dev.vars.hcl' \
  --exclude='*.vars.hcl' \
  "$SOURCE_DIR/" "$DEST_DIR/"

echo "Synced $SOURCE_DIR -> $DEST_DIR"
