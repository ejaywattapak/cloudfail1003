#!/bin/bash
# ==============================================================
# MODULE 6: DOMAIN TO IP LOOKUP (ipdomain.sh)
# ==============================================================

ipdomain_worker() {
    local target_dom=$1
    local seen_file=$2
    > /tmp/dom_orig_ips.txt
    > /tmp/dom_orig_details.txt
    > /tmp/dom_other_raw.txt
    > /tmp/dom_other_clean.txt

    curl -s --max-time 5 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=${target_dom}&type=A" > /tmp/doh_cf.json 2>/dev/null
    jq -r '.Answer[]? | select(.type==1) | .data' /tmp/doh_cf.json 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt
    getent ahostsv4 "$target_dom" 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> /tmp/dom_orig_ips.txt

    awk '!seen[$0]++' /tmp/dom_orig_ips.txt > /tmp/dom_orig_u.txt
    mapfile -t orig_ips < /tmp/dom_orig_u.txt

    for o_ip in "${orig_ips[@]}"; do
        [ -z "$o_ip" ] && continue
        resp=$(curl -s --connect-timeout 1.5 --max-time 2.2 "http://${o_ip}" 2>/dev/null)
        if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then st="Error 1003 ✔"; else st="Direct/Active"; fi
        geo=$(curl -s --max-time 3 "http://ip-api.com/json/${o_ip}?fields=country,city,isp" 2>/dev/null)
        echo "${o_ip}|${st}|$(echo "$geo"|jq -r '.city//"Unknown"'), $(echo "$geo"|jq -r '.country//"Unknown"')|$(echo "$geo"|jq -r '.isp//"Unknown"')" >> /tmp/dom_orig_details.txt
    done

    root_dom=$(echo "$target_dom" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
    curl -s --max-time 7 "https://api.hackertarget.com/hostsearch/?q=${root_dom}" 2>/dev/null | grep -vE "API count|error|No DNS" | awk -F',' '{print $1}' >> /tmp/dom_other_raw.txt

    primary_ip="${orig_ips[0]}"
    if [ -n "$primary_ip" ]; then
        curl -s --max-time 7 -A "Mozilla/5.0" "https://api.hackertarget.com/reverseiplookup/?q=${primary_ip}" 2>/dev/null | grep -vE "API count|error|No DNS" >> /tmp/dom_other_raw.txt
        curl -s --max-time 7 -A "Mozilla/5.0" "https://otx.alienvault.com/api/v1/indicators/IPv4/${primary_ip}/passive_dns" 2>/dev/null | jq -r '.passive_dns[]?.hostname' 2>/dev/null >> /tmp/dom_other_raw.txt
    fi

    tr '[:upper:]' '[:lower:]' < /tmp/dom_other_raw.txt \
        | grep -Eo '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,12}' \
        | grep -vxF "$target_dom" | awk '!seen[$0]++' > /tmp/dom_all_u.txt

    if [ -s "$seen_file" ]; then
        awk -F'|' '{print $1}' "$seen_file" > /tmp/dom_seen.txt
        grep -vxFf /tmp/dom_seen.txt /tmp/dom_all_u.txt | head -n 35 > /tmp/dom_cand.txt
    else
        head -n 35 /tmp/dom_all_u.txt > /tmp/dom_cand.txt
    fi

    cat /tmp/dom_cand.txt | xargs -P 25 -I {} bash -c '
        d="{}"
        real_ip=$(getent ahostsv4 "$d" 2>/dev/null | awk "{print \$1}" | head -n 1)
        [ -n "$real_ip" ] && echo "${d}|${real_ip}"
    ' | head -n 20 > /tmp/dom_other_clean.txt
    rm -f /tmp/doh_cf.json /tmp/dom_orig_ips.txt /tmp/dom_orig_u.txt /tmp/dom_other_raw.txt /tmp/dom_all_u.txt /tmp/dom_seen.txt /tmp/dom_cand.txt
}

menu_ipdomain() {
    sub_header "6. DOMAIN TO IP LOOKUP (ORIGINAL IP + LIVE DNS)"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Domain (cth: sub.viu.com) atau ${YELLOW}0${WHITE} Exit : ${YELLOW}"
    read -r raw_dom
    echo -ne "${NC}"
    [ "$raw_dom" == "0" ] || [ -z "$raw_dom" ] && return

    target_dom=$(echo "$raw_dom" | sed -E 's#^https?://##; s#/.*$##' | tr '[:upper:]' '[:lower:]' | xargs)
    local seen_session="/tmp/seen_m6_$$.txt"
    > "$seen_session"
    local batch_num=1

    while true; do
        sub_header "6. DOMAIN TO IP : ${target_dom} (Batch #${batch_num})"
        mapfile -t old_dns < "$seen_session" 2>/dev/null

        (ipdomain_worker "$target_dom" "$seen_session") &
        loading_spinner $! "Mencari Original IP & menyemak Live DNS bagi ${target_dom}..."

        mapfile -t orig_ip_lines < /tmp/dom_orig_details.txt 2>/dev/null
        mapfile -t fresh_dns_lines < /tmp/dom_other_clean.txt 2>/dev/null

        echo -e "${YELLOW}╭───[ ★ ORIGINAL IP ADDRESS DIGUNAKAN OLEH: ${target_dom} ★ ]───╮${NC}"
        orig_ips_only=()
        idx=1
        for o_line in "${orig_ip_lines[@]}"; do
            IFS='|' read -r o_ip o_1003 o_loc o_isp <<< "$o_line"
            orig_ips_only+=("$o_ip")
            echo -e "${YELLOW}│${NC} ${GREEN}[0${idx}]${NC} ${WHITE}${o_ip}${NC}  ${CYAN}[ ${o_1003} | ${o_loc} | ${o_isp} ]${NC}"
            ((idx++))
        done
        echo -e "${YELLOW}╰───────────────────────────────────────────────────────────────────╯${NC}\n"

        echo -e "${GREEN}╭───[ ★ REKOD DNS BAHARU / FRESH (Batch #${batch_num} - ${#fresh_dns_lines[@]} Rekod) ★ ]───╮${NC}"
        other_ips=(); other_hosts=()
        count=1
        for d_line in "${fresh_dns_lines[@]}"; do
            IFS='|' read -r d_host d_ip <<< "$d_line"
            other_hosts+=("$d_host"); other_ips+=("$d_ip")
            echo "$d_line" >> "$seen_session"
            printf "  ${GREEN}%-4s${NC} ${WHITE}%-36s${NC} ${YELLOW}➜ %-15s${NC} ${CYAN}[Live IP]${NC}\n" "${count}." "$d_host" "$d_ip"
            ((count++))
        done

        if [ ${#old_dns[@]} -gt 0 ]; then
            echo -e "\n${GRAY}╭───[ ↺ REKOD DNS LAMA / SUDAH DIBACA (${#old_dns[@]}) ]───╮${NC}"
            for old_e in "${old_dns[@]}"; do
                IFS='|' read -r o_host o_ip <<< "$old_e"
                other_hosts+=("$o_host"); other_ips+=("$o_ip")
                printf "  ${GRAY}%-4s %-36s ➜ %-15s [Sudah Dibaca]${NC}\n" "${count}." "$o_host" "$o_ip"
                ((count++))
            done
        fi

        rm -f /tmp/dom_orig_details.txt /tmp/dom_other_clean.txt
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}[Enter]=Search More, [01]=VLESS Orig, [1-${#other_ips[@]}]=VLESS Lain, [0]=Back : ${YELLOW}"
        read -r ic
        echo -ne "${NC}"
        if [ "$ic" == "0" ]; then break
        elif [[ "$ic" =~ ^0[1-9]$ ]]; then
            o_i=$(( 10#$ic - 1 ))
            [ -n "${orig_ips_only[$o_i]}" ] && print_vless_links "${orig_ips_only[$o_i]}" "$target_dom"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        elif [[ "$ic" =~ ^[0-9]+$ ]] && [ "$ic" -ge 1 ] && [ "$ic" -le "${#other_ips[@]}" ]; then
            print_vless_links "${other_ips[$((ic-1))]}" "${other_hosts[$((ic-1))]}"
            read -rp "Tekan [Enter] untuk sambung atau taip 0 untuk keluar: " sc
            [ "$sc" == "0" ] && break
        fi
        ((batch_num++))
    done
    rm -f "$seen_session"
}
