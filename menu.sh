#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.0 - MAIN MENU (VNSTAT + KL TIME + CLEAN)
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

INSTALL_DIR="/usr/local/share/cloudfail1003"
[ ! -d "$INSTALL_DIR" ] && INSTALL_DIR="."

source "${INSTALL_DIR}/core.sh"
source "${INSTALL_DIR}/ipclone.sh"
source "${INSTALL_DIR}/twinip.sh"
source "${INSTALL_DIR}/country.sh"
source "${INSTALL_DIR}/postcode.sh"
source "${INSTALL_DIR}/domainip.sh"
source "${INSTALL_DIR}/ipdomain.sh"
source "${INSTALL_DIR}/bughunter.sh"
source "${INSTALL_DIR}/dnsipv6.sh"
source "${INSTALL_DIR}/ipv6to4.sh"
source "${INSTALL_DIR}/history.sh"

get_system_stats() {
    KL_TIME=$(TZ="Asia/Kuala_Lumpur" date +"%d %b %Y | %I:%M:%S %p")
    UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/up //')

    # Kiraan RAM & CPU
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
    MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    MEM_PCT=$(( MEM_USED * 100 / (MEM_TOTAL > 0 ? MEM_TOTAL : 1) ))
    CPU_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null)

    # Kiraan Trafik Sebenar vnStat (Hari Ini & Bulan Ini)
    IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n 1)
    if command -v vnstat >/dev/null 2>&1 && [ -n "$IFACE" ]; then
        VN_LINE=$(vnstat -i "$IFACE" --oneline 2>/dev/null)
        if [[ "$VN_LINE" == *";"* ]]; then
            TODAY_RX=$(echo "$VN_LINE" | cut -d';' -f4)
            TODAY_TX=$(echo "$VN_LINE" | cut -d';' -f5)
            TODAY_TOT=$(echo "$VN_LINE" | cut -d';' -f6)
            MONTH_TOT=$(echo "$VN_LINE" | cut -d';' -f11)
        fi
    fi
    [ -z "$TODAY_TOT" ] && TODAY_TOT="Calculating..."
    [ -z "$MONTH_TOT" ] && MONTH_TOT="Calculating..."
}

show_main_banner() {
    clear
    get_system_stats
    echo -e "${CYAN}"
    cat << "ASCII"
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
   ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝
ASCII
    echo -e "${NC}"
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    printf "${PURPLE}│${NC} ${WHITE}Time (KL) :${NC} ${YELLOW}%-40s${NC} ${PURPLE}│${NC}\n" "${KL_TIME} (MYT)"
    printf "${PURPLE}│${NC} ${WHITE}CPU / RAM :${NC} ${CYAN}%-40s${NC} ${PURPLE}│${NC}\n" "Load: ${CPU_LOAD} | RAM: ${MEM_USED}/${MEM_TOTAL}MB (${MEM_PCT}%)"
    printf "${PURPLE}│${NC} ${WHITE}vnStat Day:${NC} ${GREEN}%-40s${NC} ${PURPLE}│${NC}\n" "Today: ${TODAY_TOT} (RX:${TODAY_RX:-0} / TX:${TODAY_TX:-0})"
    printf "${PURPLE}│${NC} ${WHITE}vnStat Mo :${NC} ${GREEN}%-40s${NC} ${PURPLE}│${NC}\n" "Monthly Total: ${MONTH_TOT}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

while true; do
    show_main_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                      ${WHITE}MAIN MENU${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[1]${NC}  ${WHITE}IP Clone Scanner${NC}      ${GRAY}(Same & Alt Range 1003)${NC}  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[2]${NC}  ${WHITE}Twin IP Scanner${NC}       ${GRAY}(Cari Pasangan IP Kembar)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[3]${NC}  ${WHITE}Country & City Scan${NC}   ${GRAY}(Cari IP Ikut Lokasi)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[4]${NC}  ${WHITE}Postcode IP Scanner${NC}   ${GRAY}(Cari IP Ikut Poskod)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[5]${NC}  ${WHITE}Reverse IP to Domain${NC}  ${GRAY}(Input IP -> Cari Domain)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[6]${NC}  ${WHITE}Domain to IP Lookup${NC}   ${GRAY}(Input Domain -> Cari IP)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[7]${NC}  ${WHITE}Bug Hunter Verified${NC}   ${GRAY}(Senarai Bug + Host Asal)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[8]${NC}  ${WHITE}Search DNS IPv6${NC}       ${GRAY}(Live AAAA [2606:4700..])${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[9]${NC}  ${WHITE}Search IPv6 to IPv4${NC}   ${GRAY}(Live Resolve IPv6 -> v4)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}[10]${NC} ${WHITE}Search History${NC}        ${GRAY}(Papar Rekod Carian)${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${RED}[0]${NC}  ${WHITE}Exit Terminal${NC}         ${GRAY}(Keluar dari Menu)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${NC}"
    echo -e "${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}\n"
    echo -ne "${CYAN}╭─[${NC}${WHITE}Pilih Menu (1-10 / 0=Exit)${NC}${CYAN}]${NC}\n${CYAN}╰─➤ ${YELLOW}"
    read -r choice
    echo -ne "${NC}"

    case $choice in
        1) menu_ipclone ;;
        2) menu_twinip ;;
        3) menu_country ;;
        4) menu_postcode ;;
        5) menu_domainip ;;
        6) menu_ipdomain ;;
        7) menu_bughunter ;;
        8) menu_dnsipv6 ;;
        9) menu_ipv6to4 ;;
        10) menu_history ;;
        0)
            echo -e "\n${GREEN}Terima kasih! Taip 'menu' bila-bila masa untuk buka semula.${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!] Pilihan tidak sah. Sila pilih 1-10 atau 0.${NC}"
            sleep 1.2
            ;;
    esac
done
