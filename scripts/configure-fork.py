import os
import re
import sys
from pathlib import Path


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"Missing required secret: {name}")
    return value


api_id = required("TELEGRAM_API_ID")
api_hash = required("TELEGRAM_API_HASH")
bundle_id = required("APP_BUNDLE_ID")
team_id = os.environ.get("APPLE_TEAM_ID", "").strip()

if not re.fullmatch(r"[0-9]{1,10}", api_id) or not 0 < int(api_id) <= 2147483647:
    sys.exit("TELEGRAM_API_ID must be a positive Int32")
if not re.fullmatch(r"[0-9a-fA-F]{32}", api_hash):
    sys.exit("TELEGRAM_API_HASH must contain 32 hexadecimal characters")
if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
    sys.exit("APP_BUNDLE_ID must be a reverse-DNS bundle identifier")
if team_id and not re.fullmatch(r"[A-Z0-9]{10}", team_id):
    sys.exit("APPLE_TEAM_ID must contain 10 uppercase letters or digits")

root = Path(__file__).resolve().parent.parent
swift_path = root / "packages/ApiCredentials/Sources/ApiCredentials/ForkCredentials.generated.swift"
config_path = root / "configurations/Fork.generated.xcconfig"
os.umask(0o077)
swift_path.write_text(
    "enum ForkCredentials {\n"
    f"    static let apiId: Int32 = {int(api_id)}\n"
    f'    static let apiHash = "{api_hash}"\n'
    f'    static let bundleId = "{bundle_id}"\n'
    f'    static let teamId = "{team_id}"\n'
    "}\n"
)
config_path.write_text(
    f"CHARGEDGRAM_BUNDLE_ID = {bundle_id}\n"
    f"CHARGEDGRAM_TEAM_ID = {team_id}\n"
)
print("Fork configuration generated")
