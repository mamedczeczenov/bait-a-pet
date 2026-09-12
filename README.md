# Bait a Pet

Prywatne repo: [mamedczeczenov/bait-a-pet](https://github.com/mamedczeczenov/bait-a-pet).

Kod Luau na dysku. **Rojo** wgrywa go na żywo do Roblox Studio.

## Mac — od zera do edycji

### 1. Programy

- [Cursor](https://cursor.com) (edytor)
- [Roblox Studio](https://create.roblox.com/landing) na macOS
- [Homebrew](https://brew.sh) jeśli jeszcze nie masz:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Sklonuj repo (prywatne — musisz być zalogowany)

```bash
brew install gh git
gh auth login
git clone https://github.com/mamedczeczenov/bait-a-pet.git
cd bait-a-pet
```

Albo w Cursorze: **File → Clone Repository** i wklej ten sam URL.

### 3. Odpal Rojo

**Opcja A — jeden skrypt** (Terminal.app, w folderze projektu):

```bash
chmod +x scripts/setup-mac.sh
./scripts/setup-mac.sh
```

**Opcja B — ręcznie:**

```bash
brew install rojo
rojo plugin install
rojo serve
```

Zostaw terminal z `rojo serve` otwarty.

### 4. Połącz Studio

1. Otwórz **istniejące miejsce** BAIT A PET (to z mapą i VIP cave), nie pusty Baseplate.
2. **Plugins → Rojo → Connect** (`127.0.0.1:34872`).
3. W Cursorze edytuj `src/**/*.luau` — zapis = sync do Studio.
4. **Play** w Studio, żeby testować.

Place (mapa, modele) **nie** jest w gicie. Skrypty tak.

### 5. Push zmian

```bash
git add -A
git commit -m "opis"
git push
```

## Struktura

```
default.project.json          mapa folderów → usługi Roblox
src/ReplicatedStorage/        configi i UI modules
src/ServerScriptService/      serwer (BaitSystem)
src/StarterPlayer/            klient (HUD, catch, shop, AFK)
assets/                       ikony i pet assets
scripts/setup-mac.sh          instalacja Rojo + serve na Macu
plan.md, ready.md, to-do.md   status produkcji
```

## Dokumenty

| Plik | Co tam jest |
|------|-------------|
| `plan.md` | Fazy do launchu, VIP gamepass |
| `ready.md` | Ustalenia ekonomii i AFK |
| `to-do.md` | Otwarte taski |
| `afk.md` / `gifts.md` / `ikonki.md` | AFK, gifty, ikony |
