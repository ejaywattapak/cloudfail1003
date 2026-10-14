#!/bin/bash
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

REPO_RAW="https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main"
INSTALL_DIR="/usr/local/share/cloudfail1003"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_LIKE="$ID_LIKE"
fi

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get upgrade -y >/dev/null 2>&1
    apt-get install -y curl wget jq gawk coreutils findutils procps ca-certificates >/dev/null 2>&1
elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_LIKE" == *"rhel"* ]]; then
    dnf install -y epel-release >/dev/null 2>&1
    dnf makecache -y >/dev/null 2>&1
    dnf update -y >/dev/null 2>&1
    dnf install -y curl wget jq gawk coreutils findutils procps-ng ca-certificates >/dev/null 2>&1
fi

mkdir -p "$INSTALL_DIR"
curl -fsSL "${REPO_RAW}/core.sh" -o "${INSTALL_DIR}/core.sh"
curl -fsSL "${REPO_RAW}/menu.sh" -o "${INSTALL_DIR}/menu.sh"
sed -i 's/\r$//' "${INSTALL_DIR}/core.sh" "${INSTALL_DIR}/menu.sh"
chmod +x "${INSTALL_DIR}/core.sh" "${INSTALL_DIR}/menu.sh"

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

sed -i '/CF_MENU_LOADED/d; /\/usr\/bin\/menu/d' /root/.bashrc 2>/dev/null
echo '[ -t 0 ] && [ -z "$CF_MENU_LOADED" ] && export CF_MENU_LOADED=1 && /usr/bin/menu' >> /root/.bashrc

rm -f /tmp/cf_setup.sh "$0" /root/installer.sh /root/setup.sh ./installer.sh ./setup.sh 2>/dev/null

echo -e "\n${GREEN}Install complete, Reboot in 5sec${NC}"
sleep 5
reboot
