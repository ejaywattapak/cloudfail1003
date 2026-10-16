#!/bin/bash
# ==============================================================
# MODULE 2: TWIN IP SCANNER (twinip.sh)
# ==============================================================

twinip_worker() {
    local target_ip=$1
    local country=$2
    local seen_file=$3
    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"

    > /tmp/twin_candidates.txt
    > /tmp/twin_final_output.txt

    for _ in {1..28}; do
        b3=$(( RANDOM % 254 ))
        b4=$(( (RANDOM % 254) + 1 ))
        echo "${o1}.${o2}.${b3}.${b4}|${o1}.${o2}.$((b3+1)).${b4}" >> /tmp/twin_candidates.txt
    done

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..12}; do
            base_ip=$(cidr_to_random_ip "$prefix")
            IFS='.' read -r b1 b2 b3 b4 <<< "$base_ip"
            twin_b3=$(( b3 > 0 ? b3 - 1 : b3 + 1 ))
            echo "${b1}.${b2}.${b3}.${b4}|${b1}.${b2}.${twin_b3}.${b4}" >> /tmp/twin_candidates.txt
        done
    done < <(generate_cf_prefixes)

    awk '!seen[$0]++' /tmp/twin_candidates.txt > /tmp/twin_raw_u.txt
    if [ -s "$seen_file" ]; then
        awk -F' / ' '{print $1}' "$seen_file" > /tmp/seen_t1.txt
        grep -vFf /tmp/seen_t1.txt /tmp/twin_raw_u.txt | shuf -n 90 > /tmp/twin_unique.txt
    else
        shuf -n 90 /tmp/twin_raw_u.txt > /tmp/twin_unique.txt
    fi

    cat /tmp/twin_unique.txt | xargs -P 45 -I {} bash -c '
        pair="{}"
        ip1="${pair%|*}"; ip2="${pair#*|}"
        r1=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 "http://${ip1}" 2>/dev/null)
        if echo "$r1" | grep -Eqi "1003|Direct IP access not allowed"; then
            r2=$(curl -s --connect-timeout 1.2 --max-time 2.0 --max-filesize 65536 "http://${ip2}" 2>/dev/null)
            if echo "$r2" | grep -Eqi "1003|Direct IP access not allowed"; then
                echo "${ip1} / ${ip2}|Cloudflare Twin 1003+WS ✔"
            fi
        fi
    ' | head -n 20 > /tmp/twin_final_output.txt
    rm -f /tmp/twin_candidates.txt /tmp/twin_raw_u.txt /tmp/seen_t1.txt /tmp/twin_unique.txt
}

menu_twinip() {
    sub_header "2. TWIN IP SCANNER (PASANGAN IP KEMBAR 1003)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Target (atau ${YELLOW}0${WHITE} kembali ke Menu) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"
    [ "$target_ip" == "0" ] || [ -z "$target_ip" ] && return

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP tidak sah!${NC}"; sleep 1.2; return
    fi

    local seen_session="/tmp/seen_m2_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "2. TWIN IP SCANNER : ${target_ip} (Batch #${batch_num})"
        mapfile -t old_twins < "$seen_session" 2>/dev/null

        (twinip_worker "$target_ip" "Global" "$seen_session") &
        loading_spinner $! "Mencari 20 Pasangan Twin IP BAHARU..."

        mapfile -t fresh_twins < /tmp/twin_final_output.txt 2>/dev/null

        echo -e "${GREEN}╭───[ ★ PASANGAN TWIN IP BAHARU / FRESH (Batch #${batch_num} - ${#fresh_twins[@]}) ★ ]───╮${NC}"
        all_sel=()
        count=1
        if [ ${#fresh_twins[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi pasangan baharu ditemui.${NC}"
        else
            for entry in "${fresh_twins[@]}"; do
                IFS='|' read -r t_pair t_info <<< "$entry"
                all_sel+=("$t_pair")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s %-35s [ %s ]${NC}\n" "${count}." "$t_pair" "$t_info"
                ((count++))
            done
            {
                echo "$(LC_TIME=C date +"%Y-%m-%d %H:%M") | Twin IP: $target_ip (Batch #${batch_num})"
                for entry in "${fresh_twins[@]}"; do echo "  - ${entry%%|*}"; done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        if [ ${#old_twins[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD TWIN LAMA / SUDAH DIBACA (${#old_twins[@]}) ]───╮${NC}"
            for old_e in "${old_twins[@]}"; do
                IFS='|' read -r o_pair _ <<< "$old_e"
                all_sel+=("$o_pair")
                printf "  ${GRAY}%-3s %-35s [ Sudah Dibaca ]${NC}\n" "${count}." "$o_pair"
                ((count++))
            done
        fi

        rm -f /tmp/twin_final_output.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [1-${#all_sel[@]}]=Jana VLESS, [0]=Back to Menu : ${YELLOW}"
        read -r c_loop
        echo -ne "${NC}"
        if [ "$c_loop" == "0" ]; then break
        elif [[ "$c_loop" =~ ^[0-9]+$ ]] && [ "$c_loop" -ge 1 ] && [ "$c_loop" -le "${#all_sel[@]}" ]; then
            raw_p="${all_sel[$((c_loop-1))]}"
            print_vless_links "${raw_p%% *}" "$DEFAULT_VLESS_HOST"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
