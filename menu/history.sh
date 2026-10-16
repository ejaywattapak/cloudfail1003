#!/bin/bash
# ==============================================================
# MODULE 10: SEARCH HISTORY (history.sh)
# Format Masa: 12-Hour AM/PM (Asia/Kuala_Lumpur)
# ==============================================================

menu_history() {
    local now_kl
    now_kl=$(TZ="Asia/Kuala_Lumpur" date +"%d %b %Y | %I:%M:%S %p MYT")
    sub_header "10. SEARCH HISTORY (KL TIME: ${now_kl})"

    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "\n  ${YELLOW}Tiada rekod carian ditemui setakat ini.${NC}\n"
    else
        tail -n 55 "$HISTORY_FILE" | while IFS= read -r line; do
            if [[ "$line" == "--------------------------------------------------" ]]; then
                echo -e "${PURPLE}──────────────────────────────────────────────────────────${NC}"
            elif [[ "$line" == *"|"* ]] || [[ "$line" =~ ^(Ip\ Target|Search|Original|Bug\ Hunter) ]]; then
                echo -e "${YELLOW}🕒 ${line}${NC}"
            elif [[ "$line" =~ ^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday) ]]; then
                echo -e "${CYAN}📅 ${line}${NC}"
            else
                echo -e "${GREEN}${line}${NC}"
            fi
        done
    fi
    echo -e "\n${CYAN}──────────────────────────────────────────────────────────${NC}"
    echo -ne "${WHITE}Taip ${RED}[c]${WHITE} untuk Clear History, atau tekan ${GREEN}[Enter]${WHITE} kembali ke Menu : ${YELLOW}"
    read -r h_opt
    echo -ne "${NC}"
    if [[ "$h_opt" == "c" || "$h_opt" == "C" ]]; then
        > "$HISTORY_FILE"
        echo -e "${GREEN}[✔] Rekod carian telah dibersihkan!${NC}"
        sleep 1
    fi
}
