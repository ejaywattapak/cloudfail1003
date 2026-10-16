#!/bin/bash
# ==============================================================
# MODULE: THEMES (KEEP ORIGINAL ANSI SHADOW 3D ASCII FONT)
# ==============================================================

save_theme_settings() {
    local theme_escaped banner_escaped save_dir
    printf -v theme_escaped '%q' "$MENU_THEME"
    printf -v banner_escaped '%q' "$BANNER_TEXT"
    save_dir=$(dirname "$THEME_CONFIG_FILE")
    mkdir -p "$save_dir" || return 1

    if ! (umask 077; printf 'MENU_THEME=%s\nBANNER_TEXT=%s\n' \
        "$theme_escaped" "$banner_escaped" > "$THEME_CONFIG_FILE"); then
        return 1
    fi

    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        chmod 0644 "$THEME_CONFIG_FILE"
    else
        chmod 0600 "$THEME_CONFIG_FILE"
    fi
}

change_menu_style() {
    while true; do
        clear
        printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$CYAN" "$NC"
        printf '%b│%b%21s%bCHANGE MENU STYLE%21s%b│%b\n' "$CYAN" "$NC" "" "$WHITE" "" "$CYAN" "$NC"
        printf '%b├──────────────────────────────────────────────────────┤%b\n' "$CYAN" "$NC"
        printf '  Current style: %s\n\n' "$MENU_THEME"
        echo -e "  ${YELLOW}[1]${NC} WhatsApp Style  ${GREEN}(hijau)${NC}"
        echo -e "  ${YELLOW}[2]${NC} YouTube Style   ${RED}(merah + putih)${NC}"
        echo -e "  ${YELLOW}[3]${NC} Ocean Style     ${CYAN}(biru + putih)${NC}"
        echo -e "  ${YELLOW}[4]${NC} Default         (warna asal)"
        echo -e "  ${RED}[0]${NC} Back"
        echo
        echo -ne "${CYAN}╰─➤ Pilih style [1-4/0]: ${YELLOW}"
        read -r style_choice
        printf '%b' "$NC"

        case "$style_choice" in
            1) MENU_THEME="WhatsApp Style" ;;
            2) MENU_THEME="YouTube Style" ;;
            3) MENU_THEME="Ocean Style" ;;
            4) MENU_THEME="Default" ;;
            0) return ;;
            *) echo -e "\n${RED}[!] Pilihan tidak sah.${NC}"; sleep 1; continue ;;
        esac

        apply_menu_theme
        if save_theme_settings; then
            echo -e "\n${GREEN}[✔] Tema disimpan: ${MENU_THEME}${NC}"
            echo -e "${CYAN}[i] Menu utama, banner dan submenu ikut tema ini.${NC}"
        else
            echo -e "\n${RED}[!] Tema digunakan untuk sesi ini tetapi gagal disimpan.${NC}"
        fi
        read -rp "Tekan Enter untuk kembali..." _
        return
    done
}

menu_themes() {
    while true; do
        clear
        printf '%b╭──────────────────────────────────────────────────────╮%b\n' "$CYAN" "$NC"
        printf '%b│%b%24s%bTHEMES%24s%b│%b\n' "$CYAN" "$NC" "" "$WHITE" "" "$CYAN" "$NC"
        printf '%b├──────────────────────────────────────────────────────┤%b\n' "$CYAN" "$NC"
        printf '  Current style : %s\n' "$MENU_THEME"
        printf '  Banner text   : %s\n\n' "$BANNER_TEXT"
        echo -e "  ${YELLOW}[1]${NC} Edit Banner Text ${GRAY}(kekal font 3D ASCII asal)${NC}"
        echo -e "  ${YELLOW}[2]${NC} Change Menu Style"
        echo -e "  ${RED}[0]${NC} Back to Main Menu"
        printf '%b╰──────────────────────────────────────────────────────╯%b\n' "$CYAN" "$NC"
        echo -ne "${CYAN}╰─➤ Pilih [1/2/0]: ${YELLOW}"
        read -r theme_choice
        printf '%b' "$NC"

        case "$theme_choice" in
            1)
                echo
                echo -ne "${WHITE}Masukkan teks banner baharu (maksimum 32 aksara): ${YELLOW}"
                IFS= read -r new_text
                printf '%b' "$NC"
                if [ -z "$(printf '%s' "$new_text" | tr -d '[:space:]')" ]; then
                    echo -e "${RED}[!] Teks banner tidak boleh kosong.${NC}"
                    sleep 1.2
                    continue
                fi
                text_length=$(printf '%s' "$new_text" | wc -m)
                if [ "$text_length" -gt 32 ]; then
                    echo -e "${RED}[!] Maksimum 32 aksara supaya banner muat pada skrin.${NC}"
                    sleep 1.5
                    continue
                fi

                BANNER_TEXT="$new_text"
                apply_menu_theme
                if save_theme_settings; then
                    echo -e "\n${GREEN}[✔] Teks banner berjaya ditukar.${NC}"
                    echo -e "${CYAN}[i] Font 3D ASCII ANSI Shadow dikekalkan; warna ikut tema aktif.${NC}"
                else
                    echo -e "\n${RED}[!] Teks ditukar untuk sesi ini tetapi gagal disimpan.${NC}"
                fi
                read -rp "Tekan Enter untuk kembali..." _
                ;;
            2) change_menu_style ;;
            0) return ;;
            *) echo -e "\n${RED}[!] Pilihan tidak sah.${NC}"; sleep 1 ;;
        esac
    done
}
