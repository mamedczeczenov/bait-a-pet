# Ikonki do ogarnięcia (UI)

Lista customowych grafik 2D — **bez petów** (zostają ViewportFrame / modele 3D).

**Folder assetów:** `roblox/assets/icons/`  
**Wygenerowane:** 2026-08-11 — styl wzorowany na referencjach Index book + cash stack (gruby czarny outline, isometric candy, gloss).

---

## Konwencje dla grafika

| Parametr | Wartość |
|----------|---------|
| Format | PNG |
| Bazowy rozmiar | generowane ~kwadrat (przyciąć/scale w Studio do 256×256) |
| Styl | candy / Eggs Shop: grube czarne obrysy, nasycone kolory |
| Naming | `snake_case.png` |
| Delivery | `roblox/assets/icons/` → potem upload do Roblox → `rbxassetid://…` |

---

## Legenda statusu

| Status | Znaczenie |
|--------|-----------|
| ❌ Brak | Do zrobienia |
| ✅ Gotowe | Plik w `assets/icons/` (wygenerowany AI — warto przejrzeć / podmienić po uploadzie) |
| ⬜ Opcjonalne | Świadomie odłożone (tekstury tile) |

---

## Must

### HUD

| ID pliku | Co to | Status | Plik |
|----------|-------|--------|------|
| `hud_coins` | Monety | ✅ | `hud_coins.png` |
| `hud_pets` / `hud_inventory` | Inventory | ✅ | `hud_pets.png`, `hud_inventory.png` |
| `hud_index` | Pet Index | ✅ | `hud_index.png` |
| `hud_rewards` | Daily+Goals | ✅ | `hud_rewards.png` |
| `hud_gifts` | Playtime gifts | ❌ | — |
| `hud_settings` | Settings | ✅ | `hud_settings.png` |
| `btn_close` | Close X | ✅ | `btn_close.png` |

### Baity

| ID pliku | Bait | Status |
|----------|------|--------|
| `bait_basic` | Basic | ✅ |
| `bait_bronze` | Bronze | ✅ |
| `bait_copper` | Copper | ✅ |
| `bait_silver` | Silver | ✅ |
| `bait_cobalt` | Cobalt | ✅ |
| `bait_platinum` | Platinum | ✅ |
| `bait_gold` | Gold | ✅ |
| `bait_diamond` | Diamond | ✅ |
| `bait_nebula` | Nebula | ✅ |
| `bait_fortune` | Fortune | ✅ |

### Throw / catch

| ID pliku | Status |
|----------|--------|
| `action_throw` | ✅ |
| `badge_new` | ✅ |
| `luck_bar_knob` | ✅ |

### Eventy

| ID pliku | Status |
|----------|--------|
| `event_rain` | ✅ |
| `event_rainbow` | ✅ |
| `event_lucky` | ✅ |
| `event_market` | ✅ |
| `event_storm` | ✅ |

### Teleport

| ID pliku | Status |
|----------|--------|
| `tp_shop` | ✅ |
| `tp_sell` | ✅ |
| `tp_throw` | ✅ |
| `tp_vip` | ✅ |
| `tp_vip_locked` | ✅ |

### Inventory actions

| ID pliku | Status |
|----------|--------|
| `inv_lock` | ✅ |
| `inv_unlock` | ✅ |
| `inv_pin` | ✅ |
| `inv_walk` | ✅ |
| `inv_sort` | ✅ |

### Stacje

| ID pliku | Status |
|----------|--------|
| `station_upgrade_luck` | ✅ |
| `station_upgrade_value` | ✅ |
| `station_soda` | ✅ |

---

## Nice

| ID pliku | Status |
|----------|--------|
| `currency_coin_sm` | ✅ |
| `tab_buy` | ✅ |
| `tab_sell` | ✅ |
| `tab_daily` | ✅ |
| `tab_goals` | ✅ |
| `rewards_daily` | ✅ |
| `rewards_goals` | ✅ |
| `badge_claim_dot` | ✅ |
| `catch_locked` | ✅ |
| `ui_check` | ✅ |
| `rarity_badge_legendary` | ✅ |
| `rarity_badge_mythic` | ✅ |
| `rarity_badge_angelic` | ✅ |
| `rarity_badge_glorious` | ✅ |
| `rarity_badge_radiant` | ✅ |
| `rarity_badge_secret` | ✅ |
| `rarity_badge_eternal` | ✅ |
| `rarity_badge_divine` | ✅ |

---

## Later

| ID pliku | Status | Notatki |
|----------|--------|---------|
| `hotbar_slot_empty` | ✅ | |
| `hotbar_keycap` | ❌ | Pominięte (seria 1–9 — zrobić ręcznie / batch później) |
| `toast_bg` | ❌ | Zostaje gradient UI |
| `tutorial_arrow` | ✅ | |
| `tutorial_guide` | ✅ | |
| `confirm_sell` | ✅ | |
| `vip_crown` | ✅ | |
| `index_progress` | ❌ | Ozdoba — niski priorytet |
| `event_soon` | ✅ | |

---

## Opcjonalne — tekstury UI

| ID pliku | Status |
|----------|--------|
| `tex_studs_white` | ⬜ nie generowane (tileable — lepiej ręcznie) |
| `tex_studs_color` | ⬜ |
| `tex_header_lattice` | ⬜ |
| `tex_panel_quilt` | ⬜ |
| `tex_slot_glow` | ⬜ |
| `tex_button_noise` | ⬜ |

---

## Poza zakresem

| Temat | Powód |
|-------|--------|
| Ikony / render każdego peta | 3D ViewportFrame |
| Modele `ServerStorage.Pets` | 3D |
| Mapa | zostaje |

---

## Podsumowanie

| Priorytet | Gotowe | Brak |
|-----------|--------|------|
| **Must** | ~36 | 0 |
| **Nice** | ~18 | 0 |
| **Later** | 6 | `hotbar_keycap`, `toast_bg`, `index_progress` |
| **Tekstury** | 0 | 6 opcjonalne |

---

## Podpięcie w kodzie (zrobione)

| Moduł | Rola |
|-------|------|
| `Modules/IconAssets.luau` | mapa key → emoji + rbxassetid |
| `Modules/UiIcon.luau` | `Mount` / `ApplyToButton` |
| `Modules/IconAssetIds.luau` | **tu lądują ID po uploadzie** |

UI już woła `UiIcon` (Shop, Bait, Index, Event, Teleport, Rewards, Settings, Upgrade, Soda…).

**Dopóki `IconAssetIds.Ids` jest puste — widać emoji.** Po uploadzie PNG na Roblox obrazki włączą się same.

### Upload (wymagane do prawdziwych grafik)

```powershell
$env:ROBLOX_API_KEY = "twój_klucz"
$env:ROBLOX_CREATOR_ID = "twoje_user_id"
$env:ROBLOX_CREATOR_TYPE = "User"
node roblox/tools/upload-icons.mjs
```

PNG: `roblox/assets/icons/` · skrypt: `roblox/tools/upload-icons.mjs`

Referencje: `_ref_index.png`, `_ref_coins.png`.
