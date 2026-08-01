#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$SCRIPT_DIR/release.ps1")"
