#!/bin/bash
set -euo pipefail

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1:-}" != "--arm64" ) ]]; then
    echo "Usage: RELEASE_SIGNING_IDENTITY=ChargedGram bash scripts/build-release.sh [--arm64]" >&2
    exit 2
fi

BUILD_ARCHS=(arm64 x86_64)
BUILD_VARIANT="universal"
if [ "${1:-}" = "--arm64" ]; then
    BUILD_ARCHS=(arm64)
    BUILD_VARIANT="arm64"
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DIR="$ROOT_DIR/.build/release"
if [ "$BUILD_VARIANT" = "arm64" ]; then
    DERIVED_DIR="$ROOT_DIR/.build/release-arm64"
fi
ARCHIVE_NAME="ChargedGram-macos-$BUILD_VARIANT"
SOURCE_APP="$DERIVED_DIR/Build/Products/Release/ChargedGram.app"
SIGNING_IDENTITY="${RELEASE_SIGNING_IDENTITY:-ChargedGram}"

cd "$ROOT_DIR"
for config in packages/ApiCredentials/Sources/ApiCredentials/ForkCredentials.generated.swift configurations/Fork.generated.xcconfig; do
    if [ ! -f "$config" ]; then
        echo "Missing fork configuration. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, APP_BUNDLE_ID and run python3 scripts/configure-fork.py. See INSTALL.md." >&2
        exit 1
    fi
done

SIGNING_HASH="$(python3 - "$SIGNING_IDENTITY" <<'PY'
import re
import subprocess
import sys

identity = sys.argv[1]
result = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"], check=True, capture_output=True, text=True)
identities = re.findall(r'^\s*\d+\) ([0-9A-Fa-f]{40}) "([^"]+)"', result.stdout, re.MULTILINE)
matches = {fingerprint.upper() for fingerprint, name in identities if name == identity or fingerprint.upper() == identity.upper()}
if len(matches) != 1:
    sys.exit("Set RELEASE_SIGNING_IDENTITY to the exact name or SHA-1 of one valid code-signing identity with its private key. Check: security find-identity -v -p codesigning")
print(matches.pop())
PY
)"

bash "$ROOT_DIR/scripts/fix-recent-inline-bots.sh"
xcodebuild -workspace Telegram-Mac.xcworkspace \
    -scheme Release \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DIR" \
    "ARCHS=${BUILD_ARCHS[*]}" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    ENABLE_DEBUG_DYLIB=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) STABLE' \
    build

mkdir -p "$ROOT_DIR/.build/releases"
OUTPUT_DIR="$(mktemp -d "$ROOT_DIR/.build/releases/$(date +%Y%m%d-%H%M%S).XXXXXX")"
RELEASE_APP="$OUTPUT_DIR/ChargedGram.app"

python3 - "$SOURCE_APP" "$RELEASE_APP" "$SIGNING_HASH" <<'PY'
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
signing_identity = sys.argv[3]
shutil.copytree(source, destination, symlinks=True)
plugins = destination / "Contents/PlugIns"
if plugins.exists():
    shutil.rmtree(plugins)
info_path = destination / "Contents/Info.plist"
with info_path.open("rb") as stream:
    info = plistlib.load(stream)
info["CFBundleName"] = "ChargedGram"
info["CFBundleDisplayName"] = "ChargedGram"
info["TelegramLocalBuild"] = True
info["SUFeedURL"] = "https://github.com/spatiumstas/ChargedGram/releases/latest/download/appcast.xml"
with info_path.open("wb") as stream:
    plistlib.dump(info, stream)

mach_o_magic = {bytes.fromhex(value) for value in ["feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca"]}
paths = sorted(destination.rglob("*"), key=lambda path: len(path.parts), reverse=True)
for path in paths:
    if path.is_symlink():
        continue
    if path.is_file():
        with path.open("rb") as stream:
            if stream.read(4) not in mach_o_magic:
                continue
        subprocess.run(["xcrun", "strip", "-S", "-x", str(path)], check=True)
    elif path.suffix not in {".framework", ".app", ".xpc", ".appex"}:
        continue
    subprocess.run(["codesign", "--force", "--sign", signing_identity, "--timestamp=none", str(path)], check=True)
subprocess.run(["codesign", "--force", "--sign", signing_identity, "--timestamp=none", str(destination)], check=True)
PY

codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
lipo "$RELEASE_APP/Contents/MacOS/ChargedGram" -verify_arch "${BUILD_ARCHS[@]}"
ditto -c -k --sequesterRsrc --keepParent "$RELEASE_APP" "$OUTPUT_DIR/$ARCHIVE_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$SOURCE_APP.dSYM" "$OUTPUT_DIR/$ARCHIVE_NAME.dSYM.zip"
cd "$OUTPUT_DIR"
shasum -a 256 "$ARCHIVE_NAME.zip" > "$ARCHIVE_NAME.zip.sha256"
if [ "$BUILD_VARIANT" = "universal" ]; then
    python3 "$ROOT_DIR/scripts/generate-appcast.py" "$OUTPUT_DIR/$ARCHIVE_NAME.zip"
    echo "Update feed: $OUTPUT_DIR/appcast.xml"
fi
echo "Release app: $RELEASE_APP"
echo "Publish: $OUTPUT_DIR/$ARCHIVE_NAME.zip"
echo "Checksum: $OUTPUT_DIR/$ARCHIVE_NAME.zip.sha256"
echo "Keep debug symbols: $OUTPUT_DIR/$ARCHIVE_NAME.dSYM.zip"
