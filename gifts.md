# Playtime Gifts — sesja lucka

Specyfikacja prezentów za czas w grze. Dokument ustaleń — nie implementacja. Liczby oznaczone **propozycja** można ruszyć przy kodzie; reszta to decyzje.

---

## Cel

Gracz ma powód **nie wychodzić** z experience.

- Im dłużej siedzisz w tej sesji, tym wyższy mnożnik lucka.
- Buff **nie zapisuje się**. Leave / Rejoin z menu Robloxa = start od zera.
- Cel UX: *„nie kliknę Leave, bo stracę ×2”*.

To nie jest daily reward i nie mieszamy tego z panelem Rewards.

---

## 1. Ikona HUD

Osobny przycisk na HUD — **nie** zakładka w Rewards.

- Ikona prezentu (`hud_gifts`, fallback emoji 🎁 — Rewards już używa `hud_rewards`, więc osobny key).
- **Propozycja pozycji:** prawa krawędź, nad / obok `OpenRewards` (`RewardsGui` jest na `UDim2.new(1, -18, 0, 108)`), żeby stack prawych przycisków został czytelny na mobile.
- Klik → otwiera panel Gifts (toggle, jak Rewards).
- Zielona kropka + pulse, gdy jakiś prezent jest gotowy do odebrania (jak `ClaimDot` na Rewards).
- Gdy buff aktywny: mały badge na ikonie z aktualnym mnożnikiem, np. `×1.3`.

Tutorial: przycisk odblokowany po tutorialu (jak inne HUD).

---

## 2. Panel

Lista 5 prezentów, od góry do dołu, jeden wspólny zegar sesji.

| # | Czas w sesji | Mnożnik lucka (**propozycja**) |
|---|--------------|--------------------------------|
| 1 | 5 min | ×1.1 |
| 2 | 20 min | ×1.2 |
| 3 | 40 min | ×1.3 |
| 4 | 1 h | ×1.5 |
| 5 | 2 h | ×2 |

Każdy slot:

- nazwa + czas progu,
- stan: Locked (timer) / Ready (Claim) / Claimed (ptaszek + aktywny mnożnik),
- przy Locked: countdown do odblokowania, np. `12:41`.

Stopka panelu (zawsze widoczna):

- *“Leaving the game resets these gifts.”*

Nagłówek: aktualny buff, np. `Gift luck: ×1.3` albo `No gift luck yet`.

---

## 3. Jeden rosnący buff

Nie mnożą się przez siebie. Jest **jeden** mnożnik sesji. Odebranie kolejnego **podmienia** poprzedni.

Przykład:

- nic nie odebrane → `giftLuck = 1`
- claim 5 min → `giftLuck = 1.1`
- claim 20 min → `giftLuck = 1.2` (nie `1.1 × 1.2`)
- … aż claim 2 h → `giftLuck = 2`

Max z odebranych = aktualny buff. Niższy nigdy nie wraca, dopóki sesja żyje.

---

## 4. Claim

Trzeba **kliknąć Claim**. Nic się nie nakłada samo, gdy minie czas.

Po Claim:

- `giftLuck` od razu skacze na mnożnik tego progu,
- luck na następnym throwie już z nowym buffem (HUD lucka też),
- slot → Claimed,
- **panel sam się odświeża**: jeśli czas sesji już pokrywa kolejny próg, następny slot natychmiast pokazuje Claim (bez zamykania panelu, bez resetu zegara).

Zegar jest jeden: **łączny czas bycia w experience**, nie czas od ostatniego claimu.

Scenariusz: gracz nie otwiera panelu przez 2 h, potem klika ikonę.

1. Claim 5 min → buff ×1.1, zaraz 20 min = Ready.
2. Claim 20 min → ×1.2, zaraz 40 min = Ready.
3. … aż 2 h → ×2.

Kolejność twarda: nie da się odebrać 20 min, dopóki 5 min nie jest Claimed. Po odbiorze UI samo podsuwa następny.

Claim tylko gdy slot Ready. Spam / claim Locked → serwer odrzuca.

---

## 5. Co nabija czas

Sam fakt, że gracz **jest w experience**. Zero wymagań co do rzutów, jaskini, shopu, AFK.

Liczy się:

- stanie na spawnie, shop, inventory, VIP, Map 2, AFK place,
- idle, menu, emote.

Nie liczy się (bo nie ma gracza w sesji):

- offline,
- po Leave / Rejoin z menu Robloxa,
- po crashu / kicku bez powrotu w tej samej sesji.

Timer: czas ściany na serwerze od `Player.Join` (plus przeniesiony elapsed przy teleportcie wewnątrz experience — §7). Nie ufać klientowi.

---

## 6. Leave / Rejoin = strata + warning

Buff i postęp **tylko w pamięci sesji**. Nie DataStore.

Tracisz prezenty gdy:

- **Leave** z menu Robloxa (ESC),
- **Rejoin** z menu Robloxa (ESC),
- świeży join do experience (bez teleport data z naszego place’a),
- crash / disconnect i powrót jak do nowej gry.

**Nie** tracisz przy AFK auto-rejoin (~16 min). To nie jest ESC Rejoin — sesja idzie dalej przez TeleportData (§7).

Roblox nie da się podpiąć pod sam przycisk Leave. Warning leci, gdy gracz **otworzy menu ESC**:

`GuiService.MenuOpened` → banner / toast (nie da się zignorować przez 4–5 s, albo dopóki menu otwarte):

- *“Leaving or rejoining will reset your playtime gifts.”*
- Jeśli buff już aktywny, dopisać aktualny mnożnik: *“You will lose ×1.5 luck.”*

Dodatkowo stały tekst w panelu Gifts (§2).

Po powrocie: czas 0, nic nie odebrane, `giftLuck = 1`. Można znowu nabijać od 5 min. To jest cały haczyk.

---

## 7. Teleport wewnątrz gry vs wyjście

Bycie w grze = Map 1, Map 2, VIP, AFK — to **ta sama** sesja prezentów.

Cross-place teleport (`TeleportService`) robi nowego `Player` na drugim serwerze. Żeby nie zresetować prezentów przy Map 2 / AFK:

- przy teleportcie packujemy `GiftSession` w TeleportData: elapsed, claimed tiers, `giftLuck`,
- join z naszym TeleportData → przywróć i licz dalej,
- join bez tego (ESC Leave/Rejoin, ikona na stronie gry, crash) → sesja od zera.

**AFK auto-rejoin** (~16 min, żeby Roblox nie kicknął za idle): gracz **nie** klika ESC. Sesja prezentów **zostaje** — ten sam `GiftSession` w TeleportData. Inaczej 2 h gift jest niemożliwy przy AFK. Świadomy Rejoin z ESC i tak resetuje.

Studio: jak inne teleports — ostrzec, że cross-place w Studio może nie przejść; QA na live.

---

## 8. Wzór lucka

Mnożnik wchodzi w **aktualny** luck catcha, ten sam łańcuch co potki:

```text
luck = bar × upgrade × bait × goals × companion × cave × event × potion × giftLuck
```

`giftLuck` = 1 albo 1.1 / 1.2 / 1.3 / 1.5 / 2 po claimach.

Działa na rzutach w jaskini (mapa 1 / VIP / Map 2). HUD `Luck: …` pokazuje już po × gift.

**AFK place (spec `afk.md`):** tam luck hajsu to tylko `bait × luckUpgrade`. **Propozycja:** dodać `giftLuck` także tam (`afkLuck = bait × luckUpgrade × giftLuck`), bo sesja i tak leci na AFK. Potki nadal nie działają na AFK.

Nie rusza: sell, pity, Index, misje (poza tym, że lepszy luck = łatwiejsze catch/discover).

---

## 9. UX / komunikaty (EN, jak reszta gry)

| Kiedy | Tekst |
|-------|--------|
| ESC menu otwarte | *“Leaving or rejoining will reset your playtime gifts.”* (+ *“You will lose ×N luck.”* gdy buff > 1) |
| Stopka panelu | *“Leaving the game resets these gifts.”* |
| Gift Ready | toast *“Playtime gift ready!”* + kropka na ikonie |
| Claim | toast *“Gift luck ×1.3”* (aktualny mnożnik) |
| Claim Locked | nic / ignore |
| Join od zera (po leave) | bez toasta — po prostu puste prezenty |

Ikona: pulse gdy Ready. Po claimie pulse gaśnie, chyba że następny też już Ready.

---

## 10. Dane / serwer (orientacja pod kod)

Nie implementować tu; checklist gdy przyjdzie czas:

- `GiftConfig` — progi sekund + mnożniki
- Pamięć per player na serwerze: `JoinedAt` / `ElapsedSeconds`, `ClaimedTier` (0–5), `GiftLuck`
- Remote: stan panelu (elapsed, ready, claimed, giftLuck) + `ClaimGift(tier)`
- Serwer liczy elapsed i czy tier wolno claimnąć; klient tylko rysuje
- Wpiąć `giftLuck` w `BaitServer` obok `potionLuck`
- HUD ikona + panel (osobny `ScreenGui`, nie `RewardsGui`)
- `GuiService.MenuOpened` → warning
- TeleportData `GiftSession` przy Map 2 / AFK / VIP **oraz** przy AFK auto-rejoin (~16 min)
- Ikona `hud_gifts` w `IconAssets` / `ikonki.md`
- **Nie** zapisywać do DataStore

Anti-exploit: elapsed tylko z serwera; claim tylko kolejny tier; mnożnik tylko z configu na serwerze.

---

## 11. Ustalenia (decyzje)

| Temat | Wybór |
|--------|--------|
| UI | Osobna ikona HUD z prezentem, własny panel |
| Progi | 5 min / 20 min / 40 min / 1 h / 2 h |
| Mnożniki | ×1.1 / ×1.2 / ×1.3 / ×1.5 / ×2 (**propozycja**) |
| Stack | Jeden rosnący buff — kolejny **zastępuje** poprzedni |
| Claim | Ręczny; po odbiorze panel i luck updateują się same |
| Kolejność | Twarda: 5 → 20 → 40 → 1 h → 2 h |
| Czas | Cały czas w experience, bez interakcji |
| Leave / Rejoin ESC | Reset + warning w menu ESC |
| Crash / świeży join | Reset |
| Teleport Map 2 / VIP / AFK | Sesja leci dalej (TeleportData) |
| AFK auto-rejoin (~16 min) | Zachować sesję (TeleportData) — gracz nie klika ESC |
| Zapis | Brak DataStore |
| Luck | Mnoży aktualny catch luck (`× giftLuck`) |

---

## 12. Otwarte na implementację (nie blokuje speca)

- Dokładna pozycja ikony vs Rewards / Settings na mobile
- Grafika `hud_gifts.png` (do `ikonki.md`)
- Czy warning ESC to toast, banner na górze, czy overlay pod menu
- Czy `giftLuck` wchodzi w AFK hajs (rekomendacja: tak)
- Czy po 2 h ikona zostaje z badge `×2` bez dalszych progów (tak — max sesji)
