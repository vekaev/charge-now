# Sourced by build-app.sh: prints the identity to sign the Mac app with. A real certificate, when this Mac has
# one, keeps the app's identity the same on every build, so macOS keeps its login item across updates.
# An ad-hoc signature (the fallback, for anyone without a certificate) is a hash of the build itself.
#
# Picks a Developer ID Application certificate first (notarizable), else Apple Development. Override:
#   SIGN_IDENTITY=<SHA-1 from `security find-identity -v -p codesigning`>   or   SIGN_IDENTITY=-   (ad-hoc)
sign_identity() {
  local line
  if [ "${SIGN_IDENTITY:-}" = "-" ]; then echo "-"; return; fi
  if [ -n "${SIGN_IDENTITY:-}" ]; then
    line=$(security find-identity -v -p codesigning 2>/dev/null | grep "$SIGN_IDENTITY" | head -1)
  else
    line=$(security find-identity -v -p codesigning 2>/dev/null | grep '"Developer ID Application:' | head -1)
    [ -n "$line" ] || line=$(security find-identity -v -p codesigning 2>/dev/null | grep '"Apple Development:' | head -1)
  fi
  if [ -z "$line" ]; then echo "-"; return; fi
  echo "$line" | awk '{print $2}'
}
