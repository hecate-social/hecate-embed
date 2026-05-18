#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

cd "$ROOT/native/hecate_embed_nif"
cargo build --release

mkdir -p "$ROOT/priv/lib"
case "$(uname -s)" in
    Linux*)   ext=so ;;
    Darwin*)  ext=dylib ;;
    MINGW*|MSYS*|CYGWIN*) ext=dll ;;
    *) echo "Unsupported: $(uname -s)" >&2; exit 1 ;;
esac

src="$ROOT/native/hecate_embed_nif/target/release/libhecate_embed_nif.${ext}"
dst="$ROOT/priv/lib/libhecate_embed_nif.${ext}"
cp "$src" "$dst"
echo "Built: $dst"
