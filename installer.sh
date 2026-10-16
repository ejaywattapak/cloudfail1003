#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.6 - OFFICIAL INSTALLER / CHECK & UPDATE
# Repo: https://github.com/ejaywattapak/cloudfail1003
# --------------------------------------------------------------
#  Option 1 : jalankan setup.sh (pasang / kemas kini penuh)
#  Option 2 : semak + muat turun + update fail sahaja
#             (tak pasang ANTICK, tak buka menu)
#
#  Perubahan v13.6:
#   [1] Senarai modul dibaca dari modules.list (satu sumber sahaja);
#       sebelum ini senarai sama ada 3 salinan (installer/setup/menu)
#   [2] ROOT_FILES kini benar-benar digunakan (sebelum ini kod mati)
#   [3] Sahkan SHA256 dari SHA256SUMS sebelum ganti fail
#   [4] Backup dihadkan (default 3 terkini) supaya .bak tak menimbun
#   [5] installer.sh dipasang ke INSTALL_DIR + self-update pada
#       Option 1 DAN Option 2
#   [6] Penjajaran kotak menu diperbetulkan (menu_row/menu_title_row)
#
#  PENTING: selepas edit mana-mana fail .sh, regenerate SHA256SUMS:
#      bash tools/gen_sha256sums.sh
#  Kalau tidak, update fail itu akan DITOLAK (checksum tak sepadan).
#  Escape hatch: CF_SHA_CHECK=0 ./installer.sh
#
#  Env override (ujian / mirror): CF_REPO_RAW, CF_INSTALL_DIR,
#      CF_KEEP_BACKUPS, CF_SHA_CHECK, CF_TMPDIR
# ==============================================================
set -o pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

REPO_RAW="${CF_REPO_RAW:-https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main}"
INSTALL_DIR="${CF_INSTALL_DIR:-/usr/local/share/cloudfail1003}"
MENU_DIR="${INSTALL_DIR}/menu"
MORE_DIR="${INSTALL_DIR}/more"
SELF_PATH="$(realpath "$0" 2>/dev/null || printf '%s' "$0")"
KEEP_BACKUPS="${CF_KEEP_BACKUPS:-3}"
SHA_CHECK="${CF_SHA_CHECK:-1}"
TMP_DIR="${CF_TMPDIR:-${TMPDIR:-/tmp}}"
MODULES_FILE="modules.list"
SUM_TMP=""

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

show_banner() {
    clear
    echo -e "${CYAN}"
    if command -v figlet >/dev/null 2>&1 && figlet -w 90 -f "ANSI Shadow" "EJAYWATT CLOUDFAIL" 2>/dev/null; then
        :
    else
        echo "EJAYWATT CLOUDFAIL"
    fi
    echo -e "${NC}"
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC}   ${WHITE}⚡ OFFICIAL INSTALLER v13.6 ⚡${NC}   ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

# Baris menu dengan lebar tetap (54 aksara dalam kotak) supaya border sejajar.
menu_row() {
    local number="$1" label="$2" description="$3"
    printf '%b│%b  %b%-4s%b  %b%-21.21s%b  %b%-23.23s%b%b│%b\n' \
        "$CYAN" "$NC" "$YELLOW" "[$number]" "$NC" \
        "$WHITE" "$label" "$NC" "$GRAY" "$description" "$NC" "$CYAN" "$NC"
}

menu_title_row() {
    local title="${1:-MAIN MENU}"
    local left=$(( (54 - ${#title}) / 2 ))
    local right=$(( 54 - ${#title} - left ))
    printf '%b│%b%*s%s%*s%b│%b\n' "$CYAN" "$NC" "$left" "" "$title" "$right" "" "$CYAN" "$NC"
}

require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        say "${RED}[✘] Sila jalankan installer sebagai root (sudo -i dahulu).${NC}"
        return 1
    fi
    return 0
}

# --------------------------------------------------------------
# Muat turun SHA256SUMS (best-effort). Gagal = semakan checksum dilangkau.
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
#   0 = checksum sepadan, 1 = TIDAK sepadan, 2 = dilangkau, 3 = tak tersenarai
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

# Simpan hanya KEEP_BACKUPS backup terkini untuk satu fail.
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

# Laluan pemasangan untuk satu laluan relatif repo.
dest_for() {
    case "$1" in
        installer.sh) printf '%s' "${INSTALL_DIR}/installer.sh" ;;
        menu/*)       printf '%s/%s' "$MENU_DIR" "${1#menu/}" ;;
        more/*)       printf '%s/%s' "$MORE_DIR" "${1#more/}" ;;
        *)            printf '%s/%s' "$INSTALL_DIR" "$1" ;;
    esac
}

# --------------------------------------------------------------
# Download -> HTTP 200 -> buang CRLF -> bash -n -> SHA256 -> backup
# -> chmod -> mv (atomik). Apa-apa gagal = fail lama dikekalkan.
# --------------------------------------------------------------
update_one() {
    local rel="$1" dest="$2" tmp code backup stamp vrc
    tmp="${dest}.download.$$"
    mkdir -p "$(dirname "$dest")" || {
        say "  ${RED}[✘] ${rel}: gagal cipta folder${NC}"
        return 1
    }
    rm -f "$tmp"
    code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || code="000"
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s HTTP %s — fail lama dikekalkan${NC}\n" "$rel" "$code"
        return 1
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s sintaks Bash gagal — fail lama dikekalkan${NC}\n" "$rel"
        return 1
    fi
    verify_sha256 "$rel" "$tmp"
    vrc=$?
    if [ "$vrc" -eq 1 ]; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s SHA256 TIDAK SEPADAN — fail lama dikekalkan${NC}\n" "$rel"
        printf "  ${YELLOW}    (regenerate SHA256SUMS: bash tools/gen_sha256sums.sh)${NC}\n"
        return 1
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="${dest}.bak.${stamp}"
        if ! cp -a "$dest" "$backup"; then
            rm -f "$tmp"
            printf "  ${RED}[✘] %-26s backup gagal — fail lama dikekalkan${NC}\n" "$rel"
            return 1
        fi
    fi
    chmod 0755 "$tmp" 2>/dev/null
    if ! mv -f "$tmp" "$dest"; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s gagal ganti fail${NC}\n" "$rel"
        return 1
    fi
    prune_backups "$dest" "$KEEP_BACKUPS"
    case "$vrc" in
        0) printf "  ${GREEN}[✔] %-26s HTTP 200 | Bash OK | SHA256 OK | UPDATED${NC}\n" "$rel" ;;
        2) printf "  ${GREEN}[✔] %-26s HTTP 200 | Bash OK | UPDATED${NC} ${YELLOW}(SHA256 dilangkau)${NC}\n" "$rel" ;;
        3) printf "  ${GREEN}[✔] %-26s HTTP 200 | Bash OK | UPDATED${NC} ${YELLOW}(tiada dlm SHA256SUMS)${NC}\n" "$rel" ;;
    esac
    return 0
}

# update_plain <rel> <dest> : untuk fail bukan skrip (modules.list)
update_plain() {
    local rel="$1" dest="$2" tmp code backup stamp vrc
    tmp="${dest}.download.$$"
    mkdir -p "$(dirname "$dest")" || {
        say "  ${RED}[✘] ${rel}: gagal cipta folder${NC}"
        return 1
    }
    rm -f "$tmp"
    code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || code="000"
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s HTTP %s — fail lama dikekalkan${NC}\n" "$rel" "$code"
        return 1
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    verify_sha256 "$rel" "$tmp"
    vrc=$?
    if [ "$vrc" -eq 1 ]; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s SHA256 TIDAK SEPADAN — fail lama dikekalkan${NC}\n" "$rel"
        return 1
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="${dest}.bak.${stamp}"
        if ! cp -a "$dest" "$backup"; then
            rm -f "$tmp"
            printf "  ${RED}[✘] %-26s backup gagal — fail lama dikekalkan${NC}\n" "$rel"
            return 1
        fi
    fi
    chmod 0644 "$tmp" 2>/dev/null
    if ! mv -f "$tmp" "$dest"; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-26s gagal ganti fail${NC}\n" "$rel"
        return 1
    fi
    prune_backups "$dest" "$KEEP_BACKUPS"
    printf "  ${GREEN}[✔] %-26s HTTP 200 | UPDATED${NC}\n" "$rel"
    return 0
}

# Baca modules.list dari repo; gagal = guna senarai lalai dalam fail ini.
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
    [ "${#MODULES_TO_UPDATE[@]}" -gt 0 ] || {
        MODULES_TO_UPDATE=("${FALLBACK_MODULES[@]}")
        MODULES_FROM_REPO="0"
        return 1
    }
    return 0
}

# Kemas kini installer.sh: salinan rasmi dalam INSTALL_DIR + salinan yang
# sedang berjalan (kalau ia fail tempatan, bukan /tmp atau paip).
update_self() {
    local rc=0
    update_one "installer.sh" "${INSTALL_DIR}/installer.sh" || rc=1
    case "$SELF_PATH" in
        /dev/*|/proc/*|/run/*|/tmp/*|"${INSTALL_DIR}/installer.sh") : ;;
        *)
            if [ -f "$SELF_PATH" ] && [ -w "$SELF_PATH" ] && [ -w "$(dirname "$SELF_PATH")" ]; then
                update_one "installer.sh" "$SELF_PATH" || rc=1
            else
                say "${YELLOW}[i] Salinan installer.sh di ${SELF_PATH} tidak diganti (bukan fail tempatan yang boleh ditulis).${NC}"
            fi
            ;;
    esac
    return "$rc"
}

run_installer() {
    show_banner
    if ! require_root; then
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi

    local tmp="${TMP_DIR}/cf_setup.sh.$$" status=0 vrc
    echo -e "${CYAN}[➜] Memuat turun setup.sh dari GitHub...${NC}"
    if ! curl -fsSL --retry 2 --connect-timeout 10 --max-time 120 "${REPO_RAW}/setup.sh" -o "$tmp"; then
        rm -f "$tmp"
        echo -e "${RED}[✘] Gagal memuat turun setup.sh dari ${REPO_RAW}/setup.sh${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    sed -i 's/\r$//' "$tmp" 2>/dev/null
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        echo -e "${RED}[✘] setup.sh mempunyai ralat sintaks; pemasangan dibatalkan.${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    fetch_sums || true
    verify_sha256 "setup.sh" "$tmp"
    vrc=$?
    if [ "$vrc" -eq 1 ]; then
        rm -f "$tmp"
        echo -e "${RED}[✘] SHA256 setup.sh tidak sepadan dengan SHA256SUMS; pemasangan dibatalkan.${NC}"
        echo -e "${YELLOW}[i] Regenerate SHA256SUMS dalam repo (bash tools/gen_sha256sums.sh).${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    chmod 0700 "$tmp"
    bash "$tmp"
    status=$?
    rm -f "$tmp"

    if [ "$status" -eq 0 ]; then
        echo -e "\n${GREEN}[✔] Pemasangan / kemas kini selesai.${NC}"
        echo -e "${CYAN}[➜] Menyegarkan fail installer.sh...${NC}"
        update_self || true
    else
        echo -e "\n${RED}[✘] Setup keluar dengan kod ${status}; kemas kini installer.sh dilangkau.${NC}"
    fi
    read -rp "Tekan Enter untuk kembali ke installer..." _
}

check_and_update_modules() {
    show_banner
    if ! require_root; then
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    mkdir -p "$INSTALL_DIR" "$MENU_DIR" "$MORE_DIR" || {
        echo -e "${RED}[✘] Tak dapat menyediakan folder pemasangan.${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    }

    echo -e "${CYAN}Semak, muat turun, uji sintaks/checksum dan kemas kini fail dari GitHub:${NC}\n"
    local failures=0 f

    fetch_sums || say "${YELLOW}[!] SHA256SUMS tidak dapat dimuat turun — semakan checksum dilangkau.${NC}"
    if load_module_list; then
        say "${GREEN}[i] Senarai modul dibaca dari ${MODULES_FILE} (${#MODULES_TO_UPDATE[@]} modul).${NC}"
    else
        say "${YELLOW}[!] ${MODULES_FILE} tidak dapat dibaca — guna senarai lalai dalam installer.sh.${NC}"
    fi

    echo -e "\n${YELLOW}▸ Fail utama:${NC}"
    for f in "${ROOT_FILES[@]}"; do
        [ "$f" = "installer.sh" ] && continue
        update_one "$f" "$(dest_for "$f")" || failures=$((failures + 1))
    done

    echo -e "\n${YELLOW}▸ Modul:${NC}"
    for f in "${MODULES_TO_UPDATE[@]}"; do
        update_one "$f" "$(dest_for "$f")" || failures=$((failures + 1))
    done

    echo -e "\n${YELLOW}▸ Senarai modul:${NC}"
    update_plain "$MODULES_FILE" "${INSTALL_DIR}/${MODULES_FILE}" || failures=$((failures + 1))

    echo -e "\n${YELLOW}▸ Installer:${NC}"
    update_self || failures=$((failures + 1))

    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/bin/menu 2>/dev/null || true
    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu 2>/dev/null || true
    ln -sfn "${INSTALL_DIR}/installer.sh" /usr/local/bin/cloudfail-update 2>/dev/null || true
    chmod 0755 "${INSTALL_DIR}/menu.sh" "${INSTALL_DIR}/installer.sh" 2>/dev/null || true

    echo
    if [ "$failures" -eq 0 ]; then
        echo -e "${GREEN}[✔] Semua fail berjaya dimuat turun, disemak dan dikemas kini.${NC}"
        echo -e "${CYAN}[i] Backup lama disimpan dengan akhiran .bak.TIMESTAMP (${KEEP_BACKUPS} terkini sahaja).${NC}"
    else
        echo -e "${RED}[!] ${failures} fail gagal dikemas kini. Salinan lama dikekalkan untuk fail yang gagal.${NC}"
        echo -e "${YELLOW}[i] Kalau mesejnya \"SHA256 TIDAK SEPADAN\", regenerate SHA256SUMS dalam repo.${NC}"
    fi

    # Option 2 hanya semak/kemas kini fail; ia tak pasang ANTICK dan tak buka menu.
    read -rp "Tekan Enter untuk kembali ke installer..." _
}

while true; do
    show_banner
    printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$CYAN" "$NC"
    menu_title_row "OFFICIAL INSTALLER"
    printf '%b├──────────────────────────────────────────────────────┤%b\n' "$CYAN" "$NC"
    menu_row 1 "Run Installer / Update" "Pasang atau kemas kini"
    menu_row 2 "Check & Update Files"  "Semak, muat turun & update"
    menu_row 0 "Exit"                 "Keluar dari installer"
    printf '%b╰──────────────────────────────────────────────────────╯%b\n' "$CYAN" "$NC"
    printf '%b╰─➤ Pilih [1/2/0] : %b' "$CYAN" "$YELLOW"
    read -r opt
    printf '%b' "$NC"
    case "$opt" in
        1) run_installer ;;
        2) check_and_update_modules ;;
        0) exit 0 ;;
        *) echo -e "${RED}[!] Pilihan tidak sah.${NC}"; sleep 1 ;;
    esac
done
