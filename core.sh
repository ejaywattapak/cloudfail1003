#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - CORE ENGINE v8.0 (REVERSE DNS + VLESS WS)
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

search_error_1003_worker() {
    local target_ip=$1
    local country=$2
    local region=$3
    local city=$4
    local zip=$5

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"

    > /tmp/candidate_ips.txt
    > /tmp/live_1003_ips.txt
    > /tmp/verified_matches.txt
    > /tmp/final_matched_output.txt

    for _ in {1..30}; do
        echo "${o1}.${o2}.${o3}.$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt
    done
    for _ in {1..45}; do
        echo "${o1}.${o2}.$(( RANDOM % 256 )).$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..14}; do
            cidr_to_random_ip "$prefix" >> /tmp/candidate_ips.txt
        done
    done < <(generate_cf_prefixes)

    grep -v "^${target_ip}$" /tmp/candidate_ips.txt | awk '!seen[$0]++' | shuf -n 280 > /tmp/unique_candidates.txt

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
}

search_twin_1003_worker() {
    local target_ip=$1
    local country=$2
    local city=$3
    local zip=$4

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"

    > /tmp/twin_candidates.txt
    > /tmp/twin_live_pairs.txt
    > /tmp/twin_final_output.txt

    for _ in {1..25}; do
        b3=$(( RANDOM % 254 ))
        b4=$(( (RANDOM % 254) + 1 ))
        twin_b3=$(( b3 + 1 ))
        echo "${o1}.${o2}.${b3}.${b4}|${o1}.${o2}.${twin_b3}.${b4}" >> /tmp/twin_candidates.txt
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..12}; do
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

    awk '!seen[$0]++' /tmp/twin_candidates.txt | shuf -n 95 > /tmp/twin_unique.txt

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
}

# --- WORKER MENU 6: REVERSE IP / PASSIVE DNS DOMAIN SCANNER ---
reverse_ip_domains_worker() {
    local target_ip=$1
    > /tmp/rev_domains_raw.txt
    > /tmp/rev_domains_clean.txt

    # 1. RapidDNS.io (Sangat lengkap untuk rekod A Cloudflare)
    curl -s --max-time 10 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${target_ip}?full=1" 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    # 2. HackerTarget Reverse IP Lookup
    curl -s --max-time 8 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${target_ip}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    # 3. AlienVault OTX Passive DNS (Merekod semua domain & subdomain yang pernah guna IP ini)
    curl -s --max-time 10 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${target_ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    # 4. Webscan.cc API
    curl -s --max-time 8 -A "Mozilla/5.0" "https://api.webscan.cc/?action=query&ip=${target_ip}" 2>/dev/null \
        | jq -r '.[]?.domain' 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    # 5. PTR / Reverse DNS Rasmi
    curl -s --max-time 5 "http://ip-api.com/json/${target_ip}?fields=reverse" 2>/dev/null \
        | jq -r '.reverse' 2>/dev/null \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_domains_raw.txt

    # Bersihkan domain sampah UI laman web (seperti rapiddns.io, google, dll)
    tr '[:upper:]' '[:lower:]' < /tmp/rev_domains_raw.txt \
        | grep -vE "^(rapiddns\.io|www\.rapiddns\.io|cloudflare\.com|w3\.org|google\.com|gstatic\.com|googleapis\.com|bootstrap|jquery|fontawesome|jsdelivr|cdnjs|html5shiv|respond\.min\.js|popper\.min\.js)$" \
        | grep -vE "\.(png|jpg|jpeg|gif|svg|css|js|ico|woff|woff2|ttf)$" \
        | awk '!seen[$0]++' > /tmp/rev_domains_clean.txt
}

# --- MENU 1: CLONE IP ---
clone_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 1. CLONE IP (SAME & ALT RANGE + VLESS WS READY) ]${NC}"
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

    local batch_num=1
    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode       :${NC} ${GREEN}Julat Sama (${o1}.${o2}.*) + Alternatif CF ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Protokol   :${NC} ${CYAN}Error 1003 + VLESS WS/HttpUpgrade/Xhttp ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${region}, ${country} (${zip:-N/A})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        (search_error_1003_worker "$target_ip" "$country" "$region" "$city" "$zip") &
        loading_spinner $! "Mengimbas 20 IP (Julat Sama & Alternatif + VLESS WS Ready)..."

        mapfile -t matched_lines < /tmp/final_matched_output.txt 2>/dev/null

        echo -e "${GREEN}[✔] Selesai! 20 IP Error 1003 + VLESS WS Ready (${YELLOW}${target_ip}${GREEN}):${NC}\n"

        found_ips=()
        if [ ${#matched_lines[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif ditemui pada pusingan ini. Tekan Enter untuk cuba lagi.${NC}"
        else
            count=1
            for entry in "${matched_lines[@]}"; do
                IFS='|' read -r f_ip f_city f_zip f_isp <<< "$entry"
                found_ips+=("$f_ip")
                if [[ "$f_ip" == "${o1}.${o2}."* ]]; then
                    r_tag="SAME-RANGE"
                else
                    r_tag="ALT-RANGE "
                fi
                printf "${GREEN}%-3s %-16s [ %s | 1003+WS ✔ | %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$r_tag" "$f_city" "${f_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Clone IP + VLESS WS - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for f_ip in "${found_ips[@]}"; do
                    echo "${c}. ${f_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/candidate_*.txt /tmp/unique_candidates.txt \
              /tmp/live_1003_ips.txt /tmp/batch_1003*.json /tmp/verified_matches.txt \
              /tmp/same_range.txt /tmp/alt_range.txt /tmp/final_matched_output.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi, taip ${YELLOW}[1-20]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "${#found_ips[@]}" ]; then
            sel_ip="${found_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari 20 IP lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
}

# --- MENU 2: CLONE TWIN IP ---
clone_twin_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 2. CLONE TWIN IP (SAME & ALT RANGE + VLESS WS) ]${NC}"
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

    local batch_num=1
    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Twin Mode - Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Mode       :${NC} ${GREEN}Julat Sama (${o1}.${o2}.*) + Alternatif CF ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Protokol   :${NC} ${CYAN}Error 1003 + VLESS WS/HttpUpgrade/Xhttp ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${region}, ${country} (${country_code})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        (search_twin_1003_worker "$target_ip" "$country" "$city" "$zip") &
        loading_spinner $! "Mencari 20 Pasangan Twin IP (1003 + VLESS WS Ready)..."

        mapfile -t twin_lines < /tmp/twin_final_output.txt 2>/dev/null

        echo -e "${GREEN}[✔] Selesai! Pasangan Twin IP Error 1003 + VLESS WS (${YELLOW}${target_ip}${GREEN}):${NC}\n"

        found_twins=()
        if [ ${#twin_lines[@]} -eq 0 ]; then
            echo -e "${RED}Tiada pasangan Twin IP aktif ditemui pada pusingan ini. Tekan Enter untuk cuba lagi.${NC}"
        else
            count=1
            for entry in "${twin_lines[@]}"; do
                IFS='|' read -r t_pair t_cnt t_city t_zip t_isp <<< "$entry"
                found_twins+=("$t_pair")
                printf "${GREEN}%-3s %-35s [ 1003+WS ✔ | %s, %s | Zip:%s ]${NC}\n" "${count}." "$t_pair" "$t_city" "$t_cnt" "${t_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Twin IP + VLESS WS - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for t_p in "${found_twins[@]}"; do
                    echo "${c}. ${t_p}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/twin_*.txt /tmp/twin_batch.json

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk Twin IP lagi, taip ${YELLOW}[1-20]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "${#found_twins[@]}" ]; then
            raw_pair="${found_twins[$((choice_loop-1))]}"
            sel_ip="${raw_pair%% *}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari Twin IP lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
}

# --- MENU 4: SEARCH BY COUNTRY / REGION / CITY ---
search_by_location() {
    show_banner
    echo -e "${CYAN}╭─[ 4. SEARCH BY COUNTRY / REGION / CITY (VLESS WS READY) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Lokasi (cth: Singapore, Tokyo, USA) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_loc
    echo -ne "${NC}"

    if [ "$query_loc" == "0" ] || [ -z "$query_loc" ]; then
        return
    fi

    clean_q=$(echo "$query_loc" | xargs)
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 4. SEARCH LOCATION : ${YELLOW}${clean_q}${CYAN} (1003 + VLESS WS | Batch #${batch_num}) ]${NC}\n"

        > /tmp/loc_candidate_ips.txt
        > /tmp/loc_live_1003.txt

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do
                cidr_to_random_ip "$prefix" >> /tmp/loc_candidate_ips.txt
            done
        done < <(generate_cf_prefixes)

        shuf -n 270 /tmp/loc_candidate_ips.txt > /tmp/loc_unique.txt

        (verify_1003_and_vless_ws /tmp/loc_unique.txt /tmp/loc_live_1003.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas 20 IP Error 1003 + VLESS WS untuk '${clean_q}'..."

        mapfile -t live_ips < <(head -n 180 /tmp/loc_live_1003.txt)
        found_ips=()

        if [ ${#live_ips[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif dijumpai.${NC}"
        else
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
            mapfile -t matched_locs < /tmp/final_loc_clean.txt

            echo -e "${GREEN}[✔] Selesai! 20 IP Error 1003 + VLESS WS untuk '${YELLOW}${clean_q}${GREEN}':${NC}\n"

            count=1
            for entry in "${matched_locs[@]}"; do
                IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                found_ips+=("$f_ip")
                printf "${GREEN}%-3s %-16s [ 1003+WS ✔ | %s, %s, %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$f_city" "$f_reg" "$f_cnt" "${f_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Location : $clean_q (VLESS WS - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for f_ip in "${found_ips[@]}"; do
                    echo "${c}. ${f_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/loc_*.txt /tmp/batch_loc_*.json /tmp/all_batch_loc.json /tmp/final_loc_*.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi, taip ${YELLOW}[1-20]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "${#found_ips[@]}" ]; then
            sel_ip="${found_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari 20 IP lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
}

# --- MENU 5: SEARCH BY POSTCODE ---
search_by_postcode() {
    show_banner
    echo -e "${CYAN}╭─[ 5. SEARCH BY POSTCODE (VLESS WS READY) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Postcode / Zipcode (cth: 75001, M5V) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_zip
    echo -ne "${NC}"

    if [ "$query_zip" == "0" ] || [ -z "$query_zip" ]; then
        return
    fi

    clean_z=$(echo "$query_zip" | xargs)
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 5. SEARCH POSTCODE : ${YELLOW}${clean_z}${CYAN} (1003 + VLESS WS | Batch #${batch_num}) ]${NC}\n"

        > /tmp/zip_candidate_ips.txt
        > /tmp/zip_live_1003.txt

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do
                cidr_to_random_ip "$prefix" >> /tmp/zip_candidate_ips.txt
            done
        done < <(generate_cf_prefixes)

        shuf -n 270 /tmp/zip_candidate_ips.txt > /tmp/zip_unique.txt

        (verify_1003_and_vless_ws /tmp/zip_unique.txt /tmp/zip_live_1003.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas 20 IP Error 1003 + VLESS WS untuk poskod $clean_z..."

        mapfile -t live_ips < <(head -n 180 /tmp/zip_live_1003.txt)
        found_ips=()

        if [ ${#live_ips[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif dijumpai.${NC}"
        else
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
            mapfile -t matched_zips < /tmp/final_zip_clean.txt

            echo -e "${GREEN}[✔] Selesai! 20 IP Error 1003 + VLESS WS untuk Poskod '${YELLOW}${clean_z}${GREEN}':${NC}\n"

            count=1
            for entry in "${matched_zips[@]}"; do
                IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                found_ips+=("$f_ip")
                printf "${GREEN}%-3s %-16s [ 1003+WS ✔ | Zip:%s | %s, %s | %s ]${NC}\n" "${count}." "$f_ip" "${f_zip:-N/A}" "$f_city" "$f_cnt" "$f_isp"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Postcode : $clean_z (VLESS WS - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for f_ip in "${found_ips[@]}"; do
                    echo "${c}. ${f_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/zip_*.txt /tmp/batch_zip_*.json /tmp/all_batch_zip.json /tmp/final_zip_*.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi, taip ${YELLOW}[1-20]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        elif [[ "$choice_loop" =~ ^[0-9]+$ ]] && [ "$choice_loop" -ge 1 ] && [ "$choice_loop" -le "${#found_ips[@]}" ]; then
            sel_ip="${found_ips[$((choice_loop-1))]}"
            print_vless_links "$sel_ip" "$DEFAULT_VLESS_HOST"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk sambung cari 20 IP lagi, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
        ((batch_num++))
    done
}

# --- MENU 6: SEARCH DOMAIN IP ADDRESS (REVERSE IP / PASSIVE DNS LOOKUP) ---
search_domain_by_ip() {
    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 6. SEARCH DOMAIN IP ADDRESS (REVERSE DNS LOOKUP) ]${NC}"
        echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address (cth: 104.18.21.212) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
        read -r target_ip
        echo -ne "${NC}"

        if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
            return
        fi

        if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
            sleep 1.5
            continue
        fi

        echo ""
        (curl -s "http://ip-api.com/json/${target_ip}?fields=status,country,countryCode,regionName,city,isp,as" > /tmp/dom_ip_info.json) &
        loading_spinner $! "Mengambil maklumat rangkaian bagi $target_ip..."

        country=$(jq -r '.country // "Unknown"' /tmp/dom_ip_info.json 2>/dev/null)
        city=$(jq -r '.city // "Unknown"' /tmp/dom_ip_info.json 2>/dev/null)
        isp=$(jq -r '.isp // "Unknown"' /tmp/dom_ip_info.json 2>/dev/null)
        asn=$(jq -r '.as // "Unknown"' /tmp/dom_ip_info.json 2>/dev/null)
        rm -f /tmp/dom_ip_info.json

        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip}${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${country}${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}ISP / ASN  :${NC} ${CYAN}${isp} (${asn})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        (reverse_ip_domains_worker "$target_ip") &
        loading_spinner $! "Mengorek semua pangkalan data DNS (RapidDNS, OTX, HackerTarget, Webscan)..."

        mapfile -t all_domains < /tmp/rev_domains_clean.txt 2>/dev/null
        total_dom=${#all_domains[@]}

        if [ "$total_dom" -eq 0 ]; then
            echo -e "${RED}[!] Tiada rekod domain awam ditemui untuk IP ${target_ip}.${NC}"
        else
            echo -e "${GREEN}[✔] Dijumpai keseluruhan ${YELLOW}${total_dom}${GREEN} Domain / Subdomain yang menggunakan IP ${YELLOW}${target_ip}${GREEN}:${NC}\n"

            count=1
            for dom in "${all_domains[@]}"; do
                printf "${GREEN}%-4s${NC} ${WHITE}%-42s${NC} ${CYAN}[ DNS A -> %s ]${NC}\n" "${count}." "$dom" "$target_ip"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Search Domain IP : $target_ip (Total: $total_dom Domains)"
                echo "Ip Address Found :"
                c=1
                for dom in "${all_domains[@]:0:50}"; do
                    echo "${c}. ${dom} -> ${target_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/rev_domains_*.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk semak IP lain, taip ${YELLOW}[Nombor Domain]${WHITE} jana Link VLESS, atau ${RED}[0]${WHITE} Exit : "
        read -r dom_choice
        if [ "$dom_choice" == "0" ]; then
            break
        elif [[ "$dom_choice" =~ ^[0-9]+$ ]] && [ "$dom_choice" -ge 1 ] && [ "$dom_choice" -le "$total_dom" ]; then
            sel_dom="${all_domains[$((dom_choice-1))]}"
            print_vless_links "$target_ip" "$sel_dom"
            echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk semak IP lain, atau ${RED}[0]${WHITE} Exit : "
            read -r sub_c
            [ "$sub_c" == "0" ] && break
        fi
    done
}

# --- MENU 3: SHOW HISTORY ---
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
            elif [[ "$line" =~ ^(Ip\ Target|Search\ Location|Search\ Postcode|Search\ Domain\ IP) ]]; then
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
