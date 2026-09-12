# AFK — tryb i strefa

Specyfikacja nowego AFK. Zastępuje obecny przycisk AFK przy spawn/cave (autothrow co ~8 s, prawdziwe pety, rejoin overnight na mapie 1).

Dokument ustaleń — nie implementacja. Liczby oznaczone **propozycja** można ruszyć przy kodzie; reszta to decyzje.

---

## Cel

AFK ma być wygodą na osobnym place, nie optymalną strategią vs ręczna jaskinia.

- Gracz nie łapie petów z jaskini.
- Każdy rzut zamienia się w **hajs** tak, jakbyś wylosował tego peta w **normalnej** jaskini i od razu sprzedał za **bazowy** `SellPrice`.
- Dodatkowo: małe szanse na **potki** (niezależnie od lucka) i rzadkie **pety AFK** (zależne od lucka).
- Aktywny grind (ręka, VIP, Map 2, companion, eventy, Index, pity) zostaje wyraźnie lepszy.

---

## Stan obecny (do wycięcia / zastąpienia)

Dziś AFK to ten sam throw co ręczny, tylko automat:

- Przycisk **AFK** w HUD (`AutoThrowClient`) — działa przy spawn / cave na mapie 1 i Map 2.
- Cooldown ×3 (`BaitConfig.AfkCatchCooldownMultiplier`) ≈ **8 s**, **bez** upgrade speed.
- Łapie prawdziwe pety (inventory, Index, pity, misje).
- Rejoin co ~16 min (`AfkServer`), żeby Roblox nie wyrzucił za idle (~20 min).
- Flaga `AfkThrow` w DataStore.

To znika z mapy 1 / Map 2 / VIP. AFK istnieje **tylko** na osobnym place.

---

## 1. Gdzie jest AFK

Osobny **place** w tej samej experience (jak Map 2), nie pad na mapie 1.

- Nowy Place ID w `PlaceConfig` (np. `AfkPlaceId`) — do wklejenia po utworzeniu w Creator Dashboard.
- Na AFK place **nie ma** jaskini VIP, Map 2 luck, shopu baitów, sell station jaskiniowych petów.
- Jest pad / jaskinia AFK tylko do wizualnego rzutu + spawn gracza.

### Wejście

Górny HUD teleportów (`TeleportHud`) — nowy przycisk **AFK** obok SHOP / SELL / THROW / VIP.

1. Klik **AFK**.
2. Modal potwierdzenia (nie teleport od razu), np.:
   - *„Go AFK? You will not catch cave pets. You get coins, potions, and rare AFK pets. One throw every 30s.”*
   - **Go AFK** / **Cancel**
3. Po **Go AFK**: save → `TeleportService` na AFK place (`Destination = "afk"`, `AfkThrow = true`).
4. Po wejściu: stoi na spawnie AFK, autothrow **startuje sam** (potwierdził wejście = jest w trybie).

Tutorial: przycisk AFK zablokowany do ukończenia tutorialu (jak inne teleports).

Studio: cross-place teleport jak Map 2 — ostrzeżenie, że w Studio place się nie zmieni; QA live.

### Wyjście = wyrzucenie z trybu

Gracz wychodzi z trybu tylko świadomie:

- Przycisk na dole overlay: **Return To Lobby**.
- Znowu **potwierdzenie**: *„Leave AFK? Auto-throw will stop.”*
- Po potwierdzeniu: `AfkThrow = false`, teleport na mapę 1 (ThrowSpawn).

**Nie** wychodzi z trybu przez: idle Roblox, rejoin, respawn, lag. To zostaje w trybie (patrz §6).

Ręczny throw / przycisk AFK na mapie 1, Map 2 i VIP: **nie działa**. Jedyne AFK = ten place.

---

## 2. Pętla rzutu (autothrow)

Na AFK place serwer sam odpala rzuty. Klient nie musi klikać SPACE ani trafiać luck bara.

| Parametr | Wartość |
|----------|---------|
| Cooldown | **stałe 30 s** między resolvami |
| Bait CatchSpeed | ignorowany (nie przyspiesza AFK) |
| Upgrade speed | ignorowany (jak dziś) |
| Luck bar | brak — od razu resolve |
| Animacja | brak — pełny overlay lobby; postać w tle ignorowana |

Jeden tick AFK (co 30 s), w tej kolejności:

1. **Roll wirtualny** — jak pet z normalnej jaskini (§3) → od razu **hajs** (§4). Gracz **nie widzi** peta (ani nazwy, ani modelu).
2. **Roll potki** — niezależny od lucka (§5). Trafienie = extra, hajs i tak wpada.
3. **Roll peta AFK** — zależny od lucka AFK (§7). Trafienie = extra do kolekcji AFK; hajs z kroku 1 i tak wpada.

Gdy bag AFK pełny: krok 3 skip (toast), kroki 1–2 bez zmian.

---

## 3. Luck wirtualnego rolla (hajs + pety AFK)

„Jak w normalnej jaskini na swoim poziomie lucka” = **tylko**:

- aktywny **bait** (`BaitLuck`)
- **upgrade Luck** (`LuckBonus`)

**Nie wchodzi:**

- VIP 4×
- Map 2 1.35×
- companion luck
- eventy (Rain, Lucky Surge, …)
- buff z misji
- luck bar (minigra)
- upgrade value / companion sell / Market Boom (to i tak nie rusza hajsu AFK — §4)

Wzór lucka AFK:

```text
afkLuck = baitLuck * luckUpgradeBonus
```

Ten sam `afkLuck` idzie do:

- wirtualnego `PetService.RollPet` (tabela jaskiniowa, tylko po to żeby znać rarity / `SellPrice`)
- rolla petów AFK (osobna tabela, §7)

Pity jaskiniowe **nie** wchodzi w żaden z tych rolli.

---

## 4. Hajs zamiast peta

Serwer losuje peta tak, jakby throw w **normal cave** przy `afkLuck`.

- Nie dodaje peta do baga jaskini.
- Nie pokazuje nazwy / modelu / rarity card tego peta.
- Wypłaca **bazowy** `SellPrice` z katalogu (to, co w `PetConfig` / instancji peta). **Bez** value upgrade, companion sell, eventów, tagów (Rainbow itd.).

Przykład:

- roll = Dog (Common, SellPrice 12) → **+12** coins
- roll = Dragon (np. Legendary, SellPrice 2200) → **+2200** coins

UI: toast / tick `+12$` / `+2,200$`. Większa kwota = mocniejszy feel (kolor, dźwięk), nadal **bez** „You caught Dragon”. Opcjonalnie próg FX od kwoty, nie od rarity name.

`GoalService.OnCoinsEarned` — **propozycja: TAK** (hajs z AFK liczy się do misji „zarob X coins”, bo to realne monety). Catch-count / discover **NIE** (§8).

---

## 5. Potki

Nowy system (dziś nie ma potion inventory).

Dwa typy z AFK:

| Potka | Efekt **propozycja** | Czas **propozycja** |
|-------|----------------------|---------------------|
| Luck Boost | +50% luck (`×1.5`) | **5 min** rzeczywistego czasu w jaskini |
| Sell Boost | +50% sell (`×1.5`) | **5 min** rzeczywistego czasu w jaskini |

Szansa **niezależna od lucka**, osobno na każdy typ, co rzut AFK.

**Propozycja dropu:** 1.0% Luck potka, 1.0% Sell potka na throw (~2 potki/h przy 120 throwach). Nie stackować dwóch dropów tego samego typu w jednym ticku ponad 1 sztukę.

Zasady:

- Wpadają do **ekwipunku potek** (nie do baga petów).
- Gracz **używa ręcznie** później.
- Działają **tylko w normalnej jaskini** (mapa 1 cave / VIP / Map 2 — aktywny catch). Na AFK place **nie da się** użyć; jeśli ktoś użył przed wejściem, timer **pauzuje** na AFK i wznawia po powrocie do jaskini **albo** (prościej) timer leci tylko gdy nie jesteś na AFK place i jesteś w świecie catcha.
- **Propozycja implementacji timera:** countdown tylko gdy gracz jest na place jaskini (main lub Map 2) i `AfkThrow ~= true`. Wejście na AFK pauzuje.
- Nie działają na hajs z AFK (payout i tak bazowy; potki są po to, żeby wrócić do jaskini).
- Stack: **propozycja** — ta sama potka przedłuża czas (5+5), nie mnoży ×1.5×1.5. Inny typ może być aktywny razem (luck + sell).
- Limit ekwipunku potek: **propozycja** 20 szt. łącznie; przy pełnym skip drop + toast.

UI: mały slot / panel potek (HUD lub zakładka w shop/inventory). Toast na drop: `Luck Boost +1` / `Sell Boost +1`.

---

## 6. Rejoin i czas trwania

Rejoin **zostaje**, ale **tylko** żeby utrzymać tryb, dopóki gracz sam z niego nie wyjdzie.

- Timer ~16 min jak dziś (`AfkServer.RECONNECT_AFTER`).
- Rejoin leci **na AFK place** (nie na ThrowSpawn mapy 1), z `AfkThrow = true`.
- Po rejoin: znowu spawn AFK + autothrow dalej.
- Studio: komunikat jak dziś, że rejoin nie działa w Studio.

Kiedy tryb się **kończy**:

- potwierdzony LEAVE / teleport precz z AFK place
- gracz sam wyłączy AFK na tamtym place

Kiedy tryb **nie** kończy się:

- idle kick Roblox (rejoin wraca)
- disconnect / crash — `AfkThrow` zapisane; następny join experience → jeśli flaga true, od razu na AFK place i rzuca dalej
- śmierć / respawn na AFK place

---

## 7. Pety AFK (osobna kolekcja)

Kilka unikalnych petów **tylko** z AFK. Nie mieszają się z jaskinią.

- Osobny katalog (`AfkPetConfig`), osobny bag, osobny mini-Index AFK.
- Nie wchodzą do zwykłego Pet Index, hotbara Carry, companion fuse, sell listy jaskini.
- **Słaby sell** — da się sprzedać z UI kolekcji AFK za małe monety (flex > ekonomia).
- Głównie kolekcja / flex.

**Propozycja rosteru (6 szt.):** 3 common-ish, 2 uncommon/rare, 1 „trophy” bardzo rzadki. Nazwy i modele — przy implementacji. Szanse rosną z `afkLuck` (ten sam co §3), ale **inna tabela** niż jaskinia — nawet wysoki luck nie ma dawać jaskiniowego Divine’a.

**Propozycja rzadkości dropu peta AFK** (osobny roll po hajsie):

- bazowa szansa że w ogóle spadnie *jakikolwiek* pet AFK: niska, np. **2%** przy luck 1, skalowana w górę z `afkLuck` (soft cap, np. max ~8–10%), potem weighted rarity wewnątrz rosteru
- trophy pet: ułamek tego rolla, praktycznie tylko przy wysokim baicie + upgrade luck

Bag AFK: **propozycja** stałe 30 slotów, bez upgrade (to nie ma być sink jak cave bag). Lock jak zwykłe pety, żeby nie sprzedać trophy przypadkiem.

UI: zakładka **AFK** w inventory / osobny panel na AFK place. Index AFK = odkrycie unikalnych (dla kolekcji, **bez** nagród monet typu cave Index — albo bardzo małe, **propozycja: bez kasy za discover**, sam flex).

Equip: **propozycja** — 1 slot pokazu (nad głową / obok) **tylko na AFK place**, zero buffów. Na mapie 1/2 niewidoczny.

---

## 8. Czego AFK nie rusza (meta)

Wirtualny dragon / pies **nie istnieje** jako pet. Więc:

| System | AFK |
|--------|-----|
| Cave inventory / bag capacity | nie |
| Pet Index (jaskinia) | nie |
| Pity | nie |
| Misje catch / discover | nie |
| Tutorial catch | nie |
| Companion / fuse | nie |
| Event tagi na pecie | nie |
| Upgrade speed | nie (cooldown i tak 30 s) |

Liczy się:

- **Coins** na koncie (hajs + słaby sell petów AFK)
- **propozycja:** misje „earn coins”
- inventory potek
- kolekcja AFK

Pełny cave bag **nie blokuje** AFK (nie łapiesz cave petów).

---

## 9. Balans — dlaczego to nie zjada jaskini

Porównanie 1 h:

- Ręczny throw: ~2.8 s, pełny luck (VIP, eventy, companion, luck bar), prawdziwe pety, Index, pity, value upgrade przy sellu.
- Stary AFK: ~8 s, prawdziwe pety, overnight.
- **Nowy AFK:** 120 throwów/h, hajs = suma bazowych sellów z rolli `bait × luckUpgrade` bez VIP/eventów, plus ~2 potki/h i rzadki pet AFK.

Efekt:

- Overnight = powolny hajs + potki na sesję ręczną + kolekcja flex.
- Dragon w AFK = jedna wypłata bazowa, zero peta, zero Index.
- Potki są powodem wrócić do jaskini, nie powodem zostać w AFK (na AFK nie działają).

Nerf vs `ready.md` #1/#8 zostaje w duchu, tylko twardszy: nie ×3 od 2.8 s, tylko **stałe 30 s** i brak cave petów.

---

## 10. UX / UI (skrót)

**Mapa 1 / Map 2**

- Nowy przycisk **AFK** w górnym HUD.
- Modal potwierdzenia przed teleportem.
- Stary okrągły przycisk AFK (`AutoThrowGui`) — usunąć albo ukryć.

**AFK place — pełny overlay (jak Volleyball Legends AFK lobby)**

Avatar w tle nieważny. Nie ma rzutu baita, luck bara ani Result UI jaskiniowego peta.

- Na środku: fotka / logo **BAIT A PET!** + napis AFK LOBBY (asset później; do tego czasu placeholder).
- Góra: pasek + countdown do następnego rolla (30 s).
- Prawo: panel **CHANCES** — hybryda: krótki opis hajsu (bazowy sell wirtualnego peta) + % na potki i pety AFK (trophy osobno, % liczone z aktualnego `afkLuck`).
- Lewo: saldo monet, **COINS EARNED** (sesja), log **RECEIVED**.
- Dół, środek: **Return To Lobby** + confirm (*„Leave AFK? Auto-throw will stop.”*).
- Dół, prawo: tylko **Music: ON/OFF**. Bez VIP/Premium luck (nie działają tu — nie sugerujemy że można włączyć).
- Górny HUD (SHOP / SELL / THROW / VIP) na tym place ukryty.

**Potki** — ikona + timer gdy aktywne w jaskini.

**Komunikaty (EN, jak reszta gry):**

- Potwierdzenie wejścia — §1.
- Potwierdzenie wyjścia — §1.
- Rejoin: *„Rejoining so AFK can keep throwing…”* (jak dziś, ale wraca na AFK place).
- Bag AFK pełny: *„AFK bag full — sell or lock space.”*

---

## 11. Dane / place (orientacja pod kod)

Nie implementować tu; checklist gdy przyjdzie czas:

- `PlaceConfig.AfkPlaceId`
- Teleport destination `"afk"` / `"map1"` analogicznie do map2
- DataStore: `AfkThrow`, `AfkPets[]`, `AfkPetIndex`, `Potions{}`, aktywne buffy potek + remaining time
- Wipe **nie** potrzebny jeśli nowe pola z defaultami
- Serwer: wirtualny roll + payout na AFK place; odrzucić `StartBait` / catch z klienta na tym place (anti-exploit)
- Wyłączyć `AutoThrowClient` poza AFK place; na AFK place pętla serwerowa albo klient-only request z twardym cooldownem 30 s na serwerze

---

## 12. Ustalenia (decyzje)

| Temat | Wybór |
|--------|--------|
| Miejsce | Osobny place, wejście górnym teleportem + confirm |
| Start | Po wejściu autothrow sam |
| Stop | Return To Lobby na dole overlay + confirm |
| Rejoin idle | Tak, z powrotem na AFK place, aż gracz wyjdzie z trybu |
| Cave pety | Nie |
| Hajs | Bazowy SellPrice wirtualnego rolla (normal cave) |
| Luck hajsu / AFK petów | Tylko bait + upgrade luck |
| VIP / Map2 / companion / eventy / luck bar | Nie |
| Sell multiplier na hajs AFK | Nie |
| Index / pity / catch misje | Nie |
| Cooldown | 30 s stałe |
| Potki | Luck + sell, ekwipunek, tylko jaskinia, czas w minutach |
| Pety AFK | Osobna kolekcja, słaby sell, flex |

---

## 13. Otwarte na implementację (nie blokuje speca)

- Dokładny roster i modele 6 petów AFK
- Overlay UI: pełny lobby (timer / CHANCES hybryda / RECEIVED / Return To Lobby / Music)
- Place ID: `89818308891412` (AFK lobby)
- Fotka logo BAIT A PET! — placeholder do czasu assetu
- Czy `OnCoinsEarned` z AFK (rekomendacja: tak)
- Czy timer potki pauzuje na AFK (rekomendacja: pauzuje)
- Czy pet AFK ma slot pokazu tylko na AFK place (rekomendacja: tak, 0 buff)
- Czy Index AFK ma kasę za discover (rekomendacja: nie)
- Czy większy hajs pokazuje rarity color bez nazwy peta
