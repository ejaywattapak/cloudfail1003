#!/bin/bash
# ==============================================================
# MODULE 3: COUNTRY & CITY SCANNER (country.sh)
# ==============================================================

menu_country() {
    sub_header "3. COUNTRY & CITY IP SCANNER (1003 + VLESS WS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Negara / Bandar (cth: Singapore, Japan) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r query_loc
    echo -ne "${NC}"
    [ "$query_loc" == "0" ] || [ -z "$query_loc" ] && return

    clean_q=$(echo "$query_loc" | xargs)
    local seen_session="/tmp/seen_m3_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "3. COUNTRY SCAN : ${clean_q} (Batch #${batch_num})"
        mapfile -t old_locs < "$seen_session" 2>/dev/null

        > /tmp/loc_cand.txt
        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do cidr_to_random_ip "$prefix" >> /tmp/loc_cand.txt; done
        done < <(generate_cf_prefixes)

        awk '!seen[$0]++' /tmp/loc_cand.txt > /tmp/loc_u.txt
        if [ -s "$seen_session" ]; then
            awk -F'|' '{print $1}' "$seen_session" > /tmp/loc_seen.txt
            grep -vxFf /tmp/loc_seen.txt /tmp/loc_u.txt | shuf -n 240 > /tmp/loc_scan.txt
        else
            shuf -n 240 /tmp/loc_u.txt > /tmp/loc_scan.txt
        fi

        (verify_1003_and_vless_ws /tmp/loc_scan.txt /tmp/loc_live.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas IP Error 1003 BAHARU untuk lokasi '${clean_q}'..."

        mapfile -t live_ips < <(head -n 95 /tmp/loc_live.txt)
        fresh_locs=()
        if [ ${#live_ips[@]} -gt 0 ]; then
            json_payload=$(printf '%s\n' "${live_ips[@]}" | jq -R . | jq -s .)
            curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,query" \
                 -H "Content-Type: application/json" -d "$json_payload" > /tmp/batch_loc.json

            jq -r --arg q "$clean_q" '.[] | select(.status=="success" and ((.country|ascii_downcase|contains($q|ascii_downcase)) or (.city|ascii_downcase|contains($q|ascii_downcase)))) | "\(.query)|\(.city), \(.country)|\(.zip)"' /tmp/batch_loc.json 2>/dev/null > /tmp/loc_m.txt
            jq -r '.[] | select(.status=="success") | "\(.query)|\(.city), \(.country)|\(.zip)"' /tmp/batch_loc.json 2>/dev/null >> /tmp/loc_m.txt
            awk -F'|' '!seen[$1]++' /tmp/loc_m.txt | head -n 20 > /tmp/loc_clean.txt
            mapfile -t fresh_locs < /tmp/loc_clean.txt
        fi

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH '${clean_q}' (Batch #${batch_num} - ${#fresh_locs[@]} IP) ★ ]───╮${NC}"
        all_sel=()
        count=1
        for entry in "${fresh_locs[@]}"; do
            IFS='|' read -r f_ip f_loc f_zip <<< "$entry"
            all_sel+=("$f_ip")
            echo "$entry" >> "$seen_session"
            printf "  ${GREEN}%-3s %-16s [ 1003+WS ✔ | %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$f_loc" "${f_zip:-N/A}"
            ((count++))
        done

        if [ ${#old_locs[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_locs[@]} IP) ]───╮${NC}"
            for old_e in "${old_locs[@]}"; do
                IFS='|' read -r o_ip o_loc o_zip <<< "$old_e"
                all_sel+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | %s ]${NC}\n" "${count}." "$o_ip" "$o_loc"
                ((count++))
            done
        fi

        rm -f /tmp/loc_*.txt /tmp/batch_loc.json
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [1-${#all_sel[@]}]=Jana VLESS, [0]=Back to Menu : ${YELLOW}"
        read -r c_loop
        echo -ne "${NC}"
        if [ "$c_loop" == "0" ]; then break
        elif [[ "$c_loop" =~ ^[0-9]+$ ]] && [ "$c_loop" -ge 1 ] && [ "$c_loop" -le "${#all_sel[@]}" ]; then
            print_vless_links "${all_sel[$((c_loop-1))]}" "$DEFAULT_VLESS_HOST"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
