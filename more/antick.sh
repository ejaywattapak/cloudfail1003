
#!/usr/bin/env bash
# ==========================================================
# EJAYWATT ANTICK v1.0
# SSH KeepAlive + Persistent Terminal
# Ubuntu / Debian / Rocky Linux
# ==========================================================

set -Eeuo pipefail

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;37m'
NC='\033[0m'

log()  { printf "${CYAN}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${NC} %s\n' "$*"; exit 1; }

clear 2>/dev/null || true
printf "${CYAN}"
cat <<'BANNER'
   ___  _   _ _____ ___ ____ _  __
  / _ \| \ | |_   _|_ _/ ___| |/ /
 | | | |  \| | | |  | | |   | ' /
 | |_| | |\  | | |  | | |___| . \
  \___/|_| \_| |_| |___\____|_|\_\
           EJAYWATT ANTICK
BANNER
printf "${NC}\n"

[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    fail "Tidak dapat mengesan OS."
fi

log "OS: ${PRETTY_NAME:-Unknown}"
log "Menyediakan SSH KeepAlive dan tmux..."

# Install tmux
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y tmux openssh-client
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y tmux openssh-clients
elif command -v yum >/dev/null 2>&1; then
    yum install -y tmux openssh-clients
else
    fail "Package manager tidak disokong."
fi

# Find active SSH server configuration
SSHD_CONFIG="/etc/ssh/sshd_config"
[[ -f "$SSHD_CONFIG" ]] || fail "Fail $SSHD_CONFIG tidak dijumpai."

BACKUP="${SSHD_CONFIG}.antick.$(date +%Y%m%d%H%M%S)"
cp -a "$SSHD_CONFIG" "$BACKUP"
ok "Backup SSH: $BACKUP"

# Add a dedicated SSH configuration drop-in where supported.
mkdir -p /etc/ssh/sshd_config.d

DROPIN="/etc/ssh/sshd_config.d/00-ejaywatt-antick.conf"
DROPIN_BACKUP=""

if [[ -f "$DROPIN" ]]; then
    DROPIN_BACKUP="${DROPIN}.antick.$(date +%Y%m%d%H%M%S)"
    cp -a "$DROPIN" "$DROPIN_BACKUP"
fi

cat > "$DROPIN" <<'CONFIG'
# EJAYWATT ANTICK - SSH connection keepalive
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
CONFIG

# Validate before applying; restore on failure.
if sshd -t 2>/dev/null; then
    if systemctl reload ssh 2>/dev/null ||
       systemctl reload sshd 2>/dev/null; then
        ok "SSH KeepAlive dikemas kini."
    else
        warn "Reload SSH gagal. Memulihkan konfigurasi."
        if [[ -n "$DROPIN_BACKUP" ]]; then
            cp -a "$DROPIN_BACKUP" "$DROPIN"
        else
            rm -f "$DROPIN"
        fi
        sshd -t || true
        fail "Konfigurasi tidak diaplikasikan."
    fi
else
    warn "Konfigurasi SSH tidak sah. Memulihkan fail."
    if [[ -n "$DROPIN_BACKUP" ]]; then
        cp -a "$DROPIN_BACKUP" "$DROPIN"
    else
        rm -f "$DROPIN"
    fi
    sshd -t || true
    fail "Validasi sshd gagal. Semak konfigurasi asal."
fi

# Persistent tmux helper
cat > /usr/local/bin/antick <<'TMUX'
#!/usr/bin/env bash
set -e
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
ok "EJAYWATT ANTICK berjaya disediakan."
printf '\n'
printf "${WHITE}Cara penggunaan:${NC}\n"
printf "  antick             # Buka sesi kerja 'work'\n"
printf "  antick vps-task    # Buka sesi 'vps-task'\n"
printf "  Ctrl+B, kemudian D # Detach tanpa hentikan proses\n"
printf '\n'
warn "KeepAlive tidak boleh menghalang semua disconnect."
warn "Untuk kerja panjang, jalankan dalam tmux."
printf '\n'
