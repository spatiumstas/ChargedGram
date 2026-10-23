import base64
import os
import re
import secrets
import subprocess
import sys
from pathlib import Path


def required(name):
    value = os.environ.get(name, "")
    if not value:
        sys.exit(f"Missing required secret: {name}")
    return value


def run(*arguments, input=None):
    result = subprocess.run(arguments, input=input, capture_output=True, text=True)
    if result.returncode:
        sys.exit("Signing certificate setup failed: " + result.stderr.strip())
    return result.stdout


certificate = required("SIGNING_CERTIFICATE_BASE64")
password = required("SIGNING_CERTIFICATE_PASSWORD")
directory = Path(os.environ["RUNNER_TEMP"])
certificate_path = directory / "chargedgram-signing.p12"
keychain_path = directory / "chargedgram-signing.keychain-db"
keychain_password = secrets.token_hex(32)
os.umask(0o077)

try:
    certificate_data = base64.b64decode("".join(certificate.split()), validate=True)
except ValueError:
    sys.exit("SIGNING_CERTIFICATE_BASE64 must contain a Base64-encoded .p12 file")

with open(os.environ["GITHUB_ENV"], "a") as environment:
    environment.write(f"CHARGEDGRAM_SIGNING_KEYCHAIN={keychain_path}\n")

try:
    certificate_path.write_bytes(certificate_data)
    run("security", "create-keychain", "-p", keychain_password, str(keychain_path))
    run("security", "set-keychain-settings", "-lut", "21600", str(keychain_path))
    run("security", "unlock-keychain", "-p", keychain_password, str(keychain_path))
    run("security", "import", str(certificate_path), "-k", str(keychain_path), "-P", password, "-T", "/usr/bin/codesign")
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", keychain_password, str(keychain_path))
    run("security", "list-keychains", "-d", "user", "-s", str(keychain_path))
    identities = run("security", "find-identity", "-p", "codesigning", str(keychain_path))
    hashes = set(re.findall(r'^\s*\d+\) ([0-9A-Fa-f]{40}) "', identities, re.MULTILINE))
    if len(hashes) != 1:
        sys.exit("The .p12 file must contain exactly one code-signing identity with its private key")
    identity = hashes.pop().upper()
    certificates = run("security", "find-certificate", "-a", "-p", str(keychain_path))
    for pem in re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", certificates, re.DOTALL):
        details = run("/usr/bin/openssl", "x509", "-noout", "-subject", "-issuer", "-fingerprint", "-sha1", "-nameopt", "RFC2253", input=pem)
        fields = {key.strip(): value.strip() for key, value in (line.split("=", 1) for line in details.splitlines() if "=" in line)}
        fingerprint = next((value.replace(":", "").strip().upper() for key, value in fields.items() if "fingerprint" in key.lower()), "")
        if fingerprint == identity and fields.get("subject") and fields["subject"] == fields.get("issuer"):
            root_path = directory / "chargedgram-signing-root.pem"
            root_path.write_text(pem)
            with open(os.environ["GITHUB_ENV"], "a") as environment:
                environment.write(f"CHARGEDGRAM_SIGNING_ROOT={root_path}\n")
            run("sudo", "security", "add-trusted-cert", "-d", "-r", "trustRoot", "-p", "codeSign", "-k", str(keychain_path), str(root_path))
            break
    valid_identities = run("security", "find-identity", "-v", "-p", "codesigning", str(keychain_path))
    if identity not in valid_identities.upper():
        sys.exit("The imported signing certificate is expired or its certificate chain is not trusted")
    with open(os.environ["GITHUB_ENV"], "a") as environment:
        environment.write(f"RELEASE_SIGNING_IDENTITY={identity}\n")
finally:
    certificate_path.unlink(missing_ok=True)

print("Signing certificate imported")
