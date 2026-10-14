#!/bin/bash
# ==============================================================
# EJAYWATT CLOUDFAIL - CORE ENGINE v6.0 (TWIN IP + ANTI-PREFIX)
# Repo: https://github.com/ejaywattapak/cloudfail1003
# ==============================================================

HISTORY_FILE="$HOME/.ip_cloner_history.log"

loading_spinner() {
    local pid=$1
    local text=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}[%s]${NC} ${WHITE}%s${NC}" "${spin:$i:1}" "$text"
        sleep 0.1
    done
    printf "\r\033[K"
}

cidr_to_random_ip() {
    local cidr=$1
    local ip="${cidr%/*}"
    local mask="${cidr#*/}"
    IFS='.' read -r a b c d <<< "$ip"

    if [[ ! "$mask" =~ ^[0-9]+$ ]] || [ "$mask" -lt 8 ] || [ "$mask" -gt 30 ]; then
        mask=24
    fi

    if [ "$mask" -ge 24 ]; then
        echo "${a}.${b}.${c}.$(( (RANDOM % 254) + 1 ))"
    elif [ "$mask" -ge 16 ]; then
        local span=$(( 1 << (24 - mask) ))
        local new_c=$(( (c + (RANDOM % span)) % 256 ))
        echo "${a}.${b}.${new_c}.$(( (RANDOM % 254) + 1 ))"
    else
        local span=$(( 1 << (16 - mask) ))
        local new_b=$(( (b + (RANDOM % span)) % 256 ))
        local new_c=$(( RANDOM % 256 ))
        echo "${a}.${new_b}.${new_c}.$(( (RANDOM % 254) + 1 ))"
    fi
}

# --- WORKER MENU 1: CLONE SINGLE IP (ELAK PREFIX SAMA) ---
search_error_1003_worker() {
    local target_ip=$1
    local country=$2
    local region=$3
    local city=$4
    local zip=$5
    local isp=$6
    local asn_raw=$7

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"
    local target_prefix="${o1}.${o2}."

    > /tmp/candidate_prefixes.txt
    > /tmp/candidate_ips.txt
    > /tmp/live_1003_ips.txt
    > /tmp/verified_matches.txt
    > /tmp/final_matched_output.txt

    cat << 'PREFIXES' > /tmp/candidate_prefixes.txt
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
108.162.192.0/18
131.0.72.0/22
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
172.68.0.0/14
172.70.0.0/15
172.71.0.0/16
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
197.234.240.0/22
198.41.128.0/17
104.16.0.0/13
104.24.0.0/14
PREFIXES

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        if [[ "$prefix" == "${target_prefix}"* ]]; then
            continue
        fi
        for _ in {1..18}; do
            cidr_to_random_ip "$prefix" >> /tmp/candidate_ips.txt
        done
    done < /tmp/candidate_prefixes.txt

    grep -v "^${o1}\.${o2}\." /tmp/candidate_ips.txt | awk '!seen[$0]++' | shuf -n 260 > /tmp/unique_candidates.txt

    cat /tmp/unique_candidates.txt | xargs -P 50 -I {} bash -c '
        ip="{}"
        resp=$(curl -s --connect-timeout 1.2 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip}" 2>/dev/null)
        if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
            echo "$ip"
        fi
    ' > /tmp/live_1003_ips.txt

    mapfile -t valid_ips < <(head -n 180 /tmp/live_1003_ips.txt)
    [ ${#valid_ips[@]} -eq 0 ] && return

    rm -f /tmp/batch_1003_*.json
    for round in 1 2; do
        start_idx=$(( (round - 1) * 90 ))
        batch_slice=("${valid_ips[@]:start_idx:90}")
        [ ${#batch_slice[@]} -eq 0 ] && break

        json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
        curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
             -H "Content-Type: application/json" \
             -d "$json_payload" > "/tmp/batch_1003_${round}.json"
    done

    jq -s 'add' /tmp/batch_1003_*.json > /tmp/batch_1003.json 2>/dev/null

    jq -r --arg c "$country" --arg ct "$city" --arg z "$zip" \
        '.[] | select(.status=="success" and .country==$c and .city==$ct and .zip==$z) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r --arg c "$country" --arg ct "$city" \
        '.[] | select(.status=="success" and .country==$c and .city==$ct) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r --arg c "$country" \
        '.[] | select(.status=="success" and .country==$c) | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.zip)|\(.isp)"' \
        /tmp/batch_1003.json 2>/dev/null >> /tmp/verified_matches.txt

    awk -F'|' '!seen[$1]++' /tmp/verified_matches.txt | head -n 20 > /tmp/final_matched_output.txt
}

# --- WORKER MENU 2: CLONE TWIN IP (PASANGAN KEMBAR + ELAK PREFIX SAMA) ---
search_twin_1003_worker() {
    local target_ip=$1
    local country=$2
    local city=$3
    local zip=$4

    IFS='.' read -r o1 o2 o3 o4 <<< "$target_ip"

    > /tmp/twin_candidates.txt
    > /tmp/twin_live_pairs.txt
    > /tmp/twin_final_output.txt

    cat << 'PREFIXES' > /tmp/twin_prefixes.txt
108.162.192.0/18
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
172.68.0.0/14
172.70.0.0/15
172.71.0.0/16
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
198.41.128.0/17
104.16.0.0/13
104.24.0.0/14
PREFIXES

    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        for _ in {1..14}; do
            base_ip=$(cidr_to_random_ip "$prefix")
            IFS='.' read -r b1 b2 b3 b4 <<< "$base_ip"
            if [ "$b1" == "$o1" ] && [ "$b2" == "$o2" ]; then
                continue
            fi
            if [ "$b3" -gt 0 ]; then
                twin_b3=$(( b3 - 1 ))
            else
                twin_b3=$(( b3 + 1 ))
            fi
            ip1="${b1}.${b2}.${b3}.${b4}"
            ip2="${b1}.${b2}.${twin_b3}.${b4}"
            echo "${ip1}|${ip2}" >> /tmp/twin_candidates.txt
        done
    done < /tmp/twin_prefixes.txt

    awk '!seen[$0]++' /tmp/twin_candidates.txt | shuf -n 90 > /tmp/twin_unique.txt

    cat /tmp/twin_unique.txt | xargs -P 45 -I {} bash -c '
        pair="{}"
        ip1="${pair%|*}"
        ip2="${pair#*|}"
        r1=$(curl -s --connect-timeout 1.2 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip1}" 2>/dev/null)
        if echo "$r1" | grep -Eqi "1003|Direct IP access not allowed"; then
            r2=$(curl -s --connect-timeout 1.2 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip2}" 2>/dev/null)
            if echo "$r2" | grep -Eqi "1003|Direct IP access not allowed"; then
                echo "${ip1}|${ip2}"
            fi
        fi
    ' > /tmp/twin_live_pairs.txt

    mapfile -t live_pairs < <(head -n 40 /tmp/twin_live_pairs.txt)
    [ ${#live_pairs[@]} -eq 0 ] && return

    first_ips=()
    for p in "${live_pairs[@]}"; do
        first_ips+=("${p%|*}")
    done

    json_payload=$(printf '%s\n' "${first_ips[@]}" | jq -R . | jq -s .)
    curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,city,zip,isp,query" \
         -H "Content-Type: application/json" \
         -d "$json_payload" > /tmp/twin_batch.json

    > /tmp/twin_verified.txt
    for p in "${live_pairs[@]}"; do
        ip1="${p%|*}"
        ip2="${p#*|}"
        info=$(jq -r --arg q "$ip1" '.[] | select(.query==$q and .status=="success") | "\(.country)|\(.city)|\(.zip)|\(.isp)"' /tmp/twin_batch.json 2>/dev/null | head -n 1)
        if [ -n "$info" ]; then
            echo "${ip1} / ${ip2}|${info}" >> /tmp/twin_verified.txt
        fi
    done

    grep "|${country}|" /tmp/twin_verified.txt > /tmp/twin_final_output.txt 2>/dev/null
    cat /tmp/twin_verified.txt >> /tmp/twin_final_output.txt 2>/dev/null

    awk -F'|' '!seen[$1]++' /tmp/twin_final_output.txt | head -n 20 > /tmp/twin_clean.txt
    mv /tmp/twin_clean.txt /tmp/twin_final_output.txt
}

# --- MENU 1: CLONE IP (20 IPs + ELAK PREFIX SAMA + AUTO REPEAT) ---
clone_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 1. CLONE IP ADDRESS (ERROR 1003 - 20 IPs) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address Target (atau ${YELLOW}0${WHITE} untuk Exit) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"

    if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
        return
    fi

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
        sleep 1.5
        return
    fi

    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"

    echo ""
    (curl -s "http://ip-api.com/json/${target_ip}?fields=status,message,country,countryCode,regionName,city,zip,isp,org,as,query" > /tmp/target_ip.json) &
    loading_spinner $! "Mengambil butiran lokasi & poskod bagi $target_ip..."

    status=$(jq -r '.status' /tmp/target_ip.json 2>/dev/null)
    if [ "$status" != "success" ]; then
        msg=$(jq -r '.message' /tmp/target_ip.json 2>/dev/null)
        echo -e "${RED}[✘] Gagal mendapatkan maklumat IP (${msg:-Ralat Rangkaian}).${NC}"
        sleep 2
        return
    fi

    country=$(jq -r '.country' /tmp/target_ip.json)
    country_code=$(jq -r '.countryCode' /tmp/target_ip.json)
    region=$(jq -r '.regionName' /tmp/target_ip.json)
    city=$(jq -r '.city' /tmp/target_ip.json)
    zip=$(jq -r '.zip' /tmp/target_ip.json)
    isp=$(jq -r '.isp' /tmp/target_ip.json)
    asn=$(jq -r '.as' /tmp/target_ip.json)
    rm -f /tmp/target_ip.json

    local batch_num=1
    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Filter     :${NC} ${GREEN}Auto-Skip kepala ${o1}.${o2}.x.x ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Negara     :${NC} ${CYAN}${country} (${country_code})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Bandar     :${NC} ${CYAN}${city} (${region})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Postcode   :${NC} ${CYAN}${zip:-Tiada Data}${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        (search_error_1003_worker "$target_ip" "$country" "$region" "$city" "$zip" "$isp" "$asn") &
        loading_spinner $! "Mengimbas 20 IP Error 1003 (selain ${o1}.${o2}.x.x)..."

        mapfile -t matched_lines < /tmp/final_matched_output.txt 2>/dev/null

        echo -e "${GREEN}[✔] Selesai! Senarai 20 IP Error 1003 untuk ${YELLOW}${target_ip}${GREEN}:${NC}\n"

        if [ ${#matched_lines[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif ditemui pada pusingan ini. Tekan Enter untuk cuba lagi.${NC}"
        else
            count=1
            found_ips=()
            for entry in "${matched_lines[@]}"; do
                IFS='|' read -r f_ip f_city f_zip f_isp <<< "$entry"
                found_ips+=("$f_ip")
                printf "${GREEN}%-3s %-16s [ Error 1003 ✔ | %s | Postcode: %s | %s ]${NC}\n" "${count}." "$f_ip" "$f_city" "${f_zip:-N/A}" "$f_isp"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Clone IP - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for f_ip in "${found_ips[@]}"; do
                    echo "${c}. ${f_ip}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/candidate_*.txt /tmp/unique_candidates.txt \
              /tmp/live_1003_ips.txt /tmp/batch_1003*.json /tmp/verified_matches.txt \
              /tmp/final_matched_output.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi (${YELLOW}${target_ip}${WHITE}), atau taip ${RED}[0]${WHITE} untuk Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        fi
        ((batch_num++))
    done
}

# --- MENU 2: CLONE TWIN IP (PASANGAN IP KEMBAR + ELAK PREFIX SAMA) ---
clone_twin_ip() {
    show_banner
    echo -e "${CYAN}╭─[ 2. CLONE TWIN IP (PASANGAN IP KEMBAR ERROR 1003) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan IP Address Target (atau ${YELLOW}0${WHITE} untuk Exit) : ${YELLOW}"
    read -r target_ip
    echo -ne "${NC}"

    if [ "$target_ip" == "0" ] || [ -z "$target_ip" ]; then
        return
    fi

    if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\n${RED}[✘] Format IP Address tidak sah!${NC}"
        sleep 1.5
        return
    fi

    IFS='.' read -r o1 o2 _ _ <<< "$target_ip"

    echo ""
    (curl -s "http://ip-api.com/json/${target_ip}?fields=status,message,country,countryCode,regionName,city,zip,isp,query" > /tmp/target_twin.json) &
    loading_spinner $! "Mengambil butiran lokasi bagi $target_ip..."

    status=$(jq -r '.status' /tmp/target_twin.json 2>/dev/null)
    if [ "$status" != "success" ]; then
        echo -e "${RED}[✘] Gagal mendapatkan maklumat IP.${NC}"
        sleep 2
        return
    fi

    country=$(jq -r '.country' /tmp/target_twin.json)
    country_code=$(jq -r '.countryCode' /tmp/target_twin.json)
    region=$(jq -r '.regionName' /tmp/target_twin.json)
    city=$(jq -r '.city' /tmp/target_twin.json)
    zip=$(jq -r '.zip' /tmp/target_twin.json)
    rm -f /tmp/target_twin.json

    local batch_num=1
    while true; do
        show_banner
        echo -e "${BLUE}╭──────────────────────────────────────────────────╮${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}IP Target  :${NC} ${YELLOW}${target_ip} ${GRAY}(Twin Mode - Batch #${batch_num})${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Filter     :${NC} ${GREEN}Auto-Skip kepala ${o1}.${o2}.x.x ✔${NC}"
        echo -e "${BLUE}│${NC} ${WHITE}Lokasi     :${NC} ${CYAN}${city}, ${region}, ${country} (${country_code})${NC}"
        echo -e "${BLUE}╰──────────────────────────────────────────────────╯${NC}"
        echo ""

        (search_twin_1003_worker "$target_ip" "$country" "$city" "$zip") &
        loading_spinner $! "Mencari 20 Pasangan Twin IP Error 1003 (selain ${o1}.${o2}.x.x)..."

        mapfile -t twin_lines < /tmp/twin_final_output.txt 2>/dev/null

        echo -e "${GREEN}[✔] Selesai! Senarai Pasangan Twin IP Error 1003 untuk ${YELLOW}${target_ip}${GREEN}:${NC}\n"

        if [ ${#twin_lines[@]} -eq 0 ]; then
            echo -e "${RED}Tiada pasangan Twin IP aktif ditemui pada pusingan ini. Tekan Enter untuk cuba lagi.${NC}"
        else
            count=1
            found_twins=()
            for entry in "${twin_lines[@]}"; do
                IFS='|' read -r t_pair t_cnt t_city t_zip t_isp <<< "$entry"
                found_twins+=("$t_pair")
                printf "${GREEN}%-3s %-35s [ 1003 ✔ | %s, %s | Zip: %s ]${NC}\n" "${count}." "$t_pair" "$t_city" "$t_cnt" "${t_zip:-N/A}"
                ((count++))
            done

            current_date=$(LC_TIME=C date +"%A %dth %B %Y")
            {
                echo "$current_date"
                echo "Ip Target : $target_ip (Twin IP Mode - Batch #${batch_num})"
                echo "Ip Address Found :"
                c=1
                for t_p in "${found_twins[@]}"; do
                    echo "${c}. ${t_p}"
                    ((c++))
                done
                echo "--------------------------------------------------"
            } >> "$HISTORY_FILE"
        fi

        rm -f /tmp/twin_*.txt /tmp/twin_batch.json

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk cari Twin IP lagi (${YELLOW}${target_ip}${WHITE}), atau taip ${RED}[0]${WHITE} untuk Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        fi
        ((batch_num++))
    done
}

# --- MENU 4: SEARCH BY COUNTRY / REGION / CITY (20 IP + AUTO REPEAT) ---
search_by_location() {
    show_banner
    echo -e "${CYAN}╭─[ 4. SEARCH BY COUNTRY / REGION / CITY (20 IPs) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Lokasi (cth: France, Tokyo, USA) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_loc
    echo -ne "${NC}"

    if [ "$query_loc" == "0" ] || [ -z "$query_loc" ]; then
        return
    fi

    clean_q=$(echo "$query_loc" | xargs)
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 4. SEARCH BY LOCATION : ${YELLOW}${clean_q}${CYAN} (Batch #${batch_num}) ]${NC}\n"

        > /tmp/loc_candidate_ips.txt
        > /tmp/loc_live_1003.txt

        cat << 'PREFIXES' > /tmp/loc_prefixes.txt
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
108.162.192.0/18
131.0.72.0/22
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
172.68.0.0/14
172.70.0.0/15
172.71.0.0/16
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
197.234.240.0/22
198.41.128.0/17
104.16.0.0/13
104.24.0.0/14
PREFIXES

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do
                cidr_to_random_ip "$prefix" >> /tmp/loc_candidate_ips.txt
            done
        done < /tmp/loc_prefixes.txt

        shuf -n 260 /tmp/loc_candidate_ips.txt > /tmp/loc_unique.txt

        (
            cat /tmp/loc_unique.txt | xargs -P 50 -I {} bash -c '
                ip="{}"
                resp=$(curl -s --connect-timeout 1.2 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip}" 2>/dev/null)
                if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
                    echo "$ip"
                fi
            ' > /tmp/loc_live_1003.txt
        ) &
        loading_spinner $! "Mengimbas 20 IP Error 1003 untuk lokasi '${clean_q}'..."

        mapfile -t live_ips < <(head -n 180 /tmp/loc_live_1003.txt)
        if [ ${#live_ips[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif dijumpai.${NC}"
        else
            rm -f /tmp/batch_loc_*.json
            for round in 1 2; do
                start_idx=$(( (round - 1) * 90 ))
                batch_slice=("${live_ips[@]:start_idx:90}")
                [ ${#batch_slice[@]} -eq 0 ] && break

                json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
                curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
                     -H "Content-Type: application/json" \
                     -d "$json_payload" > "/tmp/batch_loc_${round}.json"
            done

            jq -s 'add' /tmp/batch_loc_*.json > /tmp/all_batch_loc.json 2>/dev/null

            jq -r --arg q "$clean_q" \
                '.[] | select(.status=="success" and (
                    (.country | ascii_downcase | contains($q | ascii_downcase)) or
                    (.regionName | ascii_downcase | contains($q | ascii_downcase)) or
                    (.city | ascii_downcase | contains($q | ascii_downcase))
                )) | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_loc.json 2>/dev/null > /tmp/final_loc_matched.txt

            jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_loc.json 2>/dev/null >> /tmp/final_loc_matched.txt

            awk -F'|' '!seen[$1]++' /tmp/final_loc_matched.txt | head -n 20 > /tmp/final_loc_clean.txt
            mapfile -t matched_locs < /tmp/final_loc_clean.txt

            echo -e "${GREEN}[✔] Carian Selesai! 20 IP Error 1003 untuk '${YELLOW}${clean_q}${GREEN}':${NC}\n"

            if [ ${#matched_locs[@]} -eq 0 ]; then
                echo -e "${RED}Tiada IP sepadan dijumpai untuk '${clean_q}'.${NC}"
            else
                count=1
                found_ips=()
                for entry in "${matched_locs[@]}"; do
                    IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                    found_ips+=("$f_ip")
                    printf "${GREEN}%-3s %-16s [ Error 1003 ✔ | %s, %s, %s | Postcode: %s | %s ]${NC}\n" "${count}." "$f_ip" "$f_city" "$f_reg" "$f_cnt" "${f_zip:-N/A}" "$f_isp"
                    ((count++))
                done

                current_date=$(LC_TIME=C date +"%A %dth %B %Y")
                {
                    echo "$current_date"
                    echo "Search Location : $clean_q (Batch #${batch_num})"
                    echo "Ip Address Found :"
                    c=1
                    for f_ip in "${found_ips[@]}"; do
                        echo "${c}. ${f_ip}"
                        ((c++))
                    done
                    echo "--------------------------------------------------"
                } >> "$HISTORY_FILE"
            fi
        fi

        rm -f /tmp/loc_*.txt /tmp/batch_loc_*.json /tmp/all_batch_loc.json /tmp/final_loc_*.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi (${YELLOW}${clean_q}${WHITE}), atau taip ${RED}[0]${WHITE} untuk Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        fi
        ((batch_num++))
    done
}

# --- MENU 5: SEARCH BY POSTCODE (20 IP + AUTO REPEAT) ---
search_by_postcode() {
    show_banner
    echo -e "${CYAN}╭─[ 5. SEARCH BY POSTCODE (20 IPs) ]${NC}"
    echo -ne "${CYAN}╰─➤${NC} ${WHITE}Masukkan Postcode / Zipcode (cth: 75001, M5V) atau ${YELLOW}0${WHITE} untuk Exit : ${YELLOW}"
    read -r query_zip
    echo -ne "${NC}"

    if [ "$query_zip" == "0" ] || [ -z "$query_zip" ]; then
        return
    fi

    clean_z=$(echo "$query_zip" | xargs)
    local batch_num=1

    while true; do
        show_banner
        echo -e "${CYAN}╭─[ 5. SEARCH BY POSTCODE : ${YELLOW}${clean_z}${CYAN} (Batch #${batch_num}) ]${NC}\n"

        > /tmp/zip_candidate_ips.txt
        > /tmp/zip_live_1003.txt

        cat << 'PREFIXES' > /tmp/zip_prefixes.txt
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
108.162.192.0/18
131.0.72.0/22
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
172.68.0.0/14
172.70.0.0/15
172.71.0.0/16
173.245.48.0/20
188.114.96.0/20
190.93.240.0/20
197.234.240.0/22
198.41.128.0/17
104.16.0.0/13
104.24.0.0/14
PREFIXES

        while IFS= read -r prefix; do
            [ -z "$prefix" ] && continue
            for _ in {1..16}; do
                cidr_to_random_ip "$prefix" >> /tmp/zip_candidate_ips.txt
            done
        done < /tmp/zip_prefixes.txt

        shuf -n 260 /tmp/zip_candidate_ips.txt > /tmp/zip_unique.txt

        (
            cat /tmp/zip_unique.txt | xargs -P 50 -I {} bash -c '
                ip="{}"
                resp=$(curl -s --connect-timeout 1.2 --max-time 2.2 --max-filesize 65536 -A "Mozilla/5.0" "http://${ip}" 2>/dev/null)
                if echo "$resp" | grep -Eqi "1003|Direct IP access not allowed"; then
                    echo "$ip"
                fi
            ' > /tmp/zip_live_1003.txt
        ) &
        loading_spinner $! "Mengimbas 20 IP Error 1003 untuk poskod $clean_z..."

        mapfile -t live_ips < <(head -n 180 /tmp/zip_live_1003.txt)
        if [ ${#live_ips[@]} -eq 0 ]; then
            echo -e "${RED}Tiada IP aktif dijumpai.${NC}"
        else
            rm -f /tmp/batch_zip_*.json
            for round in 1 2; do
                start_idx=$(( (round - 1) * 90 ))
                batch_slice=("${live_ips[@]:start_idx:90}")
                [ ${#batch_slice[@]} -eq 0 ] && break

                json_payload=$(printf '%s\n' "${batch_slice[@]}" | jq -R . | jq -s .)
                curl -s --max-time 8 -X POST "http://ip-api.com/batch?fields=status,country,regionName,city,zip,isp,query" \
                     -H "Content-Type: application/json" \
                     -d "$json_payload" > "/tmp/batch_zip_${round}.json"
            done

            jq -s 'add' /tmp/batch_zip_*.json > /tmp/all_batch_zip.json 2>/dev/null

            jq -r --arg z "$clean_z" \
                '.[] | select(.status=="success" and (.zip | tostring | ascii_downcase | contains($z | ascii_downcase))) | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_zip.json 2>/dev/null > /tmp/final_zip_matched.txt

            jq -r '.[] | select(.status=="success") | "\(.query)|\(.city)|\(.regionName)|\(.country)|\(.zip)|\(.isp)"' \
                /tmp/all_batch_zip.json 2>/dev/null >> /tmp/final_zip_matched.txt

            awk -F'|' '!seen[$1]++' /tmp/final_zip_matched.txt | head -n 20 > /tmp/final_zip_clean.txt
            mapfile -t matched_zips < /tmp/final_zip_clean.txt

            echo -e "${GREEN}[✔] Carian Selesai! 20 IP Error 1003 untuk Poskod '${YELLOW}${clean_z}${GREEN}':${NC}\n"

            if [ ${#matched_zips[@]} -eq 0 ]; then
                echo -e "${RED}Tiada IP sepadan dijumpai untuk poskod '${clean_z}'.${NC}"
            else
                count=1
                found_ips=()
                for entry in "${matched_zips[@]}"; do
                    IFS='|' read -r f_ip f_city f_reg f_cnt f_zip f_isp <<< "$entry"
                    found_ips+=("$f_ip")
                    printf "${GREEN}%-3s %-16s [ Error 1003 ✔ | Postcode: %s | %s, %s | %s ]${NC}\n" "${count}." "$f_ip" "${f_zip:-N/A}" "$f_city" "$f_cnt" "$f_isp"
                    ((count++))
                done

                current_date=$(LC_TIME=C date +"%A %dth %B %Y")
                {
                    echo "$current_date"
                    echo "Search Postcode : $clean_z (Batch #${batch_num})"
                    echo "Ip Address Found :"
                    c=1
                    for f_ip in "${found_ips[@]}"; do
                        echo "${c}. ${f_ip}"
                        ((c++))
                    done
                    echo "--------------------------------------------------"
                } >> "$HISTORY_FILE"
            fi
        fi

        rm -f /tmp/zip_*.txt /tmp/batch_zip_*.json /tmp/all_batch_zip.json /tmp/final_zip_*.txt

        echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -ne "${WHITE}Tekan ${GREEN}[Enter]${WHITE} untuk 20 IP lagi (${YELLOW}${clean_z}${WHITE}), atau taip ${RED}[0]${WHITE} untuk Exit : "
        read -r choice_loop
        if [ "$choice_loop" == "0" ]; then
            break
        fi
        ((batch_num++))
    done
}

# --- MENU 3: SHOW HISTORY ---
show_history() {
    show_banner
    echo -e "${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                    ${WHITE}SHOW HISTORY${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}\n"

    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "  ${YELLOW}Tiada rekod carian ditemui setakat ini.${NC}\n"
    else
        while IFS= read -r line; do
            if [[ "$line" == "--------------------------------------------------" ]]; then
                echo -e "${PURPLE}──────────────────────────────────────────────────${NC}"
            elif [[ "$line" =~ ^(Ip\ Target|Search\ Location|Search\ Postcode) ]]; then
                echo -e "${YELLOW}${line}${NC}"
            elif [[ "$line" =~ ^Ip\ Address\ Found ]]; then
                echo -e "${CYAN}${line}${NC}"
            elif [[ "$line" =~ ^[0-9]+\. ]]; then
                echo -e "${GREEN}${line}${NC}"
            else
                echo -e "${WHITE}${line}${NC}"
            fi
        done < "$HISTORY_FILE"
    fi

    echo -e "\n${PURPLE}  if found bugs contact telegram @ejwtpkvpn${NC}"
    echo -ne "${WHITE}Tekan enter untuk balik ke menu${NC}"
    read -r
}
