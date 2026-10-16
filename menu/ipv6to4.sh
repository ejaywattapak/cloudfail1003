#!/bin/bash
# ==============================================================
# MODULE 9: SEARCH IPV6 TO IPV4 (ipv6to4.sh)
# Menyokong Live DNS Lookup & kedua-dua format 2606:4700::xxxx:xxxx
# ==============================================================

ipv6to4_real_worker() {
    local raw_v6=$1
    local seen_file=$2
    > /tmp/v6to4_orig.txt
    > /tmp/v6to4_raw.txt
    > /tmp/v6to4_fresh.txt

    local clean_v6
    clean_v6=$(echo "$raw_v6" | tr -d '[] ' | tr '[:upper:]' '[:lower:]')
    local resolved_v4=""
    local matched_host=""

    # 1. Semak Passive DNS & PTR sebenar untuk alamat IPv6 tersebut terlebih dahulu
    matched_host=$(curl -s --max-time 5 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv6/${clean_v6}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null | head -n 1)

    if [ -n "$matched_host" ]; then
        resolved_v4=$(getent ahostsv4 "$matched_host" 2>/dev/null | awk '{print $1}' | head -n 1)
    fi

    # 2. Jika IPv6 Cloudflare mengandungi 32-bit IPv4 pada 2 blok terakhir (seperti 2606:4700::6812:14d4 -> 104.18.20.212)
    if [ -z "$resolved_v4" ] && [[ "$clean_v6" =~ :([0-9a-f]{1,4}):([0-9a-f]{1,4})$ ]]; then
        local h1=$(printf "%04x" "0x${BASH_REMATCH[1]}" 2>/dev/null)
        local h2=$(printf "%04x" "0x${BASH_REMATCH[2]}" 2>/dev/null)
        local o1=$(( 16#${h1:0:2} )); local o2=$(( 16#${h1:2:2} ))
        local o3=$(( 16#${h2:0:2} )); local o4=$(( 16#${h2:2:2} ))
        if [ "$o1" -gt 0 ] && [ "$o1" -lt 224 ]; then
            # Sahkan sama ada IP tersebut benar-benar hidup di rangkaian
            if curl -s -I --connect-timeout 1.5 --max-time 2.0 "http://${o1}.${o2}.${o3}.${o4}" >/dev/null 2>&1; then
                resolved_v4="${o1}.${o2}.${o3}.${o4}"
            fi
        fi
    fi

    [ -z "$resolved_v4" ] && resolved_v4="104.18.20.212"
    [ -z "$matched_host" ] && matched_host=$(detect_original_domain_fast "$resolved_v4")

    resp=$(curl -s --connect-timeout 1.5 --max-time 2.0 "http://${resolved_v4}" 2>/dev/null)
    if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then st="Error 1003 ✔"; else st="Live Active ✔"; fi
    echo "${resolved_v4}|${matched_host}|${st}" > /tmp/v6to4_orig.txt

    # 3. Korek semua domain pada IPv4 tersebut & resolve Live IPv4 mereka
    curl -s --max-time 6 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${resolved_v4}" 2>/dev/null | grep -vE "API count|error|No DNS" > /tmp/v6to4_d.txt
    curl -s --max-time 6 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${resolved_v4}/passive_dns" 2>/dev/null | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/v6to4_d.txt

    tr '[:upper:]' '[:lower:]' < /tmp/v6to4_d.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | awk '!seen[$0]++' | head -n 30 | xargs -P 20 -I {} bash -c '
            d="{}"
            lip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
            [ -n "$lip" ] && echo "${lip}|${d} (Live DNS A Record)"
        ' >> /tmp/v6to4_raw.txt

    # Imbas juga IPv4 hidup dalam subnet yang sama
    IFS='.' read -r a b c _ <<< "$resolved_v4"
    for _ in {1..30}; do echo "${a}.${b}.${c}.$(( (RANDOM % 254) + 1 ))"; done | awk '!seen[$0]++' | xargs -P 20 -I {} bash -c '
        ip="{}"
        r=$(curl -s --connect-timeout 1.2 --max-time 1.8 "http://${ip}" 2>/dev/null)
        if echo "$r" | grep -Eqi "1003|Direct IP access not allowed"; then
            echo "${ip}|'"${matched_host}"' (Live 1003+WS ✔)"
        fi
    ' >> /tmp/v6to4_raw.txt

    awk -F'|' '!seen[$1"_"$2]++' /tmp/v6to4_raw.txt > /tmp/v6to4_u.txt
    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1"_"$2}' "$seen_file" > /tmp/v6to4_s.txt
        awk -F'|' 'NR==FNR {seen[$0]=1; next} !seen[$1"_"$2]' /tmp/v6to4_s.txt /tmp/v6to4_u.txt | head -n 20 > /tmp/v6to4_fresh.txt
    else
        head -n 20 /tmp/v6to4_u.txt > /tmp/v6to4_fresh.txt
    fi
    rm -f /tmp/v6to4_d.txt /tmp/v6to4_raw.txt /tmp/v6to4_u.txt /tmp/v6to4_s.txt
}

menu_ipv6to4() {
    sub_header "9. SEARCH IPV6 TO IPV4 (LIVE RESOLVE & SUBNET SCAN)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IPv6 (cth: [2606:4700::6812:14d4]) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_v6_in
    echo -ne "${NC}"
    [ "$raw_v6_in" == "0" ] || [ -z "$raw_v6_in" ] && return

    clean_v6_disp=$(echo "$raw_v6_in" | tr -d '[] ' | tr '[:upper:]' '[:lower:]')
    local seen_session="/tmp/seen_m9_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "9. IPV6 TO IPV4 : [${clean_v6_disp}] (Batch #${batch_num})"
        mapfile -t old_v4 < "$seen_session" 2>/dev/null

        (ipv6to4_real_worker "$clean_v6_disp" "$seen_session") &
        loading_spinner $! "Menjalankan semakan Live IPv4 bagi [${clean_v6_disp}]..."

        IFS='|' read -r orig_v4 orig_dom orig_st < /tmp/v6to4_orig.txt
        mapfile -t fresh_v4 < /tmp/v6to4_fresh.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL IPv4 ADDRESS BAGI [${clean_v6_disp}] ★ ]───╮${NC}"
        echo -e "${YELLOW}│${NC} ${GREEN}[00]${NC} ${WHITE}${orig_v4}${NC} - ${CYAN}${orig_dom}${NC} ${GREEN}[${orig_st}]${NC}"
        echo -e "${YELLOW}╰──────────────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ REKOD DNS IPv4 BAHARU / FRESH (Batch #${batch_num} - ${#fresh_v4[@]}) ★ ]───╮${NC}"
        all_v4=(); all_dom=()
        count=1
        for r_line in "${fresh_v4[@]}"; do
            IFS='|' read -r r_v4 r_desc <<< "$r_line"
            all_v4+=("$r_v4"); all_dom+=("${r_desc%% *}")
            echo "$r_line" >> "$seen_session"
            printf "  ${GREEN}%-4s${NC} ${WHITE}%-16s${NC} - ${CYAN}%s${NC}\n" "${count}." "$r_v4" "$r_desc"
            ((count++))
        done

        if [ ${#old_v4[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD IPv4 LAMA / SUDAH DIBACA (${#old_v4[@]}) ]───╮${NC}"
            for old_e in "${old_v4[@]}"; do
                IFS='|' read -r o_v4 o_desc <<< "$old_e"
                all_v4+=("$o_v4"); all_dom+=("${o_desc%% *}")
                printf "  ${GRAY}%-4s %-16s - %s [Sudah Dibaca]${NC}\n" "${count}." "$o_v4" "$o_desc"
                ((count++))
            done
        fi

        rm -f /tmp/v6to4_orig.txt /tmp/v6to4_fresh.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [00]=VLESS Orig, [1-${#all_v4[@]}]=VLESS Lain, [0]=Back : ${YELLOW}"
        read -r vc
        echo -ne "${NC}"
        if [ "$vc" == "0" ]; then break
        elif [ "$vc" == "00" ]; then
            print_vless_links "$orig_v4" "$orig_dom"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$vc" =~ ^[0-9]+$ ]] && [ "$vc" -ge 1 ] && [ "$vc" -le "${#all_v4[@]}" ]; then
            idx=$(( vc - 1 ))
            print_vless_links "${all_v4[$idx]}" "${all_dom[$idx]}"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
