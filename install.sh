#!/bin/sh
# Installs kopling and its desktop app from a GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/Stjerna/kopling/main/install.sh | sh
#
# Options, set as environment variables:
#   KOPLING_VERSION      a release tag like v0.1.0 (default: latest)
#   KOPLING_INSTALL_DIR  where to put the binaries (default: ~/.local/bin)
#   KOPLING_NO_UPDATE    set to 1 to turn off self-updates
#   KOPLING_BASE_URL     for testing: download from this URL instead of
#                        the release, like http://localhost:8000
#
# The desktop app, kopling-desktop, goes next to kopling. Start it with
# `kopling app`. On Linux it also gets an entry in the app launcher. On
# macOS Kopling.app goes there too: macOS shows the app's notifications
# only from a bundle, and `kopling app` starts that.
#
# kopling updates itself once a day. Pinning a version turns that off.

set -eu

repo=Stjerna/kopling
version=${KOPLING_VERSION:-latest}
dir=${KOPLING_INSTALL_DIR:-$HOME/.local/bin}
no_update=${KOPLING_NO_UPDATE:-}
config=${XDG_CONFIG_HOME:-$HOME/.config}/kopling
data=${XDG_DATA_HOME:-$HOME/.local/share}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

case "$(uname -s)" in
  Linux) os=unknown-linux-gnu ;;
  Darwin) os=apple-darwin ;;
  *) fail "no build for $(uname -s). kopling runs on Linux and macOS." ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) arch=x86_64 ;;
  arm64 | aarch64) arch=aarch64 ;;
  *) fail "no build for $(uname -m)." ;;
esac

# A shell running under Rosetta reports x86_64 on an Apple Silicon Mac.
# The native build is faster there.
if [ "$os" = apple-darwin ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then
  arch=aarch64
fi

target=$arch-$os
if [ "$target" = aarch64-unknown-linux-gnu ]; then
  fail "no build for Linux on ARM yet."
fi

if [ -n "${KOPLING_BASE_URL:-}" ]; then
  base=$KOPLING_BASE_URL
elif [ "$version" = latest ]; then
  base=https://github.com/$repo/releases/latest/download
else
  base=https://github.com/$repo/releases/download/$version
fi

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    fail "needs curl or wget."
  fi
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

file=kopling-$target.tar.gz
printf 'Downloading %s (%s)\n' "$file" "$version"
fetch "$base/$file" "$tmp/$file" || fail "download failed: $base/$file"
fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || fail "download failed: $base/SHA256SUMS"

expected=$(awk -v f="$file" '$2 == f { print $1 }' "$tmp/SHA256SUMS")
actual=$(sha256 "$tmp/$file")
if [ -z "$actual" ]; then
  printf 'warning: no sha256sum or shasum found, so the download was not checked\n' >&2
elif [ "$expected" != "$actual" ]; then
  fail "checksum mismatch for $file. Try again, or download it by hand."
fi

mkdir "$tmp/out"
tar -xzf "$tmp/$file" -C "$tmp/out"
[ -f "$tmp/out/kopling" ] || fail "no kopling in $file."
mkdir -p "$dir"
mv "$tmp/out/kopling" "$dir/kopling"
chmod 755 "$dir/kopling"

# Older releases have no desktop app. Remove one a newer release left,
# as this kopling can't start it.
app=
if [ -f "$tmp/out/kopling-desktop" ]; then
  mv "$tmp/out/kopling-desktop" "$dir/kopling-desktop"
  chmod 755 "$dir/kopling-desktop"
  app=1
else
  rm -f "$dir/kopling-desktop" "$data/applications/kopling.desktop"
fi

# On macOS, the app as a bundle, swapped in whole. Older releases have
# none: remove one a newer release left.
bundle=
if [ -d "$tmp/out/Kopling.app" ]; then
  rm -rf "$dir/Kopling.app"
  mv "$tmp/out/Kopling.app" "$dir/Kopling.app"
  bundle=1
else
  rm -rf "$dir/Kopling.app"
fi

# The binaries aren't signed. Clear the flag macOS uses to block them.
if [ "$os" = apple-darwin ]; then
  xattr -d com.apple.quarantine "$dir/kopling" 2>/dev/null || true
  if [ -n "$app" ]; then
    xattr -d com.apple.quarantine "$dir/kopling-desktop" 2>/dev/null || true
  fi
  if [ -n "$bundle" ]; then
    xattr -dr com.apple.quarantine "$dir/Kopling.app" 2>/dev/null || true
    # Tell macOS about it, so it can ask once whether kopling may send
    # notifications.
    lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    "$lsregister" -f "$dir/Kopling.app" 2>/dev/null || true
  fi
fi

printf 'Installed %s to %s\n' "$("$dir/kopling" --version)" "$dir/kopling"

# On Linux, an entry in the app launcher, with the app's icon.
if [ -n "$app" ] && [ "$os" = unknown-linux-gnu ]; then
  if [ -f "$tmp/out/kopling.png" ]; then
    mkdir -p "$data/icons/hicolor/256x256/apps"
    mv "$tmp/out/kopling.png" "$data/icons/hicolor/256x256/apps/kopling.png"
  fi
  mkdir -p "$data/applications"
  cat > "$data/applications/kopling.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=kopling
Comment=See what changed in a repo, and how the changes connect
Exec="$dir/kopling" app
Icon=kopling
Terminal=false
Categories=Development;
StartupWMClass=kopling
DESKTOP
  update-desktop-database "$data/applications" >/dev/null 2>&1 || true
fi

if [ -n "$bundle" ]; then
  printf 'Installed the desktop app to %s\n' "$dir/Kopling.app"
  printf 'Start the app with: kopling app\n'
elif [ -n "$app" ]; then
  printf 'Installed the desktop app to %s\n' "$dir/kopling-desktop"
  printf 'Start the app with: kopling app\n'
fi

# The binary skips its daily update check while this file exists.
if [ "$version" != latest ] || { [ -n "$no_update" ] && [ "$no_update" != 0 ]; }; then
  mkdir -p "$config"
  : > "$config/no-update"
  printf 'Self-updates are off. Run this script again without options to turn them on.\n'
else
  rm -f "$config/no-update"
  printf 'kopling updates itself once a day.\n'
fi

case ":$PATH:" in
  *":$dir:"*) ;;
  *)
    printf '\n%s is not on your PATH. Add this line to your shell config:\n' "$dir"
    printf '  export PATH="%s:$PATH"\n' "$dir"
    ;;
esac
