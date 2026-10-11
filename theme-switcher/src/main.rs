//! theme-switch: a small theme switcher for this Hyprland + Waybar setup.
//!
//! App themes (amethyst/nord/gruvbox) rewrite these generated files:
//!   - ~/.config/hypr/theme.conf       (sourced by hyprland.conf)
//!   - ~/.config/waybar/colors.css     (@imported by waybar/style.css)
//!   - ~/.config/waybar/omarchy-colors.css (@imported by HANCORE layouts)
//!   - ~/.config/wofi/style.css        (read by wofi at each launch)
//!   - ~/.config/ghostty/theme-active  (config-file'd by ghostty/config)
//!   - ~/.config/dunst/dunstrc         (themed notifications; dunst restarted)
//! They also set the waybar layout the theme prefers.
//!
//! Waybar layouts (named HANCORE imports, plus "default") swap only Waybar's
//! config.jsonc + style.css; their colors come from the active app theme.
//! Assets live in ~/.config/theme-switcher/waybar-layouts/<name>/.
//!
//! After writing it reloads Hyprland (`hyprctl reload`), restarts Waybar, and
//! reloads running Ghostty instances (SIGUSR2). Wofi picks up its style on the
//! next launch, so no reload is needed there.

use std::env;
use std::fs;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

/// println! that is silenced when `$v` (verbose) is false. Used so the live
/// preview TUI isn't corrupted by apply/reload status output.
macro_rules! vprintln {
    ($v:expr, $($arg:tt)*) => {
        if $v { println!($($arg)*); }
    };
}
macro_rules! veprintln {
    ($v:expr, $($arg:tt)*) => {
        if $v { eprintln!($($arg)*); }
    };
}

/// Hyprland border/shadow colors for a theme. Values are raw Hyprland color
/// tokens (e.g. `rgba(4B0082ee)`).
struct Hyprland {
    active_border_1: &'static str,
    active_border_2: &'static str,
    inactive_border: &'static str,
    shadow: &'static str,
}

/// Waybar palette. Values are raw CSS colors used in `@define-color`.
struct Waybar {
    text_faint: &'static str,
    text_muted: &'static str,
    text_default: &'static str,
    text_bright: &'static str,
    tab_inactive: &'static str,
    tab_active: &'static str,
}

struct Theme {
    name: &'static str,
    description: &'static str,
    hyprland: Hyprland,
    waybar: Waybar,
    /// Full wofi stylesheet, written verbatim to ~/.config/wofi/style.css.
    /// nord/gruvbox come from github.com/joao-vitor-sr/wofi-themes-collection.
    wofi: &'static str,
    /// Name of a bundled Ghostty theme (see `ghostty +list-themes`).
    ghostty: &'static str,
    /// Colors used to drive imported waybar layouts (HANCORE themes) via the
    /// generated ~/.config/waybar/omarchy-colors.css file.
    bar_bg: &'static str,
    bar_fg: &'static str,
    bar_red: &'static str,
    /// Which waybar layout this theme uses (asset dir name under
    /// waybar-layouts/). "default" restores the user's original bar.
    waybar_layout: &'static str,
}

/// Imported HANCORE waybar layouts (random names). These only change Waybar;
/// their stylesheet colors come from the active app theme's bar palette.
/// Assets live in ~/.config/theme-switcher/waybar-layouts/<name>/.
// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Random names for imported waybar layouts instead of version ids. 2026-08-24.
const LAYOUTS: &[&str] = &[
    "nimbus", "lantern", "foxglove", "pebble", "drift", "cinder", "thistle", "marble", "lichen",
    "willow", "cedar", "frost", "quartz", "umber", "kelpie", "brimstone",
];
// LLM PROMPT [end]

const WOFI_AMETHYST: &str = "window {
margin: 0px;
border: 1px solid #4b0082;
background-color: #1a1420;
}

#input {
margin: 5px;
border: none;
color: #e6e0f8;
background-color: #2a2035;
}

#inner-box {
margin: 5px;
border: none;
background-color: #1a1420;
}

#outer-box {
margin: 5px;
border: none;
background-color: #1a1420;
}

#scroll {
margin: 0px;
border: none;
}

#text {
margin: 5px;
border: none;
color: #e6e0f8;
}

#entry:selected {
background-color: #3a2f4a;
}
";

const WOFI_NORD: &str = "window {
margin: 0px;
border: 1px solid #88c0d0;
background-color: #2e3440;
}

#input {
margin: 5px;
border: none;
color: #d8dee9;
background-color: #3b4252;
}

#inner-box {
margin: 5px;
border: none;
background-color: #2e3440;
}

#outer-box {
margin: 5px;
border: none;
background-color: #2e3440;
}

#scroll {
margin: 0px;
border: none;
}

#text {
margin: 5px;
border: none;
color: #d8dee9;
}

#entry:selected {
background-color: #3b4252;
}
";

const WOFI_OPENSHIFT: &str = "window {
margin: 0px;
border: 1px solid #ee0000;
background-color: #151515;
}

#input {
margin: 5px;
border: none;
color: #f0f0f0;
background-color: #212427;
}

#inner-box {
margin: 5px;
border: none;
background-color: #151515;
}

#outer-box {
margin: 5px;
border: none;
background-color: #151515;
}

#scroll {
margin: 0px;
border: none;
}

#text {
margin: 5px;
border: none;
color: #f0f0f0;
}

#entry:selected {
background-color: #ee0000;
}

#text:selected {
color: #ffffff;
}
";

// LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Wofi stylesheet for the cobble dark-red theme. 2026-08-24.
const WOFI_COBBLE: &str = "window {
margin: 0px;
border: 1px solid #6e1c28;
background-color: #140c0e;
}

#input {
margin: 5px;
border: none;
color: #e8e4e4;
background-color: #2a1c20;
}

#inner-box {
margin: 5px;
border: none;
background-color: #140c0e;
}

#outer-box {
margin: 5px;
border: none;
background-color: #140c0e;
}

#scroll {
margin: 0px;
border: none;
}

#text {
margin: 5px;
border: none;
color: #c8c2c2;
}

#entry:selected {
background-color: #6e1c28;
}

#text:selected {
color: #ffffff;
}
";
// LLM PROMPT [end]

const WOFI_GRUVBOX: &str = "window {
margin: 0px;
border: 1px solid #928374;
background-color: #282828;
}

#input {
margin: 5px;
border: none;
color: #ebdbb2;
background-color: #1d2021;
}

#inner-box {
margin: 5px;
border: none;
background-color: #282828;
}

#outer-box {
margin: 5px;
border: none;
background-color: #282828;
}

#scroll {
margin: 0px;
border: none;
}

#text {
margin: 5px;
border: none;
color: #ebdbb2;
}

#entry:selected {
background-color: #1d2021;
}
";

const THEMES: &[Theme] = &[
    Theme {
        name: "amethyst",
        description: "Deep purple (the original look)",
        hyprland: Hyprland {
            active_border_1: "rgba(4B0082ee)",
            active_border_2: "rgba(2E0055ee)",
            inactive_border: "rgba(3A0033aa)",
            shadow: "rgba(1a1a1aee)",
        },
        waybar: Waybar {
            text_faint: "rgba(196, 186, 220, 0.36)",
            text_muted: "rgba(196, 186, 220, 0.58)",
            text_default: "rgba(230, 224, 248, 0.88)",
            text_bright: "rgba(242, 238, 252, 0.96)",
            tab_inactive: "rgba(180, 165, 210, 0.55)",
            tab_active: "#d4b8ff",
        },
        wofi: WOFI_AMETHYST,
        ghostty: "Purplepeter",
        bar_bg: "#1a1420",
        bar_fg: "#e6e0f8",
        bar_red: "#e78284",
        waybar_layout: "default",
    },
    Theme {
        name: "nord",
        description: "Cool arctic blue",
        hyprland: Hyprland {
            active_border_1: "rgba(88C0D0ee)",
            active_border_2: "rgba(5E81ACee)",
            inactive_border: "rgba(3B4252aa)",
            shadow: "rgba(2E3440ee)",
        },
        waybar: Waybar {
            text_faint: "rgba(180, 200, 220, 0.36)",
            text_muted: "rgba(180, 200, 220, 0.58)",
            text_default: "rgba(216, 222, 233, 0.90)",
            text_bright: "rgba(236, 239, 244, 0.98)",
            tab_inactive: "rgba(129, 161, 193, 0.60)",
            tab_active: "#88c0d0",
        },
        wofi: WOFI_NORD,
        ghostty: "Nord",
        bar_bg: "#2e3440",
        bar_fg: "#d8dee9",
        bar_red: "#bf616a",
        waybar_layout: "default",
    },
    Theme {
        name: "gruvbox",
        description: "Warm retro amber",
        hyprland: Hyprland {
            active_border_1: "rgba(FE8019ee)",
            active_border_2: "rgba(D65D0Eee)",
            inactive_border: "rgba(3C3836aa)",
            shadow: "rgba(1D2021ee)",
        },
        waybar: Waybar {
            text_faint: "rgba(213, 196, 161, 0.36)",
            text_muted: "rgba(213, 196, 161, 0.58)",
            text_default: "rgba(235, 219, 178, 0.90)",
            text_bright: "rgba(251, 241, 199, 0.98)",
            tab_inactive: "rgba(214, 153, 33, 0.60)",
            tab_active: "#fabd2f",
        },
        wofi: WOFI_GRUVBOX,
        ghostty: "Gruvbox Dark",
        bar_bg: "#282828",
        bar_fg: "#ebdbb2",
        bar_red: "#cc241d",
        waybar_layout: "default",
    },
    Theme {
        name: "openshift",
        description: "Red Hat / OpenShift red on black",
        hyprland: Hyprland {
            active_border_1: "rgba(EE0000ee)",
            active_border_2: "rgba(CC0000ee)",
            inactive_border: "rgba(212427aa)",
            shadow: "rgba(030303ee)",
        },
        waybar: Waybar {
            text_faint: "rgba(240, 240, 240, 0.36)",
            text_muted: "rgba(240, 240, 240, 0.58)",
            text_default: "rgba(240, 240, 240, 0.90)",
            text_bright: "rgba(255, 255, 255, 0.98)",
            tab_inactive: "rgba(210, 210, 210, 0.55)",
            tab_active: "#ee0000",
        },
        wofi: WOFI_OPENSHIFT,
        ghostty: "IR Black",
        bar_bg: "#151515",
        bar_fg: "#f0f0f0",
        bar_red: "#ee0000",
        waybar_layout: "openshift",
    },
    // LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Cobble app theme using dark red, charcoal, grey, and white. 2026-08-24.
    Theme {
        name: "cobble",
        description: "Dark red, charcoal grey, and white",
        hyprland: Hyprland {
            active_border_1: "rgba(2A1218ee)",
            active_border_2: "rgba(140A0Eee)",
            inactive_border: "rgba(0E0C0Dcc)",
            shadow: "rgba(050304ee)",
        },
        waybar: Waybar {
            text_faint: "rgba(200, 194, 194, 0.36)",
            text_muted: "rgba(200, 194, 194, 0.58)",
            text_default: "rgba(232, 228, 228, 0.90)",
            text_bright: "rgba(255, 255, 255, 0.98)",
            tab_inactive: "rgba(140, 132, 134, 0.55)",
            tab_active: "#8b1e2d",
        },
        wofi: WOFI_COBBLE,
        ghostty: "Red Planet",
        bar_bg: "#140c0e",
        bar_fg: "#e8e4e4",
        bar_red: "#6e1c28",
        waybar_layout: "cobble",
    },
    // LLM PROMPT [end]
];

fn config_dir() -> PathBuf {
    if let Ok(dir) = env::var("XDG_CONFIG_HOME") {
        if !dir.is_empty() {
            return PathBuf::from(dir);
        }
    }
    let home = env::var("HOME").expect("HOME is not set");
    PathBuf::from(home).join(".config")
}

fn find_theme(name: &str) -> Option<&'static Theme> {
    THEMES.iter().find(|t| t.name.eq_ignore_ascii_case(name))
}

fn current_theme_path() -> PathBuf {
    config_dir().join("theme-switcher").join("current")
}

fn current_theme() -> Option<String> {
    fs::read_to_string(current_theme_path())
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn render_hypr(theme: &Theme) -> String {
    let h = &theme.hyprland;
    format!(
        "# Generated by theme-switch. Do not edit by hand.\n\
         # Active theme: {name}\n\
         # Sourced from hyprland.conf; referenced in the general{{}} and decoration{{}} blocks.\n\
         $activeBorder1 = {a1}\n\
         $activeBorder2 = {a2}\n\
         $inactiveBorder = {inactive}\n\
         $shadowColor = {shadow}\n",
        name = theme.name,
        a1 = h.active_border_1,
        a2 = h.active_border_2,
        inactive = h.inactive_border,
        shadow = h.shadow,
    )
}

fn render_css(theme: &Theme) -> String {
    let w = &theme.waybar;
    format!(
        "/* Generated by theme-switch. Do not edit by hand. */\n\
         /* Active theme: {name} */\n\
         @define-color text_faint {faint};\n\
         @define-color text_muted {muted};\n\
         @define-color text_default {default};\n\
         @define-color text_bright {bright};\n\
         @define-color tab_inactive {tab_inactive};\n\
         @define-color tab_active {tab_active};\n",
        name = theme.name,
        faint = w.text_faint,
        muted = w.text_muted,
        default = w.text_default,
        bright = w.text_bright,
        tab_inactive = w.tab_inactive,
        tab_active = w.tab_active,
    )
}

/// Colors that drive imported HANCORE waybar layouts, derived from the active
/// app theme. Written to ~/.config/waybar/omarchy-colors.css (which the layout
/// stylesheets @import in place of Omarchy's own color file).
fn render_omarchy_colors(theme: &Theme) -> String {
    format!(
        "/* Generated by theme-switch. Do not edit by hand. */\n\
         /* Bar colors from app theme: {name} */\n\
         @define-color background {bg};\n\
         @define-color foreground {fg};\n\
         @define-color red {red};\n\
         @define-color transparent rgba(0, 0, 0, 0);\n",
        name = theme.name,
        bg = theme.bar_bg,
        fg = theme.bar_fg,
        red = theme.bar_red,
    )
}

/// A themed dunst config (~/.config/dunst/dunstrc): rounded, padded, Nerd-Font,
/// with frame/accent from the theme and red for critical alerts.
fn render_dunst(theme: &Theme) -> String {
    let bg = theme.bar_bg;
    let fg = theme.bar_fg;
    let accent = theme.waybar.tab_active;
    let red = theme.bar_red;
    format!(
        "# Generated by theme-switch. Do not edit by hand.\n\
         # Active theme: {name}\n\
         [global]\n\
         \x20   monitor = 0\n\
         \x20   follow = mouse\n\
         \x20   width = 360\n\
         \x20   height = (0, 140)\n\
         \x20   origin = top-right\n\
         \x20   offset = (12, 12)\n\
         \x20   scale = 0\n\
         \x20   notification_limit = 5\n\
         \x20   progress_bar = true\n\
         \x20   progress_bar_height = 8\n\
         \x20   progress_bar_frame_width = 0\n\
         \x20   progress_bar_min_width = 150\n\
         \x20   progress_bar_max_width = 344\n\
         \x20   indicate_hidden = yes\n\
         \x20   transparency = 0\n\
         \x20   separator_height = 2\n\
         \x20   padding = 14\n\
         \x20   horizontal_padding = 16\n\
         \x20   text_icon_padding = 10\n\
         \x20   frame_width = 2\n\
         \x20   frame_color = \"{accent}\"\n\
         \x20   gap_size = 6\n\
         \x20   separator_color = frame\n\
         \x20   sort = yes\n\
         \x20   font = CaskaydiaCove Nerd Font 10\n\
         \x20   line_height = 2\n\
         \x20   markup = full\n\
         \x20   format = \"<b>%s</b>\\n%b\"\n\
         \x20   alignment = left\n\
         \x20   vertical_alignment = center\n\
         \x20   show_age_threshold = 60\n\
         \x20   ellipsize = middle\n\
         \x20   ignore_newline = no\n\
         \x20   stack_duplicates = true\n\
         \x20   hide_duplicate_count = false\n\
         \x20   show_indicators = yes\n\
         \x20   enable_recursive_icon_lookup = true\n\
         \x20   icon_theme = \"Adwaita, breeze, hicolor\"\n\
         \x20   icon_position = left\n\
         \x20   min_icon_size = 24\n\
         \x20   max_icon_size = 48\n\
         \x20   corner_radius = 10\n\
         \x20   mouse_left_click = do_action, close_current\n\
         \x20   mouse_middle_click = do_action, close_current\n\
         \x20   mouse_right_click = close_all\n\
         \n\
         [urgency_low]\n\
         \x20   background = \"{bg}f0\"\n\
         \x20   foreground = \"{fg}\"\n\
         \x20   frame_color = \"{accent}\"\n\
         \x20   timeout = 5\n\
         \n\
         [urgency_normal]\n\
         \x20   background = \"{bg}f0\"\n\
         \x20   foreground = \"{fg}\"\n\
         \x20   frame_color = \"{accent}\"\n\
         \x20   timeout = 8\n\
         \n\
         [urgency_critical]\n\
         \x20   background = \"{bg}f0\"\n\
         \x20   foreground = \"{fg}\"\n\
         \x20   frame_color = \"{red}\"\n\
         \x20   timeout = 0\n",
        name = theme.name,
        bg = bg,
        fg = fg,
        accent = accent,
        red = red,
    )
}

fn layouts_dir() -> PathBuf {
    config_dir().join("theme-switcher").join("waybar-layouts")
}

fn find_layout(name: &str) -> Option<&'static str> {
    LAYOUTS.iter().copied().find(|l| l.eq_ignore_ascii_case(name))
}

fn current_layout_path() -> PathBuf {
    config_dir().join("theme-switcher").join("current-layout")
}

fn current_layout() -> Option<String> {
    fs::read_to_string(current_layout_path())
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

/// The app theme whose palette drives colors. Falls back to the first theme.
fn active_theme() -> &'static Theme {
    current_theme()
        .and_then(|n| find_theme(&n))
        .unwrap_or(&THEMES[0])
}

/// Stop and relaunch Waybar so it re-reads its config and stylesheet.
fn restart_waybar(verbose: bool) {
    let _ = Command::new("pkill")
        .arg("waybar")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    // Launch Waybar in a new session (setsid) so it is detached from the
    // terminal that started us. Otherwise, when the live picker's terminal
    // window closes, the spawned Waybar would be killed by SIGHUP.
    let detached = Command::new("setsid")
        .arg("waybar")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();

    let result = match detached {
        Ok(child) => Ok(child),
        // Fall back to a plain spawn if setsid isn't available.
        Err(_) => Command::new("waybar")
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn(),
    };

    match result {
        Ok(_) => vprintln!(verbose, "  waybar: restarted"),
        Err(e) => veprintln!(verbose, "  waybar: failed to restart ({e})"),
    }
}

fn reload_apps(verbose: bool) {
    // Reload Hyprland config (picks up the new sourced theme.conf).
    match Command::new("hyprctl")
        .arg("reload")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
    {
        Ok(s) if s.success() => vprintln!(verbose, "  hyprctl reload: ok"),
        Ok(s) => veprintln!(verbose, "  hyprctl reload: exited with {s}"),
        Err(e) => veprintln!(verbose, "  hyprctl reload: failed to run ({e})"),
    }

    restart_waybar(verbose);

    // Ask running Ghostty instances to reload their config (no-op if none).
    match Command::new("pkill")
        .args(["-SIGUSR2", "-x", "ghostty"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
    {
        Ok(s) if s.success() => vprintln!(verbose, "  ghostty: reloaded"),
        // pkill exits 1 when no process matched; that's fine.
        Ok(_) => vprintln!(verbose, "  ghostty: no running instance"),
        Err(e) => veprintln!(verbose, "  ghostty: failed to signal ({e})"),
    }

    restart_dunst(verbose);
}

/// Restart dunst (detached) so it re-reads the themed dunstrc.
fn restart_dunst(verbose: bool) {
    let _ = Command::new("pkill")
        .arg("dunst")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
    let spawned = Command::new("setsid")
        .arg("dunst")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .or_else(|_| {
            Command::new("dunst")
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
        });
    match spawned {
        Ok(_) => vprintln!(verbose, "  dunst: restarted"),
        Err(e) => veprintln!(verbose, "  dunst: failed to restart ({e})"),
    }
}

fn apply(theme: &Theme, reload: bool, verbose: bool) -> std::io::Result<()> {
    let cfg = config_dir();

    let hypr_path = cfg.join("hypr").join("theme.conf");
    let css_path = cfg.join("waybar").join("colors.css");
    let wofi_path = cfg.join("wofi").join("style.css");

    fs::write(&hypr_path, render_hypr(theme))?;
    fs::write(&css_path, render_css(theme))?;

    if let Some(parent) = wofi_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&wofi_path, theme.wofi)?;

    let ghostty_path = cfg.join("ghostty").join("theme-active");
    if let Some(parent) = ghostty_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(
        &ghostty_path,
        format!(
            "# Generated by theme-switch. Do not edit by hand.\n\
             # Active theme: {}\n\
             theme = {}\n",
            theme.name, theme.ghostty
        ),
    )?;

    let dunst_path = cfg.join("dunst").join("dunstrc");
    if let Some(parent) = dunst_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&dunst_path, render_dunst(theme))?;

    // Refresh the layout color file so the waybar layout matches, then set the
    // waybar layout this theme prefers (default = user's original bar).
    let waybar = cfg.join("waybar");
    fs::write(waybar.join("omarchy-colors.css"), render_omarchy_colors(theme))?;
    let layout_src = layouts_dir().join(theme.waybar_layout);
    let mut set_layout = false;
    if layout_src.join("config.jsonc").exists() {
        fs::copy(layout_src.join("config.jsonc"), waybar.join("config.jsonc"))?;
        fs::copy(layout_src.join("style.css"), waybar.join("style.css"))?;
        // Copy any helper scripts shipped with the layout.
        if let Ok(dir) = fs::read_dir(&layout_src) {
            for entry in dir.flatten() {
                let path = entry.path();
                let is_script = path
                    .extension()
                    .map(|e| e == "py" || e == "sh")
                    .unwrap_or(false);
                if is_script {
                    let _ = fs::copy(&path, waybar.join(entry.file_name()));
                }
            }
        }
        set_layout = true;
    }

    let state_path = current_theme_path();
    if let Some(parent) = state_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&state_path, theme.name)?;
    fs::write(current_layout_path(), theme.waybar_layout)?;

    vprintln!(verbose, "Applied theme '{}' ({})", theme.name, theme.description);
    vprintln!(verbose, "  wrote {}", hypr_path.display());
    vprintln!(verbose, "  wrote {}", css_path.display());
    vprintln!(verbose, "  wrote {} (applies on next wofi launch)", wofi_path.display());
    vprintln!(verbose, "  wrote {}", ghostty_path.display());
    vprintln!(verbose, "  wrote {}", dunst_path.display());
    if set_layout {
        vprintln!(verbose, "  waybar layout: {}", theme.waybar_layout);
    }

    if reload {
        reload_apps(verbose);
        if verbose {
            // Give a quick, themed confirmation via the freshly-restarted dunst.
            let _ = Command::new("notify-send")
                .args([
                    "-a",
                    "theme-switch",
                    &format!("{} theme", theme.name),
                    "Applied \u{2014} notifications restyled",
                ])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status();
        }
    } else {
        vprintln!(verbose, "  (skipped reload)");
    }
    Ok(())
}

/// Apply an imported HANCORE waybar layout. Only Waybar changes; the app theme
/// (hyprland/wofi/ghostty and the bar palette) is left as-is.
fn apply_layout(name: &str, reload: bool, verbose: bool) -> std::io::Result<()> {
    let cfg = config_dir();
    let waybar = cfg.join("waybar");
    let src = layouts_dir().join(name);

    if !src.join("config.jsonc").exists() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("layout assets missing at {}", src.display()),
        ));
    }
    fs::create_dir_all(&waybar)?;

    let theme = active_theme();
    fs::write(waybar.join("omarchy-colors.css"), render_omarchy_colors(theme))?;
    fs::copy(src.join("config.jsonc"), waybar.join("config.jsonc"))?;
    fs::copy(src.join("style.css"), waybar.join("style.css"))?;

    // Copy any helper scripts shipped with the layout (e.g. window_pill.py).
    for entry in fs::read_dir(&src)? {
        let entry = entry?;
        let path = entry.path();
        let is_script = path
            .extension()
            .map(|e| e == "py" || e == "sh")
            .unwrap_or(false);
        if is_script {
            fs::copy(&path, waybar.join(entry.file_name()))?;
        }
    }

    fs::write(current_layout_path(), name)?;

    vprintln!(verbose, "Applied waybar layout '{name}'");
    vprintln!(verbose, "  colors driven by app theme '{}'", theme.name);
    vprintln!(
        verbose,
        "  note: this only themes Waybar; ghostty/wofi/hyprland keep the '{}' theme",
        theme.name
    );
    vprintln!(verbose, "  media modules use your now-playing script");

    if reload {
        restart_waybar(verbose);
    } else {
        vprintln!(verbose, "  (skipped reload)");
    }
    Ok(())
}

/// Apply either an app theme or a waybar layout, by name.
fn apply_by_name(name: &str, reload: bool) {
    if let Some(theme) = find_theme(name) {
        if let Err(e) = apply(theme, reload, true) {
            eprintln!("error: {e}");
            std::process::exit(1);
        }
    } else if let Some(layout) = find_layout(name) {
        if let Err(e) = apply_layout(layout, reload, true) {
            eprintln!("error: {e}");
            std::process::exit(1);
        }
    } else if name.eq_ignore_ascii_case("default") {
        if let Err(e) = apply_layout("default", reload, true) {
            eprintln!("error: {e}");
            std::process::exit(1);
        }
    } else {
        eprintln!("error: unknown theme or layout '{name}'\n");
        print_list();
        std::process::exit(1);
    }
}

/// Quietly apply an app theme or waybar layout (used by the live TUI).
fn apply_name_quiet(name: &str, reload: bool) {
    if let Some(theme) = find_theme(name) {
        let _ = apply(theme, reload, false);
    } else if find_layout(name).is_some() || name.eq_ignore_ascii_case("default") {
        let _ = apply_layout(name, reload, false);
    }
}

fn stty(args: &[&str]) {
    let _ = Command::new("stty")
        .args(args)
        .stdin(Stdio::inherit())
        .status();
}

/// Save current terminal settings so they can be restored on exit.
fn stty_save() -> Option<String> {
    let out = Command::new("stty")
        .arg("-g")
        .stdin(Stdio::inherit())
        .output()
        .ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        None
    }
}

fn live_kind_tag(name: &str) -> &'static str {
    if find_theme(name).is_some() {
        "[theme]"
    } else {
        "[waybar]"
    }
}

/// Number of terminal rows, via `stty size` ("rows cols"). Falls back to 18.
fn term_rows() -> usize {
    if let Ok(out) = Command::new("stty")
        .arg("size")
        .stdin(Stdio::inherit())
        .output()
    {
        if out.status.success() {
            let s = String::from_utf8_lossy(&out.stdout);
            if let Some(r) = s.split_whitespace().next() {
                if let Ok(n) = r.parse::<usize>() {
                    return n.max(4);
                }
            }
        }
    }
    18
}

/// Render with a sticky 2-line header and a scrolling window so the selected
/// entry stays visible even when the list is taller than the terminal.
/// `offset` (first visible row) is adjusted in place to keep `sel` on screen.
fn live_redraw(entries: &[String], sel: usize, applied: Option<usize>, offset: &mut usize) {
    const HEADER: usize = 2;
    let rows = term_rows();
    let visible = rows.saturating_sub(HEADER).max(1);

    // Scroll only when the selection moves out of the visible window.
    if sel < *offset {
        *offset = sel;
    } else if sel >= *offset + visible {
        *offset = sel + 1 - visible;
    }
    let max_off = entries.len().saturating_sub(visible);
    if *offset > max_off {
        *offset = max_off;
    }
    let end = (*offset + visible).min(entries.len());

    let up = if *offset > 0 { "\u{2191}" } else { " " };
    let down = if end < entries.len() { "\u{2193}" } else { " " };

    let mut out = String::new();
    out.push_str("\x1b[2J\x1b[H"); // clear + home
    out.push_str(&format!(
        "theme-switch \u{2014} live preview  \x1b[2m({}/{})\x1b[0m {up}{down}\r\n",
        sel + 1,
        entries.len()
    ));
    out.push_str("\x1b[2m\u{2191}/\u{2193} j/k move \u{00b7} Enter keep \u{00b7} q/Esc cancel\x1b[0m\r\n");
    for i in *offset..end {
        let e = &entries[i];
        let tag = live_kind_tag(e);
        let cur = if applied == Some(i) { "  \u{2190} applied" } else { "" };
        if i == sel {
            out.push_str(&format!("\x1b[7m> {e:<10} {tag}{cur}\x1b[0m\r\n"));
        } else {
            out.push_str(&format!("  {e:<10} {tag}{cur}\r\n"));
        }
    }
    print!("{out}");
    let _ = std::io::stdout().flush();
}

/// Interactive TUI: navigate the theme/layout list and apply the highlighted
/// entry live (after a short idle). Enter keeps it; q/Esc reverts to the
/// theme that was active when the menu opened.
fn live() {
    let mut entries: Vec<String> = THEMES.iter().map(|t| t.name.to_string()).collect();
    entries.push("default".to_string());
    entries.extend(LAYOUTS.iter().map(|l| l.to_string()));

    // Remember what was active so cancel can restore it.
    let orig_theme = current_theme();
    let orig_layout = current_layout();

    // Start on the current app theme if known.
    let mut sel = orig_theme
        .as_deref()
        .and_then(|n| entries.iter().position(|e| e.eq_ignore_ascii_case(n)))
        .unwrap_or(0);

    let saved = match stty_save() {
        Some(s) => s,
        None => {
            eprintln!(
                "error: `live` needs an interactive terminal.\n\
                 Run it inside a terminal, e.g. `ghostty -e theme-switch live`."
            );
            std::process::exit(1);
        }
    };
    // Non-canonical, no echo, 0.2s read timeout for debounced live apply.
    stty(&["-icanon", "-echo", "min", "0", "time", "2"]);
    print!("\x1b[?25l"); // hide cursor
    let _ = std::io::stdout().flush();

    let mut applied: Option<usize> = None;
    let mut keep = false;
    let mut offset = 0usize;
    live_redraw(&entries, sel, applied, &mut offset);

    let mut stdin = std::io::stdin();
    let mut buf = [0u8; 16];
    loop {
        let n = stdin.read(&mut buf).unwrap_or(0);
        if n == 0 {
            // Idle: apply the highlighted entry if not already applied.
            if applied != Some(sel) {
                apply_name_quiet(&entries[sel], true);
                applied = Some(sel);
                live_redraw(&entries, sel, applied, &mut offset);
            }
            continue;
        }

        let b = &buf[..n];
        if b[0] == 0x1b && n >= 3 && b[1] == b'[' {
            match b[2] {
                b'A' => sel = if sel == 0 { entries.len() - 1 } else { sel - 1 },
                b'B' => sel = (sel + 1) % entries.len(),
                _ => {}
            }
            live_redraw(&entries, sel, applied, &mut offset);
        } else if b[0] == 0x1b {
            // Lone Esc: cancel.
            break;
        } else {
            let mut redraw = false;
            let mut done = false;
            for &c in b {
                match c {
                    b'k' => {
                        sel = if sel == 0 { entries.len() - 1 } else { sel - 1 };
                        redraw = true;
                    }
                    b'j' => {
                        sel = (sel + 1) % entries.len();
                        redraw = true;
                    }
                    b'\r' | b'\n' => {
                        keep = true;
                        done = true;
                    }
                    b'q' => {
                        done = true;
                    }
                    _ => {}
                }
            }
            if done {
                break;
            }
            if redraw {
                live_redraw(&entries, sel, applied, &mut offset);
            }
        }
    }

    if keep {
        // Ensure the highlighted entry is actually applied before exiting.
        if applied != Some(sel) {
            apply_name_quiet(&entries[sel], true);
        }
    } else if applied.is_some() {
        // Something was previewed; revert to whatever was active on open.
        match orig_layout.as_deref() {
            Some(l) if l != "default" => {
                if let Some(t) = orig_theme.as_deref() {
                    apply_name_quiet(t, false);
                }
                apply_name_quiet(l, true);
            }
            _ => {
                if let Some(t) = orig_theme.as_deref() {
                    apply_name_quiet(t, true);
                }
            }
        }
    }

    // Restore terminal.
    stty(&[&saved]);
    print!("\x1b[?25h\x1b[2J\x1b[H"); // show cursor, clear
    let _ = std::io::stdout().flush();
    if keep {
        println!("Applied '{}'.", entries[sel]);
    } else {
        println!("Cancelled \u{2014} reverted.");
    }
}

/// Show a wofi dmenu of themes and apply the chosen one.
fn menu(reload: bool) {
    let current = current_theme();
    let cur_layout = current_layout();
    let mut input = String::new();
    for t in THEMES {
        let mark = match &current {
            Some(c) if c.eq_ignore_ascii_case(t.name) => " (current)",
            _ => "",
        };
        input.push_str(&format!("{}  [theme]{}\n", t.name, mark));
    }
    {
        let mark = match &cur_layout {
            Some(c) if c == "default" => " (current)",
            _ => "",
        };
        input.push_str(&format!("default  [waybar]{}\n", mark));
    }
    for l in LAYOUTS {
        let mark = match &cur_layout {
            Some(c) if c.eq_ignore_ascii_case(l) => " (current)",
            _ => "",
        };
        input.push_str(&format!("{}  [waybar]{}\n", l, mark));
    }

    let mut child = match Command::new("wofi")
        .args(["--dmenu", "-i", "-p", "Theme"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("error: failed to launch wofi ({e})");
            std::process::exit(1);
        }
    };

    if let Some(stdin) = child.stdin.take() {
        let mut stdin = stdin;
        let _ = stdin.write_all(input.as_bytes());
    }

    let output = match child.wait_with_output() {
        Ok(o) => o,
        Err(e) => {
            eprintln!("error: wofi failed ({e})");
            std::process::exit(1);
        }
    };

    let selection = String::from_utf8_lossy(&output.stdout);
    // Strip the " (current)" suffix and whitespace to get the bare theme name.
    let name = selection
        .trim()
        .split_whitespace()
        .next()
        .unwrap_or("");

    if name.is_empty() {
        // User pressed Escape or dismissed the menu.
        return;
    }

    apply_by_name(name, reload);
}

fn print_list() {
    let current = current_theme();
    let cur_layout = current_layout();
    println!("App themes (hyprland + waybar + wofi + ghostty):");
    for t in THEMES {
        let marker = match &current {
            Some(c) if c.eq_ignore_ascii_case(t.name) => "*",
            _ => " ",
        };
        println!("  {marker} {:<10} {}", t.name, t.description);
    }
    println!("\nWaybar layouts (HANCORE; waybar only, colored by current theme):");
    let is_default = cur_layout.as_deref().map(|c| c == "default").unwrap_or(true);
    println!("  {} {:<10} original bar (workspace tabs + now-playing)", if is_default { "*" } else { " " }, "default");
    for l in LAYOUTS {
        let marker = match &cur_layout {
            Some(c) if c.eq_ignore_ascii_case(l) => "*",
            _ => " ",
        };
        println!("  {marker} {l}");
    }
    if current.is_none() {
        println!("\n(no theme applied yet)");
    }
}

fn print_usage() {
    println!("theme-switch - switch Hyprland + Waybar themes\n");
    println!("Usage:");
    println!("  theme-switch                 list themes + waybar layouts");
    println!("  theme-switch list            list themes + waybar layouts");
    println!("  theme-switch menu            pick a theme/layout via a wofi menu");
    println!("  theme-switch live            interactive TUI with live preview on hover");
    println!("  theme-switch <name>          apply an app theme (amethyst/nord/gruvbox/cobble)");
    println!("  theme-switch <layout>        apply a waybar layout (default, nimbus, lantern, ...)");
    println!("  theme-switch <name> --no-reload   apply without reloading");
    println!("  theme-switch help            show this help");
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    let no_reload = args.iter().any(|a| a == "--no-reload");
    let positional: Vec<&String> = args.iter().filter(|a| !a.starts_with("--")).collect();

    match positional.first().map(|s| s.as_str()) {
        None | Some("list") => print_list(),
        Some("menu") => menu(!no_reload),
        Some("live") => live(),
        Some("help") | Some("-h") | Some("--help") => print_usage(),
        Some(name) => apply_by_name(name, !no_reload),
    }
}
