#!/bin/bash
set -euo pipefail

APP="${1:-}"
[[ -n "$APP" && -d "$APP" ]] || { echo "Usage: $0 Payload/YourApp.app" >&2; exit 2; }
FRAMEWORKS="$APP/Frameworks"
[[ -d "$FRAMEWORKS" ]] || { echo "ERROR: missing $FRAMEWORKS" >&2; exit 1; }

for name in iKiraPlus UIDisplayServices; do
  f="$FRAMEWORKS/$name.dylib"
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
  codesign --verify --strict --verbose=2 "$f"
done

for name in UIInfrastructure CoreLifecycle ProcessServices ProcessSupport SystemEnvironment; do
  fw="$FRAMEWORKS/$name.framework"
  [[ -d "$fw" && -f "$fw/$name" && -f "$fw/Info.plist" ]] || { echo "ERROR: incomplete $fw" >&2; exit 1; }
  codesign --verify --strict --verbose=2 "$fw"
done

PLIST="$APP/Info.plist"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
EXE="$APP/$EXE_NAME"
[[ -f "$EXE" ]] || { echo "ERROR: missing main executable $EXE" >&2; exit 1; }

LOADS="$(otool -L "$EXE")"
printf '%s\n' "$LOADS" | grep -Fq '@executable_path/Frameworks/iKiraPlus.dylib' \
  || { echo "ERROR: main executable does not load iKiraPlus.dylib" >&2; exit 1; }
printf '%s\n' "$LOADS" | grep -Fq '@executable_path/Frameworks/UIDisplayServices.dylib' \
  || { echo "ERROR: main executable does not load UIDisplayServices.dylib" >&2; exit 1; }

# Framework guards are deliberately dlopen()'d by UIDisplayServices, not injected
# into the main executable.
for peer in UIInfrastructure CoreLifecycle ProcessServices ProcessSupport SystemEnvironment; do
  if printf '%s\n' "$LOADS" | grep -Fq "$peer.framework/$peer"; then
    echo "WARNING: $peer.framework is directly linked by the main executable; this is unnecessary." >&2
  fi
done

codesign --verify --deep --strict --verbose=2 "$APP"
echo "OK: app, two dylibs, five framework bundles and direct load commands verify."
