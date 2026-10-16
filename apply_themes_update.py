#!/usr/bin/env python3
"""Patch a local clone of ejaywattapak/cloudfail1003 for persistent Themes support.

Run from the repository root. Creates timestamped backups and modifies six files:
core.sh, menu.sh, installer.sh, setup.sh, menu/history.sh, plus new menu/themes.sh.
"""
from __future__ import annotations
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one target for {label}, found {count}; no intentional replacement made.")
    return text.replace(old, new, 1)

FILES = ["core.sh", "menu.sh", "installer.sh", "setup.sh", "menu/history.sh"]
missing = [p for p in FILES if not (ROOT / p).is_file()]
if missing:
    sys.exit("Run this script from the CLOUDFAIL repository root. Missing: " + ", ".join(missing))

backup = ROOT / (".themes-update-backup-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
backup.mkdir()
for rel in FILES:
    shutil.copy2(ROOT / rel, backup / rel.replace("/", "__"))

# Insert shared config/palettes after core.sh's NC variable.
core_path = ROOT / "core.sh"
core = core_path.read_text()
if "apply_menu_theme()" not in core:
    nc_pat = re.compile(r"(?m)^(NC='\\033\[0m')\s*$")
    m = nc_pat.search(core)
    if not m:
        sys.exit("Could not find core.sh NC color definition; no files were changed.")
    core_add = r'''\1

# Central theme preferences. Root selections are shared system-wide.
GLOBAL_THEME_CONFIG="/etc/ejaywatt-cloudfail-theme.conf"
USER_THEME_CONFIG="$HOME/.config/ejaywatt-cloudfail/theme.conf"
THEME_CONFIG_FILE="$GLOBAL_THEME_CONFIG"
FIGLET_FONT="/usr/share/figlet/ANSI_Shadow.flf"
MENU_THEME="Default"
BANNER_TEXT="EJAYWATT CLOUDFAIL"

if [ -r "$GLOBAL_THEME_CONFIG" ]; then
    source "$GLOBAL_THEME_CONFIG"
fi
if [ "$EUID" -ne 0 ]; then
    THEME_CONFIG_FILE="$USER_THEME_CONFIG"
    if [ -r "$USER_THEME_CONFIG" ]; then
        source "$USER_THEME_CONFIG"
    fi
fi

apply_menu_theme() {
    case "$MENU_THEME" in
        "WhatsApp Style")
            RED='\033[1;38;5;40m'
            GREEN='\033[1;38;5;40m'
            YELLOW='\033[1;38;5;118m'
            BLUE='\033[1;38;5;34m'
            PURPLE='\033[1;38;5;35m'
            CYAN='\033[1;38;5;46m'
            WHITE='\033[1;97m'
            GRAY='\033[38;5;22m'
            ;;
        "YouTube Style")
            RED='\033[1;31m'
            GREEN='\033[1;97m'
            YELLOW='\033[1;31m'
            BLUE='\033[0;31m'
            PURPLE='\033[1;31m'
            CYAN='\033[1;31m'
            WHITE='\033[1;97m'
            GRAY='\033[0;37m'
            ;;
        "Ocean Style")
            RED='\033[1;38;5;39m'
            GREEN='\033[1;38;5;51m'
            YELLOW='\033[1;38;5;75m'
            BLUE='\033[38;5;27m'
            PURPLE='\033[1;38;5;111m'
            CYAN='\033[1;38;5;45m'
            WHITE='\033[1;97m'
            GRAY='\033[38;5;24m'
            ;;
        *)
            MENU_THEME="Default"
            RED='\033[1;31m'
            GREEN='\033[1;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[1;34m'
            PURPLE='\033[1;35m'
            CYAN='\033[1;36m'
            WHITE='\033[1;37m'
            GRAY='\033[0;37m'
            ;;
    esac
    NC='\033[0m'
}
apply_menu_theme
'''
    core = core[:m.start()] + core_add.replace("\\1", m.group(1), 1) + core[m.end():]
    core_path.write_text(core)

# Main menu: load the new module, keep the logo's ANSI Shadow font, add item 10.
main_path = ROOT / "menu.sh"
main = main_path.read_text()
if '"themes.sh"' not in main:
    main = replace_once(main,
        '"ipv6to4.sh" "history.sh"',
        '"ipv6to4.sh" "themes.sh" "history.sh"', "menu.sh module list")
if 'figlet -f "$FIGLET_FONT"' not in main:
    pat = re.compile(r'(show_main_banner\(\)\s*\{.*?)(    echo -e "\$\{CYAN\}"\n    cat << "ASCII"\n.*?\nASCII\n    echo -e "\$\{NC\}")', re.S)
    m = pat.search(main)
    if not m:
        sys.exit("Could not locate show_main_banner ASCII block; no files were changed.")
    render = '''    echo -e "${CYAN}"
    if command -v figlet >/dev/null 2>&1 && [ -r "$FIGLET_FONT" ]; then
        figlet -f "$FIGLET_FONT" -w 96 "$BANNER_TEXT"
    else
        printf '  %s\\n' "$BANNER_TEXT"
    fi
    echo -e "${NC}"'''
    main = main[:m.start(2)] + render + main[m.end(2):]
if "[10]${NC} ${WHITE}Themes" not in main:
    main = replace_once(main,
        '    echo -e "${CYAN}│${NC}  ${YELLOW}[10]${NC} ${WHITE}Search History${NC}        ${GRAY}(Papar Rekod Carian)${NC}     ${CYAN}│${NC}',
        '    echo -e "${CYAN}│${NC}  ${YELLOW}[10]${NC} ${WHITE}Themes${NC}                ${GRAY}(Banner & Menu Colors)${NC}    ${CYAN}│${NC}"\n'
        '    echo -e "${CYAN}│${NC}  ${YELLOW}[11]${NC} ${WHITE}Search History${NC}        ${GRAY}(Papar Rekod Carian)${NC}     ${CYAN}│${NC}',
        "menu.sh Themes item")
if "menu_themes ;;" not in main:
    main = replace_once(main, "        10) menu_history ;;", "        10) menu_themes ;;\n        11) menu_history ;;", "menu.sh dispatch")
main = main.replace("Pilih Menu (1-10 / 0=Exit)", "Pilih Menu (1-11 / 0=Exit)")
main = main.replace("Sila pilih 1-10 atau 0.", "Sila pilih 1-11 atau 0.")
main_path.write_text(main)

# Installer check list knows that themes.sh is a required menu module.
installer_path = ROOT / "installer.sh"
installer = installer_path.read_text()
if '"themes.sh"' not in installer:
    installer = replace_once(installer,
        '"ipv6to4.sh" "history.sh"',
        '"ipv6to4.sh" "themes.sh" "history.sh"', "installer.sh module list")
installer_path.write_text(installer)

# Setup downloads the new module and installs figlet + ANSI Shadow font.
setup_path = ROOT / "setup.sh"
setup = setup_path.read_text()
if '"themes.sh"' not in setup:
    setup = replace_once(setup,
        '    "ipv6to4.sh"\n    "history.sh"',
        '    "ipv6to4.sh"\n    "themes.sh"\n    "history.sh"', "setup.sh module list")
if "figlet" not in setup:
    setup = setup.replace("vnstat bc procps ca-certificates tzdata", "vnstat figlet bc procps ca-certificates tzdata")
    setup = setup.replace("vnstat \\\n        bc procps-ng", "vnstat figlet \\\n        bc procps-ng")
if "ANSI_Shadow.flf" not in setup:
    anchor = "# 2. TIMEZONE"
    font_setup = '''# Install the same ANSI Shadow FIGlet font used by the original banner.
if command -v figlet >/dev/null 2>&1; then
    mkdir -p /usr/share/figlet
    if ! curl -fsSL --retry 2 --connect-timeout 10 --max-time 60 \\
        "https://raw.githubusercontent.com/xero/figlet-fonts/main/ANSI%20Shadow.flf" \\
        -o /usr/share/figlet/ANSI_Shadow.flf; then
        echo -e "${YELLOW}[!] Gagal memuat turun ANSI Shadow font; banner akan guna fallback teks.${NC}"
        rm -f /usr/share/figlet/ANSI_Shadow.flf
    fi
fi

'''
    if anchor not in setup:
        sys.exit("Could not find setup.sh timezone section; no files were changed.")
    setup = setup.replace(anchor, font_setup + anchor, 1)
setup_path.write_text(setup)

# History is now item 11.
history_path = ROOT / "menu/history.sh"
history = history_path.read_text()
history = history.replace("MODULE 10: SEARCH HISTORY", "MODULE 11: SEARCH HISTORY")
history = history.replace('sub_header "10. SEARCH HISTORY', 'sub_header "11. SEARCH HISTORY')
history_path.write_text(history)

# Install themes.sh into a local clone (the bundle includes the canonical version).
provided_theme = Path(__file__).resolve().parent / "menu" / "themes.sh"
if not provided_theme.is_file():
    sys.exit("Bundle is missing menu/themes.sh")
shutil.copy2(provided_theme, ROOT / "menu" / "themes.sh")

print("Theme update prepared successfully.")
print("Changed files:")
for path in ["menu/themes.sh", "menu.sh", "core.sh", "installer.sh", "setup.sh", "menu/history.sh"]:
    print("  - " + path)
print("Backup directory: " + str(backup))
print("Next: run bash -n on modified scripts, then commit/upload the six files.")
