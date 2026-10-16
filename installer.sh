#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.5 - OFFICIAL INSTALLER / CHECK & UPDATE
# Option 2 downloads, validates and updates files from GitHub only.
# ANTICK is installed by setup.sh during Option 1 installation.
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
SELF_PATH="$(realpath "$0" 2>/dev/null || printf '%s' "$0")"
INSTALL_DIR="/usr/local/share/cloudfail1003"
MENU_DIR="${INSTALL_DIR}/menu"
MORE_DIR="${INSTALL_DIR}/more"

ROOT_FILES=("setup.sh" "menu.sh" "core.sh" "installer.sh")
MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "themes.sh" "history.sh"
)
MORE_MODULES=("antick.sh")

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
    echo -e "${PURPLE}│${NC}   ${WHITE}⚡ OFFICIAL INSTALLER v13.5 ⚡${NC}    ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
}

require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        say "${RED}[✘] Sila jalankan installer sebagai root (sudo -i dahulu).${NC}"
        return 1
    fi
    return 0
}

run_installer() {
    show_banner
    if ! require_root; then
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

# Download a shell file to a temporary path, check HTTP and Bash syntax,
# back up the current copy, then atomically install the new version.
update_one() {
    local rel="$1" dest="$2" tmp code backup_dir stamp
    tmp="${dest}.download.$$"
    mkdir -p "$(dirname "$dest")" || {
        say "${RED}[✘] Gagal mencipta folder untuk ${rel}.${NC}"
        return 1
    }
    rm -f "$tmp"
    code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || code="000"
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-24s HTTP %s — fail lama dikekalkan${NC}\n" "$rel" "$code"
        return 1
    fi
    sed -i 's/\r$//' "$tmp"
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-24s Sintaks Bash gagal — fail lama dikekalkan${NC}\n" "$rel"
        return 1
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup_dir="${dest}.bak.${stamp}"
        if ! cp -a "$dest" "$backup_dir"; then
            rm -f "$tmp"
            printf "  ${RED}[✘] %-24s Backup gagal — fail lama dikekalkan${NC}\n" "$rel"
            return 1
        fi
    fi
    chmod 0755 "$tmp"
    if ! mv -f "$tmp" "$dest"; then
        rm -f "$tmp"
        printf "  ${RED}[✘] %-24s Gagal menggantikan fail${NC}\n" "$rel"
        return 1
    fi
    printf "  ${GREEN}[✔] %-24s HTTP 200 | Bash OK | UPDATED${NC}\n" "$rel"
    return 0
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

    echo -e "${CYAN}Semak, muat turun, uji sintaks dan kemas kini fail dari GitHub:${NC}\n"
    local failures=0 file

    echo -e "${YELLOW}▸ Fail utama:${NC}"
    update_one "setup.sh" "${INSTALL_DIR}/setup.sh" || failures=$((failures + 1))
    update_one "menu.sh" "${INSTALL_DIR}/menu.sh" || failures=$((failures + 1))
    update_one "core.sh" "${INSTALL_DIR}/core.sh" || failures=$((failures + 1))

    echo -e "\n${YELLOW}▸ Modul menu/:${NC}"
    for file in "${MENU_MODULES[@]}"; do
        update_one "menu/${file}" "${MENU_DIR}/${file}" || failures=$((failures + 1))
    done

    echo -e "\n${YELLOW}▸ Modul tambahan more/:${NC}"
    for file in "${MORE_MODULES[@]}"; do
        update_one "more/${file}" "${MORE_DIR}/${file}" || failures=$((failures + 1))
    done

    # Refresh installer itself if it's installed as a regular local file.
    case "$SELF_PATH" in
        /dev/*|/proc/*|/run/*|/tmp/*)
            echo -e "\n${YELLOW}[i] installer.sh berjalan dari lokasi sementara; fail installer tidak diganti.${NC}"
            ;;
        *)
            if [ -f "$SELF_PATH" ] && [ -w "$(dirname "$SELF_PATH")" ]; then
                update_one "installer.sh" "$SELF_PATH" || failures=$((failures + 1))
            else
                echo -e "\n${YELLOW}[i] installer.sh sendiri tidak ditulis (laluan bukan fail tempatan yang boleh diubah).${NC}"
            fi
            ;;
    esac

    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/bin/menu
    ln -sfn "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu
    chmod 0755 "${INSTALL_DIR}/menu.sh" /usr/bin/menu 2>/dev/null || true

    echo
    if [ "$failures" -eq 0 ]; then
        echo -e "${GREEN}[✔] Semua fail berjaya dimuat turun, disemak sintaks dan dikemas kini.${NC}"
        echo -e "${CYAN}[i] Backup lama disimpan dengan akhiran .bak.TIMESTAMP.${NC}"
    else
        echo -e "${RED}[!] ${failures} fail gagal dikemas kini. Salinan lama dikekalkan untuk fail yang gagal.${NC}"
    fi

    # Option 2 must only check/update files; it must not install ANTICK or launch the menu.
    read -rp "Tekan Enter untuk kembali ke installer..." _
}

while true; do
    show_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[1]${NC} ${WHITE}Run Installer / Update${NC}  ${GRAY}(Pasang atau kemas kini)${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${YELLOW}[2]${NC} ${WHITE}Check & Update Files${NC}     ${GRAY}(Semak, baca dan update)   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}   ${RED}[0]${NC} ${WHITE}Exit${NC}                     ${GRAY}(Keluar)                  ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${NC}"
    echo -ne "${CYAN}╰─➤ Pilih [1/2/0] : ${YELLOW}"
    read -r opt
    printf '%b' "$NC"
    case "$opt" in
        1) run_installer ;;
        2) check_and_update_modules ;;
        0) exit 0 ;;
        *) echo -e "${RED}[!] Pilihan tidak sah.${NC}"; sleep 1 ;;
    esac
done
