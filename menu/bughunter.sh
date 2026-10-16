#!/bin/bash
# ==============================================================
# MODULE 7: BUG HUNTER VERIFIED SCANNER (bughunter.sh)
# (BUG DOMAIN LIVE IP DI ATAS + BUG IP + AUTO DISCOVERY)
# ==============================================================

bughunter_worker() {
    local seen_file=$1
    > /tmp/bh_cand.txt
    > /tmp/bh_final.txt

    local golden_subnets=(
        "104.18.21" "104.18.20" "172.66.43" "172.66.40"
        "104.17.148" "104.17.147" "104.17.183" "104.18.30"
    )
    for sub in "${golden_subnets[@]}"; do
        for _ in {1..18}; do echo "${sub}.$(( (RANDOM % 254) + 1 ))" >> /tmp/bh_cand.txt; done
    done

    grep -vE "^(104\.18\.21\.212|104\.18\.20\.212|172\.66\.43\.86|104\.17\.148\.22|104\.17\.183\.120|104\.18\.30\.244)$" /tmp/bh_cand.txt | awk '!seen[$0]++' > /tmp/bh_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/bh_s.txt
        grep -vxFf /tmp/bh_s.txt /tmp/bh_u.txt | shuf -n 160 > /tmp/bh_scan.txt
    else
        shuf -n 160 /tmp/bh_u.txt > /tmp/bh_scan.txt
    fi

    verify_1003_and_vless_ws /tmp/bh_scan.txt /tmp/bh_live.txt "$DEFAULT_VLESS_HOST"
    head -n 20 /tmp/bh_live.txt | xargs -P 10 -I {} bash -c '
        ip="{}"
        dom=$(detect_original_domain_fast "$ip")
        echo "${ip}|${dom}"
    ' > /tmp/bh_final.txt
    rm -f /tmp/bh_cand.txt /tmp/bh_u.txt /tmp/bh_s.txt /tmp/bh_scan.txt /tmp/bh_live.txt
}

resolve_verified_domains_worker() {
    > /tmp/bh_dom_live.txt
    local v_domains=(
        "opensignal.com"
        "cdn.opensignal.com"
        "mcmc-my.metricelltestcloud.com"
        "onesignal.com"
        "wap.u.com.my"
    )

    for d in "${v_domains[@]}"; do
        # Semak Live IP terkini daripada Cloudflare DoH & sistem tempatan
        ips=$(curl -s --max-time 3 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${d}&type=A" 2>/dev/null \
            | jq -r '.Answer[]? | select(.type==1) | .data' 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | paste -sd ", " -)
        if [ -z "$ips" ]; then
            ips=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u | paste -sd ", " -)
        fi
        [ -z "$ips" ] && ips="Tiada Rekod A Aktif"
        echo "${d}|${ips}" >> /tmp/bh_dom_live.txt
    done
}

menu_bughunter() {
    local batch_num=1
    local seen_session="/tmp/seen_m7_$$.txt"
    > "$seen_session"

    local top_ips=("104.18.21.212" "104.18.20.212" "172.66.43.86" "104.17.148.22" "104.17.183.120" "104.18.30.244")
    local top_doms=("mcmc-my.metricelltestcloud.com" "mcmc-my.metricelltestcloud.com" "investors.shopify.com" "www.speedtest.net" "www.udemy.com" "engage.cloudflareclient.com")

    while true; do
        sub_header "7. BUG HUNTER VERIFIED + AUTO DISCOVERY (Batch #${batch_num})"

        (resolve_verified_domains_worker) &
        loading_spinner $! "Mengambil Live Latest IP bagi senarai Bug Domain..."
        mapfile -t dom_live_lines < /tmp/bh_dom_live.txt 2>/dev/null

        # 1. BAHAGIAN PALING ATAS: SENARAI BUG DOMAIN YANG BERJAYA + LIVE LATEST IP
        echo -e "${PURPLE}╭───[ ★ SENARAI BUG DOMAIN BERJAYA + LIVE LATEST IP ★ ]──────────╮${NC}"
        v_dom_names=()
        v_dom_first_ip=()
        d_idx=1
        for d_line in "${dom_live_lines[@]}"; do
            IFS='|' read -r d_name d_ips <<< "$d_line"
            v_dom_names+=("$d_name")
            first_ip=$(echo "$d_ips" | cut -d',' -f1 | xargs)
            v_dom_first_ip+=("$first_ip")
            printf "${PURPLE}│${NC} ${GREEN}[D%d]${NC} ${WHITE}%-31s${NC} ➜ ${YELLOW}%-23s${NC} ${PURPLE}│${NC}\n" "$d_idx" "$d_name" "$d_ips"
            ((d_idx++))
        done
        echo -e "${PURPLE}╰────────────────────────────────────────────────────────────────╯${NC}\n"

        # 2. BAHAGIAN KEDUA: SENARAI BUG IP ADDRESS YANG BERJAYA DIPAKAI
        echo -e "${YELLOW}╭───[ ★ SENARAI BUG IP ADDRESS YANG BERJAYA DIPAKAI ★ ]──────────╮${NC}"
        for i in "${!top_ips[@]}"; do
            printf "${YELLOW}│${NC} ${GREEN}[0%d]${NC} ${WHITE}%-16s${NC} - ${CYAN}%-38s${NC} ${YELLOW}│${NC}\n" $((i+1)) "${top_ips[$i]}" "${top_doms[$i]}"
        done
        echo -e "${YELLOW}╰────────────────────────────────────────────────────────────────╯${NC}\n"

        # 3. BAHAGIAN KETIGA: AUTO DISCOVERY IP BUG BAHARU / FRESH
        mapfile -t old_bh < "$seen_session" 2>/dev/null
        (bughunter_worker "$seen_session") &
        loading_spinner $! "Mencari IP Bug Hunter BAHARU & mengesan Domain Original..."

        mapfile -t fresh_bh < /tmp/bh_final.txt 2>/dev/null
        echo -e "${GREEN}╭───[ ★ IP BUG HUNTER BAHARU / FRESH (Batch #${batch_num} - ${#fresh_bh[@]} IP) ★ ]───╮${NC}"
        bh_ips=(); bh_doms=()
        count=1
        if [ ${#fresh_bh[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}[!] Tiada lagi IP baharu ditemui pada pusingan ini.${NC}"
        else
            for entry in "${fresh_bh[@]}"; do
                IFS='|' read -r b_ip b_dom <<< "$entry"
                bh_ips+=("$b_ip"); bh_doms+=("$b_dom")
                echo "$entry" >> "$seen_session"
                printf "  ${GREEN}%-3s${NC} ${WHITE}%-16s${NC} - ${CYAN}%s${NC} ${GREEN}[1003+WS ✔]${NC}\n" "${count}." "$b_ip" "$b_dom"
                ((count++))
            done

            {
                echo "$(TZ='Asia/Kuala_Lumpur' date +'%d %b %Y | %I:%M:%S %p MYT') | Bug Hunter Scan (Batch #${batch_num})"
                for entry in "${fresh_bh[@]}"; do
                    IFS='|' read -r b_ip b_dom <<< "$entry"
                    echo "  - ${b_ip} (${b_dom})"
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        # 4. BAHAGIAN BAWAH: REKOD LAMA / SUDAH DIBACA
        if [ ${#old_bh[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD BUG HUNTER LAMA / SUDAH DIBACA (${#old_bh[@]}) ]───╮${NC}"
            for old_e in "${old_bh[@]}"; do
                IFS='|' read -r o_ip o_dom <<< "$old_e"
                bh_ips+=("$o_ip"); bh_doms+=("$o_dom")
                printf "  ${GRAY}%-3s %-16s - %s [Sudah Dibaca]${NC}\n" "${count}." "$o_ip" "$o_dom"
                ((count++))
            done
        fi

        rm -f /tmp/bh_final.txt /tmp/bh_dom_live.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [D1-D5]=VLESS Domain, [01-06]/[1-${#bh_ips[@]}]=VLESS IP, [0]=Back : ${YELLOW}"
        read -r bc
        echo -ne "${NC}"
        if [ "$bc" == "0" ]; then
            break
        elif [[ "$bc" =~ ^[dD][1-5]$ ]]; then
            di=$(( ${bc:1:1} - 1 ))
            sel_d="${v_dom_names[$di]}"
            sel_dip="${v_dom_first_ip[$di]}"
            [[ ! "$sel_dip" =~ ^[0-9]+\. ]] && sel_dip="$sel_d"
            print_vless_links "$sel_dip" "$sel_d"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$bc" =~ ^0[1-6]$ ]]; then
            vi=$(( 10#$bc - 1 ))
            print_vless_links "${top_ips[$vi]}" "${top_doms[$vi]}"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$bc" =~ ^[0-9]+$ ]] && [ "$bc" -ge 1 ] && [ "$bc" -le "${#bh_ips[@]}" ]; then
            si=$(( bc - 1 ))
            print_vless_links "${bh_ips[$si]}" "${bh_doms[$si]}"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
