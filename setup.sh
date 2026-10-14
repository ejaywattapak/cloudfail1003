#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - SYSTEM SETUP ENGINE (LIVE VERBOSE MODE)
# Supports: Ubuntu, Debian, Rocky Linux
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

REPO_RAW="https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main"
INSTALL_DIR="/usr/local/share/cloudfail1003"

step_msg() {
    echo -e "\n${CYAN}[➜] ${WHITE}$1${NC}"
}

ok_msg() {
    echo -e "${GREEN}[✔] ${GREEN}$1${NC}"
}

# 1. Kesan Sistem Operasi
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_LIKE="$ID_LIKE"
else
    echo -e "${RED}[✘] Tidak dapat mengesan sistem operasi!${NC}"
    exit 1
fi

echo -e "${PURPLE}────────────────────────────────────────────────────────────────────────${NC}"
echo -e "${CYAN}  EJAYWATT CLOUDFAIL - LIVE INSTALLATION & SYSTEM UPDATE${NC}"
echo -e "${YELLOW}  OS Dikesan: ${PRETTY_NAME}${NC}"
echo -e "${PURPLE}────────────────────────────────────────────────────────────────────────${NC}"

# 2. Kemas kini OS & Pasang Pakej (Paparkan output live)
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
    step_msg "Mengemas kini senarai repositori APT (Ubuntu/Debian)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    
    step_msg "Memasang pakej keperluan (curl, wget, jq, gawk, coreutils, findutils, zip)..."
    apt-get install -y curl wget jq gawk coreutils findutils procps ca-certificates zip
    ok_msg "Pakej Ubuntu/Debian selesai dipasang."

elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_LIKE" == *"rhel"* ]]; then
    step_msg "Menyediakan EPEL repository (Rocky Linux / RHEL)..."
    dnf install -y epel-release
    
    step_msg "Mengemas kini repositori DNF..."
    dnf makecache -y
    
    step_msg "Memasang pakej keperluan (curl, wget, jq, gawk, coreutils, findutils, zip)..."
    dnf install -y curl wget jq gawk coreutils findutils procps-ng ca-certificates zip
    ok_msg "Pakej Rocky Linux selesai dipasang."
else
    echo -e "${RED}[✘] OS ini (${OS_ID}) tidak disokong!${NC}"
    exit 1
fi

# 3. Muat turun komponen utama dari GitHub
step_msg "Memuat turun komponen menu.sh & core.sh daripada GitHub..."
mkdir -p "$INSTALL_DIR"

curl -fsSL "${REPO_RAW}/core.sh" -o "${INSTALL_DIR}/core.sh"
curl -fsSL "${REPO_RAW}/menu.sh" -o "${INSTALL_DIR}/menu.sh"

if [ ! -s "${INSTALL_DIR}/core.sh" ] || [ ! -s "${INSTALL_DIR}/menu.sh" ]; then
    echo -e "${RED}[✘] Ralat memuat turun fail komponen dari GitHub!${NC}"
    exit 1
fi

sed -i 's/\r$//' "${INSTALL_DIR}/core.sh" "${INSTALL_DIR}/menu.sh"
chmod +x "${INSTALL_DIR}/core.sh" "${INSTALL_DIR}/menu.sh"

ln -sf "${INSTALL_DIR}/menu.sh" /usr/bin/menu
ln -sf "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu
chmod +x /usr/bin/menu
ok_msg "Komponen berjaya dikonfigurasi ke dalam sistem."

# 4. Konfigurasi Auto-Popup SSH
step_msg "Mengaktifkan Auto-Popup Menu pada sesi SSH..."
cat << 'AUTOPOP' > /etc/profile.d/ejaywatt_cloudfail.sh
if [ -t 0 ] && [[ $- == *i* ]] && [ -z "$CF_MENU_LOADED" ]; then
    export CF_MENU_LOADED=1
    /usr/bin/menu
fi
AUTOPOP
chmod +x /etc/profile.d/ejaywatt_cloudfail.sh

for rcfile in /root/.bashrc /root/.bash_profile /root/.profile; do
    if [ -f "$rcfile" ]; then
        sed -i '/CF_MENU_LOADED/d; /\/usr\/bin\/menu/d; /ipcloner\.sh/d' "$rcfile" 2>/dev/null
    fi
done
echo '[ -t 0 ] && [ -z "$CF_MENU_LOADED" ] && export CF_MENU_LOADED=1 && /usr/bin/menu' >> /root/.bashrc
ok_msg "Auto-popup SSH diaktifkan."

# 5. Pembersihan sisa installer
step_msg "Membersihkan sisa fail setup..."
rm -f /tmp/cf_setup.sh "$0" /root/installer.sh /root/setup.sh ./installer.sh ./setup.sh 2>/dev/null

echo -e "\n${GREEN}╭──────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│                   Install complete, Reboot in 5sec                   │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────╯${NC}\n"

for i in {5..1}; do
    printf "\r${YELLOW}[⏳] Rebooting VPS dalam masa %d saat...${NC}" "$i"
    sleep 1
done
echo ""
reboot
