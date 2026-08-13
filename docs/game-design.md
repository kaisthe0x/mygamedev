# Game Design — premise, Ruh & the run loop

> Living design doc. Captures the confirmed premise and the core systems. Numbers are
> **starting points to tune**, not final. Working name candidate that fits the theme:
> **"Way of All Flesh."**

Status legend: **[CONFIRMED]** decided · **[OPEN]** still to tune/decide · **[WIP]** stored but not fully realised.

> **Built so far (vertical slice):** the full loop is playable — 5 data-driven levels, **clear-on-kill**
> arenas that spawn enemies in escalating batches, the **Ruh** surge meter (start with 3 charges,
> refill by landing hits; **specials are free — surges spend Ruh**), the **Aegis surge** (on-demand
> invincibility that costs a charge), one **random typed reward door** per level, a run-start
> **attack picker** (attack locked for the run), and per-run buffs. Code + data live in
> [`scripts/run/`](../scripts/run/README.md) + [`configs/`](../configs/). Press F5.
>
> **History:** an earlier build used *Lahm* — life-as-currency that you farmed from damage and spent
> on an exit toll, with a decay timer. That's been replaced by the Ruh / clear-on-kill model below.
> (An optional passive **health-drain "Hard mode"** revives the time-pressure idea — see
> [`future-enhancements-and-fixes.md`](future-enhancements-and-fixes.md).)

---

## 1. The one-line premise

A roguelite arena crawler. You drop into levels that spawn enemies in **batches**; **clear them all**
and the exit opens. Landing hits charges your **Ruh** meter, which fuels the **Aegis surge** — spend a
charge to turn **briefly invincible** on demand (you start with 3). **Specials are free and unlimited.**
Each level's exit is a **random reward door** — Health, Athletic, Attack, or Special — that
buffs your run. Your **attack is chosen at the start and locked**; only its power grows. Die and the run is over.

---

## 2. Ruh & HP  **[CONFIRMED]**

**Two independent pools:**

```
HP   : 0 .. max_health (100). Damage hits HP ONLY. Heals ONLY from rewards. 0 HP -> run over.
Ruh  : 0 .. ruh_cap.  The SURGE meter (surge fuel), shown in CHARGES/BLOCKS (1 block = RUH_PER_BLOCK = 100).
```

| Event | Effect |
|---|---|
| **Land a hit** | `ruh += RUH_PER_HIT` (20 → ~5 hits = 1 charge). **No decay.** |
| **Hit *with the special*** | **no Ruh** — a special's own hits don't self-pay (an `last_hit_from_special` flag rides `Hit → Hitbox → Enemy → RunManager`) |
| **Cast a special** | **free and unlimited** — no Ruh cost, no requirement. Only a tiny `SPECIAL_COOLDOWN` (0.6s) anti-spam lag, not a real limiter. |
| **Fire a surge** | **spends** `SurgeSpec.cost` Ruh (100 = one charge; Aegis = 100). **No cooldown — Ruh is the only gate** (`if ruh < s.cost: return`, then `ruh -= s.cost`). Aegis = **invincible** for its `duration` (5s); re-triggering (if you can pay) refreshes it. |
| **Take damage** | `HP -= amount × damage_taken_mult`. Ruh untouched. |
| **Death** | `HP <= 0` → **run over, start from scratch** |

- **Ruh fills by landing hits, never decays.** You start a run with **3 charges** (`BASE_RUH_CAP` =
  300); rewards raise the cap up to a hard **max of 5** (`MAX_RUH_CAP`). Ruh is **surge fuel** — one
  surge = one charge (100 Ruh); **specials cost nothing**. Consumables that refill Ruh are a planned later addition.
- **The only heal is a reward.** Camping earns nothing and bleeds you to the batches; clearing +
  taking a door is the only way to mend. That's the pull forward.
- The **run** starts at 100 HP / a **full** Ruh meter (`Player.begin_run` sets `ruh = ruh_cap`). HP,
  Ruh, and `ruh_cap` all carry between levels.

---

## 3. Specials & the Aegis surge  **[CONFIRMED]**

- **Specials** (chosen at run start, swappable at the Special door) do their own thing — a ground
  crack, a stun blast, a magnet, a shield. **They are now FREE and unlimited** — no Ruh cost, no
  requirement (`Player._start_special` no longer touches Ruh); only a tiny `SPECIAL_COOLDOWN` (0.6s)
  anti-spam lag remains. (A special's own hits still grant no Ruh — an `last_hit_from_special` flag
  rides `Hit → Hitbox → Enemy → RunManager`.)
- **Surges** are a **separate** ability on their own button (`surge` = Ctrl / RT). One press applies a
  **timed self-buff** that runs independently for its full duration. There is **no cooldown** — **Ruh is
  the only gate**: each use spends its `SurgeSpec.cost`. On trigger the player plays a **brief activation
  flex** (`State.SURGE`, the `surge_<id>` sprite anim, ~0.5s) while the buff carries on; the aura VFX is
  the invuln aura spawned for the duration and the SFX plays on trigger. `Player._try_surge` runs every
  frame (`if ruh < s.cost: return`, then `ruh -= s.cost`). Data: `Action.Category.SURGE`
  rows carrying a **`SurgeSpec`** ([`configs/surge_spec.gd`](../configs/surge_spec.gd): `cost` + `duration` +
  `invuln`) in [`ActionsKhalid.SURGES`](../configs/actions_khalid.gd) (`DEFAULT_SURGE = "aegis"`).
- **Aegis** — the one shipped Surge — is the old `special_default` "Impervious/Flex," promoted out of
  the specials pool into its own system: full damage **immunity for 5s** (`duration`), and it **costs 100
  Ruh (one charge) per use, with no cooldown — Ruh-gated**. **Impervious** itself = the hurtbox
  off (same channel as dash i-frames) + the shared **Impervious aura**
  ([`vfx/shared/impervious/`](../vfx/shared/impervious/)).
- Wired via `Player._try_surge` → `grant_special_invuln(duration)` in [`player.gd`](../scripts/player.gd).
  The old Impervious *buff* (`scripts/abilities/impervious.gd`) and the "invuln on every special cast"
  behaviour are **gone**; the `on_special_cast` Passive hook remains only as an unused seam.

---

## 4. The level & the reward door  **[CONFIRMED / BUILT]**

- A level is an **arena cleared by killing**: it opens with a `start` batch, and each time the current
  batch is wiped the **next (escalating) batch** spawns. Batches are **finite** — once the last is
  cleared, the level is done and the **exit opens**. Total enemies = `start` + every wave, introduced
  progressively (open ~4–5, ramp up). Data: [`levels.gd`](../scripts/run/levels.gd).
- The exit is a **reward DOOR** with a **random type** rolled per level: **Health / Athletic / Attack /
  Special**. It shows its **icon + label** (from the [`Icons`](../configs/icons.gd) registry), stays
  red `LOCKED` until cleared, then opens in the type's colour. Walking in → **pick one** of that type's
  rewards. [`exit_gate.gd`](../scripts/run/exit_gate.gd).
- More door types are planned (**money** to buy buffs/outfits; an **ally meeting point**).

---

## 5. Run structure, attacks & rewards  **[CONFIRMED / BUILT]**

- **Attack is chosen at run start and LOCKED.** A scrollable **attack picker**
  ([`attack_select.gd`](../scripts/run/attack_select.gd), built to scale to 12+) opens on every fresh
  run; the chosen attack can't change mid-run — only get **buffed** (the Attack door).
- **Specials CAN change** (the Special door offers change-special swaps) — and casting is **free** (no
  Ruh cost, no charge required). Impervious is no longer a special *or* a buff: it's the **Aegis surge**
  now (see §3), fired on its own passive button and paid for with Ruh.
- **Typed reward pools** ([`rewards.gd`](../scripts/run/rewards.gd)), all per-run (reset on death):
  - **Health** — Mend (+HP), Second Skin (+max HP).
  - **Athletic** — +air jump, +run speed, Thick Hide (−dmg taken), Meteor (+slam dmg).
  - **Attack** — Long Arm (+reach), Bloodlust (+dmg), Leech (lifesteal), Split Shot (+proj) **[WIP]**.
  - **Special** — Deeper Ruh (+1 charge), Fortitude (+3s Aegis invuln), Last Stand (Aegis-lasts-till-hit)
    **[WIP]**, Wide Impact (+radius) **[WIP]**, and change-special swaps.
- Every attack / special / door / buff has an **icon** via [`Icons`](../configs/icons.gd) — temp art
  now; swap a path there when real icons land, no UI changes.
- **Death = permadeath.** The run ends and restarts from scratch; the best-ever *levels cleared* is
  persisted (`SaveData`, shown on the HUD). Deeper meta-progression **[OPEN]**.
- **[OPEN] Stages & resting areas** — grouping levels into stages, bosses, and between-stage rest
  (choose character, spend money/exp) is still to build.

---

## 6. HUD  **[CONFIRMED / BUILT]**

- **HP bar** + a **Ruh charge meter** (surge fuel) beside it (crimson cells, one per charge, fill as you land hits, drain on a surge), and
  a **`LEVELS n · BEST n`** line (cleared this run + best-ever record). [`hud.gd`](../scripts/hud.gd).
- The reward door shows its **type icon + label**, red `LOCKED` → its accent colour on clear.

---

## 7. Open questions / to decide  **[OPEN]**

1. **Exact numbers** — `RUH_PER_HIT` / surge `cost` / cap, the Aegis surge `duration` (5s), special
   anti-spam cooldown, per-enemy HP, batch sizes/pacing, buff values.
2. **Modes** — Normal vs a **Hard "Attrition"** mode (passive HP drain, heal-on-kill) — see
   [`future-enhancements-and-fixes.md`](future-enhancements-and-fixes.md). Names TBD.
3. **Currencies / meta** — money (buy buffs/outfits) + exp/unlocks across runs — per-run or persistent?
4. **Stages / bosses / resting areas** — structure above the single-level loop.
5. **The WIP buffs** — realise Split Shot (multishot), Last Stand (invuln-till-hit), Wide Impact
   (scene-hitbox radius) fully.
6. **More door types** — money door, ally meeting point.
