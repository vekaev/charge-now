#!/usr/bin/env bash
# Builds the Mac app, installs it to ~/Applications and restarts it so the newest version is always running.
# The running copy is asked to quit normally first.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/check-design.sh
scripts/test-core.sh

scripts/build-app.sh --native

APP="$HOME/Applications/Charge Now.app"
RUNNING='Charge Now\.app/Contents/MacOS/'
if pgrep -f "$RUNNING" >/dev/null; then
  osascript -e 'tell application id "app.chargenow.mac" to quit' || true
  for _ in $(seq 1 40); do pgrep -f "$RUNNING" >/dev/null || break; sleep 0.25; done
  if pgrep -f "$RUNNING" >/dev/null; then echo "The running copy didn't quit; not replacing it."; exit 1; fi
fi

mkdir -p "$HOME/Applications"
rm -rf "$APP"
cp -R "build/Charge Now.app" "$APP"
open "$APP"
for _ in $(seq 1 40); do pgrep -f "$RUNNING" >/dev/null && break; sleep 0.25; done
pgrep -f "$RUNNING" >/dev/null || { echo "Failed to start"; exit 1; }
echo "Charge Now restarted with the new build"
