#!/usr/bin/env bash
# Install agyswap into ~/.local/bin (override with PREFIX=...).
#   ./install.sh            install agyswap + agyswap-probe
#   ./install.sh --as-agy   also install an `agy` symlink so existing scripts rotate
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)/bin"
PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
mkdir -p "$BIN"
install -m 0755 "$SRC/agyswap" "$SRC/agyswap-probe" "$BIN/"
echo "installed: $BIN/agyswap, $BIN/agyswap-probe"

if [ "${1:-}" = "--as-agy" ]; then
  real=$("$BIN/agyswap" which | awk '/^real agy:/ {print $3}')
  if [ -z "$real" ] || [ "$real" = "<not found>" ]; then
    echo "warning: real agy binary not found; set AGYSWAP_AGY=/path/to/agy before using the shim" >&2
  elif [ "$(dirname "$real")" = "$BIN" ]; then
    echo "error: the real agy lives in $BIN too - move it or set AGYSWAP_AGY, otherwise the shim would call itself" >&2
    exit 1
  fi
  ln -sf "$BIN/agyswap" "$BIN/agy"
  echo "installed: $BIN/agy -> agyswap (real CLI: ${real:-set AGYSWAP_AGY})"
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: $BIN is not in PATH";; esac
