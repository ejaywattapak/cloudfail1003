#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - MASTER INSTALLER (UBUNTU / DEBIAN / ROCKY)
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

REPO_RAW="https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main"
SELF_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

show_3d_banner() {
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
    echo -e "${PURPLE}│${NC}        ${WHITE}⚡ OFFICIAL INSTALLER - UBUNTU | DEBIAN | ROCKY LINUX ⚡${NC}      ${PURPLE}│${NC}"
    echo -e "${PURPLE}│${NC}               ${GRAY}GitHub : github.com/ejaywattapak/cloudfail1003${NC}         ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────────────────────╯${NC}"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_NAME="$PRETTY_NAME"
    else
        OS_ID="unknown"
        OS_NAME="Unknown Linux"
    fi
}

run_installer() {
    show_3d_banner
    echo -e "${CYAN}╭─[ 1. RUN INSTALLER ]${NC}"
    echo -e "${CYAN}╰─➤${NC} ${YELLOW}Memuat turun & menjalankan setup.sh dari repo ejaywattapak...${NC}\n"

    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[✘] Sila jalankan installer ini sebagai pengguna root (sudo su)!${NC}"
        sleep 2
        return
    fi

    curl -fsSL "${REPO_RAW}/setup.sh" -o /tmp/cf_setup.sh
    if [ ! -s /tmp/cf_setup.sh ]; then
        echo -e "${RED}[✘] Gagal memuat turun setup.sh dari ${REPO_RAW}/setup.sh${NC}"
        echo -ne "\n${WHITE}Tekan enter untuk balik ke menu installer${NC}"
        read -r
        return
    fi

    sed -i 's/\r$//' /tmp/cf_setup.sh
    chmod +x /tmp/cf_setup.sh
    rm -f "$SELF_PATH" "$HOME/installer.sh" ./installer.sh 2>/dev/null
    bash /tmp/cf_setup.sh
    exit 0
}

check_installer() {
    show_3d_banner
    detect_os
    echo -e "${CYAN}╭───────────────────────[ 2. CHECK INSTALLER ]─────────────────────────╮${NC}\n"

    if [ "$EUID" -eq 0 ]; then
        echo -e "  ${GREEN}[✔] Root Privilege     :${NC} ${WHITE}OK (Running as root)${NC}"
    else
        echo -e "  ${RED}[✘] Root Privilege     :${NC} ${YELLOW}Bukan root (Sila guna sudo / root)${NC}"
    fi

    if [[ "$OS_ID" =~ ^(ubuntu|debian|rocky|almalinux|centos|rhel)$ ]]; then
        echo -e "  ${GREEN}[✔] Sistem Operasi     :${NC} ${WHITE}${OS_NAME} (Disokong)${NC}"
    else
        echo -e "  ${RED}[✘] Sistem Operasi     :${NC} ${YELLOW}${OS_NAME} (Tidak disokong secara rasmi)${NC}"
    fi

    echo -e "\n  ${CYAN}Menyemak Fail Komponen di Repo (ejaywattapak/cloudfail1003):${NC}"
    local all_ok=1
    for file in setup.sh menu.sh core.sh; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 "${REPO_RAW}/${file}")
        if [ "$http_code" == "200" ]; then
            echo -e "  ${GREEN}[✔] Komponen ${file}	:${NC} ${GREEN}OK (HTTP 200 - Tersedia)${NC}"
        else
            echo -e "  ${RED}[✘] Komponen ${file}	:${NC} ${RED}ERROR (HTTP ${http_code} - Tidak Dijumpai)${NC}"
            all_ok=0
        fi
    done

    echo -ne "\n${WHITE}Tekan enter untuk balik ke menu installer${NC}"
    read -r
}

exit_ssh() {
    echo -e "\n${YELLOW}[!] Membersihkan sisa fail installer & keluar dari sesi SSH...${NC}"
    rm -f "$SELF_PATH" "$HOME/installer.sh" ./installer.sh /tmp/cf_setup.sh 2>/dev/null
    sleep 1
    kill -HUP "$PPID" 2>/dev/null || exit 0
}

while true; do
    show_3d_banner
    echo -e "${CYAN}╭─────────────────────────[ INSTALLER MENU ]───────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                                                                      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Run Installer${NC}    ${GRAY}(Pasang semua komponen & auto-setup menu)${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Check Installer${NC}  ${GRAY}(Semak status OS & semua fail komponen)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[3]${NC} ${WHITE}Exit${NC}             ${GRAY}(Padam installer & terus keluar SSH)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                                      ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e "${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}\n"
    echo -ne "${CYAN}╭─[${NC}${WHITE}Pilih Menu (1/2/3)${NC}${CYAN}]${NC}\n${CYAN}╰─➤ ${YELLOW}"
    read -r opt
    echo -ne "${NC}"

    case $opt in
        1) run_installer ;;
        2) check_installer ;;
        3) exit_ssh ;;
        *)
            echo -e "\n${RED}[!] Pilihan tidak sah! Sila pilih 1, 2, atau 3.${NC}"
            sleep 1.2
            ;;
    esac
done
