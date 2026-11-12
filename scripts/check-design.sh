#!/usr/bin/env bash
# One look: views use tokens from App/Theme.swift, never a bare gap, radius or color.
# install-mac.sh runs this first, so a bare number stops the build.
set -uo pipefail
cd "$(dirname "$0")/.."
FOUND=$(grep -rnE '(spacing|minLength): *[1-9][0-9.]*|\.padding\((\.[a-zA-Z]+, *)?[1-9][0-9]*[,)]|cornerRadius: *[1-9][0-9.]*|\.cornerRadius\( *[1-9]|Color\((red|white|hue):|Color\.(red|blue|green|orange|yellow|purple|pink|gray|teal|indigo|mint|cyan|brown|black|white)\b' \
  App --include='*.swift' --exclude=Theme.swift)
if [[ -n $FOUND ]]; then
  echo "$FOUND"
  echo "FAIL a bare gap, radius or color above: use a token from App/Theme.swift, or add one"
  exit 1
fi
