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

    curl -s --max-time 7 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${target_ip}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/rev_raw.txt

    curl -s --max-time 7 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${target_ip}" 2>/dev/null \
        | grep -vE "API count|error|No DNS" >> /tmp/rev_raw.txt

    curl -s --max-time 7 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${target_ip}?full=1" 2>/dev/null \
        | grep -Eo '<td>[a-zA-Z0-9.-]+\.[a-zA-Z]{2,12}</td>' \
        | sed -E 's#</?td>##g' >> /tmp/rev_raw.txt

    curl -s --max-time 7 -A "Mozilla/5.0" "https://api.webscan.cc/?action=query&ip=${target_ip}" 2>/dev/null \
        | jq -r '.[]?.domain' 2>/dev/null >> /tmp/rev_raw.txt

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
