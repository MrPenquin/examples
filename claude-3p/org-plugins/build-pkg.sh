#!/usr/bin/env bash
#
# build-pkg.sh — bundle the Acme org plugins into a macOS .pkg installer.
#
# The resulting installer drops each plugin into the system location Cowork (3P)
# scans for organization plugins:
#
#     /Library/Application Support/Claude/org-plugins/<plugin-name>/
#
# Hand the .pkg to your MDM (Jamf, Kandji, Intune for Mac, …) or run it locally
# with `sudo installer -pkg <file> -target /`. On next launch Cowork picks the
# plugins up; `installationPreference: required|auto_install` decides activation.
#
# Each plugin lives in its own directory next to this script. This script, the
# README, and the build/dist output are NOT plugins and are excluded from the pkg.
#
# Usage:
#   ./build-pkg.sh                               # unsigned, version from git/date
#   VERSION=1.2.0 ./build-pkg.sh                 # explicit version
#   SIGN_IDENTITY="Developer ID Installer: Acme Corp (TEAMID)" \
#       ./build-pkg.sh                           # signed (productsign)
#
set -euo pipefail

# Stop macOS from writing AppleDouble (._*) resource-fork files into the payload.
export COPYFILE_DISABLE=1

# ---- paths --------------------------------------------------------------------
# The script sits in the org-plugins root alongside the plugin directories.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT_DIR"
BUILD_DIR="$ROOT_DIR/build"
STAGE_DIR="$BUILD_DIR/root"     # becomes the package payload root ("/")
DIST_DIR="$ROOT_DIR/dist"

# Top-level entries that are tooling/output, not plugins — never packaged.
NON_PLUGIN=( "build" "dist" )

# Where the plugins must land on the target Mac.
INSTALL_LOCATION="/Library/Application Support/Claude/org-plugins"

# ---- config -------------------------------------------------------------------
PKG_IDENTIFIER="example.acme.cowork.org-plugins"
VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --always 2>/dev/null || date +%Y.%m.%d)}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"   # set to a "Developer ID Installer: …" identity to sign

# ---- sanity checks ------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: pkgbuild is macOS-only; run this on a Mac." >&2
  exit 1
fi
command -v pkgbuild >/dev/null || { echo "error: pkgbuild not found (install Xcode CLT)." >&2; exit 1; }

# Discover plugins: any top-level dir carrying .claude-plugin/plugin.json.
# This naturally skips build-pkg.sh, README.md, build/ and dist/.
PLUGINS=()
for entry in "$SRC_DIR"/*/; do
  [[ -d "$entry" ]] || continue
  name="$(basename "$entry")"
  # Skip known tooling/output directories.
  for skip in "${NON_PLUGIN[@]}"; do [[ "$name" == "$skip" ]] && continue 2; done
  if [[ -f "$entry/.claude-plugin/plugin.json" ]]; then
    PLUGINS+=("$name")
  else
    echo "    (skipping '$name' — no .claude-plugin/plugin.json)" >&2
  fi
done
[[ "${#PLUGINS[@]}" -gt 0 ]] || { echo "error: no plugins found in $SRC_DIR" >&2; exit 1; }

# ---- stage payload ------------------------------------------------------------
echo "==> Cleaning build dirs"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$STAGE_DIR$INSTALL_LOCATION" "$DIST_DIR"

echo "==> Staging plugins into payload"
# Copy each discovered plugin, dropping macOS cruft and any local-only files.
for name in "${PLUGINS[@]}"; do
  echo "    - $name"
  rsync -a --exclude '.DS_Store' --exclude '.git' \
        "$SRC_DIR/$name/" "$STAGE_DIR$INSTALL_LOCATION/$name/"
done

# Scrub any AppleDouble / .DS_Store cruft that slipped into the payload.
find "$STAGE_DIR" \( -name '._*' -o -name '.DS_Store' \) -delete

# Re-copy the payload through `ditto --noextattr --norsrc` into a clean root.
# Files inherit a protected `com.apple.provenance` xattr that `xattr -c` can't
# remove; without this step pkgbuild synthesizes ._* AppleDouble entries from it.
CLEAN_DIR="$BUILD_DIR/clean-root"
rm -rf "$CLEAN_DIR"
ditto --noextattr --norsrc "$STAGE_DIR" "$CLEAN_DIR"
STAGE_DIR="$CLEAN_DIR"

# Make sure hook scripts are executable inside the payload.
find "$STAGE_DIR$INSTALL_LOCATION" -type f -name '*.sh' -exec chmod 755 {} +
# Lock down ownership/perms so the installed tree is root-owned and read-only-ish.
chmod -R go-w "$STAGE_DIR$INSTALL_LOCATION"

# ---- build pkg ----------------------------------------------------------------
RAW_PKG="$BUILD_DIR/acme-org-plugins-raw.pkg"
OUT_PKG="$DIST_DIR/acme-org-plugins-$VERSION.pkg"

echo "==> Running pkgbuild (version $VERSION)"
pkgbuild \
  --root "$STAGE_DIR" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  --ownership recommended \
  "$RAW_PKG"

# ---- sign (optional) ----------------------------------------------------------
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> Signing with: $SIGN_IDENTITY"
  productsign --sign "$SIGN_IDENTITY" "$RAW_PKG" "$OUT_PKG"
  echo "    (notarize separately with: xcrun notarytool submit \"$OUT_PKG\" …)"
else
  echo "==> No SIGN_IDENTITY set — producing UNSIGNED package"
  cp "$RAW_PKG" "$OUT_PKG"
fi

echo
echo "Built: $OUT_PKG"
echo
echo "Install locally:   sudo installer -pkg \"$OUT_PKG\" -target /"
echo "Verify contents:   pkgutil --payload-files \"$OUT_PKG\""
echo "Distribute:        upload $OUT_PKG to your MDM as a managed install."
