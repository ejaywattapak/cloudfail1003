#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - MAIN INTERACTIVE MENU v10.0 (BUG HUNTER)
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
    echo -e "${RED}[✘] Fail komponen core.sh tidak ditemui!${NC}"
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
    echo -e "${PURPLE}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC}        ${CYAN}⚡ EJAYWATT CLOUDFAIL - ERROR 1003 ⚡${NC}      ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────╯${NC}"
}

while true; do
    show_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                    ${WHITE}MAIN MENU${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Clone IP${NC}         ${GRAY}(Cari ikut IP target)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Clone Twin IP${NC}    ${GRAY}(Cari sepasang IP kembar)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[3]${NC} ${WHITE}Show History${NC}     ${GRAY}(Papar rekod lepas)${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[4]${NC} ${WHITE}Search Country${NC}   ${GRAY}(Cari ikut negara/bandar)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[5]${NC} ${WHITE}Search Postcode${NC}  ${GRAY}(Cari ikut poskod)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[6]${NC} ${WHITE}Search Domain IP${NC} ${GRAY}(Input IP -> Cari Domain)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[7]${NC} ${WHITE}Search IP Domain${NC} ${GRAY}(Input Domain -> Cari IP)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[8]${NC} ${WHITE}Bug Hunter${NC}       ${GRAY}(Senarai IP Bug + Domain)${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[9]${NC} ${WHITE}Exit${NC}             ${GRAY}(Keluar ke terminal)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}"
    echo -e "${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}\n"
    echo -ne "${CYAN}╭─[${NC}${WHITE}Pilih Menu (1-9)${NC}${CYAN}]${NC}\n${CYAN}╰─➤ ${YELLOW}"
    read -r choice
    echo -ne "${NC}"

    case $choice in
        1) clone_ip ;;
        2) clone_twin_ip ;;
        3) show_history ;;
        4) search_by_location ;;
        5) search_by_postcode ;;
        6) search_domain_by_ip ;;
        7) search_ip_by_domain ;;
        8) bug_hunter_menu ;;
        9)
            echo -e "\n${GREEN}Terima kasih! Taip 'menu' untuk buka semula.${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!] Pilihan tidak sah. Sila pilih 1 hingga 9.${NC}"
            sleep 1.2
            ;;
    esac
done
