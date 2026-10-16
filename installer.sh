#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.1 - OFFICIAL INSTALLER (FOLDER MENU)
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

# Fail di direktori utama (Root Repo)
ROOT_FILES=("setup.sh" "menu.sh" "core.sh")

# Fail modul di dalam folder "menu/"
MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "history.sh"
)

# Fail modul di dalam folder "more/"
MORE_MODULES=("antick.sh")

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
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC}   ${WHITE}⚡ OFFICIAL MODULAR INSTALLER v13.1 (MENU FOLDER) ⚡${NC} ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

run_installer() {
    show_3d_banner
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[✘] Sila jalankan installer ini sebagai root (sudo su)!${NC}"
        sleep 2
        return
    fi

    echo -e "${CYAN}[➜] Memuat turun setup.sh dari repositori GitHub...${NC}"
    curl -fsSL "${REPO_RAW}/setup.sh" -o /tmp/cf_setup.sh
    if [ ! -s /tmp/cf_setup.sh ]; then
        echo -e "${RED}[✘] Gagal memuat turun setup.sh dari ${REPO_RAW}/setup.sh${NC}"
        read -rp "Tekan Enter untuk kembali..."
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
    echo -e "${CYAN}╭───[ MENYEMAK FAIL UTAMA & FOLDER MODUL DI GITHUB ]───╮${NC}\n"

    echo -e "  ${YELLOW}▸ Fail Utama (Root Repo):${NC}"
    for file in "${ROOT_FILES[@]}"; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REPO_RAW}/${file}")
        if [ "$http_code" == "200" ]; then
            printf "    ${GREEN}[✔] %-22s : OK (HTTP 200)${NC}\n" "$file"
        else
            printf "    ${RED}[✘] %-22s : MISSING (HTTP %s)${NC}\n" "$file" "$http_code"
        fi
    done

    echo -e "\n  ${YELLOW}▸ Modul Dalam Folder (menu/):${NC}"
    for mod in "${MENU_MODULES[@]}"; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REPO_RAW}/menu/${mod}")
        if [ "$http_code" == "200" ]; then
            printf "    ${GREEN}[✔] %-22s : OK (HTTP 200)${NC}\n" "menu/${mod}"
        else
            mod_no_ext="${mod%.sh}"
            http_code_alt=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REPO_RAW}/menu/${mod_no_ext}")
            if [ "$http_code_alt" == "200" ]; then
                printf "    ${GREEN}[✔] %-22s : OK (HTTP 200)${NC}\n" "menu/${mod_no_ext}"
            else
                printf "    ${RED}[✘] %-22s : MISSING (HTTP %s)${NC}\n" "menu/${mod}" "$http_code"
            fi
        fi
    done

    echo -e "\n  ${YELLOW}▸ Modul Tambahan (more/):${NC}"
    for mmod in "${MORE_MODULES[@]}"; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REPO_RAW}/more/${mmod}")
        if [ "$http_code" == "200" ]; then
            printf "    ${GREEN}[✔] %-22s : OK (HTTP 200)${NC}\n" "more/${mmod}"
        else
            mmod_no_ext="${mmod%.sh}"
            http_code_alt=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REPO_RAW}/more/${mmod_no_ext}")
            if [ "$http_code_alt" == "200" ]; then
                printf "    ${GREEN}[✔] %-22s : OK (HTTP 200)${NC}\n" "more/${mmod_no_ext}"
            else
                printf "    ${RED}[✘] %-22s : MISSING (HTTP %s)${NC}\n" "more/${mmod}" "$http_code"
            fi
        fi
    done

    echo -ne "\n${WHITE}Tekan Enter untuk kembali ke menu installer...${NC}"
    read -r
}

while true; do
    show_3d_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Run Installer${NC}    ${GRAY}(Pasang semua modul & vnstat)${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Check Modules${NC}    ${GRAY}(Semak menu/ & more/ GitHub)${NC}  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[0]${NC} ${WHITE}Exit${NC}             ${GRAY}(Keluar dari installer)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${NC}"
    echo -ne "${CYAN}╰─➤ Pilih [1/2/0] : ${YELLOW}"
    read -r opt
    echo -ne "${NC}"
    case $opt in
        1) run_installer ;;
        2) check_installer ;;
        0) rm -f "$SELF_PATH" 2>/dev/null; exit 0 ;;
    esac
done
