# Licences and credits

## Reko dotfiles

Copyright (C) 2026 Andrej "Reko" Revák

This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program
(the file `LICENSE`). If not, see <https://www.gnu.org/licenses/>.

This covers everything in this repository except the third-party parts listed below,
which keep their own licences. The full licence texts are in `LICENSE` and `LICENSES/`.

## Third-party parts

| Files                                                                                                                           | What                                                                                        | Author                                                                                                                                                               | Licence                                            |
| ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `.config/Kvantum/Future/`                                                                                                       | "Future Kvantum" Qt theme, based on the Utterly Kvantum themes                              | mrseivane ([store.kde.org/p/2142115](https://store.kde.org/p/2142115)), based on work by HimDek ([github.com/HimDek](https://github.com/HimDek/Utterly-Nord-Plasma)) | GPL-2.0, `LICENSES/GPL-2.0-only.txt`               |
| `.config/gtk-3.0/gtk.css`, `gtk-dark.css`, `assets/`                                                                            | Sunrise-Dark GTK theme, unchanged                                                           | auoi ([pling.com/p/1258305](https://www.pling.com/p/1258305))                                                                                                        | GPL-3.0, `.config/gtk-3.0/SUNRISE-THEME-COPYING`   |
| `.config/ronema/` (except `themes/reko.rasi`)                                                                                   | rofi-network-manager                                                                        | George Demesiotis ([github.com/P3rf/rofi-network-manager](https://github.com/P3rf/rofi-network-manager))                                                             | MIT, `.config/ronema/LICENSE`                      |
| `.config/rofi/amber.rasi`, `.config/rofi-bluetooth/reko.rasi`, `.config/hypr/goto/goto.rasi`, `.config/ronema/themes/reko.rasi` | rofi themes adapted from the Catppuccin "basic" rofi theme (own colours and layout changes) | Catppuccin ([github.com/catppuccin/rofi](https://github.com/catppuccin/rofi))                                                                                        | MIT, `LICENSES/MIT-Catppuccin.txt`                 |
| `.config/hypr/hyprland.lua`                                                                                                     | started from Hyprland's example config                                                      | vaxerski / Hyprland ([github.com/hyprwm/Hyprland](https://github.com/hyprwm/Hyprland))                                                                               | BSD-3-Clause, `LICENSES/BSD-3-Clause-Hyprland.txt` |
| `.config/hypr/hypridle.conf`                                                                                                    | started from hypridle's example config                                                      | Hypr Development ([github.com/hyprwm/hypridle](https://github.com/hyprwm/hypridle))                                                                                  | BSD-3-Clause, `LICENSES/BSD-3-Clause-hypridle.txt` |
| `wallpapers/Nyarch_default_walpaper.webp`                                                                                       | Nyarch Linux wallpaper, converted to WebP                                                   | Nyarch Linux ([github.com/NyarchLinux/NyarchLinux](https://github.com/NyarchLinux/NyarchLinux))                                                                      | GPL-3.0, `LICENSE`                                 |

The original of the wallpaper (its source, as the GPL calls it) is
`Gnome/etc/skel/.local/share/backgrounds/Nyarch_Wallpaper.png` in the Nyarch Linux repository:<https://github.com/NyarchLinux/NyarchLinux/blob/main/Gnome/etc/skel/.local/share/backgrounds/Nyarch_Wallpaper.png>

`.config/gtk-4.0/gtk.css` was generated with [Gradience](https://github.com/GradienceTeam/Gradience)
and only holds colour values.

Programs, fonts, cursors and sounds the installer sets up come from Arch Linux and AUR
packages under their own licences; none of them are included here.
