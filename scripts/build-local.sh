#!/bin/bash
set -euo pipefail

case "${1:-}" in
    ""|--run) ;;
    *) echo "Usage: bash scripts/build-local.sh [--run]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DIR="$ROOT_DIR/.build/local"
SOURCE_APP="$DERIVED_DIR/Build/Products/Debug/Telegram.app"
LOCAL_APP="$ROOT_DIR/.build/local-run/ChargedGram.app"
SIGNING_IDENTITY="${LOCAL_SIGNING_IDENTITY:--}"

cd "$ROOT_DIR"
for config in packages/ApiCredentials/Sources/ApiCredentials/ForkCredentials.generated.swift configurations/Fork.generated.xcconfig; do
    if [ ! -f "$config" ]; then
        echo "Missing fork configuration. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, APP_BUNDLE_ID and run python3 scripts/configure-fork.py. See INSTALL.md." >&2
        exit 1
    fi
done
bash "$ROOT_DIR/scripts/fix-recent-inline-bots.sh"
xcodebuild -workspace Telegram-Mac.xcworkspace \
    -scheme Telegram \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    build

python3 - "$SOURCE_APP" "$LOCAL_APP" "$SIGNING_IDENTITY" <<'PY'
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
signing_identity = sys.argv[3]
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(source, destination, symlinks=True)
plugins = destination / "Contents/PlugIns"
if plugins.exists():
    shutil.rmtree(plugins)
info_path = destination / "Contents/Info.plist"
with info_path.open("rb") as stream:
    info = plistlib.load(stream)
info["CFBundleIdentifier"] += ".local"
info["CFBundleName"] = "ChargedGram"
info["CFBundleDisplayName"] = "ChargedGram"
info["TelegramLocalBuild"] = True
info.pop("CFBundleURLTypes", None)
info.pop("SUFeedURL", None)
with info_path.open("wb") as stream:
    plistlib.dump(info, stream)
mach_o_magic = {bytes.fromhex(value) for value in ["feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca"]}
for path in destination.rglob("*"):
    if path.is_file() and not path.is_symlink():
        with path.open("rb") as stream:
            magic = stream.read(4)
        if magic in mach_o_magic:
            subprocess.run(["codesign", "--force", "--sign", signing_identity, str(path)], check=True)
PY

while IFS= read -r -d '' item; do
    codesign --force --sign "$SIGNING_IDENTITY" "$item"
done < <(find "$LOCAL_APP/Contents" -depth \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \) -print0)

codesign --force --sign "$SIGNING_IDENTITY" "$LOCAL_APP"
codesign --verify --deep --strict "$LOCAL_APP"
echo "Local app: $LOCAL_APP"

if [ "${1:-}" = "--run" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$LOCAL_APP"
    open -n "$LOCAL_APP"
fi
