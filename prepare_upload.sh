#!/usr/bin/env bash
# Generate complete GitHub replacement files from the latest public main branch.
set -Eeuo pipefail

REPO_URL="https://github.com/ejaywattapak/cloudfail1003.git"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PWD"
WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

command -v git >/dev/null 2>&1 || { echo "[FAIL] git diperlukan." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[FAIL] python3 diperlukan." >&2; exit 1; }

printf '[INFO] Clone repository terkini...\n'
git clone --depth 1 "$REPO_URL" "$WORKDIR/repo" >/dev/null
cp "$BUNDLE_DIR/apply_themes_update.py" "$WORKDIR/repo/apply_themes_update.py"
mkdir -p "$WORKDIR/repo/menu"
cp "$BUNDLE_DIR/menu/themes.sh" "$WORKDIR/repo/menu/themes.sh"

printf '[INFO] Menjana fail pengganti...\n'
(
  cd "$WORKDIR/repo"
  python3 ./apply_themes_update.py
  bash -n menu.sh core.sh installer.sh setup.sh menu/themes.sh menu/history.sh
)

OUTPUT_FILE="$OUTPUT_DIR/cloudfail1003-theme-files.zip"
python3 - "$WORKDIR/repo" "$OUTPUT_FILE" <<'PY'
import sys, zipfile
from pathlib import Path
root = Path(sys.argv[1])
out = Path(sys.argv[2])
files = ["menu/themes.sh", "menu.sh", "core.sh", "installer.sh", "setup.sh", "menu/history.sh"]
with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for rel in files:
        p = root / rel
        if not p.is_file():
            raise SystemExit(f"Missing output file: {rel}")
        z.write(p, rel)
print("\nZIP ready:", out)
print("Included files:")
for rel in files:
    print(" -", rel)
PY
