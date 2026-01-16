#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

PACMAN_LIST="$SCRIPTS_DIR/packages-pacman.txt"
AUR_LIST="$SCRIPTS_DIR/packages-aur.txt"

# Deine tatsächlichen Stow-Pakete (aus deinem Repo)
STOW_PACKAGES=(hypr waybar walker)

log() { printf "\n\033[1m%s\033[0m\n" "$*"; }

need_file() {
  [[ -f "$1" ]] || { echo "ERROR: Datei fehlt: $1" >&2; exit 1; }
}

log "Dotfiles: $DOTFILES_DIR"
need_file "$PACMAN_LIST"
need_file "$AUR_LIST"

log "[1/6] System update"
sudo pacman -Syu --noconfirm

log "[2/6] Installiere pacman Pakete"
sudo pacman -S --needed --noconfirm - < "$PACMAN_LIST"

log "[3/6] yay bootstrap (falls nötig)"
if ! command -v yay >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
fi

log "[4/6] Installiere AUR Pakete"
yay -S --needed --noconfirm - < "$AUR_LIST"

log "[5/6] Stow dotfiles"
sudo pacman -S --needed --noconfirm stow
cd "$DOTFILES_DIR"
stow -t "$HOME" "${STOW_PACKAGES[@]}"

log "[6/6] Services aktivieren"
# Netzwerk & BT systemweit
sudo systemctl enable --now NetworkManager.service || true
sudo systemctl enable --now bluetooth.service || true

# Audio als user services (PipeWire)
systemctl --user enable --now pipewire.service wireplumber.service pipewire-pulse.service 2>/dev/null || true

log "Fertig ✅"
echo "Hinweis: Falls Treiber/Kernel installiert wurden, reboot sinnvoll."

