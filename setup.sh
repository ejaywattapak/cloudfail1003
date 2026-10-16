#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.1 - SYSTEM & FOLDER MENU SETUP
# Includes: EJAYWATT ANTICK v2.0
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

REPO_RAW="https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main"
INSTALL_DIR="/usr/local/share/cloudfail1003"
MENU_DIR="${INSTALL_DIR}/menu"
MORE_DIR="${INSTALL_DIR}/more"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
else
    OS_ID="unknown"
    OS_LIKE=""
fi

# ==============================================================
# 1. INSTALL SYSTEM PACKAGES
# ==============================================================

echo -e "${CYAN}[➜] Mengemas kini pakej sistem, DNS utils, OpenSSL, tmux & vnStat...${NC}"

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y \
        curl wget jq gawk dnsutils bind9-host openssl \
        vnstat bc procps ca-certificates tzdata tmux

elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_LIKE" == *"rhel"* ]]; then
    dnf install -y epel-release
    dnf install -y \
        curl wget jq gawk bind-utils openssl vnstat \
        bc procps-ng ca-certificates tzdata tmux
else
    echo -e "${YELLOW}[!] OS tidak dikenali. Sila semak keserasian pakej secara manual.${NC}"
fi

# ==============================================================
# 2. TIMEZONE
# ==============================================================

echo -e "${CYAN}[➜] Menetapkan zon waktu Malaysia (Asia/Kuala_Lumpur)...${NC}"

timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null \
    || ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

# ==============================================================
# 3. ENABLE VNSTAT
# ==============================================================

echo -e "${CYAN}[➜] Mengaktifkan pemantauan trafik vnStat...${NC}"

if command -v vnstat >/dev/null 2>&1; then
    DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')

    if [ -n "$DEFAULT_IFACE" ]; then
        vnstat --add -i "$DEFAULT_IFACE" >/dev/null 2>&1 || true
    fi

    systemctl enable vnstat >/dev/null 2>&1 || true
    systemctl restart vnstat >/dev/null 2>&1 || true
fi

# ==============================================================
# 4. PREPARE INSTALLATION DIRECTORIES
# ==============================================================

echo -e "${CYAN}[➜] Menyediakan direktori CLOUDFAIL...${NC}"

mkdir -p "$INSTALL_DIR" "$MENU_DIR" "$MORE_DIR" || {
    echo -e "${RED}[✘] Gagal menyediakan direktori pemasangan.${NC}"
    exit 1
}

# ==============================================================
# 5. DOWNLOAD MAIN FILES
# ==============================================================

ROOT_FILES=("menu.sh" "core.sh")

for rfile in "${ROOT_FILES[@]}"; do
    echo -e "${WHITE}[➜] Memuat turun ${YELLOW}${rfile}${NC}"

    if curl -fsSL --retry 2 \
        "${REPO_RAW}/${rfile}" \
        -o "${INSTALL_DIR}/${rfile}"; then

        sed -i 's/\r$//' "${INSTALL_DIR}/${rfile}"
        chmod +x "${INSTALL_DIR}/${rfile}"
        echo -e "${GREEN}[✔] ${rfile} berjaya dimuat turun.${NC}"
    else
        echo -e "${RED}[✘] Gagal memuat turun ${rfile}.${NC}"
        exit 1
    fi
done

# ==============================================================
# 6. DOWNLOAD MENU MODULES
# ==============================================================

MENU_MODULES=(
    "ipclone.sh"
    "twinip.sh"
    "country.sh"
    "postcode.sh"
    "domainip.sh"
    "ipdomain.sh"
    "bughunter.sh"
    "dnsipv6.sh"
    "ipv6to4.sh"
    "history.sh"
)

for mod in "${MENU_MODULES[@]}"; do
    echo -e "${WHITE}[➜] Memuat turun ${YELLOW}menu/${mod}${NC}"

    http_code=$(curl -s -L --max-time 30 \
        -w "%{http_code}" \
        "${REPO_RAW}/menu/${mod}" \
        -o "${MENU_DIR}/${mod}")

    if [ "$http_code" != "200" ]; then
        mod_no_ext="${mod%.sh}"

        if ! curl -fsSL --retry 2 \
            "${REPO_RAW}/menu/${mod_no_ext}" \
            -o "${MENU_DIR}/${mod}"; then

            echo -e "${YELLOW}[!] Modul ${mod} tidak dapat dimuat turun.${NC}"
            rm -f "${MENU_DIR:?}/${mod}"
            continue
        fi
    fi

    sed -i 's/\r$//' "${MENU_DIR}/${mod}"
    chmod +x "${MENU_DIR}/${mod}"
    echo -e "${GREEN}[✔] Modul ${mod} selesai.${NC}"
done

# ==============================================================
# 7. INSTALL EJAYWATT ANTICK v2.0
# ==============================================================

ANTICK_TMP="/tmp/cf_antick.sh"

echo
echo -e "${CYAN}╭──────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│       EJAYWATT ANTICK v2.0 INSTALLER         │${NC}"
echo -e "${CYAN}╰──────────────────────────────────────────────╯${NC}"

echo -e "${CYAN}[➜] Memuat turun more/antick.sh dari GitHub...${NC}"

http_code_antick=$(curl -s -L --connect-timeout 10 --max-time 180 \
    -w "%{http_code}" \
    "${REPO_RAW}/more/antick.sh" \
    -o "$ANTICK_TMP")

if [ "$http_code_antick" != "200" ]; then
    # Fallback jika fail dinamakan tanpa .sh (more/antick)
    http_code_antick=$(curl -s -L --connect-timeout 10 --max-time 180 \
        -w "%{http_code}" \
        "${REPO_RAW}/more/antick" \
        -o "$ANTICK_TMP")
fi

if [ "$http_code_antick" == "200" ] && [ -s "$ANTICK_TMP" ]; then
    # Bersihkan format CRLF Windows terlebih dahulu sebelum semakan sintaks
    sed -i 's/\r$//' "$ANTICK_TMP"
    chmod +x "$ANTICK_TMP"
    
    # Simpan salinan ke dalam folder pemasangan more/
    cp -f "$ANTICK_TMP" "${MORE_DIR}/antick.sh"
    chmod +x "${MORE_DIR}/antick.sh"

    if bash -n "$ANTICK_TMP"; then
        echo -e "${CYAN}[➜] Menjalankan pemasangan ANTICK...${NC}"

        if bash "$ANTICK_TMP"; then
            echo -e "${GREEN}[✔] EJAYWATT ANTICK berjaya dipasang.${NC}"
        else
            echo -e "${YELLOW}[!] Pemasangan ANTICK memulangkan ralat semasa dijalankan.${NC}"
            echo -e "${YELLOW}[!] CLOUDFAIL akan meneruskan pemasangan.${NC}"
        fi
    else
        echo -e "${RED}[✘] Semakan sintaks (bash -n) gagal pada more/antick.sh!${NC}"
        echo -e "${YELLOW}[!] Sila semak kandungan kod di dalam more/antick.sh anda.${NC}"
    fi
else
    echo -e "${RED}[✘] Gagal memuat turun more/antick.sh (HTTP ${http_code_antick}).${NC}"
    echo -e "${YELLOW}[!] Pastikan fail wujud di: https://github.com/ejaywattapak/cloudfail1003/blob/main/more/antick.sh${NC}"
fi

rm -f "$ANTICK_TMP"

# ==============================================================
# 8. CREATE MENU COMMAND
# ==============================================================

echo
echo -e "${CYAN}[➜] Menyediakan arahan menu...${NC}"

ln -sf "${INSTALL_DIR}/menu.sh" /usr/bin/menu
ln -sf "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu

chmod +x /usr/bin/menu

# ==============================================================
# 9. AUTO-LOAD MENU ON INTERACTIVE LOGIN
# ==============================================================

echo -e "${CYAN}[➜] Mengaktifkan menu automatik ketika login...${NC}"

cat <<'AUTOPOP' > /etc/profile.d/ejaywatt_cloudfail.sh
if [ -t 0 ] && [[ $- == *i* ]] && [ -z "$CF_MENU_LOADED" ]; then
    export CF_MENU_LOADED=1
    /usr/bin/menu
fi
AUTOPOP

chmod +x /etc/profile.d/ejaywatt_cloudfail.sh

for rcfile in /root/.bashrc /root/.bash_profile /root/.profile; do
    if [ -f "$rcfile" ]; then
        sed -i '/CF_MENU_LOADED/d; /\/usr\/bin\/menu/d' "$rcfile" 2>/dev/null
    fi
done

if ! grep -q 'CF_MENU_LOADED=1 && /usr/bin/menu' /root/.bashrc 2>/dev/null; then
    echo '[ -t 0 ] && [ -z "$CF_MENU_LOADED" ] && export CF_MENU_LOADED=1 && /usr/bin/menu' >> /root/.bashrc
fi

# ==============================================================
# 10. CLEANUP
# ==============================================================

rm -f /tmp/cf_setup.sh
rm -f "$0" /root/installer.sh ./installer.sh 2>/dev/null

# ==============================================================
# 11. FINISH
# ==============================================================

echo
echo -e "${GREEN}╭──────────────────────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│             EJAYWATT CLOUDFAIL INSTALLATION                   │${NC}"
echo -e "${GREEN}│                                                              │${NC}"
echo -e "${GREEN}│   CLOUDFAIL setup selesai.                                   │${NC}"
echo -e "${GREEN}│   ANTICK telah dipasang secara automatik.                    │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────╯${NC}"
echo

echo -e "${WHITE}Arahan ANTICK selepas pemasangan:${NC}"
echo -e "  ${CYAN}antick${NC}             - Buka sesi tmux utama"
echo -e "  ${CYAN}antick mytask${NC}      - Buka sesi tmux bernama mytask"
echo -e "  ${CYAN}tmux ls${NC}            - Semak sesi tmux"
echo

echo -e "${YELLOW}[!] VPS akan reboot dalam 5 saat, mengikut tingkah laku setup asal.${NC}"

for i in {5..1}; do
    printf "\r${YELLOW}[⏳] Rebooting VPS dalam masa %d saat...${NC}" "$i"
    sleep 1
done

echo
reboot
