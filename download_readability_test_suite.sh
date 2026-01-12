#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/mozilla/readability.git"
SPARSE_PATH="test/test-pages"
TARGET_DIR="test/fixtures/readability-test-pages"

TMP_DIR="$(mktemp -d)"

echo "Cloning Readability (sparse checkout)..."

git clone \
  --depth 1 \
  --filter=blob:none \
  --sparse \
  "$REPO_URL" \
  "$TMP_DIR/readability"

cd "$TMP_DIR/readability"

git sparse-checkout set "$SPARSE_PATH"

echo "Preparing target directory..."
mkdir -p "$(pwd -P | sed "s|$TMP_DIR/readability|$PWD|")" >/dev/null 2>&1 || true

echo "Copying test pages..."
mkdir -p "$OLDPWD/$TARGET_DIR"
cp -R "$SPARSE_PATH"/. "$OLDPWD/$TARGET_DIR"

cd "$OLDPWD"

echo "Cleaning up temporary repository..."
rm -rf "$TMP_DIR"

echo "Done."
echo "Readability test pages available in: $TARGET_DIR"
