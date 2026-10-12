#!/bin/sh
# Builds sidecarctl, signs it for distribution, and has Apple notarize it, leaving in
# dist/ the tarball a release carries and its checksum.
#
#   scripts/release.sh              build, sign, and notarize the tagged commit
#   scripts/release.sh --sign-only  stop once the binary is signed, on any commit
#
# A full run wants a clean checkout of a commit tagged v<version>, where <version>
# is what `sidecarctl --version` prints.
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

xcrun swift build -c release
built=$(.build/release/sidecarctl --version)

if [ "${1:-}" = --sign-only ]; then
  tag=$(git describe --tags --always --dirty)
else
  tag=$(git describe --tags --exact-match 2>/dev/null) || { echo "this commit has no tag, so there is nothing to release" >&2; exit 1; }
  [ -z "$(git status --porcelain)" ] || { echo "the checkout has uncommitted changes" >&2; exit 1; }
  [ "$tag" = "v$built" ] || { echo "the tag is $tag and the binary says $built" >&2; exit 1; }
fi

name=sidecarctl-$tag-aarch64-apple-darwin
stage=dist/$name
rm -rf "$stage" "$stage.zip" "$stage.tar.gz" "$stage.tar.gz.sha256"
mkdir -p "$stage"
cp .build/release/sidecarctl LICENSE README.md "$stage/"

# The hardened runtime and a secure timestamp are both required for notarization
codesign --force --sign "$identity" --identifier "$bundle_id" --options runtime --timestamp "$stage/sidecarctl"
codesign --verify --strict --verbose=2 "$stage/sidecarctl"
[ "${1:-}" = --sign-only ] && { echo "signed $stage/sidecarctl"; exit 0; }

# Apple takes a zip. A bare executable cannot have the ticket stapled to it, so
# Gatekeeper looks the notarization up online the first time the binary runs, and
# the ticket covers the binary whatever archive it later travels in.
ditto -c -k --keepParent "$stage" "$stage.zip"
xcrun notarytool submit "$stage.zip" --keychain-profile "$profile" --wait
rm "$stage.zip"

# The files sit at the top of the tarball, with no folder around them
tar -czf "$stage.tar.gz" -C "$stage" sidecarctl LICENSE README.md
(cd dist && shasum -a 256 "$name.tar.gz" >"$name.tar.gz.sha256")
echo "notarized $stage.tar.gz"
cat "$stage.tar.gz.sha256"
