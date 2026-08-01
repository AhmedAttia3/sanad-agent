#!/bin/bash

set -euo pipefail

DMG_PATH="${1:?Usage: notarize_macos.sh <dmg-path>}"

if [ -n "${APPLE_NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$APPLE_NOTARYTOOL_KEYCHAIN_PROFILE" \
    --wait
else
  : "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID is required}"
  : "${APPLE_API_ISSUER_ID:?APPLE_API_ISSUER_ID is required}"
  : "${APPLE_API_PRIVATE_KEY_PATH:?APPLE_API_PRIVATE_KEY_PATH is required}"

  xcrun notarytool submit "$DMG_PATH" \
    --key "$APPLE_API_PRIVATE_KEY_PATH" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" \
    --wait
fi
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
