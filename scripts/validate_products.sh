#!/bin/bash
set -euo pipefail

DIR="${1:-.}"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -d "$DIR" ]] || fail "directory not found: $DIR"

check_macho() {
  local f="$1" label="$2"
  [[ -f "$f" && -s "$f" ]] || fail "missing/empty $label: $f"

  local header archs deps
  header="$(otool -hv "$f" 2>&1)" || { printf '%s\n' "$header" >&2; fail "$label cannot be parsed as Mach-O"; }
  printf '%s\n' "$header" | grep -Eq '(^|[[:space:]])(MH_)?DYLIB([[:space:]]|$)' \
    || { printf '%s\n' "$header" >&2; fail "$label is not an MH_DYLIB"; }

  archs="$(xcrun lipo -archs "$f" 2>/dev/null)" || fail "cannot read architectures for $label"
  case " $archs " in *" arm64 "*) ;; *) fail "$label has no arm64 slice: ${archs:-unknown}" ;; esac
  xcrun lipo "$f" -verify_arch arm64 >/dev/null 2>&1 || fail "$label failed arm64 verification"

  deps="$(otool -L "$f")" || fail "cannot read dependencies for $label"
  if printf '%s\n' "$deps" | grep -Eiq 'MobileSubstrate|CydiaSubstrate|libhooker|ElleKit|/var/jb/|/Library/MobileSubstrate/'; then
    printf '%s\n' "$deps" >&2
    fail "$label has a tweak-loader dependency"
  fi

  if /usr/bin/strings -a "$f" | grep -Fq 'https://t.me/'; then
    fail "$label exposes a plaintext Telegram URL"
  fi
}

for name in iKiraPlus UIDisplayServices; do
  check_macho "$DIR/$name.dylib" "$name.dylib"
done

for name in UIInfrastructure CoreLifecycle ProcessServices ProcessSupport SystemEnvironment; do
  fw="$DIR/$name.framework"
  bin="$fw/$name"
  plist="$fw/Info.plist"
  [[ -d "$fw" ]] || fail "missing framework bundle: $fw"
  [[ -f "$plist" ]] || fail "missing $name.framework/Info.plist"
  /usr/bin/plutil -lint "$plist" >/dev/null || fail "invalid Info.plist for $name.framework"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" == "$name" ]] \
    || fail "$name.framework has wrong CFBundleExecutable"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$plist")" == "FMWK" ]] \
    || fail "$name.framework is not CFBundlePackageType FMWK"

  check_macho "$bin" "$name.framework/$name"

  id="$(otool -D "$bin" 2>/dev/null | tail -n +2 | head -n 1 | xargs || true)"
  expected="@rpath/$name.framework/$name"
  [[ "$id" == "$expected" ]] || fail "$name.framework install-name is '$id', expected '$expected'"
done

echo "OK: 2 dylibs + 5 genuine arm64 dynamic frameworks validated."
