# To-do — bait / pets

## 1. Maszyna / companion (Soda Machine)

- [x] 3 te same odblokowane pety → fuse przy maszynie (E → UI → Create Companion)
- [x] Companion chodzi za graczem (`CompanionFollowService`)
- [x] Buff: luck + sell wg rarity (`CompanionConfig.BuffByRarity`)
- [x] 1 companion naraz (kolejny fuse podmienia); zapis `CompanionPetName` w DataStore
- [x] Inventory: lista odblokowanych companionów + **Walk** do przełączania (`UnlockedCompanions` / `SetCompanion`)

## 2. Nagrody za Pet Index

- [x] Nagrody za odblokowanie nowych petów w indexie — Claim w UI + `IndexRewardConfig` (kasa wg rarity)
- [x] Milestone’y (% kompletności / rarity tiers)
- [x] UI + zapis postępu w DataStore — `ClaimedIndexPets` (+ migracja starych discovery bez wypłaty) + `ClaimedIndexMilestones`



## 3. Eventy co N minut

- [x] Timed eventy co N minut (serwer / świat) — `EventService` + scheduler (~2.5–4 min idle, ~60–80s event)
- [x] Efekty: Rain (luck), Rainbow (tag+flare+value), Lucky Surge (luck), Market Boom (sell), Thunderstorm (luck+Storm tag)
- [x] Ogłoszenie w HUD + timer — `EventClient` banner / toast / lekki atmosphere FX



## 4. Lepsze animacje / FX dla lepszych petów

- [x] Przybliżenie kamery przy catchu Legendary+ (cinematic 1–2s, FOV + look-at)
- [x] Drżenie ekranu (screen shake) — Rare = tylko shake; Legendary+ shake w zoomie
- [x] Dźwięki tierowane: Common / Rare / Epic / Legendary / Mythic / Divine
- [x] Flary / aura: world burst Epic+; aura na modelu w Result UI (Rare+)
- [x] Skalowanie intensywności FX z rarity (`CatchFeelConfig.Tiers` Burst/Zoom/Shake)



## 5. Ekonomia długoterminowa (cel: ~2 tyg. grania, nie 5 min)

- [x] Format kasy: tysiące → miliony → miliardy → … (skróty K / M / B / T / Q / Qi / Sx) — `NumberFormat`
- [x] Luck z bardzo dużą liczbą zer (wysoki sufit liczbowy) — Fortune 250Kx, OneIn Epic+ mocno w górę
- [x] Znacznie niższy drop rate rzadkich petów / wysokich tierów — SoftWeight **0.27** (1D), VIP 4×, pity nie boostuje Angelic+
- [x] Przeliczenie cen sprzedaży, shopu i upgrade’ów pod długi grind — economy **1B** + wipe `PlayerData_v2`; **1D** Map 1 + wipe `PlayerData_v3`
- [x] Misje znacznie cięższe — catch 25/60/120, Legendary discover, earn 2.5K/14K/45K (**1D**)
- [ ] Friends smoke: VIP+basic ≠ Glorious w 15 min; Bronze nie w 15 min F2P; goals nie w kilka minut



## 6. Mikropłatności (DevProducts / passy)

- [ ] Packi monet (mały / średni / duży)
- [ ] Temporary luck boost (np. 15 / 30 / 60 min)
- [ ] Temporary sell multiplier
- [ ] Starter pack (bait + monety + mały boost)
- [ ] Limited / seasonal packs przy eventach
- [ ] Extra inventory / hotbar slots (gamepass lub DevProduct)
- [ ] Auto-sell / auto-catch convenience (gamepass)
- [ ] Daily offer / rotating shop Robux
- [ ] UI sklepu Robux + potwierdzenia zakupu na serwerze (receipt handler)



## 7. Więcej baitów

- [x] Nowe ~~~~baity w katalogu — **+5**: copper, cobalt, platinum, diamond, nebula (między bronze→fortune)
- [x] Luck + opcjonalny **CatchSpeed** (cooldown = base / speed, min 1.1s)
- [ ] Baity specjalne: sell-only, rarity bias (np. Epic+)
- [ ] Baity eventowe / limited (timed)
- [ ] Baity craft / unlock z Index lub milestone’ów
- [x] Balans cen i multiplierów pod Map 1 — economy **1D** (Bronze 16k / Copper 55k / Silver 165k)
- [x] Ikony + opisy w shopie (speed widoczny gdy >1)
