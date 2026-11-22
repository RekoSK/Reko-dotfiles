-- #######################################################################################
-- HYPRLAND LUA CONFIG
-- Part of Reko dotfiles, Copyright (C) 2026 Andrej "Reko" Revák, GPL-3.0-or-later.
-- Started from Hyprland's example config: BSD 3-Clause License, Copyright (c) 2022-2026,
-- vaxerski (full licence: LICENSES/BSD-3-Clause-Hyprland.txt in the dotfiles).
-- https://wiki.hypr.land/Configuring/Start/
-- #######################################################################################


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Every screen runs at its native resolution (the one it reports as preferred), at the
-- highest refresh rate it supports at that resolution. Screens plugged in later too.
-- Hyprland's own "highres" / "highrr" can pick modes the panel only accepts as input
-- (4K on a 1440p screen, 4096x2160@24 on TVs) or a small mode that refreshes faster.
-- Scale stays 1: many screens report a wrong physical size, so guessing the pixel
-- density goes wrong. For a HiDPI screen, give it its own rule with scale = 2 (or "auto").
--
-- To set a screen by hand, list it here and give it its own rule below, e.g.
--   local MANUAL_MONITORS = { ["HDMI-A-1"] = true }
--   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "auto", scale = 1 })
-- Screen names: hyprctl monitors all
local MANUAL_MONITORS = {}

-- Fallback until the best mode is known
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

local function best_mode(monitor)
    local modes = monitor.available_modes
    if type(modes) ~= "table" then return nil end

    local native
    for _, mode in ipairs(modes) do
        if mode.preferred then native = mode; break end
    end
    -- No preferred mode reported: take the largest one
    if not native then
        for _, mode in ipairs(modes) do
            if not native or mode.width * mode.height > native.width * native.height then native = mode end
        end
    end
    if not native then return nil end

    local best = native
    for _, mode in ipairs(modes) do
        if mode.width == native.width and mode.height == native.height and mode.refresh_rate > best.refresh_rate then
            best = mode
        end
    end
    return best
end

local function use_best_mode(monitor)
    if not monitor or MANUAL_MONITORS[monitor.name] then return end
    local mode = best_mode(monitor)
    if not mode then return end
    hl.monitor({
        output   = monitor.name,
        mode     = string.format("%dx%d@%.3f", mode.width, mode.height, mode.refresh_rate),
        position = "auto",
        scale    = 1,
    })
end

-- Screens already there when the config (re)loads, and every screen that connects
for _, monitor in ipairs(hl.get_monitors()) do use_best_mode(monitor) end
hl.on("monitor.added", use_best_mode)


---------------------
---- MY PROGRAMS ----
---------------------

local terminal      = "kitty"
local fileManager   = "nautilus"
local menu          = "rofi"
local notifications = "swaync"

local hyprDir    = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"
local rofiTheme  = "~/.config/rofi/amber.rasi"
local soundDir   = "/usr/share/sounds/LinuxMint/stereo/"

-- Plays one of the LinuxMint UI sounds (same command the old binds used)
local function playSound(name)
    hl.exec_cmd("paplay " .. soundDir .. name .. " --volume 65536")
end

local sounds = {
    close   = "close.oga",
    max     = "maximize.oga",
    switch  = "switch.oga",
    move    = "button-pressed.ogg",
}


-------------------
---- AUTOSTART ----
-------------------

-- Runs once when Hyprland starts (old `exec-once`)
hl.on("hyprland.start", function()
    --BASIC
    hl.exec_cmd("hyprpaper & hypridle & waybar & waypaper --restore")
    hl.exec_cmd("avizo-service &")
    --Login agent
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    --Clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")

    -- hl.exec_cmd("keepassxc")

    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland & /usr/lib/xdg-desktop-portal & /usr/lib/xdg-desktop-portal-gtk")

    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout ''")

    -- GTK theme, cursor and fonts for X11 apps (the xsettingsd option)
    hl.exec_cmd("command -v xsettingsd >/dev/null && xsettingsd")
end)

-- Runs on every config load/reload (old `exec`)
--for libadwaita gtk4 apps you can use this command:
--hl.exec_cmd([[gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"]])   -- for GTK4 apps
hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'default'")


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("ADW_DISABLE_PORTAL", "1")
--for kde apps you need to install: sudo pacman -S qt5ct qt6ct kvantum kvantum breeze-icons
--you will need to set dark theme for qt apps from kde more difficult thans with gnome :D:
-- (the old config set QT_QPA_PLATFORMTHEME to qt5ct and then overrode it with qt6ct;
--  only the value that actually took effect is kept)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.env("XCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("XCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(ffae00ee)", "rgba(ff5f00ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 15,
        rounding_power = 3,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1,
        inactive_opacity = 0.3,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a, -- rgba(1a1a1aee)
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true, -- yes, please :)
    },
})

-- Curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
local function bezier(name, x0, y0, x1, y1)
    hl.curve(name, { type = "bezier", points = { { x0, y0 }, { x1, y1 } } })
end

--     NAME,            X0,   Y0,   X1,   Y1
bezier("easeOutQuint",   0.23, 1,    0.32, 1)
bezier("easeInOutCubic", 0.65, 0.05, 0.36, 1)
bezier("linear",         0,    0,    1,    1)
bezier("almostLinear",   0.5,  0.5,  0.75, 1)
bezier("quick",          0.15, 0,    0.1,  1)
-- Define the 'feel' of the movement
bezier("fluent_decel",   0,    0.2,  0.4,  1)
bezier("easeOutExpo",    0.16, 1,    0.3,  1)
-- popin 10% means the window starts from a tiny point in the center
bezier("crt_on",         0.85, 0.0,  0.15, 1.0)

-- { NAME, SPEED, CURVE, [STYLE] }  (all enabled)
local animations = {
    { "global",           10,   "default" },
    { "border",           5.39, "easeOutQuint" },
    { "windows",          4.79, "easeOutQuint" },
    { "windowsIn",        7,    "crt_on",       "popin 10%" },  -- CRT-like open
    { "windowsOut",       1.49, "linear",       "popin 87%" },
    { "fadeIn",           1.73, "almostLinear" },
    { "fadeOut",          1.46, "almostLinear" },
    { "fade",             3.03, "quick" },
    { "layers",           3.81, "easeOutQuint" },
    { "layersIn",         4,    "easeOutQuint", "fade" },
    { "layersOut",        1.5,  "linear",       "fade" },
    { "fadeLayersIn",     1.79, "almostLinear" },
    { "fadeLayersOut",    1.39, "almostLinear" },
    { "zoomFactor",       7,    "quick" },
    -- Normal workspaces slide horizontally (direction follows the workspace number)
    { "workspaces",       1,    "fluent_decel", "slide" },
    -- Special workspace drops in vertically
    { "specialWorkspace", 3,    "fluent_decel", "slidevert" },
}

for _, a in ipairs(animations) do
    hl.animation({ leaf = a[1], enabled = true, speed = a[2], bezier = a[3], style = a[4] })
end

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

hl.config({
    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        --pseudotile = true, -- Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true, -- You probably want this
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = -1,   -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo    = true, -- If true disables the random hyprland logo / anime girl background. :(
        disable_splash_rendering = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",   -- the installer sets this to the computer's layout
        -- kb_variant = "qwertz",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Example per-device config
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

local function key(k) return mainMod .. " + " .. k end

-- Binds a key to a dispatcher and plays a sound first
local function bindWithSound(keys, sound, dispatcher)
    hl.bind(keys, function()
        playSound(sound)
        hl.dispatch(dispatcher)
    end)
end

hl.bind(key("T"), hl.dsp.exec_cmd(terminal))
bindWithSound(key("Q"), sounds.close, hl.dsp.window.close())
hl.bind(key("M"), hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(key("E"),         hl.dsp.exec_cmd("sh " .. hyprDir .. "/goto/goto_menu.sh nautilus"))
hl.bind(key("SHIFT + E"), hl.dsp.exec_cmd("sh " .. hyprDir .. "/goto/goto_menu.sh kitty"))
hl.bind(key("F"), hl.dsp.window.float({ action = "toggle" }))

--ROFI
hl.bind(key("R"),         hl.dsp.exec_cmd("rofi -show drun -theme " .. rofiTheme))
hl.bind(key("SHIFT + R"), hl.dsp.exec_cmd("rofi -show run -theme " .. rofiTheme))
hl.bind("ALT + TAB",      hl.dsp.exec_cmd("rofi -show window -theme " .. rofiTheme))

hl.bind(key("P"), hl.dsp.window.pseudo())          -- dwindle
hl.bind(key("J"), hl.dsp.layout("togglesplit"))    -- dwindle
hl.bind(key("B"), hl.dsp.exec_cmd("sh " .. hyprDir .. "/pwdmanager_logic.sh"))
bindWithSound(key("W"), sounds.max, hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(key("SHIFT + W"), hl.dsp.window.fullscreen())
hl.bind(key("C"), hl.dsp.exec_cmd("gnome-calculator"))
hl.bind(key("SHIFT + L"), hl.dsp.exec_cmd("hyprlock"))

-- Move focus with mainMod + arrow keys
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(key(dir), hl.dsp.focus({ direction = dir }))
end

-- Printscreens
hl.bind("Print",      hl.dsp.exec_cmd("sh " .. hyprDir .. "/hyprshot.sh output"))
hl.bind(key("Print"), hl.dsp.exec_cmd("sh " .. hyprDir .. "/hyprshot.sh region"))

--clipboard
hl.bind(key("CTRL + C"),         hl.dsp.exec_cmd([[cliphist list | rofi -dmenu -p "󰅍 Clipboard" -theme ]] .. rofiTheme .. " | cliphist decode | wl-copy"))
hl.bind(key("CTRL + SHIFT + C"), hl.dsp.exec_cmd([[cliphist wipe && notify-send "Wiped clipboard."]]))

-- Switch workspaces with mainMod + [1-0]
-- Move active window to a workspace with mainMod + SHIFT + [1-0]
-- Keycodes 10-19 are the physical number row, so this works with any keyboard layout
for i = 1, 10 do
    local numKey = "code:" .. (i + 9)
    bindWithSound(key(numKey),             sounds.switch, hl.dsp.focus({ workspace = i }))
    bindWithSound(key("SHIFT + " .. numKey), sounds.move,   hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
bindWithSound(key("S"),         sounds.switch, hl.dsp.workspace.toggle_special("magic"))
bindWithSound(key("SHIFT + S"), sounds.move,   hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
bindWithSound(key("mouse_down"), sounds.switch, hl.dsp.focus({ workspace = "e+1" }))
bindWithSound(key("mouse_up"),   sounds.switch, hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
local mediaKeys = {
    XF86AudioRaiseVolume  = "volumectl raise",
    XF86AudioLowerVolume  = "volumectl lower",
    XF86AudioMute         = "volumectl toggle-mute",
    XF86AudioMicMute      = "volumectl -m toggle-mute",
    XF86MonBrightnessUp   = "lightctl raise",
    XF86MonBrightnessDown = "lightctl lower",
}
for k, cmd in pairs(mediaKeys) do
    hl.bind(k, hl.dsp.exec_cmd(cmd), { locked = true, repeating = true })
end

-- Requires playerctl
local playerKeys = {
    XF86AudioNext  = "next",
    XF86AudioPause = "play-pause",
    XF86AudioPlay  = "play-pause",
    XF86AudioPrev  = "previous",
}
for k, action in pairs(playerKeys) do
    hl.bind(k, hl.dsp.exec_cmd("playerctl " .. action), { locked = true })
end


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- NOTE: rule order matters where noted below.

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

--Floating
for _, class in ipairs({
    "org.gnome.Calculator",
    "discord",
    "io.missioncenter.MissionCenter",
    "org.keepassxc.KeePassXC",
}) do
    hl.window_rule({ match = { class = class }, float = true })
end

--Opaque
for _, class in ipairs({
    "kitty",
    "jetbrains-rider",
    "jetbrains-rustrover",
    "jetbrains-studio",
    "brave-browser",
    "brave-origin",
    "code",       -- VSCODE
    "ONLYOFFICE",
}) do
    hl.window_rule({ match = { class = class }, opaque = true })
end

--Floating + slightly transparent (Calendar, Nautilus)
for name, class in pairs({
    calendar = "org.gnome.Calendar",
    nautilus = "org.gnome.Nautilus",
}) do
    hl.window_rule({
        name    = name,
        match   = { class = class },
        float   = true,
        opacity = "0.9",
    })
end

--Jetbrains popup windows
for _, ide in ipairs({ "rider", "rustrover", "studio" }) do
    hl.window_rule({
        name  = "jetbrains-" .. ide .. "_windowfix",
        match = { class = "jetbrains-" .. ide, title = ".*win.*" },

        --stay_focused = true,
        float    = true,
        no_anim  = true,
        pin      = true,
        no_focus = true,
    })
end

--Unity
hl.window_rule({
    name  = "unityeditor",
    match = { class = "Unity", initial_title = ".+" },

    opaque = true,
})
hl.window_rule({
    -- toto MUSÍ byť za unityeditor (must come AFTER unityeditor)
    name  = "unity-loading-fix",
    match = { title = "Unity" },

    no_focus = true,
    opacity  = "0.9",
    opaque   = false,
})

--Brave
hl.window_rule({
    name  = "brave-save-fix",
    match = { class = "brave(-origin)?", title = ".*wants to save.*" },

    float = true,
})

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
