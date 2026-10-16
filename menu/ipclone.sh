#!/bin/bash
# ==============================================================
# MODULE 1: IP CLONE SCANNER (ipclone.sh)
# ==============================================================

ipclone_worker() {
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

    for _ in {1..40}; do echo "${o1}.${o2}.${o3}.$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt; done
    for _ in {1..60}; do echo "${o1}.${o2}.$(( RANDOM % 256 )).$(( (RANDOM % 254) + 1 ))" >> /tmp/candidate_ips.txt; done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..15}; do cidr_to_random_ip "$prefix" >> /tmp/candidate_ips.txt; done
    done < <(generate_cf_prefixes)

    grep -v "^${target_ip}$" /tmp/candidate_ips.txt | awk '!seen[$0]++' > /tmp/raw_cand.txt
    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/seen_ips_only.txt
        grep -vxFf /tmp/seen_ips_only.txt /tmp/raw_cand.txt | shuf -n 260 > /tmp/unique_candidates.txt
    else
        shuf -n 260 /tmp/raw_cand.txt > /tmp/unique_candidates.txt
    fi

    verify_1003_and_vless_ws /tmp/unique_candidates.txt /tmp/live_1003_ips.txt "$DEFAULT_VLESS_HOST"

    mapfile -t valid_ips < <(head -n 160 /tmp/live_1003_ips.txt)
    [ ${#valid_ips[@]} -eq 0 ] && return

    json_payload=$(printf '%s\n' "${valid_ips[@]:0:95}" | jq -R . | jq -s .)
    curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
         -H "Content-Type: application/json" -d "$json_payload" > /tmp/batch_1003.json

    jq -r --arg c "$country" '.[] | select(.status=="success" and .country==$c) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt
    jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.zip)|\(.isp)"' /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    awk -F'|' '!seen[$1]++' /tmp/verified_matches.txt | head -n 20 > /tmp/final_matched_output.txt
    rm -f /tmp/raw_cand.txt /tmp/seen_ips_only.txt /tmp/batch_1003.json
}

menu_ipclone() {
    sub_header "1. IP CLONE SCANNER (SAME & ALT RANGE 1003)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Target (atau ${YELLOW}0${WHITE} kembali ke Menu) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"
    [ "$target_ip" == "0" ] || [ -z "$target_ip" ] && return

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP tidak sah!${NC}"; sleep 1.2; return
    fi

    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"
    (curl -s "http://ip-api.com/json/${target_ip}?fields=status,country,countryCode,regionName,city,zip" > /tmp/target_ip.json) &
    loading_spinner $! "Mengambil maklumat GeoIP bagi $target_ip..."

    country=$(jq -r '.country // "Unknown"' /tmp/target_ip.json)
    region=$(jq -r '.regionName // "Unknown"' /tmp/target_ip.json)
    city=$(jq -r '.city // "Unknown"' /tmp/target_ip.json)
    zip=$(jq -r '.zip // "N/A"' /tmp/target_ip.json)
    rm -f /tmp/target_ip.json

    local seen_session="/tmp/seen_m1_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "1. IP CLONE : ${target_ip} (${city}, ${country} | Batch #${batch_num})"
        mapfile -t old_lines < "$seen_session" 2>/dev/null

        (ipclone_worker "$target_ip" "$country" "$region" "$city" "$zip" "$seen_session") &
        loading_spinner $! "Mengimbas 20 IP Error 1003 + VLESS WS BAHARU..."

        mapfile -t fresh_lines < /tmp/final_matched_output.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ HASIL BAHARU / FRESH (Batch #${batch_num} - ${#fresh_lines[@]} IP) ★ ]───╮${NC}"
        all_sel=()
        count=1
        if [ ${#fresh_lines[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi IP baharu ditemui.${NC}"
        else
            for entry in "${fresh_lines[@]}"; do
                IFS='|' read -r f_ip f_city f_zip f_isp <<< "$entry"
                all_sel+=("$f_ip")
                echo "$entry" >> "$seen_session"
                if [[ "$f_ip" == "${o1}.${o2}."* ]]; then r_tag="SAME-RANGE"; else r_tag="ALT-RANGE "; fi
                printf "  ${GREEN}%-3s %-16s [ %s | 1003+WS ✔ | %s | Zip:%s ]${NC}\n" "${count}." "$f_ip" "$r_tag" "$f_city" "${f_zip:-N/A}"
                ((count++))
            done
            {
                echo "$(LC_TIME=C date +"%Y-%m-%d %H:%M") | IP Clone: $target_ip (Batch #${batch_num})"
                for entry in "${fresh_lines[@]}"; do echo "  - ${entry%%|*}"; done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_lines[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD LAMA / SUDAH DIBACA (${#old_lines[@]} IP) ]───╮${NC}"
            for old_e in "${old_lines[@]}"; do
                IFS='|' read -r o_ip o_city o_zip _ <<< "$old_e"
                all_sel+=("$o_ip")
                printf "  ${GRAY}%-3s %-16s [ Sudah Dibaca | %s | Zip:%s ]${NC}\n" "${count}." "$o_ip" "$o_city" "${o_zip:-N/A}"
                ((count++))
            done
        fi

        rm -f /tmp/candidate_ips.txt /tmp/unique_candidates.txt /tmp/live_1003_ips.txt /tmp/verified_matches.txt /tmp/final_matched_output.txt

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
