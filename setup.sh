#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.1 - SYSTEM & FOLDER MENU SETUP
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

ROOT_FILES=("menu.sh" "core.sh")
MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "history.sh"
)

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_LIKE="$ID_LIKE"
fi

echo -e "${CYAN}[➜] Mengemas kini pakej sistem, DNS utils, OpenSSL & vnStat...${NC}"
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl wget jq gawk dnsutils bind9-host openssl vnstat bc procps ca-certificates tzdata
elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_LIKE" == *"rhel"* ]]; then
    dnf install -y epel-release
    dnf install -y curl wget jq gawk bind-utils openssl vnstat bc procps-ng ca-certificates tzdata
fi

echo -e "${CYAN}[➜] Menetapkan Zon Waktu Malaysia (Asia/Kuala_Lumpur)...${NC}"
timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null || ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

echo -e "${CYAN}[➜] Mengaktifkan servis pemantauan trafik vnStat...${NC}"
DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n 1)
[ -n "$DEFAULT_IFACE" ] && vnstat --add -i "$DEFAULT_IFACE" >/dev/null 2>&1
systemctl enable vnstat >/dev/null 2>&1
systemctl restart vnstat >/dev/null 2>&1

echo -e "${CYAN}[➜] Menyediakan direktori ${INSTALL_DIR} dan ${MENU_DIR}...${NC}"
mkdir -p "$INSTALL_DIR" "$MENU_DIR"

# 1. Muat turun fail utama (menu.sh & core.sh)
for rfile in "${ROOT_FILES[@]}"; do
    echo -e "  ${WHITE}• Memuat turun ${YELLOW}${rfile}${WHITE}...${NC}"
    curl -fsSL "${REPO_RAW}/${rfile}" -o "${INSTALL_DIR}/${rfile}"
    sed -i 's/\r$//' "${INSTALL_DIR}/${rfile}" 2>/dev/null
    chmod +x "${INSTALL_DIR}/${rfile}" 2>/dev/null
done

# 2. Muat turun semua modul dari folder "menu/" di GitHub
for mod in "${MENU_MODULES[@]}"; do
    echo -e "  ${WHITE}• Memuat turun ${YELLOW}menu/${mod}${WHITE}...${NC}"
    http_code=$(curl -s -w "%{http_code}" -L "${REPO_RAW}/menu/${mod}" -o "${MENU_DIR}/${mod}")
    if [ "$http_code" != "200" ]; then
        # Sokongan automatik jika fail disimpan tanpa akhiran .sh di dalam folder menu/
        mod_no_ext="${mod%.sh}"
        curl -fsSL "${REPO_RAW}/menu/${mod_no_ext}" -o "${MENU_DIR}/${mod}" 2>/dev/null
    fi
    sed -i 's/\r$//' "${MENU_DIR}/${mod}" 2>/dev/null
    chmod +x "${MENU_DIR}/${mod}" 2>/dev/null
done

ln -sf "${INSTALL_DIR}/menu.sh" /usr/bin/menu
ln -sf "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu
chmod +x /usr/bin/menu

cat << 'AUTOPOP' > /etc/profile.d/ejaywatt_cloudfail.sh
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
echo '[ -t 0 ] && [ -z "$CF_MENU_LOADED" ] && export CF_MENU_LOADED=1 && /usr/bin/menu' >> /root/.bashrc

rm -f /tmp/cf_setup.sh "$0" /root/installer.sh ./installer.sh 2>/dev/null
echo -e "\n${GREEN}╭──────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│                   Install complete, Reboot in 5sec                   │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────╯${NC}\n"

for i in {5..1}; do
    printf "\r${YELLOW}[⏳] Rebooting VPS dalam masa %d saat...${NC}" "$i"
    sleep 1
done
echo ""
reboot
