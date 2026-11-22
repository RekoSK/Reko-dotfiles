#!/bin/bash
# Reko dotfiles installer (Hyprland on Arch Linux).
# Copyright (C) 2026 Andrej "Reko" Revák
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Opens a TUI where you pick which configs to install. Missing programs are installed
# with pacman / an AUR helper, existing configs are backed up first, and backups can be
# restored later by running this script again.
#
# Usage:
#   ./install.sh            open the installer (copy mode)
#   ./install.sh --link     start in link mode (symlinks into this folder)
#   ./install.sh --dry-run  walk through everything without changing anything
#   ./install.sh --keybinds show all keybinds and what they do

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES_DIR/.config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/reko-dotfiles"
BACKUP_ROOT="$DATA_DIR/backups"
STATE_FILE="$DATA_DIR/installed"
WALLPAPER_DIR="$HOME/Pictures/waypaper"
WALLPAPER="Nyarch_default_walpaper.webp"
AUTHOR_HOME="/home/reko"   # paths in the configs are written for this home folder
MARKER=".reko-dotfiles"    # dropped into copied folders so later runs recognise them

STAMP="$(date +%Y%m%d-%H%M%S)"
SESSION_BACKUP="$BACKUP_ROOT/$STAMP"

MODE="copy"
DRY=false
SHOW_KEYS=false
for arg in "$@"; do
    case "$arg" in
        --copy)    MODE="copy" ;;
        --link)    MODE="link" ;;
        --dry-run) DRY=true ;;
        --keybinds) SHOW_KEYS=true ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ---------- --keybinds ----------

show_keybinds() {
    local acc="" bold="" dim="" off=""
    if [ -t 1 ]; then acc=$'\e[38;5;202m' bold=$'\e[1m' dim=$'\e[2m' off=$'\e[0m'; fi
    local section keys action
    while IFS='|' read -r keys action; do
        if [ -z "$action" ]; then
            [ -n "$keys" ] && printf '\n%s%s%s\n' "$bold$acc" "$keys" "$off"
            continue
        fi
        printf '  %s%-28s%s %s\n' "$acc" "$keys" "$off" "$action"
    done <<'KEYS'
Apps
SUPER + T|kitty terminal
SUPER + R|app launcher (rofi)
SUPER + SHIFT + R|run a command (rofi)
SUPER + E|Places: open a folder in Nautilus
SUPER + SHIFT + E|Places: open a folder in kitty
SUPER + C|calculator
SUPER + B|KeePassXC + Brave Origin (needs the "apps" option)
Windows
SUPER + Q|close window
SUPER + F|toggle floating
SUPER + W|maximize
SUPER + SHIFT + W|fullscreen
SUPER + P|pseudotile
SUPER + J|toggle split direction
SUPER + arrows|move focus
SUPER + left mouse drag|move window
SUPER + right mouse drag|resize window
ALT + TAB|window switcher (rofi)
Workspaces
SUPER + 1..0|go to workspace 1-10
SUPER + SHIFT + 1..0|move window to workspace 1-10
SUPER + S|show / hide the scratchpad
SUPER + SHIFT + S|move window to the scratchpad
SUPER + mouse scroll|cycle workspaces
Screenshots and clipboard
Print|screenshot of the whole screen (to clipboard)
SUPER + Print|screenshot of a region (to clipboard)
SUPER + CTRL + C|clipboard history
SUPER + CTRL + SHIFT + C|wipe clipboard history
Session
SUPER + SHIFT + L|lock screen
SUPER + M|exit Hyprland
Media keys|volume, mic mute, brightness, play / pause / next
Terminal (bash)
Ctrl + R|search the command history (fzf)
z <part of a folder name>|jump to a folder you've been in (zoxide)
ll / lt|list files as a grid / as a tree
KEYS
    printf '\n%sSUPER is the Windows key.%s\n\n' "$dim" "$off"
}

if $SHOW_KEYS; then
    show_keybinds
    exit 0
fi

if $DRY; then LOG="${TMPDIR:-/tmp}/reko-dotfiles-$STAMP.log"; else LOG="$DATA_DIR/install-$STAMP.log"; fi

if [ "$EUID" -eq 0 ]; then
    echo "Run this as your normal user, not as root or with sudo. It asks for your password when it needs it."
    exit 1
fi
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "This installer needs a terminal. Download the dotfiles folder and run ./install.sh in a terminal or tty."
    exit 1
fi
if [ ! -d "$SRC" ]; then
    echo "Can't find the .config folder next to install.sh ($SRC)."
    echo "Download the whole dotfiles folder, not only this script."
    exit 1
fi

# The Linux console (a tty without a desktop) has a small font, so it gets plain symbols
if [ "${TERM:-}" == linux ] || ! locale charmap 2>/dev/null | grep -qi 'utf-\?8'; then
    CONSOLE=true
    G_OK="+" G_FAIL="x" G_SEL=">" G_MORE="..." G_ON="#" G_OFF="-"
    SPINNER=('|' '/' '-' '\')
else
    CONSOLE=false
    G_OK="✔" G_FAIL="✘" G_SEL="›" G_MORE="…" G_ON="━" G_OFF="─"
    SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
fi

# The checks below take a moment on a fresh system, so say something right away
printf 'Checking your system...\n'

# File changes go through run, so --dry-run only prints them
run() {
    if $DRY; then echo "[dry-run] $*"; else "$@"; fi
}

# ======================================================================
#  What can be installed
# ======================================================================

declare -A DESC=(
    [hypr]="Hyprland, lock screen, idle, scripts"
    [bash]="terminal prompt, history search, colours"
    [waybar]="top bar"
    [rofi]="app launcher, alt-tab, clipboard"
    [rofi-bluetooth]="bluetooth menu"
    [ronema]="network menu theme"
    [kitty]="terminal"
    [avizo]="volume / brightness popup"
    [waypaper]="wallpaper picker"
    [gtk-3.0]="GTK 3 theme"
    [gtk-4.0]="GTK 4 theme"
    [nwg-look]="GTK settings tool"
    [xsettingsd]="GTK settings daemon"
    [qt5ct]="Qt 5 theme"
    [qt6ct]="Qt 6 theme"
    [Kvantum]="Kvantum \"Future\" Qt style"
    [wallpaper]="default wallpaper"
    [apps]="KeePassXC + Brave Origin (SUPER+B)"
)

# Programs each item needs, including everything its autostart, keybinds and buttons
# start. Anything not in the official repos comes from the AUR.
declare -A PKGS=(
    [hypr]="hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-gnome swaync waybar waypaper avizo rofi kitty nautilus hyprshot cliphist wl-clipboard playerctl brightnessctl libnotify udisks2 libpulse gnome-calculator cinnamon-sounds sound-theme-freedesktop inter-font ttf-jetbrains-mono-nerd"
    [waybar]="waybar ttf-jetbrains-mono-nerd gnome-calendar mission-center swaync cliphist rofi avizo"
    [rofi]="rofi ttf-jetbrains-mono-nerd"
    [rofi-bluetooth]="rofi rofi-bluetooth-git bluez bluez-utils libnotify ttf-jetbrains-mono-nerd"
    [ronema]="rofi networkmanager libnotify"
    [kitty]="kitty ttf-jetbrains-mono-nerd"
    [bash]="blesh-git eza fzf starship zoxide ttf-jetbrains-mono-nerd"
    [avizo]="avizo"
    [waypaper]="waypaper hyprpaper"
    [gtk-3.0]="bibata-cursor-theme otf-space-grotesk"
    [gtk-4.0]="bibata-cursor-theme"
    [nwg-look]="nwg-look"
    [xsettingsd]="xsettingsd"
    [qt5ct]="qt5ct"
    [qt6ct]="qt6ct"
    [Kvantum]="kvantum"
    [apps]="keepassxc brave-origin-bin"
)

# hypr first, then the other config folders, then the extras
ITEMS=()
[ -d "$SRC/hypr" ] && ITEMS+=("hypr")
for item in "$SRC"/*; do
    name="$(basename "$item")"
    [ "$name" == "hypr" ] || ITEMS+=("$name")
done
ITEMS+=("wallpaper" "apps")

is_config() { [ "$1" != "wallpaper" ] && [ "$1" != "apps" ]; }

SELECTED=()
for name in "${ITEMS[@]}"; do
    if [ "$name" == "apps" ]; then SELECTED+=(0); else SELECTED+=(1); fi
done

# ---------- which programs are missing ----------

HAS_PACMAN=false
command -v pacman >/dev/null 2>&1 && HAS_PACMAN=true

declare -A MISSING=()    # pkg -> repo | aur
if $HAS_PACMAN; then
    all_pkgs=()
    for name in "${ITEMS[@]}"; do
        for pkg in ${PKGS[$name]:-}; do all_pkgs+=("$pkg"); done
    done
    declare -A IN_REPOS=()
    while read -r pkg; do IN_REPOS[$pkg]=1; done < <(pacman -Slq 2>/dev/null)
    while read -r pkg; do
        [ -n "$pkg" ] || continue
        if [ -n "${IN_REPOS[$pkg]:-}" ]; then MISSING[$pkg]=repo; else MISSING[$pkg]=aur; fi
    done < <(pacman -T "${all_pkgs[@]}" 2>/dev/null | sort -u)
fi

AUR_HELPER=""
for helper in yay paru; do
    if command -v "$helper" >/dev/null 2>&1; then AUR_HELPER="$helper"; break; fi
done

missing_for() {
    local pkg out=()
    for pkg in ${PKGS[$1]:-}; do [ -n "${MISSING[$pkg]:-}" ] && out+=("$pkg"); done
    echo "${out[*]:-}"
}

# ---------- state of a config in ~/.config ----------

# linked  = symlink to this folder      ours = copy from an earlier install
# exists  = the user's own config       new  = nothing there yet
config_state() {
    local target="$DEST/$1"
    if [ -L "$target" ] && [ "$(readlink -f "$target")" == "$(readlink -f "$SRC/$1")" ]; then
        echo linked
    elif [ -e "$target/$MARKER" ]; then
        echo ours
    elif [ -e "$target" ] || [ -L "$target" ]; then
        echo exists
    else
        echo new
    fi
}

STATES=()
for name in "${ITEMS[@]}"; do
    if is_config "$name"; then STATES+=("$(config_state "$name")")
    elif [ "$name" == "wallpaper" ] && [ -e "$WALLPAPER_DIR/$WALLPAPER" ]; then STATES+=(present)
    else STATES+=(new); fi
done

# ======================================================================
#  Terminal drawing
# ======================================================================

# Accent orange #ff6600: exact on true-color terminals, closest 256-color (202) otherwise
case "${COLORTERM:-}" in
    truecolor|24bit) C_ACC=$'\e[38;2;255;102;0m' ;;
    *)               C_ACC=$'\e[38;5;202m' ;;
esac
C_ACC2=$'\e[38;5;214m'
# The Linux console only has 16 colors and would show the orange as red, so the TUI
# repaints its yellow slots orange while it runs (tui_stop puts the palette back)
$CONSOLE && C_ACC=$'\e[33m' C_ACC2=$'\e[33m'
C_OK=$'\e[38;5;114m'
C_ERR=$'\e[38;5;203m'
C_DIM=$'\e[2m'
C_BOLD=$'\e[1m'
C_REV=$'\e[7m'
C_OFF=$'\e[0m'

IN_ALT=false
tui_start() {
    printf '\e[?1049h\e[?25l'
    $CONSOLE && printf '\e]P3FF6600\e]PBFF8533'   # yellow + bright yellow (used for bold)
    stty -echo 2>/dev/null
    IN_ALT=true
}
tui_stop() {
    # The Linux console has no alternate screen, so clear the TUI away instead
    $IN_ALT && { if $CONSOLE; then printf '\e[H\e[2J'; else printf '\e[?1049l'; fi; }
    $CONSOLE && printf '\e]R'
    printf '\e[?25h'
    stty echo 2>/dev/null
    IN_ALT=false
}

ROOT_DIR=""   # set while the root helper runs, see start_root_helper
cleanup() {
    stop_root_helper
    tui_stop
}
trap cleanup EXIT
trap 'exit 130' INT TERM

ROWS=24 COLS=80
term_size() {
    local s
    s=$(stty size 2>/dev/null) || s="24 80"
    ROWS=${s% *} COLS=${s#* }
}

# Screens are built in OUT and printed in one go, so redraws don't flicker
OUT=""
putf() {
    local l
    printf -v l "$@"
    OUT+="$l"$'\e[K\n'
}
flush() {
    printf '\e[H%s\e[J' "$OUT"
    OUT=""
}

# ---------- title ----------

declare -A GLYPH=(
    [R]='██████╗ |██╔══██╗|██████╔╝|██╔══██╗|██║  ██║|╚═╝  ╚═╝'
    [E]='███████╗|██╔════╝|█████╗  |██╔══╝  |███████╗|╚══════╝'
    [K]='██╗  ██╗|██║ ██╔╝|█████╔╝ |██╔═██╗ |██║  ██╗|╚═╝  ╚═╝'
    [O]=' ██████╗ |██╔═══██╗|██║   ██║|██║   ██║|╚██████╔╝| ╚═════╝ '
    [D]='██████╗ |██╔══██╗|██║  ██║|██║  ██║|██████╔╝|╚═════╝ '
    [T]='████████╗|╚══██╔══╝|   ██║   |   ██║   |   ██║   |   ╚═╝   '
    [F]='███████╗|██╔════╝|█████╗  |██╔══╝  |██║     |╚═╝     '
    [I]='██╗|██║|██║|██║|██║|╚═╝'
    [L]='██╗     |██║     |██║     |██║     |███████╗|╚══════╝'
    [S]='███████╗|██╔════╝|███████╗|╚════██║|███████║|╚══════╝'
)

big_word() {
    local word=$1 row ch line i
    local -a g
    for row in 0 1 2 3 4 5; do
        line=""
        for ((i = 0; i < ${#word}; i++)); do
            ch=${word:i:1}
            IFS='|' read -ra g <<<"${GLYPH[$ch]}"
            line+="${g[$row]}"
        done
        echo "$line"
    done
}

mapfile -t ART_REKO < <(big_word REKO)
mapfile -t ART_DOTS < <(big_word DOTFILES)
ART_HEIGHT=14

# Big title when there's room for it plus $1 lines of content, a one-liner otherwise
banner() {
    local need=${1:-0} line
    term_size
    putf ''
    if [ "$COLS" -ge 66 ] && [ $((ROWS - ART_HEIGHT)) -ge "$need" ]; then
        for line in "${ART_REKO[@]}"; do putf '  %s%s%s' "$C_ACC" "$line" "$C_OFF"; done
        for line in "${ART_DOTS[@]}"; do putf '  %s%s%s' "$C_ACC" "$line" "$C_OFF"; done
    else
        putf '  %s%sREKO dotfiles%s' "$C_BOLD" "$C_ACC" "$C_OFF"
    fi
    $DRY && putf '  %s[dry-run] nothing will be changed%s' "$C_ACC" "$C_OFF"
    putf ''
}

# ---------- keys ----------

KEY=""
# read_key [timeout]: sets KEY, "none" when the timeout ran out
read_key() {
    local k rest
    if [ -n "${1:-}" ]; then
        IFS= read -rsn1 -t "$1" k || { KEY=none; return; }
    else
        IFS= read -rsn1 k || { KEY=none; return; }
    fi
    if [ "$k" == $'\e' ]; then
        IFS= read -rsn2 -t 0.05 rest || true
        k+="$rest"
    fi
    case "$k" in
        $'\e[A'|$'\eOA'|k) KEY=up ;;
        $'\e[B'|$'\eOB'|j) KEY=down ;;
        " ")               KEY=toggle ;;
        "")                KEY=enter ;;
        a|A)               KEY=all ;;
        n|N)               KEY=none_sel ;;
        m|M)               KEY=mode ;;
        o|O)               KEY=output ;;
        q|Q|$'\e')         KEY=quit ;;
        *)                 KEY=other ;;
    esac
}

# ask_choice "Title" "body (one line per \n)" option... -> CHOICE (index, -1 on quit)
CHOICE=0
ask_choice() {
    local title=$1 body=$2 cur=0 i line body_lines
    shift 2
    local -a opts=("$@")
    body_lines=$(printf '%s\n' "$body" | wc -l)
    while true; do
        banner $((body_lines + ${#opts[@]} + 6))
        putf '  %s%s%s' "$C_BOLD" "$title" "$C_OFF"
        putf ''
        while IFS= read -r line; do putf '  %s' "$line"; done <<<"$body"
        putf ''
        for i in "${!opts[@]}"; do
            if [ "$i" == "$cur" ]; then putf '  %s%s %s%s' "$C_ACC$C_BOLD" "$G_SEL" "${opts[$i]}" "$C_OFF"
            else putf '    %s' "${opts[$i]}"; fi
        done
        putf ''
        putf '  %s↑↓ choose · enter confirm%s' "$C_DIM" "$C_OFF"
        flush
        read_key
        case "$KEY" in
            up)    [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
            down)  [ "$cur" -lt $((${#opts[@]} - 1)) ] && cur=$((cur + 1)) ;;
            enter) CHOICE=$cur; return ;;
            quit)  CHOICE=-1; return ;;
        esac
    done
}

# ======================================================================
#  Backups
# ======================================================================

list_backups() {
    local d
    [ -d "$BACKUP_ROOT" ] || return
    for d in "$BACKUP_ROOT"/*/; do
        [ -f "$d.backup-info" ] && echo "${d%/}"
    done | sort -r
}

backup_date() {
    local s
    s=$(basename "$1")
    echo "${s:0:4}-${s:4:2}-${s:6:2} ${s:9:2}:${s:11:2}"
}

# "hypr, waybar*" (* = was a copy of these dotfiles)
backup_items() {
    local line name label out=()
    while IFS= read -r line; do
        [[ "$line" == item=* ]] || continue
        line=${line#item=}
        name=${line%%:*} label=${line#*:}
        [ "$label" == "dotfiles" ] && name+="*"
        out+=("$name")
    done <"$1/.backup-info"
    local IFS=,
    echo "${out[*]}" | sed 's/,/, /g'
}

# Moves $DEST/<name> into this session's backup and records it
backup_item() {
    local name=$1 reason=$2 target="$DEST/$1" label=own
    [ -e "$target/$MARKER" ] && label=dotfiles
    run mkdir -p "$SESSION_BACKUP"
    run mv "$target" "$SESSION_BACKUP/"
    if ! $DRY; then
        [ -f "$SESSION_BACKUP/.backup-info" ] || printf 'reason=%s\n' "$reason" >"$SESSION_BACKUP/.backup-info"
        printf 'item=%s:%s\n' "$name" "$label" >>"$SESSION_BACKUP/.backup-info"
    fi
    echo "backup  $name -> $SESSION_BACKUP/$name"
}

restore_backup() {
    local dir=$1 item name target
    run mkdir -p "$DEST"
    for item in "$dir"/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        target="$DEST/$name"
        if [ -L "$target" ]; then
            run rm "$target"
            echo "remove  $name (link to the dotfiles)"
        elif [ -e "$target" ]; then
            backup_item "$name" restore
        fi
        run mv "$item" "$target"
        echo "restore $name"
        forget_installed "$name"
    done
    if ! $DRY; then
        rm -f "$dir/.backup-info"
        rmdir "$dir" 2>/dev/null
    fi
}

# ---------- install record ----------
# $STATE_FILE remembers what this installer put on the system:
#   items=    configs (and "wallpaper") it installed
#   packages= programs it installed, so uninstalling never removes ones the user already had

state_get() {
    [ -f "$STATE_FILE" ] && sed -n "s/^$1=//p" "$STATE_FILE"
}

state_set() {
    $DRY && return
    [ -f "$STATE_FILE" ] || return
    if grep -q "^$1=" "$STATE_FILE"; then sed -i "s|^$1=.*|$1=$2|" "$STATE_FILE"
    else printf '%s=%s\n' "$1" "$2" >>"$STATE_FILE"; fi
    # Nothing left that this installer put there: forget about it completely
    if [ -z "$(state_get items)" ] && [ -z "$(state_get packages)" ]; then rm -f "$STATE_FILE"; fi
}

installed_items() { state_get items; }
installed_packages() { state_get packages; }

# Removes word $2 from the space separated list in field $1
state_remove() {
    state_set "$1" "$(state_get "$1" | tr ' ' '\n' | grep -vxF "$2" | grep -v '^$' | tr '\n' ' ' | sed 's/ *$//')"
}

forget_installed() { state_remove items "$1"; }

item_state() {
    local i
    for i in "${!ITEMS[@]}"; do [ "${ITEMS[$i]}" == "$1" ] && echo "${STATES[$i]}"; done
}

# What can be uninstalled: configs from these dotfiles, the wallpaper if this installer
# copied it, and "apps" if this installer installed one of its programs
can_uninstall() {
    local name=$1 pkg
    case "$name" in
        wallpaper) installed_items | tr ' ' '\n' | grep -qx wallpaper ;;
        apps)
            for pkg in ${PKGS[apps]}; do
                installed_packages | tr ' ' '\n' | grep -qxF "$pkg" && return 0
            done
            return 1 ;;
        *) case "$(item_state "$name")" in linked|ours) return 0 ;; *) return 1 ;; esac ;;
    esac
}

# ======================================================================
#  Screens
# ======================================================================

UI_MODE=install   # install | uninstall
VIEW=()           # indices of ITEMS shown in the selector
for i in "${!ITEMS[@]}"; do VIEW+=("$i"); done

count_selected() {
    local n=0 i
    for i in "${VIEW[@]}"; do n=$((n + SELECTED[i])); done
    echo "$n"
}

state_label() {
    case "$1" in
        linked)  printf '%sinstalled (link)%s' "$C_DIM" "$C_OFF" ;;
        ours)    printf '%sinstalled (copy)%s' "$C_DIM" "$C_OFF" ;;
        exists)  printf '%syour config, will be backed up%s' "$C_ACC" "$C_OFF" ;;
        present) printf '%salready there%s' "$C_DIM" "$C_OFF" ;;
        new)     printf '%snew%s' "$C_DIM" "$C_OFF" ;;
    esac
}

# Returns 0 to continue, 1 to go back / quit
select_screen() {
    local cursor=0 top=0 rows v i end name mark line miss extra
    while true; do
        OUT=""
        banner $((${#VIEW[@]} + 9))
        rows=$((ROWS - $(printf '%s' "$OUT" | grep -c '') - 9))
        [ "$rows" -lt 3 ] && rows=3
        [ "$cursor" -lt "$top" ] && top=$cursor
        [ "$cursor" -ge $((top + rows)) ] && top=$((cursor - rows + 1))

        if [ "$UI_MODE" == install ]; then putf '  %sChoose what to install%s' "$C_BOLD" "$C_OFF"
        else putf '  %sChoose what to uninstall%s  %s(everything not ticked is kept)%s' "$C_BOLD" "$C_OFF" "$C_DIM" "$C_OFF"; fi
        putf ''
        end=$((top + rows))
        [ "$end" -gt "${#VIEW[@]}" ] && end=${#VIEW[@]}
        [ "$top" -gt 0 ] && putf '  %s%s more above%s' "$C_DIM" "$G_MORE" "$C_OFF"
        for ((v = top; v < end; v++)); do
            i=${VIEW[$v]}
            name="${ITEMS[$i]}"
            if [ "${SELECTED[$i]}" == 1 ]; then mark="${C_ACC}[x]${C_OFF}"; else mark="[ ]"; fi
            extra=""
            if [ "$UI_MODE" == install ]; then
                miss=$(missing_for "$name")
                [ -n "$miss" ] && extra="  ${C_ACC2}+$(wc -w <<<"$miss") to install${C_OFF}"
            fi
            printf -v line '%-15s %-37s' "$name" "${DESC[$name]:-}"
            if [ "$v" == "$cursor" ]; then line="${C_REV}${line}${C_OFF}"; fi
            if [ "$UI_MODE" == uninstall ] && ! is_config "$name"; then
                putf '  %s %s %sinstalled by the dotfiles%s' "$mark" "$line" "$C_DIM" "$C_OFF"
            else
                putf '  %s %s %s%s' "$mark" "$line" "$(state_label "${STATES[$i]}")" "$extra"
            fi
        done
        [ "$end" -lt "${#VIEW[@]}" ] && putf '  %s%s more below%s' "$C_DIM" "$G_MORE" "$C_OFF"
        putf ''
        if [ "$UI_MODE" == uninstall ]; then
            putf '  %sNext you choose whether the programs are removed too.%s' "$C_DIM" "$C_OFF"
        elif [ "$MODE" == "copy" ]; then
            putf '  Mode: %scopy%s %s(own copy in ~/.config, this folder can be deleted)%s' "$C_BOLD" "$C_OFF" "$C_DIM" "$C_OFF"
        else
            putf '  Mode: %slink%s %s(~/.config points here, keep this folder)%s' "$C_BOLD" "$C_OFF" "$C_DIM" "$C_OFF"
        fi
        putf '  Selected: %s / %s' "$(count_selected)" "${#VIEW[@]}"
        putf ''
        if [ "$UI_MODE" == install ]; then
            putf '  %s↑↓ move · space toggle · a all · n none · m copy/link · enter continue · q quit%s' "$C_DIM" "$C_OFF"
        else
            putf '  %s↑↓ move · space toggle · a all · n none · enter continue · q back%s' "$C_DIM" "$C_OFF"
        fi
        flush

        read_key
        i=${VIEW[$cursor]}
        case "$KEY" in
            up)       [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
            down)     [ "$cursor" -lt $((${#VIEW[@]} - 1)) ] && cursor=$((cursor + 1)) ;;
            toggle)   SELECTED[$i]=$((1 - SELECTED[i])) ;;
            all)      for i in "${VIEW[@]}"; do SELECTED[$i]=1; done ;;
            none_sel) for i in "${VIEW[@]}"; do SELECTED[$i]=0; done ;;
            mode)     [ "$UI_MODE" == install ] || continue
                      if [ "$MODE" == "copy" ]; then MODE=link; else MODE=copy; fi ;;
            quit)     return 1 ;;
            enter)    [ "$(count_selected)" -gt 0 ] && return 0 ;;
        esac
    done
}

# The network and bluetooth menus need these services running
service_for() {
    case "$1" in
        ronema)         echo NetworkManager.service ;;
        rofi-bluetooth) echo bluetooth.service ;;
    esac
}

# Network services that would fight NetworkManager over the same network cards
other_network_service() {
    local svc
    for svc in systemd-networkd dhcpcd connman netctl iwd; do
        systemctl is-enabled -q "$svc" 2>/dev/null && { echo "$svc"; return; }
    done
}

# Fills the install plan from the selection
REPO_PKGS=() AUR_PKGS=() CONFLICTS=() SERVICES=() NOTES=()
build_plan() {
    local i name pkg svc other
    local -A seen=()
    REPO_PKGS=() AUR_PKGS=() CONFLICTS=() SERVICES=() NOTES=()
    for i in "${!ITEMS[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] || continue
        name="${ITEMS[$i]}"
        for pkg in $(missing_for "$name"); do
            [ -n "${seen[$pkg]:-}" ] && continue
            seen[$pkg]=1
            if [ "${MISSING[$pkg]}" == repo ]; then REPO_PKGS+=("$pkg"); else AUR_PKGS+=("$pkg"); fi
        done
        case "${STATES[$i]}" in ours|exists) CONFLICTS+=("$name") ;; esac
        svc=$(service_for "$name")
        [ -n "$svc" ] && $HAS_PACMAN || continue
        systemctl is-enabled -q "$svc" 2>/dev/null && continue
        other=""
        [ "$svc" == NetworkManager.service ] && other=$(other_network_service)
        if [ -n "$other" ]; then
            NOTES+=("The network menu needs NetworkManager, but this computer uses $other. To switch:
    sudo systemctl disable --now $other && sudo systemctl enable --now NetworkManager")
        else
            SERVICES+=("$svc")
        fi
    done
}

# Returns 0 to install, 1 to go back
review_screen() {
    local body="" i name action
    term_size
    body+="${C_BOLD}Configs${C_OFF} (${MODE})"$'\n'
    for i in "${!ITEMS[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] || continue
        name="${ITEMS[$i]}"
        case "$name:${STATES[$i]}" in
            wallpaper:present) action="${C_DIM}skip, already there${C_OFF}" ;;
            wallpaper:*)       action="copy to $WALLPAPER_DIR" ;;
            apps:*)            action="programs only" ;;
            *:linked)          if [ "$MODE" == link ]; then action="${C_DIM}skip, already linked${C_OFF}"; else action="replace link with a copy"; fi ;;
            *:ours|*:exists)   action="${C_ACC}back up${C_OFF}, then $MODE" ;;
            *)                 action="$MODE" ;;
        esac
        body+="$(printf '  %-15s %s' "$name" "$action")"$'\n'
    done
    body+=$'\n'"${C_BOLD}Programs${C_OFF}"$'\n'
    if ! $HAS_PACMAN; then
        body+="  ${C_ACC}pacman not found, programs have to be installed by hand${C_OFF}"$'\n'
    elif [ ${#REPO_PKGS[@]} -eq 0 ] && [ ${#AUR_PKGS[@]} -eq 0 ]; then
        body+="  ${C_DIM}everything needed is already installed${C_OFF}"$'\n'
    else
        if [ ${#REPO_PKGS[@]} -gt 0 ]; then
            body+="  system update first (pacman -Syu), then ${#REPO_PKGS[@]} from the Arch repos:"$'\n'
            body+="$(fold -s -w $((COLS - 8)) <<<"${REPO_PKGS[*]}" | sed "s/^/  ${C_DIM}/; s/\$/${C_OFF}/")"$'\n'
        fi
        if [ ${#AUR_PKGS[@]} -gt 0 ]; then
            body+="  ${#AUR_PKGS[@]} from the AUR"
            [ -z "$AUR_HELPER" ] && body+=" (installs the yay AUR helper first)"
            body+=":"$'\n'"$(fold -s -w $((COLS - 8)) <<<"${AUR_PKGS[*]}" | sed "s/^/  ${C_DIM}/; s/\$/${C_OFF}/")"$'\n'
        fi
    fi
    local svc note
    for svc in "${SERVICES[@]}"; do body+="  turn on ${svc%.service} (starts now and at every boot)"$'\n'; done
    if [ ${#REPO_PKGS[@]} -gt 0 ] || [ ${#AUR_PKGS[@]} -gt 0 ] || [ ${#SERVICES[@]} -gt 0 ]; then
        body+="  your password is asked once before the install starts"$'\n'
    fi
    for note in "${NOTES[@]}"; do body+=$'\n'"  ${C_ACC}${note}${C_OFF}"$'\n'; done
    ask_choice "Review" "${body%$'\n'}" "Install" "Back"
    [ "$CHOICE" == 0 ]
}

# Returns 0 for OK, 1 for Cancel
conflict_warning() {
    local body
    body="Other config(s) were detected on the computer:"$'\n'
    body+="  ${C_ACC}${CONFLICTS[*]}${C_OFF}"$'\n\n'
    body+="They will be automatically backed up to:"$'\n'
    body+="  ${C_BOLD}$SESSION_BACKUP${C_OFF}"$'\n\n'
    body+="You can open this installer anytime to put the old config back,"$'\n'
    body+="or do it yourself by moving the folders back into $DEST."
    ask_choice "Existing configs found" "$body" "OK" "Cancel"
    [ "$CHOICE" == 0 ]
}

# ---------- root helper ----------
#
# The install runs in the background, and pacman, makepkg and yay all call sudo on their
# own there. sudo's remembered password doesn't always reach those calls, and then they
# sit at a password prompt nobody can see. So after the password is entered once, a small
# helper runs as root and does the pacman calls instead. While the install runs, a "sudo"
# stand-in comes first in PATH and hands every "sudo pacman ..." to that helper.
# It accepts nothing but pacman and turning on the bluetooth / NetworkManager service,
# and quits as soon as the installer is gone.

ROOT_HELPER='
dir=$1 installer=$2
exec 3<>"$dir/cmd"
: >"$dir/ready"
while kill -0 "$installer" 2>/dev/null; do
    IFS= read -r -t 1 id <&3 || continue
    [ "$id" == quit ] && break
    [[ "$id" =~ ^[0-9]+\.[0-9]+$ ]] && [ -f "$dir/req.$id" ] || continue
    mapfile -d "" -t args <"$dir/req.$id"
    (
        cd "${args[0]}" 2>/dev/null || cd /
        case "${args[1]}" in
            pacman)
                exec stdbuf -oL -eL pacman "${args[@]:2}" ;;
            systemctl)
                if [ ${#args[@]} -eq 5 ] && [ "${args[2]}" == enable ] && [ "${args[3]}" == --now ] &&
                    [[ "${args[4]}" =~ ^(bluetooth|NetworkManager)\.service$ ]]; then
                    exec systemctl enable --now "${args[4]}"
                fi ;;
        esac
        echo "refused: ${args[*]:1}"
        exit 1
    ) >"$dir/out.$id" 2>&1 </dev/null
    echo $? >"$dir/rc.$id.tmp" && mv "$dir/rc.$id.tmp" "$dir/rc.$id"
done
rm -rf "$dir"
'

SUDO_STANDIN='#!/bin/bash
# Installer stand-in for sudo: passes pacman calls to the root helper
dir="$(dirname "$(dirname "$(readlink -f "$0")")")"
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        # makepkg runs "sudo -k pacman -U ...": these flags only matter without a command,
        # which the check after the loop answers with success
        -v|-k|-K|--validate|--reset-timestamp|--remove-timestamp) shift ;;
        -u|-g|-p|-C|-h|-U|-r|-t|-T|-D|--prompt) shift 2 ;;
        --) shift; break ;;
        *) shift ;;
    esac
done
[ $# -eq 0 ] && exit 0
name="$(basename "$1")"
case "$name" in
    pacman|systemctl) ;;
    *) echo "installer: only pacman may run as root during the install, refused: $*" >&2; exit 1 ;;
esac
shift
id="$$.$RANDOM"
mkfifo "$dir/out.$id"
printf "%s\0" "$PWD" "$name" "$@" >"$dir/req.$id"
echo "$id" >"$dir/cmd"
cat "$dir/out.$id"
while [ ! -e "$dir/rc.$id" ]; do sleep 0.2; done
rc=$(cat "$dir/rc.$id")
rm -f "$dir/req.$id" "$dir/out.$id" "$dir/rc.$id"
exit "${rc:-1}"
'

# Needs a fresh sudo ticket (get_sudo). Returns 1 if the helper couldn't start.
start_root_helper() {
    ROOT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/reko-dotfiles-root.XXXXXX") || return 1
    mkdir "$ROOT_DIR/bin"
    mkfifo "$ROOT_DIR/cmd"
    printf '%s' "$SUDO_STANDIN" >"$ROOT_DIR/bin/sudo"
    chmod +x "$ROOT_DIR/bin/sudo"
    sudo -n bash -c "$ROOT_HELPER" reko-root-helper "$ROOT_DIR" "$$" </dev/null >/dev/null 2>&1 &
    local i
    for i in $(seq 30); do
        [ -e "$ROOT_DIR/ready" ] && break
        sleep 0.1
    done
    [ -e "$ROOT_DIR/ready" ] || { rm -rf "$ROOT_DIR"; ROOT_DIR=""; return 1; }
    PATH="$ROOT_DIR/bin:$PATH"
    export PATH
}

stop_root_helper() {
    # The helper also quits on its own within a second once the installer is gone
    [ -n "$ROOT_DIR" ] && [ -p "$ROOT_DIR/cmd" ] && timeout 2 bash -c 'echo quit >"$1"' _ "$ROOT_DIR/cmd"
    ROOT_DIR=""
}

# Asks for the password and starts the root helper. Returns 1 if it failed, with the
# reason in SUDO_ERROR.
SUDO_ERROR=""
get_sudo() {
    $DRY && return 0
    if ! command -v sudo >/dev/null 2>&1; then
        SUDO_ERROR="sudo isn't installed. Install it as root with: pacman -S sudo"
        return 1
    fi
    OUT=""
    banner 6
    putf '  %sAdministrator rights needed%s' "$C_BOLD" "$C_OFF"
    putf ''
    putf '  Installing programs needs your password (it goes straight to sudo).'
    putf ''
    flush
    printf '\e[?25h'
    stty echo
    sudo -v -p "  Password for %u: "
    local rc=$?
    stty -echo
    printf '\e[?25l'
    if [ $rc -ne 0 ]; then
        SUDO_ERROR="sudo didn't accept it: the password was wrong, or $(id -un) may not use sudo.
To allow it, run as root:  usermod -aG wheel $(id -un)
and uncomment the %wheel line in /etc/sudoers (edit it with: EDITOR=nano visudo)."
        return 1
    fi
    start_root_helper || { SUDO_ERROR="sudo worked, but the helper that installs the programs didn't start."; return 1; }
}

# ======================================================================
#  Install tasks (each runs in the background, output goes to $LOG)
# ======================================================================

# Package commands only print in --dry-run, with a pause so the progress is visible
runp() {
    if $DRY; then echo "[dry-run] $*"; sleep 1; else "$@"; fi
}

# Goes through the root helper, which also makes pacman print each line right away
# (it holds its output back when writing to a file, so the o view would stay empty)
pacman_live() {
    runp sudo pacman "$@"
}

install_config() {
    local name=$1 item="$SRC/$1" target="$DEST/$1" linked=false
    [ -L "$target" ] && [ "$(readlink -f "$target")" == "$(readlink -f "$item")" ] && linked=true
    if $linked && [ "$MODE" == link ]; then
        echo "ok      $name (already linked)"
    else
        if $linked; then
            run rm "$target"
        elif [ -e "$target" ] || [ -L "$target" ]; then
            backup_item "$name" install
        fi
        run mkdir -p "$DEST"   # a brand-new account may not have ~/.config yet
        if [ "$MODE" == link ]; then
            run ln -s "$item" "$target"
            echo "link    $name"
        else
            run cp -a "$item" "$target"
            run touch "$target/$MARKER"
            echo "copy    $name"
        fi
    fi
    [ "$name" == bash ] && add_bash_hook
    if [ "$name" == hypr ]; then
        if [ "$MODE" == link ]; then set_keyboard_layout "$item"; else set_keyboard_layout "$target"; fi
    fi
    return 0
}

# hyprland.lua ships with the "us" layout; use the one this computer is set up with
set_keyboard_layout() {
    local file="$1/hyprland.lua" layout variant
    layout=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: //p')
    variant=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Variant: //p')
    # Only a console keymap set (e.g. "sk-qwertz"): its first part is the layout
    if [ -z "$layout" ]; then
        layout=$(localectl status 2>/dev/null | sed -n 's/^ *VC Keymap: //p' | cut -d- -f1)
        [ "$layout" == "(unset)" ] && layout=""
    fi
    if [ -z "$layout" ]; then
        echo "keyboard layout not set on this computer, keeping the one in hyprland.lua"
        return
    fi
    run sed -i "s|^\(\s*\)kb_layout *= *\"[^\"]*\"|\1kb_layout  = \"$layout\"|" "$file"
    [ -n "$variant" ] && run sed -i "s|^\(\s*\)-- kb_variant *= *\"[^\"]*\"|\1kb_variant = \"$variant\"|" "$file"
    echo "keyboard layout: $layout${variant:+ ($variant)}"
}

# The bash config lives in ~/.config/bash; one marked line in ~/.bashrc loads it, so the
# user's own ~/.bashrc stays as it is
BASH_HOOK='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bash/bashrc" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/bashrc"   # reko-dotfiles'

add_bash_hook() {
    if grep -qF '# reko-dotfiles' "$HOME/.bashrc" 2>/dev/null; then
        echo "ok      ~/.bashrc already loads the bash config"
        return
    fi
    if $DRY; then echo "[dry-run] add to ~/.bashrc: $BASH_HOOK"; return; fi
    printf '\n%s\n' "$BASH_HOOK" >>"$HOME/.bashrc"
    echo "hook    ~/.bashrc now loads ~/.config/bash/bashrc"
}

remove_bash_hook() {
    [ -f "$HOME/.bashrc" ] || return 0
    run sed -i '/# reko-dotfiles$/d' "$HOME/.bashrc"
    echo "unhook  removed the dotfiles line from ~/.bashrc"
}

install_wallpaper() {
    if [ -e "$WALLPAPER_DIR/$WALLPAPER" ]; then echo "ok      wallpaper (already there)"; return; fi
    run mkdir -p "$WALLPAPER_DIR"
    run cp "$DOTFILES_DIR/wallpapers/$WALLPAPER" "$WALLPAPER_DIR/"
    echo "copy    wallpaper -> $WALLPAPER_DIR"
}

bootstrap_yay() {
    pacman_live -S --needed --noconfirm git base-devel || return 1
    local tmp
    tmp=$(mktemp -d)
    runp git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || return 1
    if $DRY; then echo "[dry-run] makepkg -si --noconfirm"; sleep 1
    else (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || return 1; fi
    rm -rf "$tmp"
    if ! $DRY && ! command -v yay >/dev/null 2>&1; then
        echo "yay was built but isn't installed"
        return 1
    fi
}

# AUR packages that replace an older package under another name. The two conflict, and
# with --noconfirm pacman answers "remove the old one?" with no, so remove it first.
declare -A REPLACES=(
    [blesh-git]=blesh
)

install_aur() {
    local old=${REPLACES[$1]:-}
    if [ -n "$old" ] && pacman -Q "$old" >/dev/null 2>&1; then
        echo "remove  $old first, $1 replaces it"
        runp sudo pacman -Rdd --noconfirm "$old" || return 1
    fi
    if command -v yay >/dev/null 2>&1 || $DRY; then
        runp yay -S --needed --noconfirm --answerdiff None --answerclean None --answeredit None --removemake "$1"
    elif command -v paru >/dev/null 2>&1; then
        runp paru -S --needed --noconfirm --skipreview "$1"
    else
        echo "No AUR helper available"
        return 1
    fi
}

# Folders that ended up with the configs: the copies in ~/.config, or this folder for links
installed_dirs() {
    local i name
    for i in "${!ITEMS[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] || continue
        name="${ITEMS[$i]}"
        is_config "$name" || continue
        if [ "$MODE" == copy ] && ! $DRY; then echo "$DEST/$name"; else echo "$SRC/$name"; fi
    done
}

# The configs use /home/reko/... paths; point them at this user's config folder and home
fix_paths() {
    local f
    local -a dirs
    mapfile -t dirs < <(installed_dirs)
    { grep -rlI "$AUTHOR_HOME" "${dirs[@]}" 2>/dev/null || true; } | while IFS= read -r f; do
        run sed -i -e "s|$AUTHOR_HOME/\.config|$DEST|g" -e "s|$AUTHOR_HOME|$HOME|g" "$f"
        echo "fixed   $f"
    done
}

finish_install() {
    local d items
    while IFS= read -r d; do
        [ "$(basename "$d")" == hypr ] && run find "$d" -name '*.sh' -exec chmod +x {} +
    done < <(installed_dirs)
    $DRY && return
    mkdir -p "$DATA_DIR"
    local i new_items=() new_pkgs=() pkgs
    for i in "${!TASK_KIND[@]}"; do
        [ "${TASK_STATE[$i]}" == done ] || continue
        case "${TASK_KIND[$i]}" in
            pkg|aur)   new_pkgs+=("${TASK_ARG[$i]}") ;;
            config)    new_items+=("${TASK_ARG[$i]}") ;;
            wallpaper) [ "$(item_state wallpaper)" == new ] && new_items+=(wallpaper) ;;
        esac
    done
    items=$( (installed_items | tr ' ' '\n'; printf '%s\n' "${new_items[@]}") | grep -v '^$' | sort -u | tr '\n' ' ')
    pkgs=$( (installed_packages | tr ' ' '\n'; printf '%s\n' "${new_pkgs[@]}") | grep -v '^$' | sort -u | tr '\n' ' ')
    if [ -z "${items// }" ] && [ -z "${pkgs// }" ]; then
        rm -f "$STATE_FILE"
        echo "nothing was installed, no install info saved"
        return
    fi
    printf 'mode=%s\ndate=%s\nitems=%s\npackages=%s\nsource=%s\n' "$MODE" "$(date '+%Y-%m-%d %H:%M')" \
        "${items% }" "${pkgs% }" "$DOTFILES_DIR" >"$STATE_FILE"
    echo "saved   install info -> $STATE_FILE"
}

TASK_LABEL=() TASK_KIND=() TASK_ARG=() TASK_STATE=() TASK_SKIP=() TASK_LOG_START=()
TASK_TITLE="Installing"
add_task() {
    TASK_LABEL+=("$1") TASK_KIND+=("$2") TASK_ARG+=("${3:-}") TASK_STATE+=(queued) TASK_SKIP+=("")
}

build_tasks() {
    local i name pkg
    TASK_LABEL=() TASK_KIND=() TASK_ARG=() TASK_STATE=() TASK_SKIP=()
    if [ ${#REPO_PKGS[@]} -gt 0 ]; then
        add_task "System update" sysupdate
        for pkg in "${REPO_PKGS[@]}"; do add_task "$pkg" pkg "$pkg"; done
    fi
    if [ ${#AUR_PKGS[@]} -gt 0 ]; then
        [ -z "$AUR_HELPER" ] && add_task "yay (AUR helper)" helper
        for pkg in "${AUR_PKGS[@]}"; do add_task "$pkg" aur "$pkg"; done
    fi
    for i in "${!ITEMS[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] || continue
        name="${ITEMS[$i]}"
        if is_config "$name"; then add_task "$name config" config "$name"
        elif [ "$name" == wallpaper ]; then add_task "Wallpaper" wallpaper; fi
    done
    local svc
    for svc in "${SERVICES[@]}"; do add_task "Turn on ${svc%.service}" service "$svc"; done
    if [ "$HOME" != "$AUTHOR_HOME" ] || [ "$DEST" != "$AUTHOR_HOME/.config" ]; then
        add_task "Fix paths for your home folder" paths
    fi
    add_task "Finish up" finish
}

run_task() {
    case "$1" in
        sysupdate) pacman_live -Syu --noconfirm ;;
        pkg)       pacman_live -S --needed --noconfirm "$2" ;;
        helper)    bootstrap_yay ;;
        aur)       install_aur "$2" ;;
        config)    install_config "$2" ;;
        wallpaper) install_wallpaper ;;
        paths)     fix_paths ;;
        service)   runp sudo systemctl enable --now "$2" ;;
        finish)    finish_install ;;
        unconfig)   uninstall_config "$2" ;;
        restoreown) restore_own "$2" ;;
        unwall)     uninstall_wallpaper ;;
        unpkg)      pacman_live -Rns --noconfirm "$2" && state_remove packages "$2" ;;
    esac
}

# ---------- progress view ----------

FRAME=0
progress_bar() {
    local width=22 size=7 span pos i bar=""
    span=$((width - size))
    pos=$((FRAME % (2 * span)))
    [ "$pos" -gt "$span" ] && pos=$((2 * span - pos))
    for ((i = 0; i < width; i++)); do
        if [ "$i" -ge "$pos" ] && [ "$i" -lt $((pos + size)) ]; then bar+="${C_ACC}${G_ON}"; else bar+="${C_DIM}${G_OFF}${C_OFF}"; fi
    done
    printf '%s%s' "$bar" "$C_OFF"
}

done_word() {
    case "$1" in
        pkg|aur|helper)        echo INSTALLED ;;
        sysupdate)             echo UPDATED ;;
        unconfig|unpkg|unwall) echo REMOVED ;;
        restoreown)            echo RESTORED ;;
        service)               echo "TURNED ON" ;;
        *)                     echo DONE ;;
    esac
}

draw_progress() {
    local cur=$1 finished=${2:-false} rows top end i label kind state n_done=0 n_fail=0 n_skip=0 spin fails=""
    for state in "${TASK_STATE[@]}"; do
        [ "$state" == done ] && n_done=$((n_done + 1))
        [ "$state" == failed ] && n_fail=$((n_fail + 1))
        [ "$state" == skipped ] && n_skip=$((n_skip + 1))
    done

    OUT=""
    banner $((${#TASK_LABEL[@]} + 7))
    rows=$((ROWS - $(printf '%s' "$OUT" | grep -c '') - 6))
    [ "$rows" -lt 3 ] && rows=3
    top=$((cur - rows / 3))
    [ $((top + rows)) -gt "${#TASK_LABEL[@]}" ] && top=$((${#TASK_LABEL[@]} - rows))
    [ "$top" -lt 0 ] && top=0
    end=$((top + rows))
    [ "$end" -gt "${#TASK_LABEL[@]}" ] && end=${#TASK_LABEL[@]}

    if $finished; then
        [ $n_fail -gt 0 ] && fails=", ${C_ERR}${n_fail} failed${C_OFF}"
        [ $n_skip -gt 0 ] && fails+=", ${n_skip} skipped"
        putf '  %sFinished%s  %s/%s done%s' "$C_BOLD" "$C_OFF" "$n_done" "${#TASK_LABEL[@]}" "$fails"
    else
        putf '  %s%s%s  step %s of %s' "$C_BOLD" "$TASK_TITLE" "$C_OFF" $((cur + 1)) "${#TASK_LABEL[@]}"
    fi
    putf ''
    spin=${SPINNER[$((FRAME % ${#SPINNER[@]}))]}
    [ "$top" -gt 0 ] && putf '  %s%s %s more above%s' "$C_DIM" "$G_MORE" "$top" "$C_OFF"
    for ((i = top; i < end; i++)); do
        label="${TASK_LABEL[$i]}" kind="${TASK_KIND[$i]}"
        case "${TASK_STATE[$i]}" in
            done)    putf '  %s%s%s %-36s %s%s%s' "$C_OK" "$G_OK" "$C_OFF" "$label" "$C_OK" "$(done_word "$kind")" "$C_OFF" ;;
            failed)  putf '  %s%s%s %-36s %sFAILED%s' "$C_ERR" "$G_FAIL" "$C_OFF" "$label" "$C_ERR" "$C_OFF" ;;
            skipped) putf '  %s- %-36s SKIPPED (%s)%s' "$C_DIM" "$label" "${TASK_SKIP[$i]}" "$C_OFF" ;;
            running) putf '  %s%s%s %s%-36s%s %s' "$C_ACC" "$spin" "$C_OFF" "$C_BOLD" "$label" "$C_OFF" "$(progress_bar)" ;;
            *)       putf '  %s· %-36s QUEUED%s' "$C_DIM" "$label" "$C_OFF" ;;
        esac
    done
    [ "$end" -lt "${#TASK_LABEL[@]}" ] && putf '  %s%s %s more%s' "$C_DIM" "$G_MORE" $((${#TASK_LABEL[@]} - end)) "$C_OFF"
    putf ''
    if $finished; then putf '  %spress any key%s' "$C_DIM" "$C_OFF"
    elif $STOP; then putf '  %sstopping after this step...%s' "$C_ACC" "$C_OFF"
    else putf '  %so show terminal output · ctrl+c stops after this step%s' "$C_DIM" "$C_OFF"; fi
    flush
}

# Raw view: the normal terminal with the commands' real output
RAW=false LOG_POS=0
stream_log() {
    local size
    size=$(stat -c %s "$LOG" 2>/dev/null) || return
    if [ "$size" -gt "$LOG_POS" ]; then
        tail -c +$((LOG_POS + 1)) "$LOG" | head -c $((size - LOG_POS))
        LOG_POS=$size
    fi
}

toggle_output() {
    local cur=${1:-}
    if $RAW; then
        RAW=false
        printf '\e[?1049h'
        IN_ALT=true
    else
        RAW=true
        printf '\e[?1049l'
        IN_ALT=false
        # No alternate screen on the Linux console: clear it so the switch is visible
        $CONSOLE && printf '\e[H\e[2J'
        printf '\n%s── terminal output, now: %s · press o for the progress view ──%s\n' "$C_ACC" "$cur" "$C_OFF"
        stream_log
    fi
}

STOP=false
run_tasks() {
    local i pid rc reason helper_failed=false update_failed=false
    mkdir -p "$(dirname "$LOG")"
    : >"$LOG"
    # Ctrl+C lets the running step finish (stopping pacman halfway can break the system)
    STOP=false
    trap 'STOP=true' INT
    for i in "${!TASK_LABEL[@]}"; do
        reason=""
        case "${TASK_KIND[$i]}" in
            # Installing packages after a failed system update is a partial upgrade,
            # which can break an Arch system
            pkg|helper|aur) $update_failed && reason="needs the system update" ;;
        esac
        # Without an AUR helper the AUR packages can't install, so don't wait for each to fail
        [ -z "$reason" ] && [ "${TASK_KIND[$i]}" == aur ] && $helper_failed && reason="needs the AUR helper"
        # Stopped: still fix the paths and save what got installed
        [ -z "$reason" ] && $STOP && [ "${TASK_KIND[$i]}" != paths ] && [ "${TASK_KIND[$i]}" != finish ] && reason="stopped"
        if [ -n "$reason" ]; then
            TASK_STATE[$i]=skipped TASK_SKIP[$i]=$reason
            printf '\n==> %s: skipped, %s\n' "${TASK_LABEL[$i]}" "$reason" >>"$LOG"
            continue
        fi
        TASK_STATE[$i]=running
        printf '\n==> %s\n' "${TASK_LABEL[$i]}" >>"$LOG"
        TASK_LOG_START[$i]=$(stat -c %s "$LOG")
        run_task "${TASK_KIND[$i]}" "${TASK_ARG[$i]}" >>"$LOG" 2>&1 </dev/null &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            if $RAW; then stream_log; else draw_progress "$i"; fi
            read_key 0.1
            [ "$KEY" == output ] && toggle_output "${TASK_LABEL[$i]}"
            FRAME=$((FRAME + 1))
        done
        wait "$pid"
        rc=$?
        if [ $rc -eq 0 ]; then TASK_STATE[$i]=done; else TASK_STATE[$i]=failed; fi
        [ "${TASK_KIND[$i]}" == helper ] && [ $rc -ne 0 ] && helper_failed=true
        [ "${TASK_KIND[$i]}" == sysupdate ] && [ $rc -ne 0 ] && update_failed=true
        if [ $rc -eq 0 ]; then printf '==> %s: ok\n' "${TASK_LABEL[$i]}" >>"$LOG"
        else printf '==> %s: failed (exit %s)\n' "${TASK_LABEL[$i]}" "$rc" >>"$LOG"; fi
    done
    trap 'exit 130' INT
    if $RAW; then stream_log; toggle_output; fi
    draw_progress $((${#TASK_LABEL[@]} - 1)) true
    read_key
}

# Last lines a failed task printed, which usually say why it failed
task_error() {
    tail -c +$((TASK_LOG_START[$1] + 1)) "$LOG" | sed '/^==> /q' | grep -v '^==> ' | grep -v '^[[:space:]]*$' | tail -n 5
}

print_summary() {
    local i line reason failed=()
    local -A skipped=()
    for i in "${!TASK_LABEL[@]}"; do
        [ "${TASK_STATE[$i]}" == failed ] && failed+=("${TASK_LABEL[$i]}")
        [ "${TASK_STATE[$i]}" == skipped ] && skipped[${TASK_SKIP[$i]}]=$((${skipped[${TASK_SKIP[$i]}]:-0} + 1))
    done
    echo
    if $DRY; then
        printf '%s'"$G_OK"' Dry run finished, nothing was changed.%s\n' "$C_OK" "$C_OFF"
    elif [ ${#failed[@]} -eq 0 ] && [ ${#skipped[@]} -eq 0 ]; then
        printf '%s'"$G_OK"' %s%s\n' "$C_OK" "$SUMMARY_OK" "$C_OFF"
    elif [ ${#failed[@]} -eq 0 ]; then
        printf '%sFinished, but some steps were skipped.%s\n' "$C_ACC" "$C_OFF"
    else
        printf '%s'"$G_FAIL"' Finished with %s problem(s):%s\n' "$C_ERR" "${#failed[@]}" "$C_OFF"
        for i in "${!TASK_LABEL[@]}"; do
            [ "${TASK_STATE[$i]}" == failed ] || continue
            printf '\n  %s%s%s\n' "$C_BOLD" "${TASK_LABEL[$i]}" "$C_OFF"
            while IFS= read -r line; do printf '    %s%s%s\n' "$C_DIM" "${line:0:$((COLS - 6))}" "$C_OFF"; done < <(task_error "$i")
        done
        echo
    fi
    for reason in "${!skipped[@]}"; do
        printf '  %s step(s) skipped: %s\n' "${skipped[$reason]}" "$reason"
    done
    [ -d "$SESSION_BACKUP" ] && printf "  $SUMMARY_BACKUP\n  Run this installer again to restore them.\n" "$SESSION_BACKUP"
    local note
    for note in "${NOTES[@]}"; do printf '  %s%s%s\n' "$C_ACC" "$note" "$C_OFF"; done
    printf '  Full log: %s\n' "$LOG"
    printf '  %s\n\n' "$SUMMARY_HINT"
}

SUMMARY_OK="Reko dotfiles installed."
SUMMARY_BACKUP="Old configs backed up to %s"
SUMMARY_HINT="Log out and pick Hyprland on the login screen, or run start-hyprland from a tty.
  Already in Hyprland? Reload it with: hyprctl reload"

# ======================================================================
#  Flows
# ======================================================================

# Returns 1 when the user backed out before anything was installed
install_flow() {
    local i
    UI_MODE=install
    VIEW=()
    for i in "${!ITEMS[@]}"; do
        VIEW+=("$i")
        if [ "${ITEMS[$i]}" == apps ]; then SELECTED[$i]=0; else SELECTED[$i]=1; fi
    done
    while true; do
        select_screen || return 1
        build_plan
        review_screen || continue
        if [ ${#CONFLICTS[@]} -gt 0 ]; then conflict_warning || continue; fi
        break
    done
    if [ ${#REPO_PKGS[@]} -gt 0 ] || [ ${#AUR_PKGS[@]} -gt 0 ] || [ ${#SERVICES[@]} -gt 0 ]; then
        if ! get_sudo; then
            ask_choice "No administrator rights" "$SUDO_ERROR

Without it, programs can't be installed." "Install only the configs" "Cancel"
            [ "$CHOICE" == 0 ] || return 1
            REPO_PKGS=() AUR_PKGS=() SERVICES=()
        fi
    fi
    build_tasks
    run_tasks
    ask_choice "Show the keybinds?" "Want to see all keybinds and what they do?" "Yes, show them" "No"
    local show=$CHOICE
    tui_stop
    print_summary
    if [ "$show" == 0 ]; then
        show_keybinds
    else
        printf 'You can see all keybinds anytime with:\n  %s/install.sh --keybinds\n\n' "$DOTFILES_DIR"
    fi
    return 0
}

# Returns 1 when the user backed out
restore_flow() {
    local -a backups labels=()
    local b body
    mapfile -t backups < <(list_backups)
    for b in "${backups[@]}"; do labels+=("$(backup_date "$b")  $(backup_items "$b")"); done
    ask_choice "Restore a backup" "Pick the configs to put back. * = was a copy of these dotfiles." "${labels[@]}" "Back"
    { [ "$CHOICE" -ge 0 ] && [ "$CHOICE" -lt ${#backups[@]} ]; } || return 1
    b=${backups[$CHOICE]}

    body="These folders in $DEST will be replaced with the backed-up versions:"$'\n'
    body+="  ${C_ACC}$(backup_items "$b")${C_OFF}"$'\n\n'
    body+="Links to the dotfiles are removed. Anything else that's there now is"$'\n'
    body+="backed up first, so nothing gets lost."
    ask_choice "Restore backup from $(backup_date "$b")" "$body" "OK" "Cancel"
    [ "$CHOICE" == 0 ] || return 1

    tui_stop
    echo
    restore_backup "$b"
    echo
    printf '%s'"$G_OK"' Backup restored.%s Reload Hyprland with: hyprctl reload\n\n' "$C_OK" "$C_OFF"
    return 0
}

# ======================================================================
#  Uninstall
# ======================================================================

# Newest backup that holds the user's own (not dotfiles) config <name>
own_backup_of() {
    local d
    while IFS= read -r d; do
        grep -qxF "item=$1:own" "$d/.backup-info" && [ -e "$d/$1" ] && { echo "$d"; return; }
    done < <(list_backups)
}

uninstall_config() {
    local name=$1 target="$DEST/$1"
    if [ -L "$target" ]; then
        run rm "$target"
        echo "remove  $name (link to the dotfiles)"
    elif [ -e "$target" ]; then
        # Moved, not deleted: the copy may have the user's own edits in it
        backup_item "$name" uninstall
    fi
    [ "$name" == bash ] && remove_bash_hook
    forget_installed "$name"
}

restore_own() {
    local name=$1 dir
    dir=$(own_backup_of "$name")
    [ -n "$dir" ] || { echo "no backup of your own $name config found"; return 1; }
    if [ -e "$DEST/$name" ] || [ -L "$DEST/$name" ]; then
        echo "$DEST/$name exists, leaving your backup in $dir"
        return 1
    fi
    run mv "$dir/$name" "$DEST/$name"
    echo "restore $name from $dir"
    if ! $DRY; then
        sed -i "/^item=$name:/d" "$dir/.backup-info"
        grep -q '^item=' "$dir/.backup-info" || { rm -f "$dir/.backup-info"; rmdir "$dir" 2>/dev/null; }
    fi
}

uninstall_wallpaper() {
    run rm -f "$WALLPAPER_DIR/$WALLPAPER"
    echo "remove  $WALLPAPER_DIR/$WALLPAPER"
    forget_installed wallpaper
}

# Prints "<pkg> <packages that require it...>" for installed packages
required_by() {
    LC_ALL=C pacman -Qi "$@" 2>/dev/null | awk '
        /^Name/        { name = $3 }
        /^Required By/ { sub(/^Required By *: */, ""); req = $0; inreq = 1; next }
        inreq && /^ /  { req = req " " $0; next }
        inreq          { gsub(/None/, "", req); print name, req; inreq = 0 }'
}

# Fills UN_ITEMS, OWN_ITEMS (picked configs with the user's own config in a backup),
# REMOVE_PKGS (in a safe order), KEEP_PKGS ("pkg (needed by x)") and KEEP_FORGET (kept
# programs nothing from the dotfiles uses any more: from now on they count as the user's)
REMOVE_PKGS=() KEEP_PKGS=() KEEP_FORGET=() UN_ITEMS=() OWN_ITEMS=()
plan_uninstall() {
    local i name pkg req changed blocked
    local -A cand=() reqs=() left=()
    REMOVE_PKGS=() KEEP_PKGS=() KEEP_FORGET=() UN_ITEMS=() OWN_ITEMS=()
    for i in "${VIEW[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] || continue
        name="${ITEMS[$i]}"
        UN_ITEMS+=("$name")
        is_config "$name" && [ -n "$(own_backup_of "$name")" ] && OWN_ITEMS+=("$name")
    done

    # Programs this installer installed for the picked items...
    for name in "${UN_ITEMS[@]}"; do
        for pkg in ${PKGS[$name]:-}; do
            installed_packages | tr ' ' '\n' | grep -qxF "$pkg" && cand[$pkg]=1
        done
    done
    # ...minus the ones an item that stays still uses
    for i in "${VIEW[@]}"; do
        [ "${SELECTED[$i]}" == 1 ] && continue
        name="${ITEMS[$i]}"
        for pkg in ${PKGS[$name]:-}; do
            if [ -n "${cand[$pkg]:-}" ]; then
                unset "cand[$pkg]"
                KEEP_PKGS+=("$pkg (for $name)")
            fi
        done
    done
    for pkg in "${!cand[@]}"; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            # Already removed by hand: nothing to do, and no need to remember it
            unset "cand[$pkg]"
            state_remove packages "$pkg"
        elif [ "$pkg" == networkmanager ] && systemctl is-active -q NetworkManager 2>/dev/null; then
            unset "cand[$pkg]"
            KEEP_PKGS+=("networkmanager (runs your network connection)")
            KEEP_FORGET+=("$pkg")
        fi
    done
    [ ${#cand[@]} -eq 0 ] && return

    # ...minus the ones other installed programs depend on
    while read -r pkg req; do reqs[$pkg]=$req; done < <(required_by "${!cand[@]}")
    changed=true
    while $changed; do
        changed=false
        for pkg in "${!cand[@]}"; do
            for req in ${reqs[$pkg]:-}; do
                if [ -z "${cand[$req]:-}" ]; then
                    unset "cand[$pkg]"
                    KEEP_PKGS+=("$pkg (needed by $req)")
                    # Needed by something the dotfiles didn't install: it stays for good
                    installed_packages | tr ' ' '\n' | grep -qxF "$req" || KEEP_FORGET+=("$pkg")
                    changed=true
                    break
                fi
            done
        done
    done

    # Order: a program comes after everything in the list that depends on it
    for pkg in "${!cand[@]}"; do left[$pkg]=1; done
    while [ ${#left[@]} -gt 0 ]; do
        changed=false
        for pkg in "${!left[@]}"; do
            blocked=false
            for req in ${reqs[$pkg]:-}; do [ -n "${left[$req]:-}" ] && blocked=true; done
            $blocked && continue
            REMOVE_PKGS+=("$pkg")
            unset "left[$pkg]"
            changed=true
        done
        # A dependency loop: hand over the rest as is and let pacman sort it out
        $changed || { REMOVE_PKGS+=("${!left[@]}"); break; }
    done
}

# Returns 0 to go ahead, 1 to go back. Sets REMOVE_PROGRAMS and RESTORE_OWN.
REMOVE_PROGRAMS=false RESTORE_OWN=false
uninstall_questions() {
    local body
    REMOVE_PROGRAMS=false RESTORE_OWN=false
    term_size

    if [ ${#OWN_ITEMS[@]} -gt 0 ]; then
        body="Before the dotfiles were installed you had your own config for:"$'\n'
        body+="  ${C_ACC}${OWN_ITEMS[*]}${C_OFF}"$'\n\n'
        body+="They are still in the backups. Put them back into $DEST?"
        ask_choice "Your old configs" "$body" "Yes, put them back" "No, leave them in the backups" "Back"
        case "$CHOICE" in 0) RESTORE_OWN=true ;; 1) ;; *) return 1 ;; esac
    fi

    if [ ${#REMOVE_PKGS[@]} -eq 0 ]; then
        body="No programs to uninstall: this installer didn't install any for what you picked,"$'\n'
        body+="or something you keep still needs them. Only the configs are removed."
        if [ ${#KEEP_PKGS[@]} -gt 0 ]; then
            body+=$'\n\n'"Kept:"$'\n'
            body+="$(printf '%s, ' "${KEEP_PKGS[@]}" | sed 's/, $//' | fold -s -w $((COLS - 8)) | sed "s/^/  ${C_DIM}/; s/\$/${C_OFF}/")"
        fi
        ask_choice "Uninstall the configs?" "$body" "Uninstall" "Back"
        [ "$CHOICE" == 0 ]
        return
    fi

    body="Do you really want to uninstall the programs too, or only remove their configs?"$'\n\n'
    body+="Programs this installer installed for what you picked:"$'\n'
    body+="$(fold -s -w $((COLS - 8)) <<<"${REMOVE_PKGS[*]}" | sed "s/^/  ${C_ACC}/; s/\$/${C_OFF}/")"$'\n'
    if [ ${#KEEP_PKGS[@]} -gt 0 ]; then
        body+=$'\n'"Kept either way, because something else still needs them:"$'\n'
        body+="$(printf '%s, ' "${KEEP_PKGS[@]}" | sed 's/, $//' | fold -s -w $((COLS - 8)) | sed "s/^/  ${C_DIM}/; s/\$/${C_OFF}/")"$'\n'
    fi
    body+=$'\n'"Programs you had before the install are never removed."
    if [[ " ${REMOVE_PKGS[*]} " == *" hyprland "* ]] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        body+=$'\n'"${C_ACC}You're in Hyprland right now: it keeps running until you log out.${C_OFF}"
    fi
    ask_choice "Uninstall the programs too?" "$body" \
        "No, only remove the configs" \
        "Yes, remove the configs and uninstall the programs" \
        "Back"
    case "$CHOICE" in
        0) return 0 ;;
        1) REMOVE_PROGRAMS=true; return 0 ;;
        *) return 1 ;;
    esac
}

# Returns 1 when the user backed out before anything changed
uninstall_flow() {
    local i name pkg forget=true
    UI_MODE=uninstall
    VIEW=()
    for i in "${!ITEMS[@]}"; do
        if can_uninstall "${ITEMS[$i]}"; then VIEW+=("$i"); SELECTED[$i]=1; else SELECTED[$i]=0; fi
    done
    while true; do
        select_screen || return 1
        plan_uninstall
        uninstall_questions && break
    done
    if $REMOVE_PROGRAMS && ! get_sudo; then
        ask_choice "No administrator rights" "$SUDO_ERROR

Without it, programs can't be uninstalled." "Only remove the configs" "Cancel"
        [ "$CHOICE" == 0 ] || return 1
        REMOVE_PROGRAMS=false
        forget=false   # they wanted the programs gone: keep offering it next time
    fi

    TASK_LABEL=() TASK_KIND=() TASK_ARG=() TASK_STATE=() TASK_SKIP=() TASK_LOG_START=()
    TASK_TITLE="Uninstalling"
    for name in "${UN_ITEMS[@]}"; do
        if is_config "$name"; then
            add_task "$name config" unconfig "$name"
            if $RESTORE_OWN && [[ " ${OWN_ITEMS[*]} " == *" $name "* ]]; then
                add_task "Put back your $name config" restoreown "$name"
            fi
        elif [ "$name" == wallpaper ]; then
            add_task "Wallpaper" unwall
        fi
    done
    for pkg in "${KEEP_FORGET[@]}"; do state_remove packages "$pkg"; done
    if $REMOVE_PROGRAMS; then
        for pkg in "${REMOVE_PKGS[@]}"; do add_task "$pkg" unpkg "$pkg"; done
    elif $forget; then
        # Kept programs now belong to the user: a later uninstall won't offer to remove them
        for pkg in "${REMOVE_PKGS[@]}"; do state_remove packages "$pkg"; done
        if [[ " ${UN_ITEMS[*]} " == *" apps "* ]]; then
            for pkg in ${PKGS[apps]}; do state_remove packages "$pkg"; done
        fi
    fi

    SUMMARY_OK="Reko dotfiles uninstalled."
    SUMMARY_BACKUP="The removed configs were moved to %s"
    SUMMARY_HINT="Log out and back in so everything picks up the change."
    if [ ${#TASK_LABEL[@]} -gt 0 ]; then
        run_tasks
        tui_stop
        print_summary
    else
        tui_stop
        printf '\nDone, the apps are no longer tracked by the installer.\n'
    fi
    return 0
}

main() {
    local -a backups opts
    local body i can_un
    tui_start
    while true; do
        mapfile -t backups < <(list_backups)
        can_un=false
        for i in "${ITEMS[@]}"; do can_uninstall "$i" && { can_un=true; break; }; done
        if [ -z "$(installed_items)" ] && [ ${#backups[@]} -eq 0 ] && ! $can_un; then
            install_flow || { tui_stop; echo "Nothing was changed."; }
            return
        fi
        body=""
        if [ -n "$(installed_items)" ]; then
            body+="Reko dotfiles are already installed ($(sed -n 's/^mode=//p' "$STATE_FILE") mode, $(sed -n 's/^date=//p' "$STATE_FILE"))."$'\n'
            opts=("Reinstall / update dotfiles")
        else
            opts=("Install dotfiles")
        fi
        if [ ${#backups[@]} -gt 0 ]; then
            body+="Found ${#backups[@]} backup(s) of earlier configs in $BACKUP_ROOT."$'\n'
            opts+=("Restore from a backup")
        fi
        $can_un && opts+=("Uninstall dotfiles")
        opts+=("Quit")
        ask_choice "What do you want to do?" "${body%$'\n'}" "${opts[@]}"
        case "${opts[$CHOICE]}" in
            Quit)                    tui_stop; echo "Nothing was changed."; return ;;
            "Restore from a backup") restore_flow && return ;;
            "Uninstall dotfiles")    uninstall_flow && return ;;
            *)                       install_flow && return ;;
        esac
    done
}

main
