# Game Design — premise, Ruh & the run loop

> Living design doc. Captures the confirmed premise and the core systems. Numbers are
> **starting points to tune**, not final. Working name candidate that fits the theme:
> **"Way of All Flesh."**

Status legend: **[CONFIRMED]** decided · **[OPEN]** still to tune/decide · **[WIP]** stored but not fully realised.

> **Built so far (vertical slice):** the full loop is playable — 5 data-driven levels, **clear-on-kill**
> arenas that spawn enemies in escalating batches, the **Ruh** special meter (fills by killing),
> **Impervious** specials (invincibility), one **random typed reward door** per level, a run-start
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
and the exit opens. Killing charges your **Ruh** meter, which you spend on a **special** to become
**Impervious** (briefly invincible). Each level's exit is a **random reward door** — Health, Athletic,
Attack, or Special — that buffs your run. Your **attack is chosen at the start and locked**; only its
power grows. Die and the run is over.

---

## 2. Ruh & HP  **[CONFIRMED]**

**Two independent pools:**

```
HP   : 0 .. max_health (100). Damage hits HP ONLY. Heals ONLY from rewards. 0 HP -> run over.
Ruh  : 0 .. ruh_cap.  The SPECIAL meter, shown in CHARGES/BLOCKS (1 block = RUH_PER_BLOCK = 100).
```

| Event | Effect |
|---|---|
| **Kill an enemy** | `ruh += RUH_PER_KILL` (25 → 4 kills = 1 charge). **No decay.** |
| **Kill *with the special*** | **no Ruh** — so the special can't self-loop its own Impervious (buffable later) |
| **Cast a special (with the Impervious buff + Ruh)** | `ruh -= SPECIAL_COST` (one charge) → **Impervious** for `SPECIAL_INVULN_TIME` (10s). Without the buff, the special just fires its own effect and Ruh is untouched. |
| **Take damage** | `HP -= amount × damage_taken_mult`. Ruh untouched. |
| **Death** | `HP <= 0` → **run over, start from scratch** |

- **Ruh fills by kills, never decays.** Default cap is **1 charge**; rewards raise it up to a hard
  **max of 5** (`MAX_RUH_CAP`). One cast = one charge.
- **The only heal is a reward.** Camping earns nothing and bleeds you to the batches; clearing +
  taking a door is the only way to mend. That's the pull forward.
- The **run** starts at 100 HP / empty Ruh (`Player.begin_run`). HP + `ruh_cap` carry between levels;
  Ruh itself resets each level.

---

## 3. Specials & Impervious  **[CONFIRMED]**

- **`special_default`** is the baseline special everyone loads with — no damage, no effect. On its own
  it does nothing; it's only useful once the **Impervious buff** is equipped (then a cast spends a Ruh
  charge to go invincible).
- **Other specials** (via the Special door) do their own thing — a ground crack, a stun blast — and
  are **always usable** (a short cooldown stops spam).
- **Impervious is now an earned BUFF, not a baseline** ([`scripts/abilities/impervious.gd`](../scripts/abilities/impervious.gd),
  a shared special buff). With it equipped, casting a special *also* spends a Ruh charge to go
  invincible; without it, specials never grant invuln. (It used to be hardcoded into every special.)
- **Impervious** = the hurtbox is off (same channel as dash i-frames) + the shared **Impervious aura**
  ([`vfx/shared/impervious/`](../vfx/shared/impervious/)). The buff grants that one aura.
- Wired via the buff's `on_special_cast` hook → `grant_special_invuln` in [`player.gd`](../scripts/player.gd); the
  no-refill twist rides a `from_special` flag through `Hit → Hitbox → Enemy → RunManager`.

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
- **Specials CAN change** (the Special door offers change-special swaps). Impervious is no longer
  automatic — it's an earned buff (see §3) that layers the invuln window onto any special cast.
- **Typed reward pools** ([`rewards.gd`](../scripts/run/rewards.gd)), all per-run (reset on death):
  - **Health** — Mend (+HP), Second Skin (+max HP).
  - **Athletic** — +air jump, +run speed, Thick Hide (−dmg taken), Meteor (+slam dmg).
  - **Attack** — Long Arm (+reach), Bloodlust (+dmg), Leech (lifesteal), Split Shot (+proj) **[WIP]**.
  - **Special** — Deeper Ruh (+1 charge), Fortitude (+Impervious time), Last Stand (invuln-till-hit)
    **[WIP]**, Wide Impact (+radius) **[WIP]**, and change-special swaps.
- Every attack / special / door / buff has an **icon** via [`Icons`](../configs/icons.gd) — temp art
  now; swap a path there when real icons land, no UI changes.
- **Death = permadeath.** The run ends and restarts from scratch; the best-ever *levels cleared* is
  persisted (`SaveData`, shown on the HUD). Deeper meta-progression **[OPEN]**.
- **[OPEN] Stages & resting areas** — grouping levels into stages, bosses, and between-stage rest
  (choose character, spend money/exp) is still to build.

---

## 6. HUD  **[CONFIRMED / BUILT]**

- **HP bar** + a **Ruh charge meter** beside it (crimson cells, one per charge, fill as you kill), and
  a **`LEVELS n · BEST n`** line (cleared this run + best-ever record). [`hud.gd`](../scripts/hud.gd).
- The reward door shows its **type icon + label**, red `LOCKED` → its accent colour on clear.

---

## 7. Open questions / to decide  **[OPEN]**

1. **Exact numbers** — `RUH_PER_KILL` / cost / cap, `SPECIAL_INVULN_TIME` (10s feels long?), cooldown,
   per-enemy HP, batch sizes/pacing, buff values.
2. **Modes** — Normal vs a **Hard "Attrition"** mode (passive HP drain, heal-on-kill) — see
   [`future-enhancements-and-fixes.md`](future-enhancements-and-fixes.md). Names TBD.
3. **Currencies / meta** — money (buy buffs/outfits) + exp/unlocks across runs — per-run or persistent?
4. **Stages / bosses / resting areas** — structure above the single-level loop.
5. **The WIP buffs** — realise Split Shot (multishot), Last Stand (invuln-till-hit), Wide Impact
   (scene-hitbox radius) fully.
6. **More door types** — money door, ally meeting point.
