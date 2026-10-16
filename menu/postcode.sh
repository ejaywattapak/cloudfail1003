#!/bin/bash
# ==============================================================
# MODULE 4: POSTCODE IP SCANNER (postcode.sh)
# ==============================================================

menu_postcode() {
    sub_header "4. POSTCODE IP SCANNER (1003 + VLESS WS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Poskod / Zipcode (cth: 75001) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r query_zip
    echo -ne "${NC}"
    [ "$query_zip" == "0" ] || [ -z "$query_zip" ] && return

    clean_z=$(echo "$query_zip" | xargs)
    local seen_session="/tmp/seen_m4_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "4. POSTCODE SCAN : ${clean_z} (Batch #${batch_num})"
        mapfile -t old_zips < "$seen_session" 2>/dev/null

        > /tmp/zip_cand.txt
        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do cidr_to_random_ip "$prefix" >> /tmp/zip_cand.txt; done
        done < <(generate_cf_prefixes)

        awk '!seen[$0]++' /tmp/zip_cand.txt > /tmp/zip_u.txt
        if [ -s "$seen_session" ]; then
            awk -F'|' '{print $1}' "$seen_session" > /tmp/zip_seen.txt
            grep -vxFf /tmp/zip_seen.txt /tmp/zip_u.txt | shuf -n 240 > /tmp/zip_scan.txt
        else
            shuf -n 240 /tmp/zip_u.txt > /tmp/zip_scan.txt
        fi

        (verify_1003_and_vless_ws /tmp/zip_scan.txt /tmp/zip_live.txt "$DEFAULT_VLESS_HOST") &
        loading_spinner $! "Mengimbas IP Error 1003 BAHARU untuk poskod '${clean_z}'..."

        mapfile -t live_ips < <(head -n 95 /tmp/zip_live.txt)
        fresh_zips=()
        if [ ${#live_ips[@]} -gt 0 ]; then
            json_payload=$(printf '%s\n' "${live_ips[@]}" | jq -R . | jq -s .)
            curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,city,zip,query" \
                 -H "Content-Type: application/json" -d "$json_payload" > /tmp/batch_zip.json

            jq -r --arg z "$clean_z" '.[] | select(.status=="success" and (.zip|tostring|ascii_downcase|contains($z|ascii_downcase))) | "\(.query)|\(.zip)|\(.city), \(.country)"' /tmp/batch_zip.json 2>/dev/null > /tmp/zip_m.txt
            jq -r '.[] | select(.status=="success") | "\(.query)|\(.zip)|\(.city), \(.country)"' /tmp/batch_zip.json 2>/dev/null >> /tmp/zip_m.txt
            awk -F'|' '!seen[$1]++' /tmp/zip_m.txt | head -n 20 > /tmp/zip_clean.txt
            mapfile -t fresh_zips < /tmp/zip_clean.txt
        fi

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH POSKOD '${clean_z}' (Batch #${batch_num} - ${#fresh_zips[@]} IP) ★ ]───╮${NC}"
        all_sel=()
        count=1
        for entry in "${fresh_zips[@]}"; do
            IFS='|' read -r f_ip f_zip f_loc <<< "$entry"
            all_sel+=("$f_ip")
            echo "$entry" >> "$seen_session"
            printf "  ${GREEN}%-3s %-16s [ 1003+WS ✔ | Zip:%s | %s ]${NC}\n" "${count}." "$f_ip" "${f_zip:-N/A}" "$f_loc"
            ((count++))
        done

        if [ ${#old_zips[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_zips[@]} IP) ]───╮${NC}"
            for old_e in "${old_zips[@]}"; do
                IFS='|' read -r o_ip o_zip o_loc <<< "$old_e"
                all_sel+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | Zip:%s | %s ]${NC}\n" "${count}." "$o_ip" "${o_zip:-N/A}" "$o_loc"
                ((count++))
            done
        fi

        rm -f /tmp/zip_*.txt /tmp/batch_zip.json
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
