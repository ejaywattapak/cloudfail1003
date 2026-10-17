#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.6 - INSTALL / UPDATE
# Repo: https://github.com/ejaywattapak/cloudfail1003
# --------------------------------------------------------------
#  Setiap fail: muat turun -> HTTP 200 -> buang CRLF -> bash -n
#               -> sahkan SHA256 -> backup -> chmod -> mv (atomik)
#  Sebarang semakan gagal = fail lama dikekalkan (tak rosak).
#
#  Perubahan v13.6:
#   [1] modules.list = satu sumber senarai modul
#   [2] Sahkan SHA256 (SHA256SUMS) sebelum ganti fail
#   [3] Backup dihadkan (default 3 terkini per fail)
#   [4] installer.sh turut dipasang ke INSTALL_DIR
#   [5] Arahan baharu: cloudfail-update
#   [6] Auto-menu login guna marker blok; tak lagi padam baris
#       /root/.bashrc yang cuma kebetulan menyebut /usr/bin/menu
#
#  Env override: CF_REPO_RAW, CF_INSTALL_DIR, CF_KEEP_BACKUPS,
#      CF_SHA_CHECK, CF_SKIP_DEPS, CF_SKIP_ANTICK, CF_SKIP_AUTOMENU
# ==============================================================
set -o pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

REPO_RAW="${CF_REPO_RAW:-https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main}"
INSTALL_DIR="${CF_INSTALL_DIR:-/usr/local/share/cloudfail1003}"
MENU_DIR="${INSTALL_DIR}/menu"
MORE_DIR="${INSTALL_DIR}/more"
KEEP_BACKUPS="${CF_KEEP_BACKUPS:-3}"
SHA_CHECK="${CF_SHA_CHECK:-1}"
TMP_DIR="${CF_TMPDIR:-${TMPDIR:-/tmp}}"
MODULES_FILE="modules.list"
SUM_TMP=""
AUTOMENU_MARK_BEGIN="# >>> cloudfail-automenu >>>"
AUTOMENU_MARK_END="# <<< cloudfail-automenu <<<"

ROOT_FILES=("setup.sh" "menu.sh" "core.sh" "installer.sh")
FALLBACK_MODULES=(
    "menu/ipclone.sh" "menu/twinip.sh" "menu/country.sh" "menu/postcode.sh"
    "menu/domainip.sh" "menu/ipdomain.sh" "menu/bughunter.sh" "menu/dnsipv6.sh"
    "menu/ipv6to4.sh" "menu/themes.sh" "menu/history.sh"
    "more/antick.sh"
)
MODULES_TO_UPDATE=()
MODULES_FROM_REPO="0"

say() { echo -e "$1"; }
fail() {
    say "${RED}[✘] $*${NC}" >&2
    exit 1
}

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    fail "Sila jalankan setup sebagai root (sudo -i dahulu)."
fi

# --------------------------------------------------------------
# SHA256SUMS + backup retention + pemetaan laluan
# --------------------------------------------------------------
fetch_sums() {
    local code
    SUM_TMP="${TMP_DIR}/cf_sums.$$"
    rm -f "$SUM_TMP"
    code=$(curl -sS -L --connect-timeout 10 --max-time 60 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/SHA256SUMS" -o "$SUM_TMP" 2>/dev/null) || code="000"
    if [ "$code" != "200" ] || [ ! -s "$SUM_TMP" ]; then
        rm -f "$SUM_TMP"
        SUM_TMP=""
        return 1
    fi
    sed -i 's/\r$//' "$SUM_TMP" 2>/dev/null
    return 0
}

# verify_sha256 <rel> <file>
#   0 = sepadan, 1 = TIDAK sepadan, 2 = dilangkau, 3 = tak tersenarai
verify_sha256() {
    local rel="$1" file="$2" want got
    [ "$SHA_CHECK" = "1" ] || return 2
    command -v sha256sum >/dev/null 2>&1 || return 2
    [ -n "$SUM_TMP" ] && [ -s "$SUM_TMP" ] || return 2
    want=$(awk -v f="$rel" '{ n=$2; sub(/^\*/, "", n); if (n == f) { print $1; exit } }' "$SUM_TMP")
    [ -n "$want" ] || return 3
    got=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
    if [ -n "$got" ] && [ "$got" = "$want" ]; then
        return 0
    fi
    return 1
}

prune_backups() {
    local dest="$1" keep="$2" f n=0
    keep="${keep:-3}"
    case "$keep" in ''|*[!0-9]*) keep=3 ;; esac
    [ "$keep" -eq 0 ] && return 0
    ls -1dt "${dest}".bak.* 2>/dev/null | while IFS= read -r f; do
        n=$((n + 1))
        if [ "$n" -gt "$keep" ]; then
            rm -f "$f"
        fi
    done
    return 0
}

dest_for() {
    case "$1" in
        installer.sh) printf '%s' "${INSTALL_DIR}/installer.sh" ;;
        menu/*)       printf '%s/%s' "$MENU_DIR" "${1#menu/}" ;;
        more/*)       printf '%s/%s' "$MORE_DIR" "${1#more/}" ;;
        *)            printf '%s/%s' "$INSTALL_DIR" "$1" ;;
    esac
}

# --------------------------------------------------------------
# Muat turun + semua semakan + backup + ganti atomik
# --------------------------------------------------------------
update_one() {
    local rel="$1" dest="$2" tmp http_code backup stamp vrc
    tmp="${dest}.download.$$"
    mkdir -p "$(dirname "$dest")" || return 1
    rm -f "$tmp"
    say "${WHITE}[➜] Memuat turun ${rel}...${NC}"
    http_code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || http_code="000"
    if [ "$http_code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        fail "Muat turun ${rel} gagal (HTTP ${http_code}); salinan lama dikekalkan."
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        fail "Sintaks ${rel} tidak sah; salinan lama dikekalkan."
    fi
    verify_sha256 "$rel" "$tmp"
    vrc=$?
    if [ "$vrc" -eq 1 ]; then
        rm -f "$tmp"
        fail "SHA256 ${rel} tak sepadan; salinan lama dikekalkan. (regenerate: bash tools/gen_sha256sums.sh)"
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="${dest}.bak.${stamp}"
        cp -a "$dest" "$backup" || {
            rm -f "$tmp"
            fail "Tidak dapat membuat backup bagi ${rel}; salinan lama tidak disentuh."
        }
    fi
    chmod 0755 "$tmp" 2>/dev/null
    if ! mv -f "$tmp" "$dest"; then
        rm -f "$tmp"
        fail "Gagal memasang ${rel}."
    fi
    prune_backups "$dest" "$KEEP_BACKUPS"
    case "$vrc" in
        0) say "${GREEN}[✔] ${rel} OK (http200 bash sha256)${NC}" ;;
        2) say "${GREEN}[✔] ${rel} OK (http200 bash, sha dilangkau)${NC}" ;;
        3) say "${GREEN}[✔] ${rel} OK (http200 bash, tak dlm sums)${NC}" ;;
    esac
    return 0
}

# Untuk fail bukan skrip (modules.list) - tiada semakan bash -n
update_plain() {
    local rel="$1" dest="$2" tmp http_code backup stamp vrc
    tmp="${dest}.download.$$"
    mkdir -p "$(dirname "$dest")" || return 1
    rm -f "$tmp"
    say "${WHITE}[➜] Memuat turun ${rel}...${NC}"
    http_code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || http_code="000"
    if [ "$http_code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        fail "Muat turun ${rel} gagal (HTTP ${http_code}); salinan lama dikekalkan."
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    verify_sha256 "$rel" "$tmp"
    vrc=$?
    if [ "$vrc" -eq 1 ]; then
        rm -f "$tmp"
        fail "SHA256 ${rel} tak sepadan; salinan lama dikekalkan."
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="${dest}.bak.${stamp}"
        cp -a "$dest" "$backup" || {
            rm -f "$tmp"
            fail "Gagal backup ${rel}."
        }
    fi
    chmod 0644 "$tmp" 2>/dev/null
    mv -f "$tmp" "$dest" || fail "Gagal memasang ${rel}."
    prune_backups "$dest" "$KEEP_BACKUPS"
    say "${GREEN}[✔] ${rel} OK (http200)${NC}"
    return 0
}

load_module_list() {
    local tmp code line
    tmp="${TMP_DIR}/cf_modules.$$"
    rm -f "$tmp"
    code=$(curl -sS -L --connect-timeout 10 --max-time 60 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${MODULES_FILE}" -o "$tmp" 2>/dev/null) || code="000"
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        MODULES_TO_UPDATE=("${FALLBACK_MODULES[@]}")
        MODULES_FROM_REPO="0"
        return 1
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    MODULES_TO_UPDATE=()
    while IFS= read -r line; do
        case "$line" in ''|"#"*) continue ;; esac
        case "$line" in *" "*) continue ;; esac
        MODULES_TO_UPDATE+=("$line")
    done < "$tmp"
    rm -f "$tmp"
    MODULES_FROM_REPO="1"
    if [ "${#MODULES_TO_UPDATE[@]}" -eq 0 ]; then
        MODULES_TO_UPDATE=("${FALLBACK_MODULES[@]}")
        MODULES_FROM_REPO="0"
        return 1
    fi
    return 0
}

# --------------------------------------------------------------
# Kebergantungan sistem / zon waktu / vnstat / arahan / auto-menu
# --------------------------------------------------------------
install_deps() {
    local OS_ID="" OS_LIKE=""
    if [ -r /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
    else
        OS_ID="unknown"
    fi
    say "${CYAN}[➜] Menyediakan kebergantungan sistem...${NC}"
    case "$OS_ID $OS_LIKE" in
        *ubuntu*|*debian*)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y || fail "apt-get update gagal."
            apt-get install -y curl wget jq gawk dnsutils bind9-host openssl vnstat bc procps \
                ca-certificates tzdata tmux figlet || fail "Gagal memasang pakej yang diperlukan."
            ;;
        *rocky*|*almalinux*|*centos*|*rhel*|*fedora*)
            dnf install -y epel-release || true
            dnf install -y curl wget jq gawk bind-utils openssl vnstat bc procps-ng \
                ca-certificates tzdata tmux figlet || fail "Gagal memasang pakej yang diperlukan."
            ;;
        *)
            say "${YELLOW}[!] Distro tidak dikenali (${OS_ID}); cuba teruskan dengan pakej sedia ada.${NC}"
            ;;
    esac
}

set_timezone() {
    say "${CYAN}[➜] Menetapkan zon waktu Malaysia...${NC}"
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null; then
            return 0
        fi
    fi
    if [ -e /usr/share/zoneinfo/Asia/Kuala_Lumpur ]; then
        ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime 2>/dev/null || \
            say "${YELLOW}[!] Gagal set zon waktu (bukan fatal).${NC}"
    fi
    return 0
}

enable_vnstat() {
    if ! command -v vnstat >/dev/null 2>&1; then
        say "${YELLOW}[i] vnstat tiada; langkau pengaktifan.${NC}"
        return 0
    fi
    local IFACE
    IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
    if [ -n "$IFACE" ]; then
        vnstat --add -i "$IFACE" >/dev/null 2>&1 || true
    fi
    systemctl enable vnstat >/dev/null 2>&1 || true
    systemctl restart vnstat >/dev/null 2>&1 || true
    return 0
}

link_commands() {
    say "${CYAN}[➜] Mengaktifkan arahan menu & update...${NC}"
    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/bin/menu 2>/dev/null || true
    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu 2>/dev/null || true
    ln -sfn "${INSTALL_DIR}/installer.sh" /usr/local/bin/cloudfail-update 2>/dev/null || true
    chmod 0755 "${INSTALL_DIR}/menu.sh" "${INSTALL_DIR}/installer.sh" 2>/dev/null || true
    return 0
}

# Auto-menu masa login. Guna blok bermarker supaya boleh dibuang dengan
# selamat (versi lama padam apa-apa baris yang menyebut /usr/bin/menu).
write_automenu() {
    if [ "${CF_SKIP_AUTOMENU:-0}" = "1" ]; then
        say "${YELLOW}[i] CF_SKIP_AUTOMENU=1 - auto-menu login dilangkau.${NC}"
        return 0
    fi
    local target rc_file

    target="/etc/profile.d/ejaywatt_cloudfail.sh"
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
        cat > "$target" <<'AUTOPOP'
# Auto-buka menu CloudFail untuk login SSH interaktif (blok bermarker).
# Buang blok ini jika tak mahu menu auto-buka.
# >>> cloudfail-automenu >>>
if [ -t 0 ] && [ -n "$PS1" ] && [ -z "${CF_MENU_LOADED:-}" ]; then
    export CF_MENU_LOADED=1
    /usr/bin/menu
fi
# <<< cloudfail-automenu <<<
AUTOPOP
        chmod 0644 "$target" 2>/dev/null || true
    else
        say "${YELLOW}[!] /etc/profile.d tidak boleh ditulis; auto-menu profil dilangkau.${NC}"
    fi

    rc_file="${HOME}/.bashrc"
    if [ ! -e "$rc_file" ]; then
        : > "$rc_file" 2>/dev/null || return 0
    fi
    [ -w "$rc_file" ] || {
        say "${YELLOW}[!] ${rc_file} tidak boleh ditulis; auto-menu bashrc dilangkau.${NC}"
        return 0
    }
    # Buang blok bermarker lama DAN baris lama v13.5 (penanda CF_MENU_LOADED sahaja).
    awk -v b="$AUTOMENU_MARK_BEGIN" -v e="$AUTOMENU_MARK_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        skip == 1 { next }
        /CF_MENU_LOADED/ { next }
        { print }
    ' "$rc_file" > "${rc_file}.cf.tmp" 2>/dev/null && mv -f "${rc_file}.cf.tmp" "$rc_file"
    {
        printf '\n%s\n' "$AUTOMENU_MARK_BEGIN"
        printf '%s\n' '[ -t 0 ] && [ -z "${CF_MENU_LOADED:-}" ] && export CF_MENU_LOADED=1 && /usr/bin/menu'
        printf '%s\n' "$AUTOMENU_MARK_END"
    } >> "$rc_file"
    say "${GREEN}[✔] Auto-menu login ditulis dengan marker (senang dibuang).${NC}"
    return 0
}

# ==============================================================
# Aliran utama
# ==============================================================
if [ "${CF_SKIP_DEPS:-0}" = "1" ]; then
    say "${YELLOW}[i] CF_SKIP_DEPS=1 - pemasangan pakej dilangkau.${NC}"
else
    install_deps
fi

set_timezone

mkdir -p "$INSTALL_DIR" "$MENU_DIR" "$MORE_DIR" || fail "Gagal mencipta direktori pemasangan."

fetch_sums || say "${YELLOW}[!] SHA256SUMS tidak dapat dimuat turun - semakan checksum dilangkau.${NC}"
if load_module_list; then
    say "${GREEN}[i] Senarai modul dari ${MODULES_FILE} (${#MODULES_TO_UPDATE[@]} modul).${NC}"
else
    say "${YELLOW}[!] ${MODULES_FILE} tidak dapat dibaca - guna senarai lalai.${NC}"
fi

failures=0

say "${CYAN}[➜] Menyediakan senarai modul...${NC}"
update_plain "$MODULES_FILE" "${INSTALL_DIR}/${MODULES_FILE}" || failures=$((failures + 1))

say "${CYAN}[➜] Mengemas kini fail utama...${NC}"
for f in "${ROOT_FILES[@]}"; do
    update_one "$f" "$(dest_for "$f")" || failures=$((failures + 1))
done

say "${CYAN}[➜] Mengemas kini modul...${NC}"
for f in "${MODULES_TO_UPDATE[@]}"; do
    update_one "$f" "$(dest_for "$f")" || failures=$((failures + 1))
done

# ANTICK ialah installer, bukan fail library pasif.
if [ "${CF_SKIP_ANTICK:-0}" = "1" ]; then
    say "${YELLOW}[i] CF_SKIP_ANTICK=1 - ANTICK dilangkau.${NC}"
elif [ -f "${MORE_DIR}/antick.sh" ]; then
    say "${CYAN}[➜] Menjalankan pemasang ANTICK...${NC}"
    if bash "${MORE_DIR}/antick.sh"; then
        say "${GREEN}[✔] ANTICK berjaya dipasang.${NC}"
    else
        say "${YELLOW}[!] ANTICK gagal dipasang; semak mesej ralat di atas. Setup CloudFail diteruskan.${NC}"
    fi
else
    say "${YELLOW}[!] ${MORE_DIR}/antick.sh tiada; ANTICK dilangkau.${NC}"
fi

enable_vnstat
link_commands
write_automenu

say ""
if [ "$failures" -eq 0 ]; then
    say "${GREEN}╭──────────────────────────────────────────────────────────────╮${NC}"
    say "${GREEN}│          CLOUDFAIL v13.6 - INSTALL / UPDATE SELESAI          │${NC}"
    say "${GREEN}╰──────────────────────────────────────────────────────────────╯${NC}"
    say "${WHITE}Tema disimpan dalam: ${HOME}/.cloudfail_theme.conf${NC}"
    say "${WHITE}Buka menu dengan arahan: ${CYAN}menu${NC}"
    say "${WHITE}Kemas kini kemudian: ${CYAN}cloudfail-update${NC}"
    say "${YELLOW}[i] VPS tidak akan reboot secara automatik.${NC}"
    say "${CYAN}[i] Backup: .bak.TIMESTAMP (${KEEP_BACKUPS} terkini per fail).${NC}"

    # Buka menu serta-merta, tetapi hanya dalam terminal interaktif.
    if [ -t 0 ] && [ -x /usr/bin/menu ]; then
        say "${CYAN}[➜] Membuka menu CloudFail...${NC}"
        exec /usr/bin/menu
    fi
else
    say "${RED}[!] ${failures} fail gagal dipasang. Salinan lama bagi fail itu dikekalkan.${NC}"
    say "${YELLOW}[i] Jalankan semula: bash setup.sh${NC}"
    exit 1
fi
