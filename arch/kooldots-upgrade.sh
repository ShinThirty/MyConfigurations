#!/usr/bin/env bash
#
# Attended upgrade of KooL's Hyprland setup: the ~/Arch-Hyprland installer and
# its Hyprland-Dots. copy.sh --express-upgrade alone goes wrong here: it deletes
# its own backup of ~/.config/hypr, replaces qt5ct, qt6ct and yazi, which this
# repo and the ~/.dotfiles.git bare repo own, undoes two waybar fixes, and
# installs Oh My Zsh beside sheldon's. This backs up first, runs the upgrade,
# puts all of that back, and checks that the Lua config loads.
#
#   arch/kooldots-upgrade.sh              the whole upgrade
#   arch/kooldots-upgrade.sh --post-only  only the repairs and checks; safe to rerun
#
# The repairs follow $XDG_CONFIG_HOME, so they can be tried on a copy first.

set -uo pipefail

INSTALLER="$HOME/Arch-Hyprland"
DOTS="$INSTALLER/Hyprland-Dots"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CFG/hypr"
STAMP="$(date +%Y%m%d-%H%M)"

post_only=0
case "${1:-}" in
  '') ;;
  --post-only) post_only=1 ;;
  -h | --help) awk 'NR > 2 && !/^#/ { exit } NR > 2 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
  *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
esac

[[ $EUID -ne 0 ]] ||
  { echo "run this as your normal user, not root (copy.sh calls sudo where needed)" >&2; exit 1; }

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*"; }
todo=()

# The bare repo behind zsh's cfg alias
cfg() { git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" "$@"; }

if (( ! post_only )); then
  for repo in "$INSTALLER" "$DOTS"; do
    [[ -d $repo/.git ]] || { echo "no git clone at $repo" >&2; exit 1; }
  done

  # --- Backup -------------------------------------------------------------------
  # Express mode keeps only the newest ~/.config/*-backup-* per app, and the Lua
  # migrator makes a newer one of ~/.config/hypr after the pristine one, so the
  # pristine copy is gone by the end. This one lives outside ~/.config.
  info "Backup"
  backup="$HOME/kooldots-pre-upgrade-$STAMP.tar.gz"
  dirs=()
  for d in hypr qt5ct qt6ct yazi rofi waybar cava btop Kvantum swappy wlogout swaync \
           fastfetch ghostty wezterm quickshell wallust systemd waybar-weather; do
    [[ -e $CFG/$d ]] && dirs+=("$d")
  done
  tar -czf "$backup" -C "$CFG" "${dirs[@]}" ||
    { echo "backup failed; stopping before anything changes" >&2; exit 1; }
  ok "${backup/#"$HOME"/\~} ($(du -h "$backup" | cut -f1)); undo with: tar -xzf <it> -C ${CFG/#"$HOME"/\~}"

  if [[ -d $HOME/.dotfiles.git ]]; then
    mapfile -t dirty < <(cfg status --porcelain --untracked-files=no)
    (( ${#dirty[@]} )) &&
      warn "${#dirty[@]} uncommitted change(s) in ~/.dotfiles.git: the tarball has them, the tag doesn't"
    cfg tag -a "pre-kooldots-upgrade-$STAMP" -m "Before the KooL Hyprland-Dots upgrade of $(date +%F)" &&
      ok "tagged ~/.dotfiles.git: pre-kooldots-upgrade-$STAMP"
  else
    warn "no ~/.dotfiles.git, so no tag, and qt5ct/qt6ct can't be restored from it below"
  fi

  # --- Clones -------------------------------------------------------------------
  info "Installer and dotfiles"
  git -C "$INSTALLER" pull --ff-only || { echo "git pull failed in $INSTALLER" >&2; exit 1; }
  # copy.sh edits its own checkout before copying (NVIDIA and VM settings, the
  # kitty font size), so the last run's edits are still there. Stashed rather
  # than dropped, as KooL's upgrade guide does
  if [[ -n $(git -C "$DOTS" status --porcelain --untracked-files=no) ]]; then
    git -C "$DOTS" stash push -q -m "copy.sh's own edits, before kooldots-upgrade $STAMP" &&
      skip "stashed copy.sh's edits from the last run"
  fi
  git -C "$DOTS" pull --ff-only || { echo "git pull failed in $DOTS" >&2; exit 1; }
  installed="$(find "$HYPR" -maxdepth 1 -name 'v[0-9]*' -printf '%f\n' 2>/dev/null | sort -V | tail -n 1)"
  latest="$(find "$DOTS/config/hypr" -maxdepth 1 -name 'v[0-9]*' -printf '%f\n' | sort -V | tail -n 1)"
  ok "dotfiles ${installed:-unknown} -> ${latest:-unknown}"

  # --- Upgrade ------------------------------------------------------------------
  info "Dependencies (install-scripts/update-deps.sh)"
  "$INSTALLER/install-scripts/update-deps.sh" ||
    { echo "update-deps.sh failed; sort that out, then run this again" >&2; exit 1; }

  info "Dotfiles (copy.sh --express-upgrade)"
  cat <<'EOF'
  copy.sh asks a few things. This machine's answers:
    keyboard layout   us
    12-hour clock     yes (waybar's clock)
    resolution        ≥ 1440p
EOF
  # copy.sh installs Oh My Zsh to ~/.oh-my-zsh unless $ZSH names a checkout with
  # themes/, and it doesn't look in sheldon's
  omz="${XDG_DATA_HOME:-$HOME/.local/share}/sheldon/repos/github.com/ohmyzsh/ohmyzsh"
  if [[ ! -d $omz/themes ]]; then
    warn "no sheldon Oh My Zsh at ${omz/#"$HOME"/\~}, so copy.sh will install its own"
    omz="${ZSH:-}"
  fi
  # It reads config/ and scripts/ relative to the working directory
  (cd "$DOTS" && ZSH="$omz" bash ./copy.sh --express-upgrade) ||
    { echo "copy.sh failed; read its output above, then run this with --post-only" >&2; exit 1; }
fi

# --- What copy.sh replaced ----------------------------------------------------
info "qt5ct and qt6ct (Noto Sans, as committed to ~/.dotfiles.git)"
# KooL ships Fira Code. Restored from the bare repo's HEAD, so commit any change
# made in qt5ct/qt6ct before upgrading
if [[ -d $HOME/.dotfiles.git ]]; then
  mapfile -t qtfiles < <(cfg ls-tree -r --name-only HEAD -- .config/qt5ct .config/qt6ct)
  restored=()
  for f in "${qtfiles[@]}"; do
    dest="$CFG/${f#.config/}"
    cfg show "HEAD:$f" | cmp -s - "$dest" && continue
    mkdir -p "${dest%/*}"
    cfg show "HEAD:$f" > "$dest" && restored+=("${f#.config/}")
  done
  if (( ${#restored[@]} )); then ok "restored ${restored[*]}"; else skip "already as committed"; fi
else
  todo+=("qt5ct/qt6ct: no ~/.dotfiles.git to restore them from; set Noto Sans 10 / Noto Sans Mono 10 in each")
fi

info "yazi (this repo's symlinks and the installed plugins)"
# copy.sh moves ~/.config/yazi to yazi-backup-* and copies KooL's in. Its
# plugins and flavors aren't in this repo, so the backup goes back whole
if [[ -L $CFG/yazi/yazi.toml ]]; then
  skip "already this repo's"
else
  yazi_backup="$(find "$CFG" -maxdepth 1 -name 'yazi-backup-*' -printf '%T@ %p\n' | sort -rn | head -n 1 | cut -d' ' -f2-)"
  if [[ -n $yazi_backup && -L $yazi_backup/yazi.toml ]]; then
    rm -rf -- "$CFG/yazi" && mv -- "$yazi_backup" "$CFG/yazi" &&
      ok "put back ${yazi_backup/#"$HOME"/\~}"
  else
    todo+=("yazi: no backup with this repo's symlinks; remove KooL's yazi.toml, theme.toml and package.toml from ~/.config/yazi, run setup_symlinks.sh, then ya pkg install")
  fi
fi

# --- What express mode undoes -------------------------------------------------
# It syncs KooL's waybar files over the installed ones, sparing only
# UserModules, wallust/ and the config and style.css links
ppd_line='^[[:space:]]*"power-profiles-daemon"[[:space:]]*,?[[:space:]]*$'
info "waybar: power-profiles-daemon module"
# waybar 0.15.0 segfaults in this module when it's reloaded within ~0.1 s of
# starting, and KooL's login scripts reload it twice. power-profiles-daemon
# isn't installed, so the module showed nothing anyway. Gone from every layout,
# so switching layouts can't bring the crash back
mapfile -d '' -t files < <(grep -lZE "$ppd_line" "$HYPR/waybar/ModulesGroups" "$HYPR"/waybar/configs/* 2>/dev/null)
if (( ${#files[@]} )); then
  sed -i -E "/$ppd_line/d" "${files[@]}" && ok "removed from ${#files[@]} file(s)"
else
  skip "already gone"
fi

info "waybar: tray icon style"
# Since v2.3.25 nearly every style ends with a "tray readability override" that
# boxes each tray icon in blue and makes it monochrome. Dropped from all of them
mapfile -d '' -t files < <(grep -lZF 'tray readability override (global)' "$HYPR"/waybar/style/*.css 2>/dev/null)
stripped=0
for f in "${files[@]}"; do
  # From the marker through the end of the #tray image rule, and the blank lines
  # after it. Exits non-zero, leaving the file alone, if that rule never closes
  if awk '
      /tray readability override \(global\)/ { skip = 1 }
      skip {
        if (/^#tray image[[:space:]]*\{/) img = 1
        else if (img && /^\}/) { skip = 0; img = 0; blank = 1 }
        next
      }
      blank && /^[[:space:]]*$/ { next }
      { blank = 0; print }
      END { exit skip }' "$f" > "$f.tmp"; then
    mv -- "$f.tmp" "$f" && stripped=$((stripped + 1))
  else
    rm -f -- "$f.tmp"
    todo+=("waybar: the tray override in ${f##*/} isn't shaped as expected; delete it by hand")
  fi
done
if (( stripped )); then ok "removed from $stripped style(s)"; elif (( ! ${#files[@]} )); then skip "already gone"; fi

# --- Settings this machine adds -----------------------------------------------
# Upgrades copy UserConfigs back, so these normally survive; each is re-added
# only if one didn't. The hyprlang -> Lua migration of 2026-10-11 dropped them all
info "Hyprland user settings"
U="$HYPR/UserConfigs"
added=()
missing=()
for f in user_keybinds.lua user_env.lua user_settings.lua user_startup.lua monitors.lua; do
  [[ -f $U/$f ]] || missing+=("$f")
done
if (( ${#missing[@]} )); then
  todo+=("UserConfigs is missing ${missing[*]}, so nothing was re-added; see commit 4109c5a3 in ~/.dotfiles.git for what goes in them")
else
  if ! grep -q 'voice-dictate' "$U/user_keybinds.lua"; then
    cat >> "$U/user_keybinds.lua" <<'EOF'

-- --- Voice dictation ---------------------------------------------------------
-- Hold SUPER+Z and speak; releasing transcribes locally (whisper.cpp on the GPU)
-- and types the text into the focused window. Script: ~/MyConfigurations/voice/
bind("SUPER", "Z", exec_cmd("$HOME/.local/bin/voice-dictate start"), { description = "voice dictation (hold to talk)" })
bind("SUPER", "Z", exec_cmd("$HOME/.local/bin/voice-dictate stop"), { release = true })
bind("SUPER SHIFT", "Z", exec_cmd("$HOME/.local/bin/voice-dictate cancel"), { description = "voice dictation (discard take)" })
EOF
    added+=("SUPER+Z dictation")
  fi
  if ! grep -q 'XMODIFIERS' "$U/user_env.lua"; then
    cat >> "$U/user_env.lua" <<'EOF'

-- Input method configuration
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")

-- Default editor (was env = EDITOR,vim in 01-UserDefaults.conf)
hl.env("EDITOR", "vim")
EOF
    added+=("fcitx and EDITOR")
  fi
  if ! grep -q 'KITTY_CONFIG_DIRECTORY' "$U/user_env.lua"; then
    cat >> "$U/user_env.lua" <<'EOF'

-- kitty: use the repo's config (~/.config/kitty -> ~/MyConfigurations/kitty), not the
-- KooL one lua/env.lua points at. UserConfigs/kitty.conf just includes it, because
-- LaunchTerminal.sh and Dropterminal.sh force --config on that file.
hl.env("KITTY_CONFIG_DIRECTORY", (os.getenv("HOME") or "") .. "/.config/kitty")
EOF
    added+=("KITTY_CONFIG_DIRECTORY")
  fi
  if ! grep -q 'caps:swapescape' "$U/user_settings.lua"; then
    # The first kb_options line is the active hl.config; later ones are commented examples
    sed -i -E '0,/^([[:space:]]*)kb_options = "[^"]*",/s//\1kb_options = "caps:swapescape",/' "$U/user_settings.lua"
    if grep -q 'caps:swapescape' "$U/user_settings.lua"; then
      added+=("caps:swapescape")
    else
      todo+=("user_settings.lua has no kb_options line to set caps:swapescape on")
    fi
  fi
  # Active entries only: KooL's template lists both as commented-out examples
  for cmd in "blueman-applet" "udiskie --no-notify --smart-tray"; do
    if ! grep -qE "^[[:space:]]*\"${cmd%% *}( [^\"]*)?\"," "$U/user_startup.lua"; then
      sed -i "/local startup_commands = {/a \\  \"$cmd\"," "$U/user_startup.lua"
      added+=("${cmd%% *}")
    fi
  done
  # SECURITY.md section 7's Login database. Qt looks for a tray only once, at
  # start, so KeePassXC waits for waybar's; $HOME stays literal, for the shell
  # exec_once runs it in
  if ! grep -q 'keepassxc --minimized' "$U/user_startup.lua"; then
    sed -i '/local startup_commands = {/a \  "gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher; keepassxc --minimized $HOME/.local/share/keepassxc/login.kdbx",' "$U/user_startup.lua"
    added+=(keepassxc)
  fi
  if ! grep -q '"DP-4"' "$U/monitors.lua"; then
    cat >> "$U/monitors.lua" <<'EOF'

hl.monitor({
    output = "DP-4",
    mode = "2560x1440@59.95",
    position = "0x0",
    scale = "1",
    bitdepth = 10,
})
EOF
    added+=("DP-4 monitor")
  fi
  if (( ${#added[@]} )); then ok "re-added: ${added[*]}"; else skip "all still there"; fi
fi

info "kitty: UserConfigs/kitty.conf"
# KooL's launchers force --config on this file, so it only includes the repo's
# config. copy.sh's kitty patch may append remember_window_size no to it; the
# repo's config sets that too (kitty 0.49+ reopens windows maximized without it)
stub="$U/kitty.conf"
include='include ~/.config/kitty/kitty.conf'
if grep -qxF "$include" "$stub" 2>/dev/null; then
  skip "already includes ~/.config/kitty/kitty.conf"
else
  printf '%s\n' "# Points KooL's launchers (which force --config on this file) at the repo's" \
    "# kitty config: ~/MyConfigurations/kitty via the ~/.config/kitty symlink." "$include" > "$stub" &&
    ok "replaced KooL's with an include of ~/.config/kitty/kitty.conf"
fi

# --- Checks -------------------------------------------------------------------
info "Hyprland's stub config"
# A running Hyprland writes a stub hyprland.conf when copy.sh moves its config
# away. hyprland.lua wins at login, so the stub is only clutter
if [[ -f $HYPR/hyprland.lua ]] && grep -qs 'This config is a STUB' "$HYPR/hyprland.conf"; then
  rm -f -- "$HYPR/hyprland.conf" && ok "removed"
else
  skip "none"
fi

info "Check: user Lua files"
# lua/user_overrides.lua loads these through pcall, so a broken one is skipped
# at login with only a log line, and Hyprland --verify-config still says ok.
# Run here against a stand-in for hl that records calls, failing loudly
if ! command -v lua >/dev/null 2>&1; then
  todo+=("lua isn't installed, so the user Lua files weren't checked")
elif lua - "$HYPR" <<'LUA'; then
local hypr = arg[1]
local bind_options = {
  repeating = true, locked = true, release = true, non_consuming = true,
  transparent = true, ignore_mods = true, dont_inhibit = true, long_press = true,
  submap_universal = true, click = true, drag = true, description = true,
  desc = true, device = true,
}
local failed, current = false, ""
local function stand_in(path)
  return setmetatable({}, {
    __index = function(_, key) return stand_in(path .. "." .. tostring(key)) end,
    __call = function(_, ...)
      local args = { ... }
      if path == "hl.bind" and type(args[3]) == "table" then
        for key in pairs(args[3]) do
          -- KooL's own system_keybinds.lua uses "repeat"; in a user file it's
          -- what the migrator wrote for bindr, which needs release = true
          if not bind_options[key] and not (key == "repeat" and current:find("^configs/")) then
            print(("  bind %s: unknown option %q"):format(tostring(args[1]), tostring(key)))
            failed = true
          end
        end
      end
      return stand_in(path .. "()")
    end,
  })
end
hl = stand_in("hl")
hl.on = function() end -- never run the hyprland.start callbacks
for _, f in ipairs({
  "configs/system_env.lua", "configs/system_settings.lua", "configs/system_keybinds.lua",
  "UserConfigs/user_env.lua", "UserConfigs/user_startup.lua", "UserConfigs/user_keybinds.lua",
  "UserConfigs/user_settings.lua", "UserConfigs/user_decorations.lua", "UserConfigs/user_defaults.lua",
  "UserConfigs/monitors.lua", "UserConfigs/workspaces.lua", "UserConfigs/user_window_rules.lua",
  "UserConfigs/user_layer_rules.lua",
}) do
  current = f
  local loaded, err = pcall(dofile, hypr .. "/" .. f)
  if not loaded then
    print(("  %s: %s"):format(f, tostring(err)))
    failed = true
  end
end
os.exit(failed and 1 or 0)
LUA
  ok "all load"
else
  todo+=("Fix the user Lua problem above: Hyprland skips a file that fails to load, and ignores a bind option it doesn't know, both silently")
fi

info "Check: Hyprland --verify-config"
# A made-up instance, so nothing it runs can reach the session's socket
out="$(HYPRLAND_INSTANCE_SIGNATURE=kooldots-upgrade-check Hyprland --verify-config 2>&1)"
if grep -q 'Using lua config' <<<"$out" && grep -qx 'config ok' <<<"$out"; then
  ok "config ok, and Hyprland picks hyprland.lua"
else
  printf '%s\n' "$out" | tail -n 5 | sed 's/^/  /'
  todo+=("Hyprland --verify-config failed or didn't pick hyprland.lua; see above")
fi

if (( post_only )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  info "Check: waybar"
  if pgrep -x waybar >/dev/null; then
    ok "running"
  else
    todo+=("waybar isn't running: coredumpctl list waybar shows whether it crashed, and ~/.config/hypr/scripts/WaybarStartup.sh starts it")
  fi
fi

# --- Left for you -------------------------------------------------------------
if (( ! post_only )); then
  todo+=("Log out and back in: until then this session runs on Hyprland's stub config (SUPER+M quits it)")
  todo+=("Then run arch/kooldots-upgrade.sh --post-only once more: it rechecks, and checks waybar came up")
  todo+=("Commit the result: cfg add -A ~/.config/hypr && cfg commit")
  todo+=("Once you're happy, delete ~/.config/*-backup-* and ${backup/#"$HOME"/\~}")
fi
info "Left for you"
if (( ${#todo[@]} )); then
  printf '  \033[33m-\033[0m %s\n' "${todo[@]}"
else
  ok "nothing"
fi
