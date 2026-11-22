# Reko's Dotfiles

## Contents

```
.config/
├── hypr/            Hyprland (hyprland.lua), hypridle, hyprlock, polkit agent
│   ├── goto/        rofi "Places" menu (SUPER+E / SUPER+SHIFT+E)
│   ├── USB/         waybar USB drive widgets (mount / eject)
│   └── *.sh         screenshot, logout/reboot, password-manager helpers
├── waybar/          top bar (config.jsonc + style.css)
├── rofi/            amber.rasi – launcher, alt-tab, clipboard theme
├── rofi-bluetooth/  bluetooth menu theme
├── ronema/          rofi network manager config + themes
├── kitty/           terminal
├── bash/            shell setup: starship prompt, ble.sh, fzf, zoxide, eza (loaded from ~/.bashrc)
├── avizo/           volume / brightness OSD
├── waypaper/        wallpaper picker (hyprpaper backend)
├── gtk-3.0, gtk-4.0, nwg-look, xsettingsd   GTK theming (gtk-3.0 carries the Sunrise-Dark theme, GPLv3)
└── qt5ct, qt6ct, Kvantum                     Qt theming (Kvantum "Future")
wallpapers/          default wallpaper
```

## Install

```bash
git clone <this repo> && cd hyprland
./install.sh             # open the installer
./install.sh --dry-run   # walk through it without changing anything
./install.sh --link      # start in link mode instead of copy mode
./install.sh --keybinds  # list all keybinds and what they do
```

Run it as your normal user (not with `sudo`) on Arch Linux. The installer:

1. **Lets you pick** which configs to install. Each line shows whether that config is new, already installed, or one of your own that will be backed up, and how many programs it still needs.
2. **Shows a review** of what will be copied, backed up and installed.
3. **Warns about existing configs** and says where they will be backed up (`~/.local/share/reko-dotfiles/backups/<date>/`). Pick OK to continue or Cancel to go back.
4. **Asks for your password once** if programs are missing, then runs a system update (`pacman -Syu`) and installs them from the Arch repos and the AUR (it sets up `yay` first if you have no AUR helper). If the update fails, no packages are installed, because installing on a half-updated system can break it.
5. **Shows the progress** of every step. Press `o` to switch to the real terminal output and `o` again to get back. `Ctrl+C` stops after the current step. The full log is saved next to the backups.
6. **Turns on NetworkManager and Bluetooth** for the network and bluetooth menus, unless another network service already runs your connection (then it tells you how to switch).

Paths in the configs are written for `/home/reko`; the installer rewrites them to your home folder. It also sets the keyboard layout to the one your system uses.

Afterwards, log out and pick Hyprland on the login screen, or run `start-hyprland` from a tty.

### Screens

Every screen runs at its native resolution at the highest refresh rate it supports there, including screens plugged in later. Scale stays at 1; for a HiDPI screen, or to pick a mode yourself, see the comments at the top of `hypr/hyprland.lua`.

### Keys in the selector

| Key               | Action                            |
| ----------------- | --------------------------------- |
| `↑` `↓` / `j` `k` | move                              |
| `space`           | toggle item                       |
| `a` / `n`         | select all / none                 |
| `m`               | switch between copy and link mode |
| `enter`           | continue to the review            |
| `q` / `esc`       | quit without changing anything    |

**Copy mode** (default) puts an independent copy in `~/.config`. You can delete the cloned folder afterwards, and your own edits never touch the repo.
**Link mode** makes `~/.config/<name>` a symlink into the cloned folder. A `git pull` updates your setup straight away, but the folder has to stay where it is.

### Uninstall and undo

Run `./install.sh` again. When it finds an earlier install or backups, it offers to reinstall, **restore a backup** or **uninstall**.

**Uninstall** lists everything the installer put on the system. Untick what you want to keep. Then:

1. If you had your own config for something before the install, it asks whether to put it back.
2. It asks whether to **uninstall the programs too, or only remove their configs**. Only programs the installer installed itself are offered. Programs you already had, and ones something you keep still needs, are never removed.

Removed configs are moved to a backup, not deleted, so edits you made to them aren't lost.

**Restore a backup** puts old folders back into `~/.config`; whatever is there at that moment is backed up first. You can also move the folders back from `~/.local/share/reko-dotfiles/backups/` yourself.

## Dependencies

| Purpose     | Packages                                                                                                                        |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Core        | `hyprland` `hyprpaper` `hypridle` `hyprlock` `xdg-desktop-portal-hyprland` `xdg-desktop-portal-gtk` `polkit-gnome`              |
| Bar / menus | `waybar` `rofi` `rofi-bluetooth-git` `swaync` `waypaper` `networkmanager` `bluez` `bluez-utils`                                 |
| Apps        | `kitty` `nautilus` `gnome-calculator` `gnome-calendar` `mission-center` `keepassxc` `brave-origin-bin`                          |
| Shell       | `blesh-git` `eza` `fzf` `starship` `zoxide`                                                                                     |
| Utilities   | `hyprshot` `cliphist` `wl-clipboard` `avizo` `playerctl` `brightnessctl` `libnotify` `udisks2` `libpulse` (paplay) `xsettingsd` |
| Theming     | `nwg-look` `qt5ct` `qt6ct` `kvantum` `bibata-cursor-theme` `ttf-jetbrains-mono-nerd` `inter-font` `otf-space-grotesk`           |
| Sounds      | LinuxMint sound theme (`cinnamon-sounds`), `sound-theme-freedesktop`                                                            |

The installer installs all of these for the parts you pick.

The network menu is [rofi-network-manager](https://github.com/P3rf/rofi-network-manager) by George Demesiotis (MIT, licence in `ronema/LICENSE`).

## Keybindings

`SUPER` is the main modifier. The installer sets the keyboard layout to the one your system uses.
Run `./install.sh --keybinds` to see this list in the terminal.

| Keys                                    | Action                                          |
| --------------------------------------- | ----------------------------------------------- |
| `SUPER + T`                             | kitty                                           |
| `SUPER + Q`                             | close window                                    |
| `SUPER + M`                             | exit Hyprland                                   |
| `SUPER + E` / `SUPER + SHIFT + E`       | Places menu → Nautilus / kitty                  |
| `SUPER + R` / `SUPER + SHIFT + R`       | rofi drun / run                                 |
| `ALT + TAB`                             | rofi window switcher                            |
| `SUPER + C`                             | Calculator                                      |
| `SUPER + B`                             | KeePassXC + Brave Origin                        |
| `SUPER + F`                             | toggle floating                                 |
| `SUPER + W` / `SUPER + SHIFT + W`       | maximize / fullscreen                           |
| `SUPER + P` / `SUPER + J`               | pseudotile / toggle split                       |
| `SUPER + SHIFT + L`                     | lock screen                                     |
| `SUPER + arrows`                        | move focus                                      |
| `SUPER + 1..0` / `SUPER + SHIFT + 1..0` | switch to / move window to workspace            |
| `SUPER + S` / `SUPER + SHIFT + S`       | toggle / move to scratchpad                     |
| `SUPER + scroll`                        | cycle workspaces                                |
| `SUPER + LMB / RMB drag`                | move / resize window                            |
| `Print` / `SUPER + Print`               | screenshot whole output / region (to clipboard) |
| `SUPER + CTRL + C`                      | clipboard history                               |
| `SUPER + CTRL + SHIFT + C`              | wipe clipboard history                          |
| Media keys                              | volume, mic, brightness (avizo), playerctl      |

## License

Copyright (C) 2026 Andrej "Reko" Revák

These dotfiles are free software under the [GNU General Public License v3.0 or later](LICENSE).
Some parts come from other projects and keep their own licences: the Kvantum "Future" theme
(GPL-2.0), the Sunrise-Dark GTK theme (GPL-3.0), rofi-network-manager (MIT), the
Catppuccin-based rofi themes (MIT), the Hyprland and hypridle example configs (BSD-3-Clause)
and the Nyarch Linux wallpaper (GPL-3.0). [NOTICE.md](NOTICE.md) lists who made what, where it
comes from and which file holds each licence.
