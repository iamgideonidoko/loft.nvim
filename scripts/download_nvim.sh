#!/usr/bin/env bash
# Download a specific Neovim release binary for the current platform and cache
# it under deps/nvim-versions/<version>/.
#
# Usage:  bash scripts/download_nvim.sh <version>
# Example: bash scripts/download_nvim.sh v0.11.0

set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
DEST="deps/nvim-versions/$VERSION"
NVIM_BIN="$DEST/bin/nvim"

if [ -f "$NVIM_BIN" ]; then
  echo "nvim $VERSION already cached at $NVIM_BIN"
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

# ---------------------------------------------------------------------------
# Determine archive filename.
#
# Neovim naming history (GitHub Releases):
#   Linux  < 0.11 : nvim-linux64.tar.gz        (dir: nvim-linux64/)
#   Linux >= 0.11 : nvim-linux-x86_64.tar.gz   (dir: nvim-linux-x86_64/)
#   macOS  < 0.9  : nvim-macos.tar.gz           (dir: nvim-osx64/)
#   macOS >= 0.9  : nvim-macos-{arm64,x86_64}.tar.gz
# ---------------------------------------------------------------------------
minor_version() {
  local ver="$1"
  if [ "$ver" = "nightly" ]; then
    echo 99
  else
    echo "$ver" | sed 's/v0\.\([0-9]*\)\..*/\1/'
  fi
}

MINOR="$(minor_version "$VERSION")"

case "$OS" in
  Linux)
    if [ "$MINOR" -ge 11 ]; then
      ARCHIVE="nvim-linux-x86_64.tar.gz"
    else
      ARCHIVE="nvim-linux64.tar.gz"
    fi
    ;;
  Darwin)
    if [ "$MINOR" -ge 10 ]; then
      if [ "$ARCH" = "arm64" ]; then
        ARCHIVE="nvim-macos-arm64.tar.gz"
      else
        ARCHIVE="nvim-macos-x86_64.tar.gz"
      fi
    else
      # v0.8 and v0.9: universal / x86_64-only binary
      ARCHIVE="nvim-macos.tar.gz"
    fi
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

URL="https://github.com/neovim/neovim/releases/download/$VERSION/$ARCHIVE"
echo "Downloading Neovim $VERSION for $OS/$ARCH ..."
echo "  $URL"

mkdir -p "$DEST"
TMP_ARCHIVE="$DEST/nvim.tar.gz"
curl -fsSL --retry 3 --retry-delay 2 "$URL" -o "$TMP_ARCHIVE"

echo "Extracting..."
# All Neovim archives contain exactly one top-level directory; strip it so
# bin/nvim ends up directly inside $DEST/.
tar -xzf "$TMP_ARCHIVE" -C "$DEST" --strip-components=1
rm "$TMP_ARCHIVE"

if [ ! -f "$NVIM_BIN" ]; then
  echo "Error: $NVIM_BIN not found after extraction." >&2
  exit 1
fi

echo "Neovim $VERSION ready: $NVIM_BIN ($("$NVIM_BIN" --version | head -1))"
