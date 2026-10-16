#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL v13.2 - CORE ENGINE (ACCURATE HOST DETECTOR)
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

HISTORY_FILE="$HOME/.ip_cloner_history.log"
DEFAULT_VLESS_HOST="sgs.ejwtpkvpn.my"
DEFAULT_VLESS_UUID="9bdf39ed-0160-4d36-91d9-88737a9eabc0"
DEFAULT_VLESS_TAG="random_2026-10-18"

sub_header() {
    local title="$1"
    clear
    echo -e "${CYAN}╭──────────────────────────────────────────────────────────╮${NC}"
    printf "${CYAN}│${NC} ${YELLOW}⚡ %-52s${NC} ${CYAN}│${NC}\n" "$title"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────╯${NC}"
}

loading_spinner() {
    local pid=$1
    local text=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}[%s]${NC} ${WHITE}%s${NC}" "${spin:$i:1}" "$text"
        sleep 0.1
    done
    printf "\r\033[K"
}

cidr_to_random_ip() {
    local cidr=$1
    local ip="${cidr%/*}"
    local mask="${cidr#*/}"
    IFS='.' read -r a b c d <<< "$ip"
    if [ "$mask" -ge 24 ]; then
        echo "${a}.${b}.${c}.$(( (RANDOM % 254) + 1 ))"
    elif [ "$mask" -ge 16 ]; then
        local span=$(( 1 << (24 - mask) ))
        local new_c=$(( (c + (RANDOM % span)) % 256 ))
        echo "${a}.${b}.${new_c}.$(( (RANDOM % 254) + 1 ))"
    else
        local span=$(( 1 << (16 - mask) ))
        local new_b=$(( (b + (RANDOM % span)) % 256 ))
        local new_c=$(( RANDOM % 256 ))
        echo "${a}.${new_b}.${new_c}.$(( (RANDOM % 254) + 1 ))"
    fi
}

generate_cf_prefixes() {
    cat << 'PREFIXES'
104.16.0.0/13
104.24.0.0/14
172.64.0.0/13
172.68.0.0/14
172.70.0.0/15
172.71.0.0/16
162.158.0.0/15
108.162.192.0/18
141.101.64.0/18
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
198.41.128.0/17
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
131.0.72.0/22
197.234.240.0/22
PREFIXES
}

print_vless_links() {
    local bug_ip=$1
    local v_host="${2:-$DEFAULT_VLESS_HOST}"
    echo -e "\n${CYAN}╭───[ PAUTAN VLESS UNTUK: ${YELLOW}${bug_ip}${CYAN} (Host: ${v_host}) ]───╮${NC}"
    echo -e "${WHITE}Link Ws TLS :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:443?path=/vless&security=tls&encryption=none&host=${v_host}&type=ws&sni=${v_host}#${DEFAULT_VLESS_TAG}${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Link Ws None TLS (Multipath) :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:80?path=/&encryption=none&host=${v_host}&type=ws#${DEFAULT_VLESS_TAG}${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Link HttpUpgrade TLS :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:443?path=/httpupgrade&security=tls&encryption=none&host=${v_host}&type=httpupgrade&sni=${v_host}#${DEFAULT_VLESS_TAG}${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Link HttpUpgrade None TLS :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:80?path=/httpupgrade&encryption=none&host=${v_host}&type=httpupgrade#${DEFAULT_VLESS_TAG}${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Link Xhttp TLS :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:8443?path=/xhttp&security=tls&encryption=none&host=${v_host}&type=xhttp&sni=${v_host}&alpn=h2#${DEFAULT_VLESS_TAG}${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Link Xhttp None TLS :${NC}"
    echo -e "${GREEN}vless://${DEFAULT_VLESS_UUID}@${bug_ip}:8080?path=/xhttp&encryption=none&host=${v_host}&type=xhttp#${DEFAULT_VLESS_TAG}${NC}\n"
}

verify_1003_and_vless_ws() {
    local input_file=$1
    local output_file=$2
    local v_host="${3:-$DEFAULT_VLESS_HOST}"

    cat "$input_file" | xargs -P 55 -I {} bash -c '
        ip="{}"
        vhost="'"$v_host"'"
        resp=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip}" 2>/dev/null)
        if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
            ws_hdr=$(curl -s -I --connect-timeout 1.2 --max-time 2.0 \
                -H "Host: ${vhost}" \
                -H "Connection: Upgrade" \
                -H "Upgrade: websocket" \
                -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
                -H "Sec-WebSocket-Version: 13" \
                "http://${ip}:80/vless" 2>/dev/null)
            if echo "$ws_hdr" | grep -Eqi "101 Switching Protocols|cloudflare|cf-ray|HTTP/1.1 [12345][0-9][0-9]"; then
                echo "$ip"
            fi
        fi
    ' > "$output_file"
}

detect_original_domain_fast() {
    local ip=$1
    local orig=""

    case "$ip" in
        104.18.21.212|104.18.20.212) echo "mcmc-my.metricelltestcloud.com"; return ;;
        172.66.43.86|172.66.40.*)    echo "investors.shopify.com"; return ;;
        104.17.148.22|104.17.147.22) echo "www.speedtest.net"; return ;;
        104.17.183.120)              echo "www.udemy.com"; return ;;
        104.18.30.244)               echo "engage.cloudflareclient.com"; return ;;
    esac

    if command -v openssl >/dev/null 2>&1; then
        ssl_dom=$(echo | timeout 2.0 openssl s_client -connect "${ip}:443" 2>/dev/null \
            | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null \
            | grep -Eo 'DNS:[a-zA-Z0-9.*-]+' | sed 's/DNS://g; s/^\*\.//g' \
            | grep -vE "^(cloudflare\.com|sni\.cloudflaressl\.com|localhost)$" | head -n 1)
        if [ -n "$ssl_dom" ]; then
            echo "$ssl_dom"
            return
        fi
    fi

    ptr_dom=$(curl -s --max-time 2.5 "http://ip-api.com/json/${ip}?fields=reverse" 2>/dev/null | jq -r '.reverse // empty')
    if [ -n "$ptr_dom" ]; then
        echo "$ptr_dom"
        return
    fi

    otx_list=$(curl -s --max-time 3 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null | tr '[:upper:]' '[:lower:]' | awk '!seen[$0]++' | head -n 15)
    for d in $otx_list; do
        lip=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1}' | head -n 1)
        if [ "$lip" == "$ip" ]; then
            echo "$d"
            return
        fi
    done

    isp_name=$(curl -s --max-time 2.5 "http://ip-api.com/json/${ip}?fields=isp" 2>/dev/null | jq -r '.isp // "Direct-Server"')
    echo "Direct-IP (${isp_name})"
}
export -f detect_original_domain_fast
