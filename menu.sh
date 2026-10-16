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

MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "themes.sh" "history.sh"
)

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

ensure_banner_font() {
    local font_dir="${INSTALL_DIR}/fonts"
    local font_file="${font_dir}/ANSI Shadow.flf"
    local tmp="${font_file}.download.$$"

    # Keep the original 3D font available even when the VPS lacks the system font.
    if [ -s "$font_file" ] && grep -q '^flf2a' "$font_file"; then
        return 0
    fi
    command -v curl >/dev/null 2>&1 || return 1
    mkdir -p "$font_dir" 2>/dev/null || return 1
    if curl -fsSL --connect-timeout 5 --max-time 20 --retry 2 \
        'https://raw.githubusercontent.com/xero/figlet-fonts/main/ANSI%20Shadow.flf' \
        -o "$tmp" 2>/dev/null && grep -q '^flf2a' "$tmp"; then
        chmod 0644 "$tmp"
        mv -f "$tmp" "$font_file"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

show_main_banner() {
    clear
    get_system_stats
    # Keep one terminal row above the original 3D ANSI Shadow banner.
    printf '\n%b' "$BANNER_COLOR"
    # Preserve the original 3D ANSI Shadow font. Never print custom banner text tiny.
    local banner_text="${BANNER_TEXT:-EJAYWATT CLOUDFAIL}"
    local banner_drawn=0
    local terminal_cols=80 banner_width=78
    if command -v tput >/dev/null 2>&1; then
        terminal_cols=$(tput cols 2>/dev/null || printf '80')
    fi
    [[ "$terminal_cols" =~ ^[0-9]+$ ]] || terminal_cols=80
    (( terminal_cols < 24 )) && terminal_cols=24
    banner_width=$((terminal_cols - 2))
    if command -v figlet >/dev/null 2>&1; then
        if ensure_banner_font && figlet -d "${INSTALL_DIR}/fonts" -w "$banner_width" -f "ANSI Shadow" "$banner_text" 2>/dev/null; then
            banner_drawn=1
        elif figlet -w "$banner_width" -f "ANSI Shadow" "$banner_text" 2>/dev/null; then
            banner_drawn=1
        fi
    fi
    if [ "$banner_drawn" -eq 0 ]; then
        if [ "$banner_text" = "EJAYWATT CLOUDFAIL" ]; then
            # Static original 3D ASCII banner as a last-resort fallback.
            cat <<'ASCII'
  ███████╗     ██╗ █████╗ ██╗   ██╗██╗    ██╗ █████╗ ████████╗████████╗
  ██╔════╝     ██║██╔══██╗╚██╗ ██╔╝██║    ██║██╔══██╗╚══██╔══╝╚══██╔══╝
  █████╗       ██║███████║ ╚████╔╝ ██║ █╗ ██║███████║   ██║      ██║   
  ██╔══╝  ██   ██║██╔══██║  ╚██╔╝  ██║███╗██║██╔══██║   ██║      ██║   
  ███████╗╚█████╔╝██║  ██║   ██║   ╚███╔███╔╝██║  ██║   ██║      ██║   
  ╚══════╝ ╚════╝ ╚═╝  ╚═╝   ╚═╝    ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝      ╚═╝   
   ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ███████╗ █████╗ ██╗██╗     
  ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗██║██║     
  ██║     ██║     ██║   ██║██║   ██║██║  ██║█████╗  ███████║██║██║     
  ██║     ██║     ██║   ██║██║   ██║██║  ██║██╔══╝  ██╔══██║██║██║     
  ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝██║     ██║  ██║██║███████╗
   ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═════╝  ╚═╝╚═╝╚══════╝
ASCII
        else
            printf '%b[!] Font 3D ANSI Shadow gagal dimuat; teks banner kecil tidak dipaparkan.%b\n' "$YELLOW" "$NC"
        fi
    fi
    printf '%b\n' "$NC"

    printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "Time (KL) :" "$NC" "$YELLOW" "${KL_TIME} (MYT)" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "CPU / RAM :" "$NC" "$CYAN" "Load: ${CPU_LOAD} | RAM: ${MEM_USED}/${MEM_TOTAL}MB (${MEM_PCT}%)" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "vnStat Day:" "$NC" "$GREEN" "Today: ${TODAY_TOT} (RX:${TODAY_RX} / TX:${TODAY_TX})" "$NC" "$PURPLE" "$NC"
    printf '%b│%b %b%-11s%b %b%-39.39s%b %b│%b\n' "$PURPLE" "$NC" "$WHITE" "vnStat Mo :" "$NC" "$GREEN" "Monthly Total: ${MONTH_TOT}" "$NC" "$PURPLE" "$NC"
    printf '%b╰──────────────────────────────────────────────────────╯%b\n' "$PURPLE" "$NC"
}

# Use the alternate screen while the menu is open. Submenus inherit this screen.
# On exit, restore the terminal and clear visible output/scrollback where supported.
CF_MENU_ALT_SCREEN=0
if [ -t 1 ]; then
    printf '\033[?1049h\033[3J\033[H\033[2J'
    CF_MENU_ALT_SCREEN=1
    trap 'if [ "$CF_MENU_ALT_SCREEN" = 1 ]; then printf "\033[?25h\033[?1049l\033[3J\033[H\033[2J"; fi' EXIT
fi

while true; do
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
