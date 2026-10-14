#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - MAIN INTERACTIVE MENU
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

CORE_SCRIPT="/usr/local/share/cloudfail1003/core.sh"
if [ -f "$CORE_SCRIPT" ]; then
    source "$CORE_SCRIPT"
elif [ -f "./core.sh" ]; then
    source "./core.sh"
else
    echo -e "${RED}[✘] Fail komponen core.sh tidak ditemui! Sila jalankan semula installer.${NC}"
    exit 1
fi

show_banner() {
    clear
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
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC}              ${CYAN}⚡ EJAYWATT CLOUDFAIL - ERROR 1003 FINDER ⚡${NC}            ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC}            ${GRAY}Multi-Block GeoIP, Postcode & Live 1003 Scanner${NC}           ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────────────────────╯${NC}"
}

while true; do
    show_banner
    echo -e "${CYAN}╭─────────────────────────────[ MAIN MENU ]─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                                                                                                                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Clone IP${NC}               ${GRAY}(Cari IP ikut IP target + Error 1003)${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Show History${NC}           ${GRAY}(Papar rekod carian lepas)${NC}                 ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[4]${NC} ${WHITE}Search by Country${NC}      ${GRAY}(Cari IP ikut Negara/Negeri/Bandar)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[5]${NC} ${WHITE}Search by Postcode${NC}     ${GRAY}(Cari IP ikut Poskod / Zipcode)${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[6]${NC} ${WHITE}Exit${NC}                   ${GRAY}(Keluar ke terminal)${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                                                                                ${CYAN}│${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e "${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}\n"
    echo -ne "${CYAN}╭─[${NC}${WHITE}Pilih Menu (1/2/4/5/6)${NC}${CYAN}]${NC}\n${CYAN}╰─➤ ${YELLOW}"
    read -r choice
    echo -ne "${NC}"

    case $choice in
        1) clone_ip ;;
        2) show_history ;;
        4) search_by_location ;;
        5) search_by_postcode ;;
        6)
            echo -e "\n${GREEN}Terima kasih! Taip 'menu' bila-bila masa untuk buka semula.${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!] Pilihan tidak sah. Sila pilih 1, 2, 4, 5, atau 6.${NC}"
            sleep 1.2
            ;;
    esac
done
