# BAIT A PET! — decyzje i zmiany

Dokument roboczy: co dodajemy / zmieniamy. Wspólnie oceniamy (dobrze / źle / ryzyko) i zapisujemy tu ustalenia.

---

## Status

Sesja decyzji **domknięta** — **9 akceptacji**. Implementacja: **#1–#9 done**.

**Economy 1D (Map 1)** — liczby wpisane. Kotwica: jak Fisch (pierwszy „kij” ~1h), nie jak PS99 (pierwszy świat w 15 min). Smoke: sekcja na dole.

**Wipe:** `PlayerData_v3` + leaderboardy `*_v2`. Stary save `v2` jest porzucony. VIP gamepass zostaje (Marketplace).

---

## Ustalenia

### 1. Nerf AFK — dłuższy cooldown (AKCEPTACJA)

**Decyzja:** AFK ma być wyraźnie gorszy od ręcznego łapania przez dłuższy cooldown między throwami.

**Dlaczego dobrze:**
- Teraz AFK używa tego samego catch cooldownu co manual (~2.8s base) → overnight ≈ aktywna gra.
- To podkopuje ekonomię 1B/1C i cel „~2 tyg. grindu”, nie „drukuj w nocy”.
- Aktywny gracz musi być nagradzany; AFK zostaje convenience, nie optymalną strategią.

**Implementacja:**
- `BaitConfig.AfkCatchCooldownMultiplier = 3`
- `GetCatchCooldown(baitId, afkThrow)` — gdy AFK: cooldown × **3** (po MinCatchCooldown)
- Serwer: `getCatchCooldownForPlayer` czyta `AfkThrow`
- Cel: 1h AFK ≪ 1h ręcznego; patrz też **#8** (AFK bez upgrade speed)

**Świadomie nie:** wyłączanie AFK; kara luck/sell przy AFK.

---

### 2. Drugi slot noszenia petów po map 2 (AKCEPTACJA — A)

**Decyzja:** po odblokowaniu / pierwszym wejściu na mapę 2 gracz ma **2 sloty** equipped (noszenie petów).

**Dlaczego dobrze:** jasna nagroda za progress świata; mapa 2 coś realnie daje.

**Implementacja:**
- Flaga `Map2Unlocked` (DataStore) — pierwsze wejście na mapę 2 / teleport Destination=map2
- Toast: „Map 2 unlocked — you can equip 2 pets!”
- Max equipped: 1 → **2** (kosmetyka: prawa + lewa ręka)
- Hotbar: multi-select highlight (`EquippedPetSlot` + `EquippedPetSlot2`)
- Studio QA: `/map2unlock`

**Świadomie nie:** kupno pierwszego ekstra slotu tylko w upgrade; pełne buffy z 2 equipped + companion.

---

### 3. Upgrade skracający cooldown rzutu (AKCEPTACJA z limitem)

**Decyzja:** nowy upgrade (obok luck / value) zmniejsza catch cooldown.

**Dlaczego dobrze:**
- Sink monet + odczuwalny progress aktywnej gry.
- Łączy się z nerfem AFK: ręczny throw + upgrade ≫ AFK.

**Warunki / implementacja:**
- Upgrade `speed` (`SpeedLevel`), soft cap **30%** CDR na max level (`MaxCatchCooldownReduction = 0.30`)
- Manual: `(base / baitSpeed / upgradeSpeed)` → `max(MinCatchCooldown)`
- AFK: **bez** upgrade speed (#8), potem **×3** AFK mult
- UI: rząd „Catch Speed” (−X% cooldown, manual)

**Ryzyko bez limitu:** bait speed + upgrade → spam throw → pity/coins/goals zbyt szybko.

---

### 4. Max bag inventory + upgrade pojemności (AKCEPTACJA)

**Decyzja:** wprowadzić **limit ekwipunku petów** (bag capacity) z możliwością powiększania w sklepie **Upgrade** (monety).

**Dlaczego dobrze:**
- Dziś inventory jest **bez limitu** — brak ciśnienia na sell i słaby sink.
- Limit + upgrade = klasyczna progresja pets + naturalny powód sprzedawać / lockować ważne.
- Pasuje do istniejącego Upgrade (luck / value / + speed z #3); lepiej za monety niż od razu DevProduct.

**Kierunek / implementacja:**
- Start **30**, **+5**/BagLevel, max level **24** → **150** slotów
- Upgrade `bag` w Upgrade shop (ten sam cost curve co early luck/value)
- Przy pełnym bagu: **blokada catcha** + toast
- Ostrzeżenie przy **~90%** (raz, aż spadnie poniżej) — #9
- Gracze z >30 petami: nie tracą ich; nie łapią nowych aż sell/upgrade
- DataStore: `BagLevel`; atrybuty `BagCapacity` / `PetCount`

**Świadomie nie:** gamepass-only slots; auto-delete przy full.

---

### 5. VIP luck 4× (AKCEPTACJA świadoma)

**Decyzja:** `VipLuckMultiplier` **2 → 4**. Gracz świadomie wybiera mocniejsze P2W.

**Implementacja:**
- `CaveConfig.VipLuckMultiplier = 4`
- Copy UI: `VipNearHint`, `VipPurchase` toast, `VipConfig.PromptMessage` → „4x luck”
- Po sync: re-smoke VIP cave (pacing); jeśli padnie — SoftWeight / OneIn, nie cofamy 4× bez decyzji

**Ryzyko przyjęte:** płatny progress wyraźnie szybszy vs F2P.

---

### 6. Map 2 — sens gameplay (AKCEPTACJA — DONE)

**Decyzja:** mapa 2 nie jest tylko portalem + slotem noszenia. Daje **powód wracać**: lekki biom luck i/lub unikalny bait i/lub inny pet pool (jeden lub kombinacja — doprecyzować przy implementacji).

**Dlaczego dobrze:** inaczej po odblokowaniu slotu 2 mapa umiera; retention wymaga różnicy vs main.

**Implementacja:** biom luck **1.35×** na Map 2 (`CaveConfig.Map2LuckMultiplier` / `GetPlaceLuckMultiplier`); CatchZone `CaveLuckMult` na place Map 2; hint throw `Map2NearHint`.

**Świadomie nie:** pełny „drugi świat endgame” od razu; trade/eggs/combat; osobny bait/pool w tym kroku.

---

### 7. Index milestone’y (AKCEPTACJA — DONE)

**Decyzja:** nagrody za milestone’y Pet Index — % kompletności i/lub rarity tiers (obok istniejących claimów per-pet).

**Dlaczego dobrze:** długoterminowy cel discovery; retention; już było w `to-do.md` jako otwarte.

**Implementacja:**
- Percent: `pct_10` … `pct_100` + rarity complete `rarity_Common` … `rarity_Divine`
- DataStore: `ClaimedIndexMilestones` (osobno od `ClaimedIndexPets`)
- Claim w UI Index (sekcja Milestones) + `ClaimMilestone` remote
- Config: `IndexRewardConfig` helpers

---

### 8. AFK bez upgrade speed (AKCEPTACJA)

**Decyzja:** upgrade skracający cooldown (#3) działa **tylko przy ręcznym** throwie. Przy `AfkThrow` upgrade speed = 1 (ignorowany).

**Dlaczego dobrze:** wzmacnia #1+#3 bez kolejnego mnożnika; AFK nie „kupuje” sobie tempa za monety tak samo jak aktywny gracz.

---

### 9. Toast przy ~90% bag (AKCEPTACJA)

**Decyzja:** gdy ekwipunek ≈ **90%** pojemności — toast ostrzegawczy („Bag almost full — sell pets”), zanim złapie blokadę 100% z #4.

**Dlaczego dobrze:** mniej frustracji; gracz zdąży sprzedać / ulepszyć bag.

**UX:** nie spamować co catch — cooldown toastu albo raz na sesję aż spadnie poniżej progu.

---

### 10. Economy 1D — Map 1 pacing (DONE)

**Kotwica F2P** (Fisch / catch-sell-upgrade, nie PS99 area-rush):

| Moment | Czas | Feel |
| First luck/bag upgrade (2k) | 10–15 min | win sesji 1, mapa NIE skończona |
| Bronze 3× (16k) | 50–75 min | pierwszy prawdziwy spike; **nie w 15 min** |
| Copper 8× (55k) | 2.5–4 h / dzień 2 | mid Map 1 |
| Silver 25× (165k) | 5–8 h / 2–3 dni casual | „umiem Map 1” |
| Gold+ baits / Mythic+ sells | tydzień+ | long tail Map 1, nie warunek wyjścia |
| Index 100% | 1–2 tyg. | discovery, nie clear |

**Liczby:** Common sell **10**, Uncommon **28**, Rare **80**. Upgrade early **2k / 4.5k / 8k**. Potion **65k** (po Copper). Lucky Surge **1.8×**. SoftWeight **0.27**, ExponentScale **0.40**. VIP **4×** bez zmian. Pity Epic–Legendary bez zmian. AFK sells poniżej cave Common. Goal ID `earn_*` bez zmian (tylko target/nagroda).

**Świadomie nie:** wipe DataStore, ProductId, gate portalu Map 2, zmiana luck baitów.

#### Smoke checklist Map 1 (Studio, nowy save)

- [ ] **15 min F2P, basic bait, no VIP:** da się kupić luck/bag 1; **nie** da się kupić Bronze
- [ ] **15 min VIP + basic:** Common/Uncommon dominują; **brak** Glorious / Radiant+
- [ ] **~60 min F2P:** Bronze w zasięgu albo tuż po; Copper wciąż daleko
- [ ] Potion 65k jest **droższa** niż Copper 55k — gracz kupuje bait, nie snack
- [ ] catch_25 / earn easy **nie** dopłacają do Bronze
- [ ] Group chest 500 + tutorial 80 **nie** skipują Bronze
- [ ] 10 ads (1.5k) w 15 min **nie** kupują Bronze
- [ ] AFK: wolniejszy throw + gorszy sell niż cave Common
- [ ] Bag 30 blokuje catch; toast ~90%
- [ ] Goals `earn_1500` (target 2500) nadal ładują się ze starego save

---

## Otwarte

Świadomie później (nie w tym pakiecie): DevProducts, trade, eggs, combat — wg `plan.md`.
