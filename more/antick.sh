
#!/usr/bin/env bash
# ==========================================================
# EJAYWATT ANTICK v2.0
# SSH KeepAlive + Persistent tmux Sessions
# Ubuntu / Debian / Rocky Linux
# ==========================================================

set -Eeuo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log()  { printf "${CYAN}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$*" >&2; exit 1; }

spinner() {
    local pid="$1"
    local message="$2"
    local frames='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%s]${NC} %s" \
            "${frames:i++%4:1}" "$message"
        sleep 0.15
    done

    printf "\r\033[K"
    wait "$pid"
}

clear 2>/dev/null || true

printf "${CYAN}"
cat <<'BANNER'
    ___  _   _ _____ ___ ____ _  __
   / _ \| \ | |_   _|_ _/ ___| |/ /
  | | | |  \| | | |  | | |   | ' /
  | |_| | |\  | | |  | | |___| . \
   \___/|_| \_| |_| |___\____|_|\_\
             EJAYWATT ANTICK v2.0
BANNER
printf "${NC}\n"

[[ "$EUID" -eq 0 ]] || fail "Jalankan sebagai root."

[[ -f /etc/os-release ]] || fail "OS tidak dikenali."
. /etc/os-release

log "OS: ${PRETTY_NAME:-Unknown}"
log "Memeriksa keperluan sistem..."

if ! command -v apt-get >/dev/null 2>&1 &&
   ! command -v dnf >/dev/null 2>&1 &&
   ! command -v yum >/dev/null 2>&1; then
    fail "OS/package manager tidak disokong."
fi

# Install required packages
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y tmux openssh-server openssh-client
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y tmux openssh-server openssh-clients
else
    yum install -y tmux openssh-server openssh-clients
fi

command -v tmux >/dev/null 2>&1 || fail "tmux gagal dipasang."
command -v sshd >/dev/null 2>&1 || fail "sshd tidak dijumpai."

SSHD_CONFIG="/etc/ssh/sshd_config"
DROPIN_DIR="/etc/ssh/sshd_config.d"
DROPIN="${DROPIN_DIR}/00-ejaywatt-antick.conf"

[[ -f "$SSHD_CONFIG" ]] || fail "Fail sshd_config tidak dijumpai."

# Check whether sshd_config includes drop-in files
if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' \
    "$SSHD_CONFIG"; then
    warn "Drop-in SSH tidak di-include oleh konfigurasi utama."
    warn "Tiada perubahan SSH dibuat untuk mengelakkan konfigurasi tidak aktif."
    warn "Semak Include dalam ${SSHD_CONFIG} secara manual."
    exit 1
fi

mkdir -p "$DROPIN_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
MAIN_BACKUP="${SSHD_CONFIG}.antick-${STAMP}"
cp -a "$SSHD_CONFIG" "$MAIN_BACKUP"

DROPIN_EXISTED=0
if [[ -f "$DROPIN" ]]; then
    DROPIN_EXISTED=1
    DROPIN_BACKUP="${DROPIN}.antick-${STAMP}"
    cp -a "$DROPIN" "$DROPIN_BACKUP"
fi

restore_config() {
    if [[ "$DROPIN_EXISTED" -eq 1 ]]; then
        cp -a "$DROPIN_BACKUP" "$DROPIN"
    else
        rm -f "$DROPIN"
    fi
}

cat > "$DROPIN" <<'CONFIG'
# EJAYWATT ANTICK - SSH keepalive
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
CONFIG

if ! sshd -t; then
    restore_config
    fail "SSH config tidak sah. Perubahan telah dipulihkan."
fi

# Reload existing SSH service without intentionally disconnecting sessions
if systemctl reload ssh 2>/dev/null ||
   systemctl reload sshd 2>/dev/null; then
    ok "SSH KeepAlive diaktifkan."
else
    restore_config
    systemctl reload ssh 2>/dev/null ||
        systemctl reload sshd 2>/dev/null || true
    fail "Reload SSH gagal. Konfigurasi baharu dipulihkan."
fi

# Install tmux session helper
cat > /usr/local/bin/antick <<'TMUX'
#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-work}"

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux belum dipasang."
    exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION"
else
    exec tmux new-session -s "$SESSION"
fi
TMUX

chmod 0755 /usr/local/bin/antick

printf '\n'
ok "EJAYWATT ANTICK v2.0 selesai dipasang."
printf 'Backup SSH: %s\n' "$MAIN_BACKUP"
printf '\n'
printf "${WHITE}Cara guna:${NC}\n"
printf '  antick              # Sesi kerja utama\n'
printf '  antick mytask       # Sesi kerja bernama mytask\n'
printf '  Ctrl+B kemudian D   # Keluar tanpa menghentikan sesi\n'
printf '\n'
warn "KeepAlive bukan jaminan rangkaian tidak terputus."
warn "Proses panjang perlu dijalankan di dalam sesi tmux."
