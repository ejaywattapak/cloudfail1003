#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.5 - INSTALL / UPDATE
# Safe download, syntax validation and timestamped backups.
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================
set -o pipefail

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

say() { echo -e "$1"; }
fail() { say "${RED}[✘] $*${NC}" >&2; exit 1; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    fail "Sila jalankan setup sebagai root (sudo -i dahulu)."
fi

if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
else
    OS_ID="unknown"
    OS_LIKE=""
fi

say "${CYAN}[➜] Menyediakan kebergantungan sistem...${NC}"
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *debian* ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || fail "apt-get update gagal."
    apt-get install -y curl wget jq gawk dnsutils bind9-host openssl vnstat bc procps \
        ca-certificates tzdata tmux figlet || fail "Gagal memasang pakej yang diperlukan."
elif [[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_LIKE" == *rhel* ]]; then
    dnf install -y epel-release || true
    dnf install -y curl wget jq gawk bind-utils openssl vnstat bc procps-ng \
        ca-certificates tzdata tmux figlet || fail "Gagal memasang pakej yang diperlukan."
else
    say "${YELLOW}[!] Distro tidak dikenali (${OS_ID}); cuba teruskan dengan pakej sedia ada.${NC}"
fi

say "${CYAN}[➜] Menetapkan zon waktu Malaysia...${NC}"
timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null \
    || ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

mkdir -p "$INSTALL_DIR" "$MENU_DIR" "$MORE_DIR" || fail "Gagal mencipta direktori pemasangan."

# Download, check HTTP 200, validate Bash syntax, back up current copy,
# then atomically replace the file. Existing files are preserved on error.
download_script() {
    local rel="$1" dest="$2" tmp http_code backup stamp
    tmp="${dest}.download.$$"
    rm -f "$tmp"
    say "${WHITE}[➜] Memuat turun ${rel}...${NC}"
    http_code=$(curl -sS -L --connect-timeout 10 --max-time 90 --retry 2 \
        -w '%{http_code}' "${REPO_RAW}/${rel}" -o "$tmp" 2>/dev/null) || http_code="000"
    if [ "$http_code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        fail "Fail ${rel} tidak tersedia atau gagal dimuat turun (HTTP ${http_code}); salinan lama dikekalkan."
    fi
    sed -i 's/\r$//' "$tmp"
    if ! bash -n "$tmp"; then
        rm -f "$tmp"
        fail "Sintaks Bash tidak sah dalam ${rel}; salinan lama tidak disentuh."
    fi
    if [ -f "$dest" ]; then
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="${dest}.bak.${stamp}"
        cp -a "$dest" "$backup" || {
            rm -f "$tmp"
            fail "Tidak dapat membuat backup bagi ${rel}; salinan lama tidak disentuh."
        }
    fi
    chmod 0755 "$tmp"
    mv -f "$tmp" "$dest" || fail "Gagal memasang ${rel}."
    say "${GREEN}[✔] ${rel} dikemas kini (HTTP 200, Bash OK).${NC}"
}

say "${CYAN}[➜] Mengemas kini fail utama...${NC}"
for file in "core.sh" "menu.sh" "setup.sh"; do
    download_script "$file" "${INSTALL_DIR}/${file}"
done

say "${CYAN}[➜] Mengemas kini modul menu...${NC}"
MENU_MODULES=(
    "ipclone.sh" "twinip.sh" "country.sh" "postcode.sh"
    "domainip.sh" "ipdomain.sh" "bughunter.sh" "dnsipv6.sh"
    "ipv6to4.sh" "themes.sh" "history.sh"
)
for mod in "${MENU_MODULES[@]}"; do
    download_script "menu/${mod}" "${MENU_DIR}/${mod}"
done

say "${CYAN}[➜] Mengemas kini modul tambahan...${NC}"
download_script "more/antick.sh" "${MORE_DIR}/antick.sh"

# IMPORTANT: antick.sh is an installer, not a passive library file. Run it.
say "${CYAN}[➜] Menjalankan pemasang ANTICK...${NC}"
if bash "${MORE_DIR}/antick.sh"; then
    say "${GREEN}[✔] ANTICK berjaya dipasang.${NC}"
else
    say "${YELLOW}[!] ANTICK gagal dipasang; semak mesej ralat di atas. Setup CloudFail diteruskan.${NC}"
fi

say "${CYAN}[➜] Mengaktifkan vnStat dan arahan menu...${NC}"
if command -v vnstat >/dev/null 2>&1; then
    DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
    if [ -n "$DEFAULT_IFACE" ]; then
        vnstat --add -i "$DEFAULT_IFACE" >/dev/null 2>&1 || true
    fi
    systemctl enable vnstat >/dev/null 2>&1 || true
    systemctl restart vnstat >/dev/null 2>&1 || true
fi
ln -sfn "${INSTALL_DIR}/menu.sh" /usr/bin/menu
ln -sfn "${INSTALL_DIR}/menu.sh" /usr/local/bin/menu
chmod 0755 "${INSTALL_DIR}/menu.sh" /usr/bin/menu 2>/dev/null || true

# Preserve auto-menu behavior on new interactive SSH logins.
cat > /etc/profile.d/ejaywatt_cloudfail.sh <<'AUTOPOP'
if [ -t 0 ] && [[ $- == *i* ]] && [ -z "${CF_MENU_LOADED:-}" ]; then
    export CF_MENU_LOADED=1
    /usr/bin/menu
fi
AUTOPOP
chmod 0644 /etc/profile.d/ejaywatt_cloudfail.sh
if [ -f /root/.bashrc ]; then
    sed -i '/CF_MENU_LOADED/d; /\/usr\/bin\/menu/d' /root/.bashrc 2>/dev/null || true
    printf '\n%s\n' '[ -t 0 ] && [ -z "${CF_MENU_LOADED:-}" ] && export CF_MENU_LOADED=1 && /usr/bin/menu' >> /root/.bashrc
fi

say ""
say "${GREEN}╭──────────────────────────────────────────────────────────────╮${NC}"
say "${GREEN}│          CLOUDFAIL v13.5 — INSTALL / UPDATE SELESAI           │${NC}"
say "${GREEN}╰──────────────────────────────────────────────────────────────╯${NC}"
say "${WHITE}Tema disimpan dalam: ${HOME}/.cloudfail_theme.conf${NC}"
say "${WHITE}Buka menu dengan arahan: ${CYAN}menu${NC}"
say "${YELLOW}[i] VPS tidak akan reboot secara automatik.${NC}"
say "${CYAN}[i] Backup lama disimpan sebagai fail .bak.TIMESTAMP.${NC}"

# Run the main menu immediately, but only in an interactive terminal.
if [ -t 0 ] && [ -x /usr/bin/menu ]; then
    say "${CYAN}[➜] Membuka menu CloudFail...${NC}"
    exec /usr/bin/menu
fi
