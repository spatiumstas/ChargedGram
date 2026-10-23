#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$ROOT_DIR/submodules/telegram-ios"
PATCH_FILE="$ROOT_DIR/patches/telegram-ios/recent-inline-bots.patch"

if git -C "$CORE_DIR" apply --reverse --check "$PATCH_FILE" 2>/dev/null; then
    exit 0
fi

git -C "$CORE_DIR" apply --check "$PATCH_FILE"
git -C "$CORE_DIR" apply "$PATCH_FILE"
