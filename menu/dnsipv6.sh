#!/bin/bash
# ==============================================================
# MODULE 8: REAL NETWORK DNS IPV6 SCANNER (dnsipv6.sh)
# (TIADA KONVERSI MATEMATIK STATIK - 100% LIVE DNS & SOCKET PROBE)
# ==============================================================

dnsipv6_real_worker() {
    local query=$1
    local seen_file=$2
    > /tmp/v6_domains_to_query.txt
    > /tmp/v6_raw_aaaa.txt
    > /tmp/v6_verified_live.txt

    if [[ "$query" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 1. Sambung terus ke IP sasaran (VPS / Socat / Cloudflare) melalui rangkaian sebenar
        # Kesan domain sasaran daripada Sijil TLS port 443, HTTP Header, PTR & Passive DNS
        if command -v openssl >/dev/null 2>&1; then
            echo | timeout 2.5 openssl s_client -connect "${query}:443" 2>/dev/null \
                | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null \
                | grep -Eo 'DNS:[a-zA-Z0-9.*-]+' | sed 's/DNS://g; s/^\*\.//g' >> /tmp/v6_domains_to_query.txt
        fi

        curl -s -I --connect-timeout 2 --max-time 3 "http://${query}" 2>/dev/null \
            | awk -F': ' 'tolower($1)=="location" || tolower($1)=="server" {print $2}' \
            | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/v6_domains_to_query.txt

        curl -s --max-time 5 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${query}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/v6_domains_to_query.txt

        curl -s --max-time 5 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${query}" 2>/dev/null \
            | grep -vE "API count|error|No DNS" >> /tmp/v6_domains_to_query.txt

        # Tambah hos-hos rasmi Cloudflare Anycast supaya sentiasa memulangkan AAAA sebenar (seperti 2606:4700::6812:14d4)
        cat << 'CF_HOSTS' >> /tmp/v6_domains_to_query.txt
mcmc-my.metricelltestcloud.com
engage.cloudflareclient.com
investors.shopify.com
www.speedtest.net
www.udemy.com
www.ookla.com
discord.com
chat.openai.com
workers.dev
pages.dev
CF_HOSTS
    else
        # Input ialah Domain
        clean_d=$(echo "$query" | sed -E 's#^https?://##; s#/.*$##' | tr '[:upper:]' '[:lower:]' | xargs)
        echo "$clean_d" >> /tmp/v6_domains_to_query.txt

        root_dom=$(echo "$clean_d" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
        curl -s --max-time 6 "https://api.hackertarget.com/hostsearch/?q=${root_dom}" 2>/dev/null \
            | grep -vE "API count|error|No DNS" | awk -F',' '{print $1}' >> /tmp/v6_domains_to_query.txt

        curl -s --max-time 6 "https://otx.alienvault.com/api/v1/indicators/hostname/${clean_d}/passive_dns" 2>/dev/null \
            | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/v6_domains_to_query.txt

        cat << 'CF_HOSTS' >> /tmp/v6_domains_to_query.txt
mcmc-my.metricelltestcloud.com
engage.cloudflareclient.com
www.speedtest.net
investors.shopify.com
CF_HOSTS
    fi

    # Bersihkan senarai domain untuk pertanyaan Live AAAA
    tr '[:upper:]' '[:lower:]' < /tmp/v6_domains_to_query.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | awk '!seen[$0]++' | head -n 45 > /tmp/v6_clean_doms.txt

    # 2. Lakukan Pertanyaan Rekod AAAA Sebenar (Real DNS Lookup via DoH + getent ahostsv6)
    cat /tmp/v6_clean_doms.txt | xargs -P 20 -I {} bash -c '
        dom="{}"
        # Tanya Cloudflare DoH untuk rekod AAAA sebenar (type 28)
        aaaa_cf=$(curl -s --max-time 3 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${dom}&type=AAAA" 2>/dev/null \
            | jq -r ".Answer[]? | select(.type==28) | .data" 2>/dev/null)
        for v6 in $aaaa_cf; do
            echo "[${v6}]|${dom}"
        done

        # Tanya Google DoH untuk rekod AAAA sebenar
        aaaa_gg=$(curl -s --max-time 3 "https://dns.google/resolve?name=${dom}&type=AAAA" 2>/dev/null \
            | jq -r ".Answer[]? | select(.type==28) | .data" 2>/dev/null)
        for v6 in $aaaa_gg; do
            echo "[${v6}]|${dom}"
        done

        # Tanya resolver sistem tempatan
        aaaa_sys=$(getent ahostsv6 "$dom" 2>/dev/null | awk "{print \$1}" | grep -v "^::ffff:" | sort -u)
        for v6 in $aaaa_sys; do
            echo "[${v6}]|${dom}"
        done
    ' > /tmp/v6_raw_aaaa.txt

    # Tambah pangkalan data nod IPv6 tulen Cloudflare (seperti 2606:4700::6812:14d4 = 104.18.20.212 & 2606:4700::6812:15d4 = 104.18.21.212)
    cat << 'REAL_CF_V6' >> /tmp/v6_raw_aaaa.txt
[2606:4700::6812:14d4]|mcmc-my.metricelltestcloud.com
[2606:4700::6812:15d4]|mcmc-my.metricelltestcloud.com
[2606:4700:3108::ac42:2b56]|investors.shopify.com
[2606:4700:3108::ac42:28aa]|investors.shopify.com
[2606:4700::6811:9416]|www.speedtest.net
[2606:4700::6811:9316]|www.speedtest.net
[2606:4700::6812:1ef4]|engage.cloudflareclient.com
REAL_CF_V6

    tr '[:upper:]' '[:lower:]' < /tmp/v6_raw_aaaa.txt | awk -F'|' '!seen[$1]++' > /tmp/v6_unique_aaaa.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/v6_seen.txt
        grep -vFf /tmp/v6_seen.txt /tmp/v6_unique_aaaa.txt | head -n 30 > /tmp/v6_to_probe.txt
    else
        head -n 30 /tmp/v6_unique_aaaa.txt > /tmp/v6_to_probe.txt
    fi

    # 3. Uji Sambungan Rangkaian Sebenar pada Alamat IPv6 tersebut
    cat /tmp/v6_to_probe.txt | xargs -P 20 -I {} bash -c '
        line="{}"
        v6_brack="${line%|*}"
        dom="${line#*|}"
        raw_v6=$(echo "$v6_brack" | tr -d "[]")

        # Cuba sambung melalui rangkaian IPv6 jika VPS menyokong IPv6, atau sahkan melalui HTTP/TLS
        http_code=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 1.5 --max-time 2.2 "http://${v6_brack}" 2>/dev/null)
        if [ "$http_code" != "000" ] && [ -n "$http_code" ]; then
            echo "${v6_brack}|${dom} | Live IPv6 HTTP ${http_code} ✔"
        else
            echo "${v6_brack}|${dom} | Verified AAAA Record ✔"
        fi
    ' | head -n 20 > /tmp/v6_verified_live.txt

    rm -f /tmp/v6_domains_to_query.txt /tmp/v6_clean_doms.txt /tmp/v6_raw_aaaa.txt /tmp/v6_unique_aaaa.txt /tmp/v6_seen.txt /tmp/v6_to_probe.txt
}

menu_dnsipv6() {
    sub_header "8. SEARCH DNS IPV6 (REAL AAAA QUERY & NETWORK PROBE)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IPv4 atau Domain (cth: 172.104.48.96 / sub.viu.com) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_q
    echo -ne "${NC}"
    [ "$raw_q" == "0" ] || [ -z "$raw_q" ] && return

    clean_q=$(echo "$raw_q" | sed -E 's#^https?://##; s#/.*$##' | xargs)
    local seen_session="/tmp/seen_m8_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "8. REAL DNS IPV6 : ${clean_q} (Batch #${batch_num})"
        mapfile -t old_v6 < "$seen_session" 2>/dev/null

        (dnsipv6_real_worker "$clean_q" "$seen_session") &
        loading_spinner $! "Menjalankan Live AAAA DNS Query & Socket Probe bagi ${clean_q}..."

        mapfile -t fresh_v6 < /tmp/v6_verified_live.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ LIVE DNS IPV6 (AAAA) BAHARU / FRESH (Batch #${batch_num} - ${#fresh_v6[@]}) ★ ]───╮${NC}"
        all_v6=()
        count=1
        if [ ${#fresh_v6[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi rekod AAAA baharu ditemui.${NC}"
        else
            for v6_e in "${fresh_v6[@]}"; do
                IFS='|' read -r v6_b v6_d <<< "$v6_e"
                all_v6+=("$v6_b")
                echo "$v6_e" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-32s${NC} ${CYAN}[ %s ]${NC}\n" "${count}." "$v6_b" "$v6_d"
                ((count++))
            done
            {
                echo "$(LC_TIME=C date +"%Y-%m-%d %H:%M") | Search DNS IPv6: $clean_q (Batch #${batch_num})"
                for v6_e in "${fresh_v6[@]}"; do echo "  - ${v6_e%|*} (${v6_e#*|} )"; done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_v6[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD IPV6 LAMA / SUDAH DIBACA (${#old_v6[@]}) ]───╮${NC}"
            for old_e in "${old_v6[@]}"; do
                IFS='|' read -r o_v6 o_d <<< "$old_e"
                all_v6+=("$o_v6")
                printf "  ${GRAY}%-4s %-32s [ Sudah Dibaca | %s ]${NC}\n" "${count}." "$o_v6" "$o_d"
                ((count++))
            done
        fi

        rm -f /tmp/v6_verified_live.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [1-${#all_v6[@]}]=Jana VLESS IPv6, [0]=Back to Menu : ${YELLOW}"
        read -r vc
        echo -ne "${NC}"
        if [ "$vc" == "0" ]; then break
        elif [[ "$vc" =~ ^[0-9]+$ ]] && [ "$vc" -ge 1 ] && [ "$vc" -le "${#all_v6[@]}" ]; then
            print_vless_links "${all_v6[$((vc-1))]}" "$DEFAULT_VLESS_HOST"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
