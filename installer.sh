#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.4 - OFFICIAL INSTALLER / MODULE CHECKER
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

ROOT_FILES=("setup.sh" "menu.sh" "core.sh")
MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "themes.sh" "history.sh"
)
MORE_MODULES=("antick.sh")

show_banner() {
    clear
    echo -e "${CYAN}"
    if command -v figlet >/dev/null 2>&1; then
        figlet -w 90 -f "ANSI Shadow" "EJAYWATT CLOUDFAIL" 2>/dev/null || echo "EJAYWATT CLOUDFAIL"
    else
        echo "EJAYWATT CLOUDFAIL"
    fi
    echo -e "${NC}"
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC}   ${WHITE}⚡ OFFICIAL INSTALLER v13.4 — THEMES READY ⚡${NC}    ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

run_installer() {
    show_banner
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        echo -e "${RED}[✘] Sila jalankan installer sebagai root (sudo -i dahulu).${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi

    local tmp="/tmp/cf_setup.sh.$$" status=0
    echo -e "${CYAN}[➜] Memuat turun setup.sh dari GitHub...${NC}"
    if ! curl -fsSL --retry 2 --connect-timeout 10 --max-time 120 "${REPO_RAW}/setup.sh" -o "$tmp"; then
        rm -f "$tmp"
        echo -e "${RED}[✘] Gagal memuat turun setup.sh dari ${REPO_RAW}/setup.sh${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    sed -i 's/\r$//' "$tmp"
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        echo -e "${RED}[✘] setup.sh mempunyai ralat sintaks; pemasangan dibatalkan.${NC}"
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi
    chmod 0700 "$tmp"
    bash "$tmp"
    status=$?
    rm -f "$tmp"
    if [ "$status" -eq 0 ]; then
        echo -e "\n${GREEN}[✔] Pemasangan / kemas kini selesai.${NC}"
    else
        echo -e "\n${RED}[✘] Setup keluar dengan kod ${status}.${NC}"
    fi
    read -rp "Tekan Enter untuk kembali ke installer..." _
}

check_url() {
    local path="$1" url="${REPO_RAW}/$1" code
    code=$(curl -sSL --connect-timeout 5 --max-time 15 -o /dev/null -w '%{http_code}' "$url" || true)
    if [ "$code" = "200" ]; then
        printf "  ${GREEN}[✔] %-24s HTTP %s${NC}\n" "$path" "$code"
        return 0
    fi
    printf "  ${RED}[✘] %-24s HTTP %s${NC}\n" "$path" "${code:-000}"
    return 1
}

check_modules() {
    show_banner
    echo -e "${CYAN}Semakan fail yang akan digunakan oleh setup.sh:${NC}\n"
    local failures=0 file
    echo -e "${YELLOW}▸ Fail utama:${NC}"
    for file in "${ROOT_FILES[@]}"; do
        check_url "$file" || failures=$((failures + 1))
    done
    echo -e "\n${YELLOW}▸ Modul menu/:${NC}"
    for file in "${MENU_MODULES[@]}"; do
        check_url "menu/${file}" || failures=$((failures + 1))
    done
    echo -e "\n${YELLOW}▸ Modul tambahan more/:${NC}"
    for file in "${MORE_MODULES[@]}"; do
        check_url "more/${file}" || failures=$((failures + 1))
    done
    echo
    if [ "$failures" -eq 0 ]; then
        echo -e "${GREEN}[✔] Semua fail ditemui. Themes dan Search History ada dalam senarai modul.${NC}"
    else
        echo -e "${RED}[!] ${failures} fail tiada atau tidak dapat dicapai. Baiki GitHub dahulu sebelum install/update.${NC}"
    fi
    read -rp "Tekan Enter untuk kembali..." _
}

while true; do
    show_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Run Installer / Update${NC}  ${GRAY}(Pasang atau kemas kini)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Check Modules${NC}            ${GRAY}(Semak semua fail GitHub) ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[0]${NC} ${WHITE}Exit${NC}                     ${GRAY}(Keluar)                 ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${NC}"
    echo -ne "${CYAN}╰─➤ Pilih [1/2/0] : ${YELLOW}"
    read -r opt
    printf '%b' "$NC"
    case "$opt" in
        1) run_installer ;;
        2) check_modules ;;
        0) exit 0 ;;
        *) echo -e "${RED}[!] Pilihan tidak sah.${NC}"; sleep 1 ;;
    esac
done
