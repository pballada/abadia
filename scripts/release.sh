#!/bin/bash
# Developer ID release. Credentials stay in Keychain; never passed on the CLI.
set -euo pipefail
cd "$(dirname "$0")/.."

release_team="${TEAM_ID:-5UXXXESGMK}"
release_profile="${NOTARY_PROFILE:-notary}"
release_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
release_dir="${RELEASE_DIR:-$PWD/build/releases/$release_version}"
release_app="$release_dir/La abadia del crimen.app"
release_upload="$release_dir/Abadia-notarization-upload.zip"
release_zip="$release_dir/Abadia-macOS.zip"

if [ -e "$release_app" ] || [ -e "$release_zip" ]; then
    echo "A release already exists in $release_dir. Move it aside or set RELEASE_DIR to a fresh directory." >&2
    exit 1
fi

# Resolve a usable identity, including its private key, for the intended team.
# An explicit SIGNING_IDENTITY may be the certificate's SHA-1 fingerprint.
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    release_identity="$SIGNING_IDENTITY"
else
release_identity="$(security find-identity -v -p codesigning | python3 -c '
import re,sys
team=sys.argv[1]
matches=[m.group(1) for line in sys.stdin for m in [re.search(r"\b([A-Fa-f0-9]{40})\b.*\"Developer ID Application:.*\("+re.escape(team)+r"\)\"",line)] if m]
if len(matches)!=1:
    sys.exit("Expected one usable Developer ID Application identity for team "+team+"; found "+str(len(matches))+". Check Xcode / Keychain Access in your normal login session.")
print(matches[0])
' "$release_team")"
fi

# Fail before touching the release if credentials or Apple connectivity fail.
xcrun notarytool history --keychain-profile "$release_profile" --output-format json >/dev/null
make -j8 universal
mkdir -p "$release_dir"
ditto "build/La abadia del crimen.app" "$release_app"
codesign --force --options runtime --timestamp --sign "$release_identity" "$release_app"
codesign --verify --deep --strict --verbose=2 "$release_app"
codesign --display --verbose=4 "$release_app" 2>"$release_dir/signature.txt"
if ! /usr/bin/grep -Fxq "TeamIdentifier=$release_team" "$release_dir/signature.txt"; then
    echo "Signing identity belongs to a different team. Nothing was submitted." >&2
    exit 1
fi
if ! /usr/bin/grep -q 'flags=.*runtime' "$release_dir/signature.txt" || ! /usr/bin/grep -q '^Timestamp=' "$release_dir/signature.txt"; then
    echo "Signature must include hardened runtime and a secure timestamp. Nothing was submitted." >&2
    exit 1
fi
ditto -c -k --keepParent "$release_app" "$release_upload"

# The JSON receipt and full Apple log remain beside the finished archive.
if ! xcrun notarytool submit "$release_upload" --keychain-profile "$release_profile" \
    --wait --timeout 30m --output-format json >"$release_dir/notarization.json"; then
    echo "Submission did not finish successfully. See $release_dir/notarization.json before retrying; do not resubmit a pending job." >&2
    exit 1
fi
release_submission="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$release_dir/notarization.json")"
xcrun notarytool log "$release_submission" --keychain-profile "$release_profile" "$release_dir/notarization-log.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r.get("status")=="Accepted" else "Apple did not accept this submission. Review notarization-log.json.")' "$release_dir/notarization.json"

xcrun stapler staple "$release_app"
xcrun stapler validate "$release_app"
codesign --verify --deep --strict --verbose=2 "$release_app"
spctl --assess --type execute --verbose=2 "$release_app"

# Package again AFTER stapling: this is the archive to distribute.
ditto -c -k --keepParent "$release_app" "$release_zip"
(cd "$release_dir" && shasum -a 256 "Abadia-macOS.zip" >SHA256SUMS.txt)
echo "Notarized release: $release_zip"
