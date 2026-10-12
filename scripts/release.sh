#!/bin/sh
# Builds sidecarctl, signs it for distribution, and has Apple notarize it, leaving a
# zip in dist/ that Gatekeeper accepts on another Mac.
#
#   scripts/release.sh              build, sign, and notarize
#   scripts/release.sh --sign-only  stop once the zip is signed
#
# Signing needs a Developer ID Application certificate in the keychain. Notarizing
# needs credentials stored once, which asks for an app-specific password:
#
#   xcrun notarytool store-credentials notary --apple-id <Apple ID> --team-id <team ID>
#
# SIGN_IDENTITY    the certificate to sign with, by default the one Developer ID
#                  Application certificate in the keychain
# NOTARY_PROFILE   the name the credentials were stored under, by default notary
# BUNDLE_ID        the identifier signed into the binary, which macOS keys granted
#                  permissions on, so it stays the same from one release to the next

set -eu

identity=${SIGN_IDENTITY:-Developer ID Application}
profile=${NOTARY_PROFILE:-notary}
bundle_id=${BUNDLE_ID:-sidecarctl}

repo=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repo"

version=$(git describe --tags --always --dirty)
name=sidecarctl-$version-macos-arm64
stage=dist/$name
zip=dist/$name.zip

xcrun swift build -c release
rm -rf "$stage" "$zip"
mkdir -p "$stage"
cp .build/release/sidecarctl LICENSE README.md "$stage/"

# The hardened runtime and a secure timestamp are both required for notarization
codesign --force --sign "$identity" --identifier "$bundle_id" --options runtime --timestamp "$stage/sidecarctl"
codesign --verify --strict --verbose=2 "$stage/sidecarctl"

ditto -c -k --keepParent "$stage" "$zip"
echo "signed $zip"
[ "${1:-}" = --sign-only ] && exit 0

# A bare executable cannot have the ticket stapled to it, so Gatekeeper looks the
# notarization up online the first time the binary runs
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
echo "notarized $zip"
