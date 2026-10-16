#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.4 - MAIN MENU WITH THEMES
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

INSTALL_DIR="/usr/local/share/cloudfail1003"
if [ ! -f "${INSTALL_DIR}/core.sh" ]; then
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

show_main_banner() {
    clear
    get_system_stats
    printf '%b' "$BANNER_COLOR"
    if command -v figlet >/dev/null 2>&1; then
        if ! figlet -w 90 -f "ANSI Shadow" "$BANNER_TEXT" 2>/dev/null; then
            printf '  %s\n' "$BANNER_TEXT"
        fi
    else
        printf '  %s\n' "$BANNER_TEXT"
    fi
    printf '%b\n' "$NC"

    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    printf "${PURPLE}│${NC} ${WHITE}Time (KL) :${NC} ${YELLOW}%-40s${NC} ${PURPLE}│${NC}\n" "${KL_TIME} (MYT)"
    printf "${PURPLE}│${NC} ${WHITE}CPU / RAM :${NC} ${CYAN}%-40s${NC} ${PURPLE}│${NC}\n" "Load: ${CPU_LOAD} | RAM: ${MEM_USED}/${MEM_TOTAL}MB (${MEM_PCT}%)"
    printf "${PURPLE}│${NC} ${WHITE}vnStat Day:${NC} ${GREEN}%-40s${NC} ${PURPLE}│${NC}\n" "Today: ${TODAY_TOT} (RX:${TODAY_RX} / TX:${TODAY_TX})"
    printf "${PURPLE}│${NC} ${WHITE}vnStat Mo :${NC} ${GREEN}%-40s${NC} ${PURPLE}│${NC}\n" "Monthly Total: ${MONTH_TOT}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

while true; do
    show_main_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                      ${WHITE}MAIN MENU${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[1]${NC}  ${WHITE}IP Clone Scanner${NC}      ${GRAY}(Same & Alt Range 1003)  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[2]${NC}  ${WHITE}Twin IP Scanner${NC}       ${GRAY}(Cari Pasangan IP Kembar)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[3]${NC}  ${WHITE}Country & City Scan${NC}   ${GRAY}(Cari IP Ikut Lokasi)    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[4]${NC}  ${WHITE}Postcode IP Scanner${NC}   ${GRAY}(Cari IP Ikut Poskod)    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[5]${NC}  ${WHITE}Reverse IP to Domain${NC}  ${GRAY}(Input IP -> Cari Domain)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[6]${NC}  ${WHITE}Domain to IP Lookup${NC}   ${GRAY}(Input Domain -> Cari IP)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[7]${NC}  ${WHITE}Bug Hunter Verified${NC}   ${GRAY}(Senarai Bug + Host Asal)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[8]${NC}  ${WHITE}Search DNS IPv6${NC}       ${GRAY}(Live AAAA [2606:4700..])${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[9]${NC}  ${WHITE}Search IPv6 to IPv4${NC}   ${GRAY}(Live Resolve IPv6 -> v4)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[10]${NC} ${WHITE}Themes${NC}                ${GRAY}(Banner & Menu Style)     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[11]${NC} ${WHITE}Search History${NC}        ${GRAY}(Papar Rekod Carian)     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${RED}[0]${NC}  ${WHITE}Exit Terminal${NC}         ${GRAY}(Keluar dari Menu)       ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${NC}"
    echo -e "${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}\n"
    echo -ne "${CYAN}╭─[${NC}${WHITE}Pilih Menu (1-11 / 0=Exit)${NC}${CYAN}]${NC}\n${CYAN}╰─➤ ${YELLOW}"
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
