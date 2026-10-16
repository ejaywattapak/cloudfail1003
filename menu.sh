#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.5 - MAIN MENU (3D ASCII + THEMES)
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ============================================================== 

INSTALL_DIR="/usr/local/share/cloudfail1003"
if [ ! -r "${INSTALL_DIR}/core.sh" ]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    INSTALL_DIR="${SCRIPT_DIR:-.}"
fi

if [ ! -r "${INSTALL_DIR}/core.sh" ]; then
    echo "[!] core.sh tidak ditemui di ${INSTALL_DIR}. Jalankan setup.sh dahulu."
    exit 1
fi
# shellcheck source=/dev/null
source "${INSTALL_DIR}/core.sh"

# Senarai modul dibaca dari modules.list (satu sumber bersama installer/setup).
MODULES_LIST="${INSTALL_DIR}/modules.list"
MENU_MODULES=()
if [ -r "$MODULES_LIST" ]; then
    while IFS= read -r _mod; do
        case "$_mod" in ''|"#"*) continue ;; esac
        case "$_mod" in
            menu/*) MENU_MODULES+=("${_mod#menu/}") ;;
        esac
    done < "$MODULES_LIST"
fi
# Fallback kalau modules.list tiada (cth. pemasangan lama).
if [ "${#MENU_MODULES[@]}" -eq 0 ]; then
    MENU_MODULES=(
        "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
        "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
        "ipv6to4.sh" "themes.sh" "history.sh"
    )
fi

for mod in "${MENU_MODULES[@]}"; do
    if [ -r "${INSTALL_DIR}/menu/${mod}" ]; then
        # shellcheck source=/dev/null
        source "${INSTALL_DIR}/menu/${mod}"
    elif [ -r "${INSTALL_DIR}/${mod}" ]; then
        # shellcheck source=/dev/null
        source "${INSTALL_DIR}/${mod}"
    else
        printf '%b[!] Modul tidak ditemui: %s%b\n' "$YELLOW" "$mod" "$NC" >&2
    fi
done

get_system_stats() {
    KL_TIME=$(TZ="Asia/Kuala_Lumpur" date +"%d %b %Y | %I:%M:%S %p")
    MEM_USED=$(free -m 2>/dev/null | awk '/Mem:/ {print $3}')
    MEM_TOTAL=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
    MEM_USED=${MEM_USED:-0}
    MEM_TOTAL=${MEM_TOTAL:-0}
    MEM_PCT=$(( MEM_USED * 100 / (MEM_TOTAL > 0 ? MEM_TOTAL : 1) ))
    CPU_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
    CPU_LOAD=${CPU_LOAD:-N/A}

    TODAY_RX="0"
    TODAY_TX="0"
    TODAY_TOT="Calculating..."
    MONTH_TOT="Calculating..."
    IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
    if command -v vnstat >/dev/null 2>&1 && [ -n "$IFACE" ]; then
        VN_LINE=$(vnstat -i "$IFACE" --oneline 2>/dev/null)
        if [[ "$VN_LINE" == *";"* ]]; then
            TODAY_RX=$(printf '%s' "$VN_LINE" | cut -d';' -f4)
            TODAY_TX=$(printf '%s' "$VN_LINE" | cut -d';' -f5)
            TODAY_TOT=$(printf '%s' "$VN_LINE" | cut -d';' -f6)
            MONTH_TOT=$(printf '%s' "$VN_LINE" | cut -d';' -f11)
        fi
    fi
}

# Print a box row with exactly 54 display characters between borders.
# Keeping the number column fixed prevents [10] and [11] from shifting the box.
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

show_main_banner() {
    # Render the 3D banner only while drawing the top-level menu.
    [[ "${CF_MAIN_MENU_RENDER:-0}" == "1" ]] || return 0
    clear
    get_system_stats
    # Keep the original 3D ANSI Shadow font and one blank row above the banner.
    printf '\n%b' "$BANNER_COLOR"
    local banner_text="${BANNER_TEXT:-EJAYWATT CLOUDFAIL}"
    local font_dir="${INSTALL_DIR}/fonts"
    local font_file="${font_dir}/ANSI Shadow.flf"
    local font_tmp="${font_file}.tmp.$$"

    if command -v figlet >/dev/null 2>&1; then
        # If the ANSI Shadow font is missing, fetch it once and cache it locally.
        if [ ! -s "$font_file" ] || ! grep -q '^flf2a' "$font_file" 2>/dev/null; then
            mkdir -p "$font_dir" 2>/dev/null || true
            if command -v curl >/dev/null 2>&1 && \
               curl -fsSL --connect-timeout 5 --max-time 20 --retry 1 \
                   'https://raw.githubusercontent.com/xero/figlet-fonts/main/ANSI%20Shadow.flf' \
                   -o "$font_tmp" 2>/dev/null && grep -q '^flf2a' "$font_tmp"; then
                chmod 0644 "$font_tmp"
                mv -f "$font_tmp" "$font_file"
            else
                rm -f "$font_tmp"
            fi
        fi

        if [ -s "$font_file" ] && grep -q '^flf2a' "$font_file" 2>/dev/null; then
            if ! figlet -d "$font_dir" -w 100 -f "ANSI Shadow" "$banner_text" 2>/dev/null; then
                printf '%b[!] Gagal memuat font 3D ANSI Shadow.%b\n' "$YELLOW" "$NC"
            fi
        elif ! figlet -w 100 -f "ANSI Shadow" "$banner_text" 2>/dev/null; then
            # Do not replace the requested 3D font with plain text.
            printf '%b[!] Font 3D ANSI Shadow tidak ditemui. Semak pemasangan FIGlet/font.%b\n' "$YELLOW" "$NC"
        fi
    else
        printf '%b[!] FIGlet belum dipasang; banner 3D tidak dapat dipaparkan.%b\n' "$YELLOW" "$NC"
    fi
    printf '%b\n' "$NC"

    printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "Time (KL) :" "$NC" "$YELLOW" "${KL_TIME} (MYT)" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "CPU / RAM :" "$NC" "$CYAN" "Load: ${CPU_LOAD} | RAM: ${MEM_USED}/${MEM_TOTAL}MB (${MEM_PCT}%)" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "vnStat Day:" "$NC" "$GREEN" "Today: ${TODAY_TOT} (RX:${TODAY_RX} / TX:${TODAY_TX})" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "vnStat Mo :" "$NC" "$GREEN" "Monthly Total: ${MONTH_TOT}" "$NC" "$PURPLE" "$NC"
    printf '%b╰──────────────────────────────────────────────────────╯%b\n' "$PURPLE" "$NC"
}

while true; do
    CF_MAIN_MENU_RENDER=1
    show_main_banner
    printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$CYAN" "$NC"
    menu_title_row "MAIN MENU"
    printf '%b├──────────────────────────────────────────────────────┤%b\n' "$CYAN" "$NC"
    menu_row 1  "IP Clone Scanner"       "Same & Alt Range 1003"
    menu_row 2  "Twin IP Scanner"        "Cari Pasangan IP Kembar"
    menu_row 3  "Country & City Scan"    "Cari IP Ikut Lokasi"
    menu_row 4  "Postcode IP Scanner"    "Cari IP Ikut Poskod"
    menu_row 5  "Reverse IP to Domain"   "Input IP -> Cari Domain"
    menu_row 6  "Domain to IP Lookup"    "Input Domain -> Cari IP"
    menu_row 7  "Bug Hunter Verified"    "Senarai Bug + Host Asal"
    menu_row 8  "Search DNS IPv6"        "Live AAAA [2606:4700..]"
    menu_row 9  "Search IPv6 to IPv4"    "Live Resolve IPv6 -> v4"
    menu_row 10 "Themes"                "Banner Text & Menu Style"
    menu_row 11 "Search History"        "Papar Rekod Carian"
    menu_row 0  "Exit Terminal"          "Keluar dari Menu"
    printf '%b╰──────────────────────────────────────────────────────╯%b\n' "$CYAN" "$NC"
    printf '%b  if found bugs contact telegram @ejwtpkvpn%b\n\n' "$PURPLE" "$NC"
    printf '%b╭─[%bPilih Menu (1-11 / 0=Exit)%b]\n%b╰─➤ %b' "$CYAN" "$WHITE" "$CYAN" "$CYAN" "$YELLOW"
    read -r choice
    printf '%b' "$NC"

    # Disable the main banner while a submenu is running.
    CF_MAIN_MENU_RENDER=0

    case "$choice" in
        1) menu_ipclone ;;
        2) menu_twinip ;;
        3) menu_country ;;
        4) menu_postcode ;;
        5) menu_domainip ;;
        6) menu_ipdomain ;;
        7) menu_bughunter ;;
        8) menu_dnsipv6 ;;
        9) menu_ipv6to4 ;;
        10) menu_themes ;;
        11) menu_history ;;
        0)
            echo -e "\n${GREEN}Terima kasih! Taip 'menu' bila-bila masa untuk buka semula.${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!] Pilihan tidak sah. Sila pilih 1-11 atau 0.${NC}"
            sleep 1.2
            ;;
    esac
done
