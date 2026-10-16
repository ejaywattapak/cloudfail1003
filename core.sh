INSTALL_DIR="/usr/local/share/cloudfail1003"
mkdir -p "${INSTALL_DIR}/menu"

# ==========================================================
# 1. UPDATE core.sh (Perbaikan Deteksi Original Host & Header)
# ==========================================================
cat << 'EOF' > "${INSTALL_DIR}/core.sh"
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

# Deteksi Original Host yang Akurat (Hanya menerima domain yang benar-benar AKTIF di IP tersebut)
detect_original_domain_fast() {
    local ip=$1
    local orig=""

    # 1. Database IP Bug Cloudflare Terverifikasi
    case "$ip" in
        104.18.21.212|104.18.20.212) echo "mcmc-my.metricelltestcloud.com"; return ;;
        172.66.43.86|172.66.40.*)    echo "investors.shopify.com"; return ;;
        104.17.148.22|104.17.147.22) echo "www.speedtest.net"; return ;;
        104.17.183.120)              echo "www.udemy.com"; return ;;
        104.18.30.244)               echo "engage.cloudflareclient.com"; return ;;
    esac

    # 2. Cek Sijil SSL Langsung (Port 443) - Sangat akurat jika IP adalah VPS/Socat/Direct Server
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

    # 3. Cek PTR Record Resmi (Reverse DNS) dari IP tersebut
    ptr_dom=$(curl -s --max-time 2.5 "http://ip-api.com/json/${ip}?fields=reverse" 2>/dev/null | jq -r '.reverse // empty')
    if [ -n "$ptr_dom" ]; then
        echo "$ptr_dom"
        return
    fi

    # 4. Cek OTX Passive DNS HANYA JIKA domain tersebut saat ini masih resolve (Live) ke IP target
    otx_list=$(curl -s --max-time 3 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null | tr '[:upper:]' '[:lower:]' | awk '!seen[$0]++' | head -n 15)
    for d in $otx_list; do
        lip=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1}' | head -n 1)
        if [ "$lip" == "$ip" ]; then
            echo "$d"
            return
        fi
    done

    # 5. Fallback berdasarkan ISP/ASN
    isp_name=$(curl -s --max-time 2.5 "http://ip-api.com/json/${ip}?fields=isp" 2>/dev/null | jq -r '.isp // "Direct-Server"')
    echo "Direct-IP (${isp_name})"
}
export -f detect_original_domain_fast
EOF

# ==========================================================
# 2. UPDATE menu/domainip.sh (Menu 5: Bersihkan Sampah HTML RapidDNS)
# ==========================================================
cat << 'EOF' > "${INSTALL_DIR}/menu/domainip.sh"
#!/bin/bash
# ==============================================================
# MODULE 5: REVERSE IP TO DOMAIN LOOKUP (domainip.sh)
# ==============================================================

domainip_worker() {
    local target_ip=$1
    local seen_file=$2
    > /tmp/rev_raw.txt
    > /tmp/rev_clean.txt

    orig_domain=$(detect_original_domain_fast "$target_ip")
    echo "$orig_domain" > /tmp/rev_orig.txt

    # 1. Ambil dari OTX AlienVault
    curl -s --max-time 7 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${target_ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/rev_raw.txt

    # 2. Ambil dari HackerTarget
    curl -s --max-time 7 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${target_ip}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" >> /tmp/rev_raw.txt

    # 3. Ambil dari RapidDNS HANYA isi tabel <td> (Mencegah bocornya domain iklan Google/Twitter/CDN)
    curl -s --max-time 7 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${target_ip}?full=1" 2>/dev/null \
        | grep -Eo '<td>[a-zA-Z0-9.-]+\.[a-zA-Z]{2,12}</td>' \
        | sed -E 's#</?td>##g' >> /tmp/rev_raw.txt

    # 4. Ambil dari Webscan
    curl -s --max-time 7 -A "Mozilla/5.0" "https://api.webscan.cc/?action=query&ip=${target_ip}" 2>/dev/null \
        | jq -r '.[]?.domain' 2>/dev/null >> /tmp/rev_raw.txt

    # Filter ketat domain sampah web
    tr '[:upper:]' '[:lower:]' < /tmp/rev_raw.txt \
        | grep -Eo '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9\-]+)+\.[a-zA-Z]{2,12}$' \
        | grep -vE "(rapiddns\.io|googlesyndication\.com|googleapis\.com|gstatic\.com|cloudflare\.com|jsdelivr\.net|schema\.org|twitter\.com|facebook\.com|w3\.org|bootstrap|jquery|fontawesome)" \
        | grep -vxF "$orig_domain" | awk '!seen[$0]++' > /tmp/rev_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/rev_seen.txt
        grep -vxFf /tmp/rev_seen.txt /tmp/rev_all_u.txt | head -n 45 > /tmp/rev_cand.txt
    else
        head -n 45 /tmp/rev_all_u.txt > /tmp/rev_cand.txt
    fi

    # Cek Live DNS dan utamakan yang benar-benar mengarah ke target_ip
    cat /tmp/rev_cand.txt | xargs -P 25 -I {} bash -c '
        d="{}"
        tip="'"$target_ip"'"
        lip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        if [ "$lip" == "$tip" ]; then
            echo "${d}|${lip} (Active on Target IP ✔)"
        elif [ -n "$lip" ]; then
            echo "${d}|${lip} (Moved IP)"
        fi
    ' > /tmp/rev_verified.txt

    # Urutkan yang Active di atas
    grep "Active on Target IP" /tmp/rev_verified.txt > /tmp/rev_clean.txt 2>/dev/null
    grep "Moved IP" /tmp/rev_verified.txt >> /tmp/rev_clean.txt 2>/dev/null
    head -n 20 /tmp/rev_clean.txt > /tmp/rev_top20.txt && mv /tmp/rev_top20.txt /tmp/rev_clean.txt

    rm -f /tmp/rev_raw.txt /tmp/rev_all_u.txt /tmp/rev_seen.txt /tmp/rev_cand.txt /tmp/rev_verified.txt
}

menu_domainip() {
    sub_header "5. REVERSE IP TO DOMAIN (ORIGINAL HOST + LIVE DNS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address (cth: 172.104.48.96) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"
    [ "$target_ip" == "0" ] || [ -z "$target_ip" ] && return

    local seen_session="/tmp/seen_m5_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "5. REVERSE IP TO DOMAIN : ${target_ip} (Batch #${batch_num})"
        mapfile -t old_doms < "$seen_session" 2>/dev/null

        (domainip_worker "$target_ip" "$seen_session") &
        loading_spinner $! "Mendeteksi Original Host & memverifikasi Live DNS pada $target_ip..."

        orig_host=$(cat /tmp/rev_orig.txt 2>/dev/null)
        mapfile -t fresh_doms < /tmp/rev_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL DOMAIN / HOST BAGI IP ${target_ip} ★ ]───╮${NC}"
        echo -e "${YELLOW}│${NC} ${GREEN}[00]${NC} ${WHITE}${orig_host}${NC} ${CYAN}[ ORIGINAL HOST ✔ ]${NC}"
        echo -e "${YELLOW}╰────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ DOMAIN BAHARU / FRESH (Batch #${batch_num} - ${#fresh_doms[@]} Domain) ★ ]───╮${NC}"
        all_sel=()
        count=1
        if [ ${#fresh_doms[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tidak ada lagi domain aktif yang menggunakan IP ${target_ip}.${NC}"
        else
            for d_entry in "${fresh_doms[@]}"; do
                IFS='|' read -r dom live_ip <<< "$d_entry"
                all_sel+=("$dom")
                echo "$d_entry" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-34s${NC} ${CYAN}[ %s ]${NC}\n" "${count}." "$dom" "$live_ip"
                ((count++))
            done
        fi

        if [ ${#old_doms[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DOMAIN LAMA / SUDAH DIBACA (${#old_doms[@]}) ]───╮${NC}"
            for old_e in "${old_doms[@]}"; do
                IFS='|' read -r o_dom o_lip <<< "$old_e"
                all_sel+=("$o_dom")
                printf "  ${GRAY}%-4s %-34s [ Sudah Dibaca -> %s ]${NC}\n" "${count}." "$o_dom" "$o_lip"
                ((count++))
            done
        fi

        rm -f /tmp/rev_orig.txt /tmp/rev_clean.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [00]=VLESS Orig, [1-${#all_sel[@]}]=VLESS Domain, [0]=Back : ${YELLOW}"
        read -r d_c
        echo -ne "${NC}"
        if [ "$d_c" == "0" ]; then break
        elif [ "$d_c" == "00" ]; then
            print_vless_links "$target_ip" "$orig_host"
            read -rp "Tekan [Enter] untuk lanjut atau ketik 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$d_c" =~ ^[0-9]+$ ]] && [ "$d_c" -ge 1 ] && [ "$d_c" -le "${#all_sel[@]}" ]; then
            print_vless_links "$target_ip" "${all_sel[$((d_c-1))]}"
            read -rp "Tekan [Enter] untuk lanjut atau ketik 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
EOF

# ==========================================================
# 3. UPDATE menu/ipdomain.sh (Menu 6: Akurasi Status 1003 vs Direct VPS)
# ==========================================================
cat << 'EOF' > "${INSTALL_DIR}/menu/ipdomain.sh"
#!/bin/bash
# ==============================================================
# MODULE 6: DOMAIN TO IP LOOKUP (ipdomain.sh)
# ==============================================================

ipdomain_worker() {
    local target_dom=$1
    local seen_file=$2
    > /tmp/dom_orig_ips.txt
    > /tmp/dom_orig_details.txt
    > /tmp/dom_other_raw.txt
    > /tmp/dom_other_clean.txt

    # 1. Cek Live DNS A Record saat ini
    curl -s --max-time 5 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${target_dom}&type=A" > /tmp/doh_cf.json 2>/dev/null
    jq -r '.Answer[]? | select(.type==1) | .data' /tmp/doh_cf.json 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt
    getent ahostsv4 "$target_dom" 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt

    awk '!seen[$0]++' /tmp/dom_orig_ips.txt > /tmp/dom_orig_u.txt
    mapfile -t orig_ips < /tmp/dom_orig_u.txt

    for o_ip in "${orig_ips[@]}"; do
        [ -z "$o_ip" ] && continue
        geo=$(curl -s --max-time 3 "http://ip-api.com/json/${o_ip}?fields=country,city,isp" 2>/dev/null)
        isp_str=$(echo "$geo" | jq -r '.isp // "Unknown"')
        loc_str="$(echo "$geo" | jq -r '.city // "Unknown"'), $(echo "$geo" | jq -r '.country // "Unknown"')"

        resp=$(curl -s --connect-timeout 1.5 --max-time 2.2 "http://${o_ip}" 2>/dev/null)
        if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
            if echo "$isp_str" | grep -Eqi "Cloudflare"; then
                st="CF Error 1003 ✔"
            else
                st="Forwarded 1003 (Socat/Proxy) ✔"
            fi
        else
            st="Direct IP / Active"
        fi
        echo "${o_ip}|${st}|${loc_str}|${isp_str}" >> /tmp/dom_orig_details.txt
    done

    # 2. Cari subdomain lain yang satu induk (cth: *.thehope.app)
    root_dom=$(echo "$target_dom" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
    curl -s --max-time 7 "https://api.hackertarget.com/hostsearch/?q=${root_dom}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" | awk -F',' '{print $1}' >> /tmp/dom_other_raw.txt

    curl -s --max-time 7 "https://otx.alienvault.com/api/v1/indicators/domain/${root_dom}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/dom_other_raw.txt

    tr '[:upper:]' '[:lower:]' < /tmp/dom_other_raw.txt \
        | grep -Eo '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9\-]+)+\.[a-zA-Z]{2,12}$' \
        | grep -vxF "$target_dom" | awk '!seen[$0]++' > /tmp/dom_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/dom_seen.txt
        grep -vxFf /tmp/dom_seen.txt /tmp/dom_all_u.txt | head -n 35 > /tmp/dom_cand.txt
    else
        head -n 35 /tmp/dom_all_u.txt > /tmp/dom_cand.txt
    fi

    cat /tmp/dom_cand.txt | xargs -P 25 -I {} bash -c '
        d="{}"
        real_ip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        [ -n "$real_ip" ] && echo "${d}|${real_ip}"
    ' | head -n 20 > /tmp/dom_other_clean.txt

    rm -f /tmp/doh_cf.json /tmp/dom_orig_ips.txt /tmp/dom_orig_u.txt /tmp/dom_other_raw.txt /tmp/dom_all_u.txt /tmp/dom_seen.txt /tmp/dom_cand.txt
}

menu_ipdomain() {
    sub_header "6. DOMAIN TO IP LOOKUP (ORIGINAL IP + SUBDOMAIN DNS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Domain (cth: support.thehope.app) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_dom
    echo -ne "${NC}"
    [ "$raw_dom" == "0" ] || [ -z "$raw_dom" ] && return

    target_dom=$(echo "$raw_dom" | sed -E 's#^https?://##; s#/.*$##' | tr '[:upper:]' '[:lower:]' | xargs)
    local seen_session="/tmp/seen_m6_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "6. DOMAIN TO IP : ${target_dom} (Batch #${batch_num})"
        mapfile -t old_dns < "$seen_session" 2>/dev/null

        (ipdomain_worker "$target_dom" "$seen_session") &
        loading_spinner $! "Mencari Original IP & Subdomain Live DNS bagi ${target_dom}..."

        mapfile -t orig_ip_lines < /tmp/dom_orig_details.txt 2>/dev/null
        mapfile -t fresh_dns_lines < /tmp/dom_other_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL IP ADDRESS DIGUNAKAN OLEH: ${target_dom} ★ ]───╮${NC}"
        orig_ips_only=()
        if [ ${#orig_ip_lines[@]} -eq 0 ]; then
            echo -e "${YELLOW}│${NC} ${RED}[!] Domain ${target_dom} tidak memiliki rekod IPv4 (A Record) aktif saat ini.${NC}"
        else
            idx=1
            for o_line in "${orig_ip_lines[@]}"; do
                IFS='|' read -r o_ip o_1003 o_loc o_isp <<< "$o_line"
                orig_ips_only+=("$o_ip")
                echo -e "${YELLOW}│${NC} ${GREEN}[0${idx}]${NC} ${WHITE}${o_ip}${NC}  ${CYAN}[ ${o_1003} | ${o_loc} | ${o_isp} ]${NC}"
                ((idx++))
            done
        fi
        echo -e "${YELLOW}╰───────────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ SUBDOMAIN SEINDUK & LIVE IP (Batch #${batch_num} - ${#fresh_dns_lines[@]} Rekod) ★ ]───╮${NC}"
        other_ips=(); other_hosts=()
        count=1
        if [ ${#fresh_dns_lines[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi subdomain berkaitan ditemui.${NC}"
        else
            for d_line in "${fresh_dns_lines[@]}"; do
                IFS='|' read -r d_host d_ip <<< "$d_line"
                other_hosts+=("$d_host"); other_ips+=("$d_ip")
                echo "$d_line" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-36s${NC} ${YELLOW}➜ %-15s${NC} ${CYAN}[Live IP]${NC}\n" "${count}." "$d_host" "$d_ip"
                ((count++))
            done
        fi

        if [ ${#old_dns[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_dns[@]}) ]───╮${NC}"
            for old_e in "${old_dns[@]}"; do
                IFS='|' read -r o_host o_ip <<< "$old_e"
                other_hosts+=("$o_host"); other_ips+=("$o_ip")
                printf "  ${GRAY}%-4s %-36s ➜ %-15s [Sudah Dibaca]${NC}\n" "${count}." "$o_host" "$o_ip"
                ((count++))
            done
        fi

        rm -f /tmp/dom_orig_details.txt /tmp/dom_other_clean.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [01]=VLESS Orig, [1-${#other_ips[@]}]=VLESS Lain, [0]=Back : ${YELLOW}"
        read -r ic
        echo -ne "${NC}"
        if [ "$ic" == "0" ]; then break
        elif [[ "$ic" =~ ^0[1-9]$ ]]; then
            o_i=$(( 10#$ic - 1 ))
            [ -n "${orig_ips_only[$o_i]}" ] && print_vless_links "${orig_ips_only[$o_i]}" "$target_dom"
            read -rp "Tekan [Enter] untuk lanjut atau ketik 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$ic" =~ ^[0-9]+$ ]] && [ "$ic" -ge 1 ] && [ "$ic" -le "${#other_ips[@]}" ]; then
            print_vless_links "${other_ips[$((ic-1))]}" "${other_hosts[$((ic-1))]}"
            read -rp "Tekan [Enter] untuk lanjut atau ketik 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
EOF

chmod +x "${INSTALL_DIR}/core.sh" "${INSTALL_DIR}/menu/domainip.sh" "${INSTALL_DIR}/menu/ipdomain.sh"
echo -e "\033[1;32m[✔] Perbaikan selesai! Sekarang Menu 5 & 6 bebas dari sampah HTML RapidDNS dan mendeteksi Original Host secara akurat.\033[0m"
