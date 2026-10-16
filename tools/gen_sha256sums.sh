#!/usr/bin/env bash
# ==============================================================
# Jana fail SHA256SUMS untuk repo CloudFail.
# Jalankan dari mana-mana lokasi:  bash tools/gen_sha256sums.sh
#
# WAJIB dijalankan setiap kali mana-mana fail di bawah diubah, jika
# tidak installer VPS akan TOLAK fail itu (checksum tak sepadan).
# ==============================================================
set -o pipefail

cd "$(dirname "$0")/.." || exit 1

command -v sha256sum >/dev/null 2>&1 || {
    echo "[FAIL] sha256sum diperlukan." >&2
    exit 1
}

FILES=("installer.sh" "setup.sh" "core.sh" "menu.sh" "modules.list")

if [ -f modules.list ]; then
    while IFS= read -r line; do
        case "$line" in ''|"#"*) continue ;; esac
        case "$line" in *" "*) continue ;; esac
        [ -f "$line" ] || { echo "[WARN] tiada fail: $line" >&2; continue; }
        FILES+=("$line")
    done < modules.list
else
    echo "[FAIL] modules.list tidak dijumpai." >&2
    exit 1
fi

sha256sum "${FILES[@]}" > SHA256SUMS || exit 1
echo "[OK] SHA256SUMS dijana (${#FILES[@]} fail):"
cat SHA256SUMS
