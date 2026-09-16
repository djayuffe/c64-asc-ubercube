#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./audit_static.py c64_asc_ubercube.asm
if ! command -v acme >/dev/null 2>&1; then
  echo "ERROR: ACME assembler not found. Install acme, then run ./build.sh again." >&2
  exit 127
fi
acme c64_asc_ubercube.asm
ls -l c64_asc_ubercube.prg
