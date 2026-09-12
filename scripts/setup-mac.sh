#!/usr/bin/env bash
# Jednorazowy setup + start Rojo na macOS.
# Uruchom w Terminal.app:
#   chmod +x scripts/setup-mac.sh && ./scripts/setup-mac.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "Ten skrypt jest na macOS. Na Linuxie: brew/rokit install rojo && rojo serve"
fi

if ! command -v git >/dev/null 2>&1; then
  die "Brak git. W Terminalu: xcode-select --install"
fi

if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Brak Homebrew. Wklej to w Terminal i wróć tu:  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
fi

if ! command -v rojo >/dev/null 2>&1; then
  say "Instaluję Rojo (Homebrew)"
  brew install rojo
fi

say "Rojo: $(rojo --version)"

say "Instaluję plugin Rojo do Roblox Studio"
if ! rojo plugin install; then
  printf '%s\n' "Plugin CLI nie wszedł — zainstaluj ręcznie:" \
    "https://create.roblox.com/store/asset/13916111004/Rojo"
fi

if rojo sourcemap --output sourcemap.json; then
  say "Sourcemap OK (Luau LSP w Cursorze)"
fi

cat <<'EOF'

Następny krok w Roblox Studio:
  1. Zaloguj się na konto z grą BAIT A PET
  2. Otwórz istniejące miejsce (mapa / VIP cave) — NIE pusty Baseplate
  3. Plugins → Rojo → Connect  (127.0.0.1:34872)

Startuję serwer Rojo. Zostaw to okno otwarte.

EOF

exec rojo serve
