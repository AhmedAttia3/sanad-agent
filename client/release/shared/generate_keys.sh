#!/bin/bash

# This script helps generate the EdDSA keys required for Sparkle (macOS auto-update).
# It assumes you have the 'generate_keys' tool or we can use the dart package helper if available,
# but usually it's easier to use the `sparkle` bin.
#
# Since we are using the `auto_updater` flutter package, it wraps Sparkle.
# The easiest way to generate keys is using the verify_appcast command or similar from Sparkle distribution.
#
# However, `auto_updater` documentation suggests using the `dart run auto_updater:generate_keys` if available, 
# OR manually generating them.
#
# Let's try to use the `generate_keys` tool if we can find it, otherwise we guide the user to download Sparkle.

echo "----------------------------------------------------------------"
echo "  Generating EdDSA Keys for Sparkle Auto-Update"
echo "----------------------------------------------------------------"
echo ""
echo "Please run the following command to generate your keys:"
echo ""
echo "  dart run auto_updater:generate_keys"
echo ""
echo "If that command is not available, you can use the openssl command:"
echo ""
echo "  openssl genpkey -algorithm ed25519 -out private_key.pem"
echo "  openssl pkey -in private_key.pem -pubout -out public_key.pem"
echo ""
echo "Then cat the files to see your keys."
echo "----------------------------------------------------------------"
