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

    curl -s --max-time 8 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${target_ip}/passive_dns" 2>/dev/null | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/rev_raw.txt
    curl -s --max-time 8 -A "Mozilla/5.0" "https://rapiddns.io/sameip/${target_ip}?full=1" 2>/dev/null | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' >> /tmp/rev_raw.txt
    curl -s --max-time 8 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${target_ip}" 2>/dev/null | grep -vE "API count|error|No DNS" >> /tmp/rev_raw.txt

    tr '[:upper:]' '[:lower:]' < /tmp/rev_raw.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | grep -vE "^(rapiddns\.io|www\.rapiddns\.io|cloudflare\.com|w3\.org|google\.com|gstatic\.com|googleapis\.com|bootstrap|jquery|fontawesome|jsdelivr|cdnjs)$" \
        | grep -vxF "$orig_domain" | awk '!seen[$0]++' > /tmp/rev_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/rev_seen.txt
        grep -vxFf /tmp/rev_seen.txt /tmp/rev_all_u.txt | head -n 35 > /tmp/rev_cand.txt
    else
        head -n 35 /tmp/rev_all_u.txt > /tmp/rev_cand.txt
    fi

    cat /tmp/rev_cand.txt | xargs -P 25 -I {} bash -c '
        d="{}"
        lip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        [ -n "$lip" ] && echo "${d}|${lip}"
    ' | head -n 20 > /tmp/rev_clean.txt
    rm -f /tmp/rev_raw.txt /tmp/rev_all_u.txt /tmp/rev_seen.txt /tmp/rev_cand.txt
}

menu_domainip() {
    sub_header "5. REVERSE IP TO DOMAIN (ORIGINAL HOST + LIVE DNS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address (cth: 104.18.21.212) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
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
        loading_spinner $! "Mengesan Domain Original & Live DNS pada IP $target_ip..."

        orig_host=$(cat /tmp/rev_orig.txt 2>/dev/null)
        mapfile -t fresh_doms < /tmp/rev_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL DOMAIN / HOST BAGI IP ${target_ip} ★ ]───╮${NC}"
        echo -e "${YELLOW}│${NC} ${GREEN}[00]${NC} ${WHITE}${orig_host}${NC} ${CYAN}[ ORIGINAL HOST ✔ ]${NC}"
        echo -e "${YELLOW}╰────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ DOMAIN BAHARU / FRESH (Batch #${batch_num} - ${#fresh_doms[@]} Domain) ★ ]───╮${NC}"
        all_sel=()
        count=1
        if [ ${#fresh_doms[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi domain baharu ditemui.${NC}"
        else
            for d_entry in "${fresh_doms[@]}"; do
                IFS='|' read -r dom live_ip <<< "$d_entry"
                all_sel+=("$dom")
                echo "$d_entry" >> "$seen_session"
                printf "  ${GREEN}%-4s${NC} ${WHITE}%-36s${NC} ${CYAN}[ Live IP -> %s ]${NC}\n" "${count}." "$dom" "$live_ip"
                ((count++))
            done
        fi

        if [ ${#old_doms[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DOMAIN LAMA / SUDAH DIBACA (${#old_doms[@]}) ]───╮${NC}"
            for old_e in "${old_doms[@]}"; do
                IFS='|' read -r o_dom o_lip <<< "$old_e"
                all_sel+=("$o_dom")
                printf "  ${GRAY}%-4s %-36s [ Sudah Dibaca -> %s ]${NC}\n" "${count}." "$o_dom" "$o_lip"
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
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$d_c" =~ ^[0-9]+$ ]] && [ "$d_c" -ge 1 ] && [ "$d_c" -le "${#all_sel[@]}" ]; then
            print_vless_links "$target_ip" "${all_sel[$((d_c-1))]}"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
