#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - CORE ENGINE v12.0 (IPV6 TO IPV4 + NO-REPEAT)
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

HISTORY_FILE="$HOME/.ip_cloner_history.log"
DEFAULT_VLESS_HOST="sgs.ejwtpkvpn.my"
DEFAULT_VLESS_UUID="9bdf39ed-0160-4d36-91d9-88737a9eabc0"
DEFAULT_VLESS_TAG="random_2026-10-18"

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

    if [[ ! "$mask" =~ ^[0-9]+$ ]] || [ "$mask" -lt 8 ] || [ "$mask" -gt 30 ]; then
        mask=24
    fi

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

detect_original_domain_fast() {
    local ip=$1
    local orig=""

    case "$ip" in
        104.18.21.212|104.18.20.212) orig="mcmc-my.metricelltestcloud.com" ;;
        172.66.43.86|172.66.40.*)    orig="investors.shopify.com" ;;
        104.17.148.22|104.17.147.22) orig="www.speedtest.net" ;;
        104.17.183.120)              orig="www.udemy.com" ;;
        104.18.30.244)               orig="engage.cloudflareclient.com" ;;
        104.18.0.197|104.18.1.197)   orig="www.ookla.com" ;;
        162.159.135.42|162.159.136.*) orig="discord.com" ;;
    esac

    if [ -z "$orig" ] && command -v openssl >/dev/null 2>&1; then
        orig=$(echo | timeout 1.8 openssl s_client -connect "${ip}:443" 2>/dev/null \
            | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null \
            | grep -Eo 'DNS:[a-zA-Z0-9.*-]+' | sed 's/DNS://g; s/^\*\.//g' \
            | grep -vE "cloudflare|sni\.cloudflaressl" | head -n 1)
    fi

    if [ -z "$orig" ]; then
        orig=$(curl -s --max-time 2.5 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${ip}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' \
            | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
            | grep -vE "\.(shop|xyz|top|club|online|site|fun|icu|cyou|cfd|sbs|buzz|tk|ml|ga|cf|gq|my\.id|biz\.id)$" \
            | head -n 1)
    fi

    if [ -z "$orig" ]; then
        case "$ip" in
            104.18.20.*|104.18.21.*) orig="mcmc-my.metricelltestcloud.com" ;;
            104.17.147.*|104.17.148.*) orig="www.speedtest.net" ;;
            104.17.183.*) orig="www.udemy.com" ;;
            104.18.30.*) orig="engage.cloudflareclient.com" ;;
            172.66.43.*|172.66.40.*) orig="investors.shopify.com" ;;
            104.16.*) orig="cdn.cloudflare.net" ;;
            104.17.*) orig="anycast.cloudflare.com" ;;
            104.18.*) orig="sni.cloudflaressl.com" ;;
            172.64.*|172.67.*) orig="workers.dev" ;;
            162.158.*|162.159.*) orig="warp.cloudflare.com" ;;
            *) orig="cloudflare-anycast.net" ;;
        esac
    fi

    echo "$orig"
}
export -f detect_original_domain_fast

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

# --- WORKER MENU 1 ---
search_error_1003_worker() {
    local target_ip=$1
    local country=$2
    local region=$3
    local city=$4
    local zip=$5
    local seen_file=$6

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"

    > /tmp/candidate_ips.txt
    > /tmp/live_1003_ips.txt
    > /tmp/verified_matches.txt
    > /tmp/final_matched_output.txt

    for _ in {1..40}; do
        echo "${o1}.${o2}.${o3}.$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt
    done
    for _ in {1..60}; do
        echo "${o1}.${o2}.$(( RANDOM % 256 )).$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..16}; do
            cidr_to_random_ip "$prefix" >> /tmp/candidate_ips.txt
        done
    done < <(generate_cf_prefixes)

    grep -v "^${target_ip}$" /tmp/candidate_ips.txt | awk '!seen[$0]++' > /tmp/raw_cand.txt
    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/seen_ips_only.txt
        grep -vxFf /tmp/seen_ips_only.txt /tmp/raw_cand.txt | shuf -n 280 > /tmp/unique_candidates.txt
    else
        shuf -n 280 /tmp/raw_cand.txt > /tmp/unique_candidates.txt
    fi

    verify_1003_and_vless_ws /tmp/unique_candidates.txt /tmp/live_1003_ips.txt "$DEFAULT_VLESS_HOST"

    mapfile -t valid_ips < <(head -n 180 /tmp/live_1003_ips.txt)
    [ ${#valid_ips[@]} -eq 0 ] && return

    rm -f /tmp/batch_1003_*.json
    for round in 1 2; do
        start_idx=$(( (round - 1) * 90 ))
        batch_slice=("${valid_ips[@]:start_idx:90}")
        [ ${#batch_slice[@]} -eq 0 ] && break

        json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
        curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
             -H "Content-Type: application/json" \
             -d "$json_payload" > "/tmp/batch_1003_${round}.json"
    done

    jq -s 'add' /tmp/batch_1003_*.json > /tmp/batch_1003.json 2>/dev/null

    jq -r --arg c "$country" --arg ct "$city" --arg z "$zip" \
        '.[] | select(.status=="success" and .country==$c and .city==$ct and .zip==$z) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r --arg c "$country" --arg ct "$city" \
        '.[] | select(.status=="success" and .country==$c and .city==$ct) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r --arg c "$country" \
        '.[] | select(.status=="success" and .country==$c) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    grep "^${o1}\.${o2}\." /tmp/verified_matches.txt | awk -F'|' '!seen[$1]++' | head -n 8 > /tmp/same_range.txt
    grep -v "^${o1}\.${o2}\." /tmp/verified_matches.txt | awk -F'|' '!seen[$1]++' | head -n 15 > /tmp/alt_range.txt

    cat /tmp/same_range.txt /tmp/alt_range.txt /tmp/verified_matches.txt | awk -F'|' '!seen[$1]++' | head -n 20 > /tmp/final_matched_output.txt
    rm -f /tmp/raw_cand.txt /tmp/seen_ips_only.txt
}

# --- WORKER MENU 2 ---
search_twin_1003_worker() {
    local target_ip=$1
    local country=$2
    local city=$3
    local zip=$4
    local seen_file=$5

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"

    > /tmp/twin_candidates.txt
    > /tmp/twin_live_pairs.txt
    > /tmp/twin_final_output.txt

    for _ in {1..30}; do
        b3=$(( RANDOM % 254 ))
        b4=$(( (RANDOM % 254) + 1 ))
        twin_b3=$(( b3 + 1 ))
        echo "${o1}.${o2}.${b3}.${b4}|${o1}.${o2}.${twin_b3}.${b4}" >> /tmp/twin_candidates.txt
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..14}; do
            base_ip=$(cidr_to_random_ip "$prefix")
            IFS='.' read -r b1 b2 b3 b4 <<< "$base_ip"
            if [ "$b3" -gt 0 ]; then
                twin_b3=$(( b3 - 1 ))
            else
                twin_b3=$(( b3 + 1 ))
            fi
            echo "${b1}.${b2}.${b3}.${b4}|${b1}.${b2}.${twin_b3}.${b4}" >> /tmp/twin_candidates.txt
        done
    done < <(generate_cf_prefixes)

    awk '!seen[$0]++' /tmp/twin_candidates.txt > /tmp/twin_raw_u.txt
    if [ -s "$seen_file" ]; then
        awk -F' / ' '{print $1}' "$seen_file" > /tmp/seen_twin_ip1.txt
        grep -vFf /tmp/seen_twin_ip1.txt /tmp/twin_raw_u.txt | shuf -n 95 > /tmp/twin_unique.txt
    else
        shuf -n 95 /tmp/twin_raw_u.txt > /tmp/twin_unique.txt
    fi

    cat /tmp/twin_unique.txt | xargs -P 45 -I {} bash -c '
        pair="{}"
        ip1="${pair%|*}"
        ip2="${pair#*|}"
        vhost="'"$DEFAULT_VLESS_HOST"'"
        r1=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip1}" 2>/dev/null)
        if echo "$r1" | grep -Eqi "1003|Direct IP access not allowed"; then
            r2=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip2}" 2>/dev/null)
            if echo "$r2" | grep -Eqi "1003|Direct IP access not allowed"; then
                ws=$(curl -s -I --connect-timeout 1.2 --max-time 2.0 -H "Host: ${vhost}" -H "Connection: Upgrade" -H "Upgrade: websocket" "http://${ip1}:80/vless" 2>/dev/null)
                if echo "$ws" | grep -Eqi "101|cloudflare|cf-ray|HTTP/1.1"; then
                    echo "${ip1}|${ip2}"
                fi
            fi
        fi
    ' > /tmp/twin_live_pairs.txt

    mapfile -t live_pairs < <(head -n 45 /tmp/twin_live_pairs.txt)
    [ ${#live_pairs[@]} -eq 0 ] && return

    first_ips=()
    for p in "${live_pairs[@]}"; do
        first_ips+=("${p%|*}")
    done

    json_payload=$(printf '%s\n' "${first_ips[@]}" | jq -R . | jq -s .)
    curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,city,zip,isp,query" \
         -H "Content-Type: application/json" \
         -d "$json_payload" > /tmp/twin_batch.json

    > /tmp/twin_verified.txt
    for p in "${live_pairs[@]}"; do
        ip1="${p%|*}"
        ip2="${p#*|}"
        info=$(jq -r --arg q "$ip1" '.[] | select(.query==$q and .status=="success") | "\(.country)|\(.city)|\(.zip)|\(.isp)"' /tmp/twin_batch.json 2>/dev/null | head -n 1)
        if [ -n "$info" ]; then
            echo "${ip1} / ${ip2}|${info}" >> /tmp/twin_verified.txt
        fi
    done

    grep "^${o1}\.${o2}\." /tmp/twin_verified.txt | head -n 8 > /tmp/twin_final_output.txt 2>/dev/null
    grep "|${country}|" /tmp/twin_verified.txt >> /tmp/twin_final_output.txt 2>/dev/null
    cat /tmp/twin_verified.txt >> /tmp/twin_final_output.txt 2>/dev/null

    awk -F'|' '!seen[$1]++' /tmp/twin_final_output.txt | head -n 20 > /tmp/twin_clean.txt
    mv /tmp/twin_clean.txt /tmp/twin_final_output.txt
    rm -f /tmp/twin_raw_u.txt /tmp/seen_twin_ip1.txt
}

# --- WORKER MENU 8 ---
bug_hunter_worker() {
    local seen_file=$1
    > /tmp/bh_candidates.txt
    > /tmp/bh_live.txt
    > /tmp/bh_final_results.txt

    local golden_subnets=(
        "104.18.21" "104.18.20" "172.66.43" "172.66.40"
        "104.17.148" "104.17.147" "104.17.183" "104.18.30"
        "104.18.31" "104.17.182" "104.18.22" "172.66.41"
    )

    for sub in "${golden_subnets[@]}"; do
        for _ in {1..18}; do
            echo "${sub}.$(( (RANDOM % 254) + 1 ))" >> /tmp/bh_candidates.txt
        done
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..10}; do
            cidr_to_random_ip "$prefix" >> /tmp/bh_candidates.txt
        done
    done < <(generate_cf_prefixes)

    grep -vE "^(104\.18\.21\.212|104\.18\.20\.212|172\.66\.43\.86|104\.17\.148\.22|104\.17\.183\.120|104\.18\.30\.244)$" /tmp/bh_candidates.txt \
        | awk '!seen[$0]++' > /tmp/bh_raw_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/bh_seen_ips.txt
        grep -vxFf /tmp/bh_seen_ips.txt /tmp/bh_raw_u.txt | shuf -n 220 > /tmp/bh_unique.txt
    else
        shuf -n 220 /tmp/bh_raw_u.txt > /tmp/bh_unique.txt
    fi

    verify_1003_and_vless_ws /tmp/bh_unique.txt /tmp/bh_live.txt "$DEFAULT_VLESS_HOST"

    head -n 20 /tmp/bh_live.txt > /tmp/bh_top20.txt

    cat /tmp/bh_top20.txt | xargs -P 10 -I {} bash -c '
        ip="{}"
        dom=$(detect_original_domain_fast "$ip")
        echo "${ip}|${dom}"
    ' > /tmp/bh_final_results.txt

    rm -f /tmp/bh_candidates.txt /tmp/bh_raw_u.txt /tmp/bh_seen_ips.txt /tmp/bh_unique.txt /tmp/bh_live.txt /tmp/bh_top20.txt
}

# --- WORKER MENU 6 ---
reverse_ip_domains_worker() {
    local target_ip=$1
    local seen_file=$2
    > /tmp/rev_domains_raw.txt
    > /tmp/rev_domains_clean.txt
    > /tmp/rev_original_host.txt

    local orig_domain
    orig_domain=$(detect_original_domain_fast "$target_ip")
    echo "$orig_domain" > /tmp/rev_original_host.txt

    curl -s --max-time 8 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${target_ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    curl -s --max-time 8 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${target_ip}?full=1" 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    curl -s --max-time 8 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${target_ip}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    curl -s --max-time 8 -A "Mozilla/5.0" "https://api.webscan.cc/?action=query&ip=${target_ip}" 2>/dev/null \
        | jq -r '.[]?.domain' 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    tr '[:upper:]' '[:lower:]' < /tmp/rev_domains_raw.txt \
        | grep -vE "^(rapiddns\.io|www\.rapiddns\.io|cloudflare\.com|w3\.org|google\.com|gstatic\.com|googleapis\.com|bootstrap|jquery|fontawesome|jsdelivr|cdnjs|html5shiv|respond\.min\.js|popper\.min\.js)$" \
        | grep -vE "\.(png|jpg|jpeg|gif|svg|css|js|ico|woff|woff2|ttf)$" \
        | awk '!seen[$0]++' > /tmp/rev_all_u.txt

    [ -n "$orig_domain" ] && grep -vxF "$orig_domain" /tmp/rev_all_u.txt > /tmp/rev_no_orig.txt || cp /tmp/rev_all_u.txt /tmp/rev_no_orig.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/rev_seen_doms.txt
        grep -vxFf /tmp/rev_seen_doms.txt /tmp/rev_no_orig.txt | head -n 35 > /tmp/rev_candidates.txt
    else
        head -n 35 /tmp/rev_no_orig.txt > /tmp/rev_candidates.txt
    fi

    cat /tmp/rev_candidates.txt | xargs -P 25 -I {} bash -c '
        dom="{}"
        live_ip=$(getent ahostsv4 "$dom" 2>/dev/null | awk "{print \$1}" | head -n 1)
        if [ -n "$live_ip" ]; then
            echo "${dom}|${live_ip}"
        fi
    ' | head -n 20 > /tmp/rev_domains_clean.txt

    rm -f /tmp/rev_all_u.txt /tmp/rev_no_orig.txt /tmp/rev_seen_doms.txt /tmp/rev_candidates.txt
}

# --- WORKER MENU 7 ---
domain_to_ip_worker() {
    local target_dom=$1
    local seen_file=$2
    > /tmp/dom_orig_ips.txt
    > /tmp/dom_orig_details.txt
    > /tmp/dom_cname.txt
    > /tmp/dom_other_raw.txt
    > /tmp/dom_other_clean.txt

    curl -s --max-time 6 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${target_dom}&type=A" > /tmp/doh_cf.json 2>/dev/null
    curl -s --max-time 6 "https://dns.google/resolve?name=${target_dom}&type=A" > /tmp/doh_gg.json 2>/dev/null

    jq -r '.Answer[]? | select(.type==5) | .data' /tmp/doh_cf.json /tmp/doh_gg.json 2>/dev/null | sed 's/\.$//' | head -n 1 > /tmp/dom_cname.txt
    jq -r '.Answer[]? | select(.type==1) | .data' /tmp/doh_cf.json /tmp/doh_gg.json 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt
    getent ahostsv4 "$target_dom" 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt

    awk '!seen[$0]++' /tmp/dom_orig_ips.txt > /tmp/dom_orig_unique.txt
    mapfile -t orig_ips < /tmp/dom_orig_unique.txt

    for o_ip in "${orig_ips[@]}"; do
        [ -z "$o_ip" ] && continue
        resp=$(curl -s --connect-timeout 1.5 --max-time 2.5 --max-filesize 65536 -A "Mozilla/5.0" "http://${o_ip}" 2>/dev/null)
        if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
            st_1003="Error 1003 ✔"
        else
            st_1003="Direct/Other"
        fi
        geo=$(curl -s --max-time 4 "http://ip-api.com/json/${o_ip}?fields=country,city,isp" 2>/dev/null)
        cnt=$(echo "$geo" | jq -r '.country // "Unknown"' 2>/dev/null)
        cty=$(echo "$geo" | jq -r '.city // "Unknown"' 2>/dev/null)
        isp=$(echo "$geo" | jq -r '.isp // "Unknown"' 2>/dev/null)
        echo "${o_ip}|${st_1003}|${cty}, ${cnt}|${isp}" >> /tmp/dom_orig_details.txt
    done

    root_dom=$(echo "$target_dom" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')

    curl -s --max-time 8 "https://api.hackertarget.com/hostsearch/?q=${root_dom}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" \
        | awk -F',' 'NF>=1 {print $1}' >> /tmp/dom_other_raw.txt

    primary_ip="${orig_ips[0]}"
    if [ -n "$primary_ip" ]; then
        curl -s --max-time 8 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${primary_ip}" 2>/dev/null \
            | grep -vE "API count|error|No DNS" >> /tmp/dom_other_raw.txt

        curl -s --max-time 8 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${primary_ip}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/dom_other_raw.txt

        curl -s --max-time 8 -A "Mozilla/5.0" "https://api.webscan.cc/?action=query&ip=${primary_ip}" 2>/dev/null \
            | jq -r '.[]?.domain' 2>/dev/null >> /tmp/dom_other_raw.txt

        curl -s --max-time 8 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${primary_ip}?full=1" 2>/dev/null \
            | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/dom_other_raw.txt
    fi

    tr '[:upper:]' '[:lower:]' < /tmp/dom_other_raw.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | grep -vxF "$target_dom" \
        | grep -vE "^(rapiddns\.io|www\.rapiddns\.io|cloudflare\.com|w3\.org|google\.com|gstatic\.com|googleapis\.com|bootstrap|jquery|fontawesome|jsdelivr|cdnjs)$" \
        | awk '!seen[$0]++' > /tmp/dom_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/dom_seen_list.txt
        grep -vxFf /tmp/dom_seen_list.txt /tmp/dom_all_u.txt | head -n 35 > /tmp/dom_candidates.txt
    else
        head -n 35 /tmp/dom_all_u.txt > /tmp/dom_candidates.txt
    fi

    cat /tmp/dom_candidates.txt | xargs -P 25 -I {} bash -c '
        d="{}"
        real_ip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        if [ -n "$real_ip" ]; then
            echo "${d}|${real_ip}"
        fi
    ' | head -n 20 > /tmp/dom_other_clean.txt

    rm -f /tmp/doh_cf.json /tmp/doh_gg.json /tmp/dom_orig_ips.txt /tmp/dom_other_raw.txt /tmp/dom_all_u.txt /tmp/dom_seen_list.txt /tmp/dom_candidates.txt
}

# --- WORKER MENU 9: SEARCH DNS IPV6 ---
ipv6_dns_worker() {
    local query=$1
    local seen_file=$2
    > /tmp/v6_raw_records.txt
    > /tmp/v6_fresh_output.txt

    ipv4_to_cf_ipv6() {
        local ip4=$1
        local host_label=$2
        IFS='.' read -r a b c d <<< "$ip4"
        local hex_part
        hex_part=$(printf "%02x%02x:%02x%02x" "$a" "$b" "$c" "$d")
        echo "[2606:4700:3108::${hex_part}]|${host_label} (CF-IPv6-Mapped from ${ip4})"
        echo "[2606:4700:3030::${hex_part}]|${host_label} (CF-Anycast-v6 from ${ip4})"
        echo "[2606:4700:20::${hex_part}]|${host_label} (CF-Edge-v6 from ${ip4})"
    }

    if [[ "$query" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local orig_dom
        orig_dom=$(detect_original_domain_fast "$query")
        ipv4_to_cf_ipv6 "$query" "${orig_dom:-Direct-IPv4}" >> /tmp/v6_raw_records.txt

        if [ -n "$orig_dom" ]; then
            curl -s --max-time 5 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${orig_dom}&type=AAAA" 2>/dev/null \
                | jq -r --arg h "$orig_dom" '.Answer[]? | select(.type==28) | "[\(.data)]|\($h) (Native AAAA)"' >> /tmp/v6_raw_records.txt
        fi

        curl -s --max-time 6 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${query}" 2>/dev/null \
            | grep -vE "API count|error|No DNS" | head -n 25 > /tmp/v6_sub_doms.txt
        curl -s --max-time 6 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${query}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null | head -n 25 >> /tmp/v6_sub_doms.txt

        awk '!seen[$0]++' /tmp/v6_sub_doms.txt | head -n 30 | xargs -P 15 -I {} bash -c '
            d="{}"
            v6_list=$(getent ahostsv6 "$d" 2>/dev/null | awk "{print \$1}" | grep -v "^::ffff:" | sort -u)
            for v6 in $v6_list; do
                echo "[${v6}]|${d} (Live AAAA)"
            done
        ' >> /tmp/v6_raw_records.txt

        IFS='.' read -r o1 o2 o3 _ <<< "$query"
        for _ in {1..25}; do
            r_o4=$(( (RANDOM % 254) + 1 ))
            hex_p=$(printf "%02x%02x:%02x%02x" "$o1" "$o2" "$o3" "$r_o4")
            p_tag=$(shuf -n 1 -e "3108" "3030" "3031" "3032" "3033" "20" "10")
            echo "[2606:4700:${p_tag}::${hex_p}]|${orig_dom:-Cloudflare-Node} (Subnet ${o1}.${o2}.${o3}.${r_o4})" >> /tmp/v6_raw_records.txt
        done
    else
        local clean_d
        clean_d=$(echo "$query" | sed -E 's#^https?://##; s#/.*$##' | tr '[:upper:]' '[:lower:]' | xargs)

        curl -s --max-time 5 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${clean_d}&type=AAAA" 2>/dev/null \
            | jq -r --arg h "$clean_d" '.Answer[]? | select(.type==28) | "[\(.data)]|\($h) (Original AAAA)"' >> /tmp/v6_raw_records.txt
        curl -s --max-time 5 "https://dns.google/resolve?name=${clean_d}&type=AAAA" 2>/dev/null \
            | jq -r --arg h "$clean_d" '.Answer[]? | select(.type==28) | "[\(.data)]|\($h) (Original AAAA)"' >> /tmp/v6_raw_records.txt

        mapfile -t d_v4s < <(getent ahostsv4 "$clean_d" 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
        for v4 in "${d_v4s[@]}"; do
            ipv4_to_cf_ipv6 "$v4" "$clean_d" >> /tmp/v6_raw_records.txt
        done

        root_dom=$(echo "$clean_d" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
        curl -s --max-time 6 "https://api.hackertarget.com/hostsearch/?q=${root_dom}" 2>/dev/null \
            | grep -vE "API count|error|No DNS" | awk -F',' '{print $1}' | head -n 30 > /tmp/v6_rel_doms.txt

        cat /tmp/v6_rel_doms.txt | xargs -P 15 -I {} bash -c '
            d="{}"
            v6_list=$(getent ahostsv6 "$d" 2>/dev/null | awk "{print \$1}" | grep -v "^::ffff:" | sort -u)
            for v6 in $v6_list; do
                echo "[${v6}]|${d} (Subdomain AAAA)"
            done
        ' >> /tmp/v6_raw_records.txt

        if [ ${#d_v4s[@]} -gt 0 ]; then
            IFS='.' read -r o1 o2 o3 _ <<< "${d_v4s[0]}"
            for _ in {1..20}; do
                r_o4=$(( (RANDOM % 254) + 1 ))
                hex_p=$(printf "%02x%02x:%02x%02x" "$o1" "$o2" "$o3" "$r_o4")
                p_tag=$(shuf -n 1 -e "3108" "3030" "3031" "3032" "20")
                echo "[2606:4700:${p_tag}::${hex_p}]|${clean_d} (CF-IPv6 Block ${o1}.${o2}.${o3}.${r_o4})" >> /tmp/v6_raw_records.txt
            done
        fi
    fi

    tr '[:upper:]' '[:lower:]' < /tmp/v6_raw_records.txt | awk -F'|' '!seen[$1]++' > /tmp/v6_all_unique.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/v6_seen_keys.txt
        grep -vFf /tmp/v6_seen_keys.txt /tmp/v6_all_unique.txt | head -n 20 > /tmp/v6_fresh_output.txt
    else
        head -n 20 /tmp/v6_all_unique.txt > /tmp/v6_fresh_output.txt
    fi

    rm -f /tmp/v6_raw_records.txt /tmp/v6_sub_doms.txt /tmp/v6_rel_doms.txt /tmp/v6_all_unique.txt /tmp/v6_seen_keys.txt
}

# --- WORKER MENU 10: IPV6 KE DNS RECORD IPV4 (ORIGINAL IPV4 + REKOD LAIN) ---
ipv6_to_ipv4_worker() {
    local raw_v6=$1
    local seen_file=$2

    > /tmp/v6to4_orig_info.txt
    > /tmp/v6to4_other_raw.txt
    > /tmp/v6to4_fresh_output.txt

    # Buang kurungan siku [ ] jika pengguna memasukkannya
    local clean_v6
    clean_v6=$(echo "$raw_v6" | tr -d '[] ' | tr '[:upper:]' '[:lower:]')

    local decoded_ipv4=""

    # 1. Nyahkod heksadesimal 32-bit terakhir jika format IPv6 mengandungi xxxx:xxxx (cth: 2606:4700:3108::ac42:28aa -> 172.66.40.170)
    if [[ "$clean_v6" =~ :([0-9a-f]{1,4}):([0-9a-f]{1,4})$ ]]; then
        local h1="${BASH_REMATCH[1]}"
        local h2="${BASH_REMATCH[2]}"
        h1=$(printf "%04x" "0x${h1}" 2>/dev/null)
        h2=$(printf "%04x" "0x${h2}" 2>/dev/null)
        local o1=$(( 16#${h1:0:2} ))
        local o2=$(( 16#${h1:2:2} ))
        local o3=$(( 16#${h2:0:2} ))
        local o4=$(( 16#${h2:2:2} ))

        # Pastikan ia julat IPv4 awam yang sah (bukan 0.x.x.x)
        if [ "$o1" -gt 0 ] && [ "$o1" -lt 224 ]; then
            decoded_ipv4="${o1}.${o2}.${o3}.${o4}"
        fi
    fi

    # 2. Jika bukan format hex-mapped atau gagal, cuba semak Passive DNS IPv6 / PTR untuk cari domain -> resolve ke IPv4
    local ptr_host=""
    if [ -z "$decoded_ipv4" ]; then
        ptr_host=$(curl -s --max-time 6 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv6/${clean_v6}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null | head -n 1)
        if [ -n "$ptr_host" ]; then
            decoded_ipv4=$(getent ahostsv4 "$ptr_host" 2>/dev/null | awk '{print $1}' | head -n 1)
        fi
    fi

    # 3. Jika masih kosong (contohnya Pure Native IPv6 Cloudflare 2606:4700::6810:xxxx), padankan ke julat utama Cloudflare
    if [ -z "$decoded_ipv4" ]; then
        case "$clean_v6" in
            2606:4700:3108*) decoded_ipv4="172.66.40.170" ;;
            2606:4700:303*)  decoded_ipv4="104.18.21.212" ;;
            2606:4700:20*)   decoded_ipv4="104.17.148.22" ;;
            2606:4700:10*)   decoded_ipv4="104.16.132.229" ;;
            *)               decoded_ipv4="104.18.21.212" ;;
        esac
    fi

    # 4. Ambil maklumat Original IPv4 (Domain Asal, Status Error 1003, Lokasi, ISP)
    local orig_dom
    orig_dom=$(detect_original_domain_fast "$decoded_ipv4")
    [ -n "$ptr_host" ] && orig_dom="$ptr_host"

    local resp
    resp=$(curl -s --connect-timeout 1.5 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${decoded_ipv4}" 2>/dev/null)
    if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
        st_1003="Error 1003 ✔"
    else
        st_1003="Direct/Active"
    fi

    local geo
    geo=$(curl -s --max-time 4 "http://ip-api.com/json/${decoded_ipv4}?fields=country,city,isp" 2>/dev/null)
    local cnt=$(echo "$geo" | jq -r '.country // "Unknown"' 2>/dev/null)
    local cty=$(echo "$geo" | jq -r '.city // "Unknown"' 2>/dev/null)
    local isp=$(echo "$geo" | jq -r '.isp // "Cloudflare, Inc."' 2>/dev/null)

    echo "${decoded_ipv4}|${orig_dom}|${st_1003}|${cty}, ${cnt}|${isp}" > /tmp/v6to4_orig_info.txt

    # 5. Cari Rekod DNS IPv4 Lain (Domain yang berkongsi IPv4 ini + IPv4 lain dalam subnet yang sama)
    curl -s --max-time 7 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${decoded_ipv4}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" > /tmp/v6to4_doms.txt

    curl -s --max-time 7 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${decoded_ipv4}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/v6to4_doms.txt

    curl -s --max-time 7 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${decoded_ipv4}?full=1" 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/v6to4_doms.txt

    tr '[:upper:]' '[:lower:]' < /tmp/v6to4_doms.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | grep -vE "^(rapiddns\.io|www\.rapiddns\.io|cloudflare\.com|w3\.org|google\.com|gstatic\.com|googleapis\.com|bootstrap|jquery|fontawesome|jsdelivr|cdnjs)$" \
        | awk '!seen[$0]++' | head -n 35 > /tmp/v6to4_dom_u.txt

    # Sahkan Live IPv4 bagi setiap domain berkaitan
    cat /tmp/v6to4_dom_u.txt | xargs -P 20 -I {} bash -c '
        d="{}"
        lip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        if [ -n "$lip" ]; then
            echo "${lip}|${d} (Shared DNS A Record)"
        fi
    ' >> /tmp/v6to4_other_raw.txt

    # Tambah juga imbasan IPv4 aktif Error 1003 dalam blok /24 yang sama supaya sentiasa ada 20 rekod segar apabila tekan Enter
    IFS='.' read -r a b c _ <<< "$decoded_ipv4"
    > /tmp/v6to4_sub_cand.txt
    for _ in {1..35}; do
        echo "${a}.${b}.${c}.$(( (RANDOM % 254) + 1 ))" >> /tmp/v6to4_sub_cand.txt
    done
    grep -vxF "$decoded_ipv4" /tmp/v6to4_sub_cand.txt | awk '!seen[$0]++' > /tmp/v6to4_sub_u.txt

    cat /tmp/v6to4_sub_u.txt | xargs -P 25 -I {} bash -c '
        ip="{}"
        r=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip}" 2>/dev/null)
        if echo "$r" | grep -Eqi "1003|Direct IP access not allowed"; then
            echo "${ip}|'"${orig_dom}"' (Same Subnet 1003+WS ✔)"
        fi
    ' >> /tmp/v6to4_other_raw.txt

    # Tapis pendua & rekod yang sudah pernah dipaparkan dalam sesi ini
    awk -F'|' '!seen[$1"_"$2]++' /tmp/v6to4_other_raw.txt > /tmp/v6to4_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1"_"$2}' "$seen_file" > /tmp/v6to4_seen_keys.txt
        awk -F'|' 'NR==FNR {seen[$0]=1; next} !seen[$1"_"$2]' /tmp/v6to4_seen_keys.txt /tmp/v6to4_all_u.txt | head -n 20 > /tmp/v6to4_fresh_output.txt
    else
        head -n 20 /tmp/v6to4_all_u.txt > /tmp/v6to4_fresh_output.txt
    fi

    rm -f /tmp/v6to4_doms.txt /tmp/v6to4_dom_u.txt /tmp/v6to4_sub_cand.txt /tmp/v6to4_sub_u.txt /tmp/v6to4_other_raw.txt /tmp/v6to4_all_u.txt /tmp/v6to4_seen_keys.txt
}

# ==============================================================
# MENU 1: CLONE IP
# ==============================================================
clone_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 1. CLONE IP (FRESH ATAS + LAMA TURUN BAWAH) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address Target (atau ${YELLOW}0${WHITE} untuk Exit) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"

    if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
        return
    fi

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
        sleep 1.5
        return
    fi

    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"

    echo ""
    (curl -s "http://ip-api.com/json/${target_ip}?fields=status,message,country,countryCode,regionName,city,zip,isp,org,as,query" > /tmp/target_ip.json) &
    loading_spinner $! "Mengambil butiran lokasi & poskod bagi $target_ip..."

    status=$(jq -r '.status' /tmp/target_ip.json 2>/dev/null)
    if [ "$status" != "success" ]; then
        msg=$(jq -r '.message' /tmp/target_ip.json 2>/dev/null)
        echo -e "${RED}[✘] Gagal mendapatkan maklumat IP (${msg:-Ralat Rangkaian}).${NC}"
        sleep 2
        return
    fi

    country=$(jq -r '.country' /tmp/target_ip.json)
    country_code=$(jq -r '.countryCode' /tmp/target_ip.json)
    region=$(jq -r '.regionName' /tmp/target_ip.json)
    city=$(jq -r '.city' /tmp/target_ip.json)
    zip=$(jq -r '.zip' /tmp/target_ip.json)
    rm -f /tmp/target_ip.json

    local seen_session="/tmp/seen_menu1_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode       :${NC} ${GREEN}No-Repeat (Fresh Atas / Lama Bawah) ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${region}, ${country} (${zip:-N/A})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_lines < "$seen_session" 2>/dev/null

        (search_error_1003_worker "$target_ip" "$country" "$region" "$city" "$zip" "$seen_session") &
        loading_spinner $! "Mengimbas IP Error 1003 BAHARU (Batch #${batch_num})..."

        mapfile -t fresh_lines < /tmp/final_matched_output.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH (Batch #${batch_num} - ${#fresh_lines[@]} IP) ★ ]───╮${NC}"
        all_selectable_ips=()
        count=1
        if [ ${#fresh_lines[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi IP baharu ditemui. Semua IP aktif telah disenaraikan di bawah.${NC}"
        else
            for entry in "${fresh_lines[@]}"; do
                IFS='|' read -r f_ip f_city f_zip f_isp <<< "$entry"
                all_selectable_ips+=("$f_ip")
                echo "$entry" >> "$seen_session"
                if [[ "$f_ip" == "${o1}.${o2}."* ]]; then r_tag="SAME-RANGE"; else r_tag="ALT-RANGE "; fi
                printf "  ${GREEN}%-3s %-16s [ %s | 1003+WS ✔ | %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$r_tag" "$f_city" "${f_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Clone IP Fresh - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for entry in "${fresh_lines[@]}"; do
                    echo "${c}. ${entry%%|*}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_lines[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_lines[@]} IP Terdahulu) ]───╮${NC}"
            for old_e in "${old_lines[@]}"; do
                IFS='|' read -r o_ip o_city o_zip o_isp <<< "$old_e"
                all_selectable_ips+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | %s | Zip:%s ]${NC}\n" "${count}." "$o_ip" "$o_city" "${o_zip:-N/A}"
                ((count++))
            done
        fi

        rm -f /tmp/candidate_*.txt /tmp/unique_candidates.txt /tmp/live_1003_ips.txt /tmp/batch_1003*.json /tmp/verified_matches.txt /tmp/same_range.txt /tmp/alt_range.txt /tmp/final_matched_output.txt

        total_sel=${#all_selectable_ips[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari IP Fresh lagi, taip ${YELLOW}[1-${total_sel}]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "$total_sel" ]; then
            sel_ip="${all_selectable_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari IP Fresh lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 2: CLONE TWIN IP
# ==============================================================
clone_twin_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 2. CLONE TWIN IP (FRESH ATAS + LAMA TURUN BAWAH) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address Target (atau ${YELLOW}0${WHITE} untuk Exit) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"

    if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
        return
    fi

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
        sleep 1.5
        return
    fi

    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"

    echo ""
    (curl -s "http://ip-api.com/json/${target_ip}?fields=status,message,country,countryCode,regionName,city,zip,isp,query" > /tmp/target_twin.json) &
    loading_spinner $! "Mengambil butiran lokasi bagi $target_ip..."

    status=$(jq -r '.status' /tmp/target_twin.json 2>/dev/null)
    if [ "$status" != "success" ]; then
        echo -e "${RED}[✘] Gagal mendapatkan maklumat IP.${NC}"
        sleep 2
        return
    fi

    country=$(jq -r '.country' /tmp/target_twin.json)
    country_code=$(jq -r '.countryCode' /tmp/target_twin.json)
    region=$(jq -r '.regionName' /tmp/target_twin.json)
    city=$(jq -r '.city' /tmp/target_twin.json)
    zip=$(jq -r '.zip' /tmp/target_twin.json)
    rm -f /tmp/target_twin.json

    local seen_session="/tmp/seen_menu2_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Twin Mode - Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode       :${NC} ${GREEN}No-Repeat (Fresh Atas / Lama Bawah) ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${region}, ${country} (${country_code})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_twins < "$seen_session" 2>/dev/null

        (search_twin_1003_worker "$target_ip" "$country" "$city" "$zip" "$seen_session") &
        loading_spinner $! "Mencari Pasangan Twin IP BAHARU (Batch #${batch_num})..."

        mapfile -t fresh_twins < /tmp/twin_final_output.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ PASANGAN TWIN IP BAHARU / FRESH (Batch #${batch_num} - ${#fresh_twins[@]} Pasang) ★ ]───╮${NC}"
        all_selectable_twins=()
        count=1
        if [ ${#fresh_twins[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi pasangan Twin IP baharu ditemui. Sila rujuk senarai di bawah.${NC}"
        else
            for entry in "${fresh_twins[@]}"; do
                IFS='|' read -r t_pair t_cnt t_city t_zip t_isp <<< "$entry"
                all_selectable_twins+=("$t_pair")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s %-35s [ 1003+WS ✔ | %s, %s | Zip:%s ]${NC}\n" "${count}." "$t_pair" "$t_city" "$t_cnt" "${t_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Twin IP Fresh - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for entry in "${fresh_twins[@]}"; do
                    echo "${c}. ${entry%%|*}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_twins[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD TWIN IP LAMA / SUDAH DIBACA (${#old_twins[@]} Pasang) ]───╮${NC}"
            for old_e in "${old_twins[@]}"; do
                IFS='|' read -r o_pair o_cnt o_city o_zip o_isp <<< "$old_e"
                all_selectable_twins+=("$o_pair")
                printf "  ${GRAY}%-3s %-35s [ Sudah Dibaca | %s, %s ]${NC}\n" "${count}." "$o_pair" "$o_city" "$o_cnt"
                ((count++))
            done
        fi

        rm -f /tmp/twin_*.txt /tmp/twin_batch.json

        total_sel=${#all_selectable_twins[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari Twin Fresh lagi, taip ${YELLOW}[1-${total_sel}]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "$total_sel" ]; then
            raw_pair="${all_selectable_twins[$((choice_loop-1))]}"
            sel_ip="${raw_pair%% *}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari Twin IP lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 4: SEARCH BY COUNTRY / REGION / CITY
# ==============================================================
search_by_location() {
    show_banner
    echo -e "${CYAN}╭─[ 4. SEARCH BY COUNTRY / REGION / CITY (NO-REPEAT) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Lokasi (cth: Singapore, Tokyo, USA) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_loc
    echo -ne "${NC}"

    if [ "$query_loc" == "0" ] || [ -z "$query_loc" ]; then
        return
    fi

    clean_q=$(echo "$query_loc" | xargs)
    local seen_session="/tmp/seen_menu4_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 4. SEARCH LOCATION : ${YELLOW}${clean_q}${CYAN} (Fresh Atas / Lama Bawah | Batch #${batch_num}) ]${NC}\n"

        mapfile -t old_locs < "$seen_session" 2>/dev/null

        > /tmp/loc_candidate_ips.txt
        > /tmp/loc_live_1003.txt

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..18}; do
                cidr_to_random_ip "$prefix" >> /tmp/loc_candidate_ips.txt
            done
        done < <(generate_cf_prefixes)

        awk '!seen[$0]++' /tmp/loc_candidate_ips.txt > /tmp/loc_raw_u.txt
        if [ -s "$seen_session" ]; then
            awk -F'|' '{print $1}' "$seen_session" > /tmp/loc_seen_ips.txt
            grep -vxFf /tmp/loc_seen_ips.txt /tmp/loc_raw_u.txt | shuf -n 270 > /tmp/loc_unique.txt
        else
            shuf -n 270 /tmp/loc_raw_u.txt > /tmp/loc_unique.txt
        fi

        (verify_1003_and_vless_ws /tmp/loc_unique.txt /tmp/loc_live_1003.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas IP BAHARU untuk lokasi '${clean_q}' (Batch #${batch_num})..."

        mapfile -t live_ips < <(head -n 180 /tmp/loc_live_1003.txt)
        fresh_locs=()

        if [ ${#live_ips[@]} -gt 0 ]; then
            rm -f /tmp/batch_loc_*.json
            for round in 1 2; do
                start_idx=$(( (round - 1) * 90 ))
                batch_slice=("${live_ips[@]:start_idx:90}")
                [ ${#batch_slice[@]} -eq 0 ] && break

                json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
                curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
                     -H "Content-Type: application/json" \
                     -d "$json_payload" > "/tmp/batch_loc_${round}.json"
            done

            jq -s 'add' /tmp/batch_loc_*.json > /tmp/all_batch_loc.json 2>/dev/null

            jq -r --arg q "$clean_q" \
                '.[] | select(.status=="success" and (
                    (.country | ascii_downcase | contains($q | ascii_downcase)) or
                    (.regionName | ascii_downcase | contains($q | ascii_downcase)) or
                    (.city | ascii_downcase | contains($q | ascii_downcase))
                )) | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_loc.json 2>/dev/null > /tmp/final_loc_matched.txt

            jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_loc.json 2>/dev/null >> /tmp/final_loc_matched.txt

            awk -F'|' '!seen[$1]++' /tmp/final_loc_matched.txt | head -n 20 > /tmp/final_loc_clean.txt
            mapfile -t fresh_locs < /tmp/final_loc_clean.txt
        fi

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH UNTUK '${clean_q}' (Batch #${batch_num} - ${#fresh_locs[@]} IP) ★ ]───╮${NC}"
        all_selectable_ips=()
        count=1
        if [ ${#fresh_locs[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi IP baharu ditemui. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for entry in "${fresh_locs[@]}"; do
                IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                all_selectable_ips+=("$f_ip")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s %-16s [ 1003+WS ✔ | %s, %s, %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$f_city" "$f_reg" "$f_cnt" "${f_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Location : $clean_q (Fresh Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for entry in "${fresh_locs[@]}"; do
                    echo "${c}. ${entry%%|*}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_locs[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_locs[@]} IP Terdahulu) ]───╮${NC}"
            for old_e in "${old_locs[@]}"; do
                IFS='|' read -r o_ip o_city o_reg o_cnt o_zip o_isp <<< "$old_e"
                all_selectable_ips+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | %s, %s | Zip:%s ]${NC}\n" "${count}." "$o_ip" "$o_city" "$o_cnt" "${o_zip:-N/A}"
                ((count++))
            done
        fi

        rm -f /tmp/loc_*.txt /tmp/batch_loc_*.json /tmp/all_batch_loc.json /tmp/final_loc_*.txt

        total_sel=${#all_selectable_ips[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari IP Fresh lagi, taip ${YELLOW}[1-${total_sel}]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "$total_sel" ]; then
            sel_ip="${all_selectable_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari IP Fresh lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 5: SEARCH BY POSTCODE
# ==============================================================
search_by_postcode() {
    show_banner
    echo -e "${CYAN}╭─[ 5. SEARCH BY POSTCODE (NO-REPEAT) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Postcode / Zipcode (cth: 75001, M5V) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_zip
    echo -ne "${NC}"

    if [ "$query_zip" == "0" ] || [ -z "$query_zip" ]; then
        return
    fi

    clean_z=$(echo "$query_zip" | xargs)
    local seen_session="/tmp/seen_menu5_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 5. SEARCH POSTCODE : ${YELLOW}${clean_z}${CYAN} (Fresh Atas / Lama Bawah | Batch #${batch_num}) ]${NC}\n"

        mapfile -t old_zips < "$seen_session" 2>/dev/null

        > /tmp/zip_candidate_ips.txt
        > /tmp/zip_live_1003.txt

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..18}; do
                cidr_to_random_ip "$prefix" >> /tmp/zip_candidate_ips.txt
            done
        done < <(generate_cf_prefixes)

        awk '!seen[$0]++' /tmp/zip_candidate_ips.txt > /tmp/zip_raw_u.txt
        if [ -s "$seen_session" ]; then
            awk -F'|' '{print $1}' "$seen_session" > /tmp/zip_seen_ips.txt
            grep -vxFf /tmp/zip_seen_ips.txt /tmp/zip_raw_u.txt | shuf -n 270 > /tmp/zip_unique.txt
        else
            shuf -n 270 /tmp/zip_raw_u.txt > /tmp/zip_unique.txt
        fi

        (verify_1003_and_vless_ws /tmp/zip_unique.txt /tmp/zip_live_1003.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas IP BAHARU untuk poskod $clean_z (Batch #${batch_num})..."

        mapfile -t live_ips < <(head -n 180 /tmp/zip_live_1003.txt)
        fresh_zips=()

        if [ ${#live_ips[@]} -gt 0 ]; then
            rm -f /tmp/batch_zip_*.json
            for round in 1 2; do
                start_idx=$(( (round - 1) * 90 ))
                batch_slice=("${live_ips[@]:start_idx:90}")
                [ ${#batch_slice[@]} -eq 0 ] && break

                json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
                curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
                     -H "Content-Type: application/json" \
                     -d "$json_payload" > "/tmp/batch_zip_${round}.json"
            done

            jq -s 'add' /tmp/batch_zip_*.json > /tmp/all_batch_zip.json 2>/dev/null

            jq -r --arg z "$clean_z" \
                '.[] | select(.status=="success" and (.zip | tostring | ascii_downcase | contains($z | ascii_downcase))) | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_zip.json 2>/dev/null > /tmp/final_zip_matched.txt

            jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_zip.json 2>/dev/null >> /tmp/final_zip_matched.txt

            awk -F'|' '!seen[$1]++' /tmp/final_zip_matched.txt | head -n 20 > /tmp/final_zip_clean.txt
            mapfile -t fresh_zips < /tmp/final_zip_clean.txt
        fi

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH POSKOD '${clean_z}' (Batch #${batch_num} - ${#fresh_zips[@]} IP) ★ ]───╮${NC}"
        all_selectable_ips=()
        count=1
        if [ ${#fresh_zips[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi IP baharu ditemui. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for entry in "${fresh_zips[@]}"; do
                IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                all_selectable_ips+=("$f_ip")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s %-16s [ 1003+WS ✔ | Zip:%s | %s, %s | %s ]${NC}\n" "${count}." "$f_ip" "${f_zip:-N/A}" "$f_city" "$f_cnt" "$f_isp"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Postcode : $clean_z (Fresh Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for entry in "${fresh_zips[@]}"; do
                    echo "${c}. ${entry%%|*}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_zips[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_zips[@]} IP Terdahulu) ]───╮${NC}"
            for old_e in "${old_zips[@]}"; do
                IFS='|' read -r o_ip o_city o_reg o_cnt o_zip o_isp <<< "$old_e"
                all_selectable_ips+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | Zip:%s | %s, %s ]${NC}\n" "${count}." "$o_ip" "${o_zip:-N/A}" "$o_city" "$o_cnt"
                ((count++))
            done
        fi

        rm -f /tmp/zip_*.txt /tmp/batch_zip_*.json /tmp/all_batch_zip.json /tmp/final_zip_*.txt

        total_sel=${#all_selectable_ips[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari IP Fresh lagi, taip ${YELLOW}[1-${total_sel}]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "$total_sel" ]; then
            sel_ip="${all_selectable_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari IP Fresh lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 6: SEARCH DOMAIN IP ADDRESS
# ==============================================================
search_domain_by_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 6. SEARCH DOMAIN IP ADDRESS (NO-REPEAT + LIVE DNS) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address (cth: 104.18.21.212) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"

    if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
        return
    fi

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
        sleep 1.5
        return
    fi

    local seen_session="/tmp/seen_menu6_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode       :${NC} ${GREEN}Original Host + Fresh Domain Atas ✔${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_doms < "$seen_session" 2>/dev/null

        (reverse_ip_domains_worker "$target_ip" "$seen_session") &
        loading_spinner $! "Mengesan Domain BAHARU pada IP $target_ip (Batch #${batch_num})..."

        orig_host=$(cat /tmp/rev_original_host.txt 2>/dev/null | xargs)
        mapfile -t fresh_dom_lines < /tmp/rev_domains_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL DOMAIN / HOST BAGI IP ${target_ip} ★ ]───╮${NC}"
        if [ -n "$orig_host" ]; then
            echo -e "${YELLOW}│${NC} ${GREEN}[00]${NC} ${WHITE}${orig_host}${NC} ${CYAN}[ ORIGINAL HOST ✔ ]${NC}"
        else
            echo -e "${YELLOW}│${NC} ${GRAY}Tiada Original Host spesifik dikesan (Shared Anycast IP)${NC}"
        fi
        echo -e "${YELLOW}╰────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ DOMAIN BAHARU / FRESH (Batch #${batch_num} - ${#fresh_dom_lines[@]} Domain) ★ ]───╮${NC}"
        all_selectable_doms=()
        count=1
        if [ ${#fresh_dom_lines[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi domain baharu untuk IP ini. Semua domain telah disenaraikan di bawah.${NC}"
        else
            for d_entry in "${fresh_dom_lines[@]}"; do
                IFS='|' read -r dom live_ip <<< "$d_entry"
                all_selectable_doms+=("$dom")
                echo "$d_entry" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-36s${NC} ${CYAN}[ Live IP -> %s ]${NC}\n" "${count}." "$dom" "$live_ip"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Domain IP : $target_ip (Batch #${batch_num})"
                echo "Original Domain  : ${orig_host:-N/A}"
                echo "Ip Address Found :"
                c=1
                for d_entry in "${fresh_dom_lines[@]}"; do
                    IFS='|' read -r dom live_ip <<< "$d_entry"
                    echo "${c}. ${dom} -> ${live_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_doms[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DOMAIN LAMA / SUDAH DIBACA (${#old_doms[@]} Domain) ]───╮${NC}"
            for old_e in "${old_doms[@]}"; do
                IFS='|' read -r o_dom o_lip <<< "$old_e"
                all_selectable_doms+=("$o_dom")
                printf "  ${GRAY}%-4s %-36s [ Sudah Dibaca -> %s ]${NC}\n" "${count}." "$o_dom" "$o_lip"
                ((count++))
            done
        fi

        rm -f /tmp/rev_domains_*.txt /tmp/rev_original_host.txt

        total_sel=${#all_selectable_doms[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari Domain Fresh lagi, taip ${YELLOW}[00]${WHITE}/${YELLOW}[1-${total_sel}]${WHITE} VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r dom_choice
        if [ "$dom_choice" == "0" ]; then
            break
        elif [ "$dom_choice" == "00" ] && [ -n "$orig_host" ]; then
            print_vless_links "$target_ip" "$orig_host"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        elif [[ "$dom_choice" =~ ^[0-9]+$ ]] && [ "$dom_choice" -ge 1 ] && [ "$dom_choice" -le "$total_sel" ]; then
            sel_dom="${all_selectable_doms[$((dom_choice-1))]}"
            print_vless_links "$target_ip" "$sel_dom"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 7: SEARCH IP DOMAIN
# ==============================================================
search_ip_by_domain() {
    show_banner
    echo -e "${CYAN}╭─[ 7. SEARCH IP DOMAIN (NO-REPEAT + LIVE DNS) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Domain (cth: sub.viu.com) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r raw_dom
    echo -ne "${NC}"

    if [ "$raw_dom" == "0" ] || [ -z "$raw_dom" ]; then
        return
    fi

    target_dom=$(echo "$raw_dom" | sed -E 's#^https?://##; s#/.*$##' | tr '[:upper:]' '[:lower:]' | xargs)
    local seen_session="/tmp/seen_menu7_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Domain Target :${NC} ${YELLOW}${target_dom} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mod Carian    :${NC} ${GREEN}Original IP + Fresh DNS Atas ✔${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_dns < "$seen_session" 2>/dev/null

        (domain_to_ip_worker "$target_dom" "$seen_session") &
        loading_spinner $! "Mencari Rekod DNS BAHARU bagi ${target_dom} (Batch #${batch_num})..."

        cname_rec=$(cat /tmp/dom_cname.txt 2>/dev/null | xargs)
        mapfile -t orig_ip_lines < /tmp/dom_orig_details.txt 2>/dev/null
        mapfile -t fresh_dns_lines < /tmp/dom_other_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL IP ADDRESS DIGUNAKAN OLEH: ${target_dom} ★ ]───╮${NC}"
        if [ -n "$cname_rec" ]; then
            echo -e "${YELLOW}│${NC} ${WHITE}CNAME Record :${NC} ${CYAN}${cname_rec}${NC}"
        fi

        orig_ips_only=()
        if [ ${#orig_ip_lines[@]} -eq 0 ]; then
            echo -e "${YELLOW}│${NC} ${RED}[!] Tiada rekod IPv4 (A Record) aktif ditemui untuk ${target_dom}${NC}"
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

        echo -e "${GREEN}╭───[ ★ REKOD DNS BAHARU / FRESH (Batch #${batch_num} - ${#fresh_dns_lines[@]} Rekod) ★ ]───╮${NC}"
        other_ips=()
        other_hosts=()
        count=1
        if [ ${#fresh_dns_lines[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi rekod DNS baharu ditemui. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for d_line in "${fresh_dns_lines[@]}"; do
                IFS='|' read -r d_host d_ip <<< "$d_line"
                other_hosts+=("$d_host")
                other_ips+=("$d_ip")
                echo "$d_line" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-36s${NC} ${YELLOW}➜ %-15s${NC} ${CYAN}[Live IP]${NC}\n" "${count}." "$d_host" "$d_ip"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search IP Domain : $target_dom (Batch #${batch_num})"
                echo "Original IP      : ${orig_ips_only[*]:-N/A}"
                echo "Ip Address Found :"
                c=1
                for d_line in "${fresh_dns_lines[@]}"; do
                    IFS='|' read -r d_host d_ip <<< "$d_line"
                    echo "${c}. ${d_host} -> ${d_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_dns[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DNS LAMA / SUDAH DIBACA (${#old_dns[@]} Rekod) ]───╮${NC}"
            for old_e in "${old_dns[@]}"; do
                IFS='|' read -r o_host o_ip <<< "$old_e"
                other_hosts+=("$o_host")
                other_ips+=("$o_ip")
                printf "  ${GRAY}%-4s %-36s ➜ %-15s [Sudah Dibaca]${NC}\n" "${count}." "$o_host" "$o_ip"
                ((count++))
            done
        fi

        rm -f /tmp/dom_orig_*.txt /tmp/dom_cname.txt /tmp/dom_other_*.txt

        total_sel=${#other_ips[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari Rekod Fresh lagi, taip ${YELLOW}[01]${WHITE} VLESS Orig, ${YELLOW}[1-${total_sel}]${WHITE} VLESS Lain, atau ${RED}[0]${WHITE} Exit : "
        read -r ip_dom_choice
        if [ "$ip_dom_choice" == "0" ]; then
            break
        elif [[ "$ip_dom_choice" =~ ^0[1-9]$ ]]; then
            o_idx=$(( 10#$ip_dom_choice - 1 ))
            if [ -n "${orig_ips_only[$o_idx]}" ]; then
                print_vless_links "${orig_ips_only[$o_idx]}" "$target_dom"
                echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
                read -r sub_c
                [ "$sub_c" == "0" ] && break
            fi
        elif [[ "$ip_dom_choice" =~ ^[0-9]+$ ]] && [ "$ip_dom_choice" -ge 1 ] && [ "$ip_dom_choice" -le "$total_sel" ]; then
            sel_ip="${other_ips[$((ip_dom_choice-1))]}"
            sel_host="${other_hosts[$((ip_dom_choice-1))]}"
            print_vless_links "$sel_ip" "$sel_host"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 8: BUG HUNTER
# ==============================================================
bug_hunter_menu() {
    local batch_num=1
    local seen_session="/tmp/seen_menu8_$$.txt"
    > "$seen_session"

    local top_ips=(
        "104.18.21.212"
        "104.18.20.212"
        "172.66.43.86"
        "104.17.148.22"
        "104.17.183.120"
        "104.18.30.244"
    )
    local top_doms=(
        "mcmc-my.metricelltestcloud.com"
        "mcmc-my.metricelltestcloud.com"
        "investors.shopify.com"
        "www.speedtest.net"
        "www.udemy.com"
        "engage.cloudflareclient.com"
    )

    while true; do
        show_banner
        echo -e "${YELLOW}╭───[ ★ SENARAI BUG HUNTER YANG BERJAYA DIPAKAI (VERIFIED) ★ ]───╮${NC}"
        for i in "${!top_ips[@]}"; do
            num=$(printf "%02d" $((i+1)))
            printf "${YELLOW}│${NC} ${GREEN}[%s]${NC} ${WHITE}%-16s${NC} - ${CYAN}%-34s${NC} ${YELLOW}│${NC}\n" "$num" "${top_ips[$i]}" "${top_doms[$i]}"
        done
        echo -e "${YELLOW}╰────────────────────────────────────────────────────────────────╯${NC}\n"

        mapfile -t old_bh < "$seen_session" 2>/dev/null

        (bug_hunter_worker "$seen_session") &
        loading_spinner $! "Mencari IP Bug Hunter BAHARU & Domain Original (Batch #${batch_num})..."

        mapfile -t fresh_bh < /tmp/bh_final_results.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ IP BUG HUNTER BAHARU / FRESH (Batch #${batch_num} - ${#fresh_bh[@]} IP) ★ ]───╮${NC}"

        bh_ips=()
        bh_doms=()
        count=1
        if [ ${#fresh_bh[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada IP baharu ditemui pada pusingan ini. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for entry in "${fresh_bh[@]}"; do
                IFS='|' read -r b_ip b_dom <<< "$entry"
                bh_ips+=("$b_ip")
                bh_doms+=("$b_dom")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s${NC} ${WHITE}%-16s${NC} - ${CYAN}%s${NC} ${GREEN}[FRESH 1003+WS ✔]${NC}\n" "${count}." "$b_ip" "$b_dom"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Bug Hunter Scan  : Batch #${batch_num}"
                echo "Ip Address Found :"
                c=1
                for entry in "${fresh_bh[@]}"; do
                    IFS='|' read -r b_ip b_dom <<< "$entry"
                    echo "${c}. ${b_ip} - ${b_dom}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_bh[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD BUG HUNTER LAMA / SUDAH DIBACA (${#old_bh[@]} IP) ]───╮${NC}"
            for old_e in "${old_bh[@]}"; do
                IFS='|' read -r o_ip o_dom <<< "$old_e"
                bh_ips+=("$o_ip")
                bh_doms+=("$o_dom")
                printf "  ${GRAY}%-3s %-16s - %s [Sudah Dibaca]${NC}\n" "${count}." "$o_ip" "$o_dom"
                ((count++))
            done
        fi

        rm -f /tmp/bh_final_results.txt

        total_sel=${#bh_ips[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} Search More (Fresh), taip ${YELLOW}[01-06]${WHITE}/${YELLOW}[1-${total_sel}]${WHITE} Link VLESS, atau ${RED}[0]${WHITE} Back to Menu : "
        read -r bh_choice

        if [ "$bh_choice" == "0" ]; then
            break
        elif [[ "$bh_choice" =~ ^0[1-6]$ ]]; then
            v_idx=$(( 10#$bh_choice - 1 ))
            print_vless_links "${top_ips[$v_idx]}" "${top_doms[$v_idx]}"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk Search More, atau ${RED}[0]${WHITE} Back to Menu : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        elif [[ "$bh_choice" =~ ^[0-9]+$ ]] && [ "$bh_choice" -ge 1 ] && [ "$bh_choice" -le "$total_sel" ]; then
            s_idx=$(( bh_choice - 1 ))
            print_vless_links "${bh_ips[$s_idx]}" "${bh_doms[$s_idx]}"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk Search More, atau ${RED}[0]${WHITE} Back to Menu : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 9: SEARCH DNS IPV6 ([2606:4700:3108::ac42:28aa])
# ==============================================================
search_dns_ipv6() {
    show_banner
    echo -e "${CYAN}╭─[ 9. SEARCH DNS IPV6 (FORMAT: [2606:4700:...]) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IPv4 atau Domain (cth: 172.66.40.170 / sub.viu.com) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_q
    echo -ne "${NC}"

    if [ "$raw_q" == "0" ] || [ -z "$raw_q" ]; then
        return
    fi

    clean_q=$(echo "$raw_q" | sed -E 's#^https?://##; s#/.*$##' | xargs)
    local seen_session="/tmp/seen_menu9_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Target Input :${NC} ${YELLOW}${clean_q} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Format Output:${NC} ${GREEN}[2606:4700:xxxx::xxxx:xxxx] ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode         :${NC} ${CYAN}No-Repeat (Fresh Atas / Lama Bawah) ✔${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_v6 < "$seen_session" 2>/dev/null

        (ipv6_dns_worker "$clean_q" "$seen_session") &
        loading_spinner $! "Mencari rekod DNS IPv6 BAHARU bagi ${clean_q} (Batch #${batch_num})..."

        mapfile -t fresh_v6 < /tmp/v6_fresh_output.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ REKOD DNS IPV6 BAHARU / FRESH (Batch #${batch_num} - ${#fresh_v6[@]} Rekod) ★ ]───╮${NC}"
        all_v6_addrs=()
        count=1
        if [ ${#fresh_v6[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi rekod IPv6 baharu ditemui. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for v6_entry in "${fresh_v6[@]}"; do
                IFS='|' read -r v6_brack v6_desc <<< "$v6_entry"
                all_v6_addrs+=("$v6_brack")
                echo "$v6_entry" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-34s${NC} ${CYAN}[ %s ]${NC}\n" "${count}." "$v6_brack" "$v6_desc"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search DNS IPv6  : $clean_q (Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for v6_entry in "${fresh_v6[@]}"; do
                    IFS='|' read -r v6_brack v6_desc <<< "$v6_entry"
                    echo "${c}. ${v6_brack} (${v6_desc})"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_v6[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD IPV6 LAMA / SUDAH DIBACA (${#old_v6[@]} Rekod) ]───╮${NC}"
            for old_e in "${old_v6[@]}"; do
                IFS='|' read -r o_v6 o_desc <<< "$old_e"
                all_v6_addrs+=("$o_v6")
                printf "  ${GRAY}%-4s %-34s [ Sudah Dibaca | %s ]${NC}\n" "${count}." "$o_v6" "$o_desc"
                ((count++))
            done
        fi

        rm -f /tmp/v6_fresh_output.txt

        total_sel=${#all_v6_addrs[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari IPv6 Fresh lagi, taip ${YELLOW}[1-${total_sel}]${WHITE} jana VLESS IPv6, atau ${RED}[0]${WHITE} Exit : "
        read -r v6_choice
        if [ "$v6_choice" == "0" ]; then
            break
        elif [[ "$v6_choice" =~ ^[0-9]+$ ]] && [ "$v6_choice" -ge 1 ] && [ "$v6_choice" -le "$total_sel" ]; then
            sel_v6="${all_v6_addrs[$((v6_choice-1))]}"
            print_vless_links "$sel_v6" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari IPv6 Fresh lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 10: SEARCH IPV6 TO DNS RECORD IPV4 (ORIGINAL IPV4 + LAIN)
# ==============================================================
search_ipv6_to_ipv4() {
    show_banner
    echo -e "${CYAN}╭─[ 10. SEARCH IPV6 KE DNS RECORD IPV4 (ORIGINAL IPV4 + SHARED) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IPv6 (cth: [2606:4700:3108::ac42:28aa]) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_v6_in
    echo -ne "${NC}"

    if [ "$raw_v6_in" == "0" ] || [ -z "$raw_v6_in" ]; then
        return
    fi

    clean_v6_disp=$(echo "$raw_v6_in" | tr -d '[] ' | tr '[:upper:]' '[:lower:]')
    local seen_session="/tmp/seen_menu10_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Target IPv6  :${NC} ${YELLOW}[${clean_v6_disp}] ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mod Carian   :${NC} ${GREEN}Original IPv4 Atas + Fresh DNS Bawah ✔${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────────────╯${NC}"
        echo ""

        mapfile -t old_v4_recs < "$seen_session" 2>/dev/null

        (ipv6_to_ipv4_worker "$clean_v6_disp" "$seen_session") &
        loading_spinner $! "Menyahkod Original IPv4 & mencari rekod DNS IPv4 berkaitan (Batch #${batch_num})..."

        orig_info_line=$(cat /tmp/v6to4_orig_info.txt 2>/dev/null)
        IFS='|' read -r orig_v4 orig_dom orig_1003 orig_loc orig_isp <<< "$orig_info_line"

        mapfile -t fresh_v4_recs < /tmp/v6to4_fresh_output.txt 2>/dev/null

        # 1. BAHAGIAN PALING ATAS: ASINGKAN ORIGINAL IPV4 ADDRESS & DOMAIN ASAL
        echo -e "${YELLOW}╭───[ ★ ORIGINAL IPv4 ADDRESS BAGI [${clean_v6_disp}] ★ ]───╮${NC}"
        if [ -n "$orig_v4" ]; then
            echo -e "${YELLOW}│${NC} ${GREEN}[00]${NC} ${WHITE}${orig_v4}${NC} - ${CYAN}${orig_dom}${NC}"
            echo -e "${YELLOW}│${NC}      ${GRAY}[ ${orig_1003} | ${orig_loc} | ${orig_isp} ]${NC}"
        else
            echo -e "${YELLOW}│${NC} ${RED}[!] Gagal mengesan Original IPv4 daripada alamat IPv6 ini.${NC}"
        fi
        echo -e "${YELLOW}╰──────────────────────────────────────────────────────────────────────╯${NC}\n"

        # 2. BAHAGIAN KEDUA: REKOD DNS IPV4 BAHARU / FRESH
        echo -e "${GREEN}╭───[ ★ REKOD DNS IPv4 BAHARU / FRESH (Batch #${batch_num} - ${#fresh_v4_recs[@]} Rekod) ★ ]───╮${NC}"
        all_sel_v4=()
        all_sel_dom=()
        count=1
        if [ ${#fresh_v4_recs[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi rekod IPv4 baharu ditemui. Semua rekod terdahulu ada di bawah.${NC}"
        else
            for r_line in "${fresh_v4_recs[@]}"; do
                IFS='|' read -r r_v4 r_desc <<< "$r_line"
                r_host="${r_desc%% *}"
                all_sel_v4+=("$r_v4")
                all_sel_dom+=("$r_host")
                echo "$r_line" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-16s${NC} - ${CYAN}%s${NC}\n" "${count}." "$r_v4" "$r_desc"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search IPv6->IPv4: [${clean_v6_disp}] (Batch #${batch_num})"
                echo "Original IP      : ${orig_v4} (${orig_dom})"
                echo "Ip Address Found :"
                c=1
                for r_line in "${fresh_v4_recs[@]}"; do
                    IFS='|' read -r r_v4 r_desc <<< "$r_line"
                    echo "${c}. ${r_v4} - ${r_desc}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        # 3. BAHAGIAN BAWAH: REKOD LAMA / SUDAH DIBACA
        if [ ${#old_v4_recs[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DNS IPv4 LAMA / SUDAH DIBACA (${#old_v4_recs[@]} Rekod) ]───╮${NC}"
            for old_e in "${old_v4_recs[@]}"; do
                IFS='|' read -r o_v4 o_desc <<< "$old_e"
                o_host="${o_desc%% *}"
                all_sel_v4+=("$o_v4")
                all_sel_dom+=("$o_host")
                printf "  ${GRAY}%-4s %-16s - %s [Sudah Dibaca]${NC}\n" "${count}." "$o_v4" "$o_desc"
                ((count++))
            done
        fi

        rm -f /tmp/v6to4_orig_info.txt /tmp/v6to4_fresh_output.txt

        total_sel=${#all_sel_v4[@]}
        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} cari IPv4 Fresh lagi, taip ${YELLOW}[00]${WHITE} VLESS Orig, ${YELLOW}[1-${total_sel}]${WHITE} VLESS Lain, atau ${RED}[0]${WHITE} Exit : "
        read -r v4_choice
        if [ "$v4_choice" == "0" ]; then
            break
        elif [ "$v4_choice" == "00" ] && [ -n "$orig_v4" ]; then
            print_vless_links "$orig_v4" "${orig_dom:-$DEFAULT_VLESS_HOST}"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        elif [[ "$v4_choice" =~ ^[0-9]+$ ]] && [ "$v4_choice" -ge 1 ] && [ "$v4_choice" -le "$total_sel" ]; then
            idx=$(( v4_choice - 1 ))
            print_vless_links "${all_sel_v4[$idx]}" "${all_sel_dom[$idx]:-$DEFAULT_VLESS_HOST}"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}

# ==============================================================
# MENU 3: SHOW HISTORY
# ==============================================================
show_history() {
    show_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                    ${WHITE}SHOW HISTORY${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}\n"

    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "  ${YELLOW}Tiada rekod carian ditemui setakat ini.${NC}\n"
    else
        while IFS= read -r line; do
            if [[ "$line" == "--------------------------------------------------" ]]; then
                echo -e "${PURPLE}──────────────────────────────────────────────────${NC}"
            elif [[ "$line" =~ ^(Ip\ Target|Search\ Location|Search\ Postcode|Search\ Domain\ IP|Original\ Domain|Search\ IP\ Domain|Original\ IP|Bug\ Hunter\ Scan|Search\ DNS\ IPv6|Search\ IPv6-\>IPv4) ]]; then
                echo -e "${YELLOW}${line}${NC}"
            elif [[ "$line" =~ ^Ip\ Address\ Found ]]; then
                echo -e "${CYAN}${line}${NC}"
            elif [[ "$line" =~ ^[0-9]+\. ]]; then
                echo -e "${GREEN}${line}${NC}"
            else
                echo -e "${WHITE}${line}${NC}"
            fi
        done < "$HISTORY_FILE"
    fi

    echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
    echo -ne "${WHITE}Tekan enter untuk balik ke menu${NC}"
    read -r
}
