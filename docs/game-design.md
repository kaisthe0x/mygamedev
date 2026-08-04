# Game Design — premise & the Lahm system

> Living design doc. Captures the confirmed premise and the core economy. Numbers are
> **starting points to tune**, not final. Working name candidate that fits the theme:
> **"Way of All Flesh."** ("Lahm" = لحم, Arabic for *flesh / meat* — you harvest biomass
> off the things you kill.)

Status legend: **[CONFIRMED]** decided · **[OPEN]** still to tune/decide.

> **Built so far (vertical slice):** the full loop is playable — 5 data-driven levels, the
> life/lahm economy + HUD bar, kills paying lahm, wave-refill-on-clear, the exit toll, and the
> reward pick. Code + data live in [`scripts/run/`](../scripts/run/README.md) (one folder). Press
> F5. Numbers are placeholders to tune.

---

## 1. The one-line premise

A roguelite arena crawler where **life is the currency.** You drop into levels that
spawn enemies to overwhelm you, harvest their flesh (**lahm**) by killing them, and spend
that same life-force to pass each level's **exit toll**. Stay to bank more (greedy, risky)
or leave once you can afford the door (safe, less reward). Die and the run is over.

---

## 2. Lahm & life — the heart of it  **[CONFIRMED]**

Lahm and HP are **the same resource.** Under the hood there is a single value, `life`:

```
life        : a single number, 0 .. MAX_LIFE      (MAX_LIFE = 100 + lahm_cap)
HP  (shown) : min(life, 100)                       # the 0..100 "health" band
Lahm(shown) : max(0, life - 100)                   # everything banked above 100
```

Everything is just add/subtract on `life`:

| Event | Effect on `life` |
|---|---|
| **Kill an enemy** | `life = min(life + enemy_value, MAX_LIFE)` — `enemy_value` = the enemy's (max) HP |
| **Take damage** | `life -= amount` (eats banked lahm first, then HP — it's the top of the pool) |
| **Pass an exit gate** | `life -= gate_cost` |
| **Death** | `life <= 0` → **run over, start from scratch** |

Notes:
- The **run** starts at `life = 100` (full HP, 0 lahm). After that it is **pure carry-over** —
  you are *not* reset to 100 each level; you keep whatever you walked out of the last gate with.
- `lahm_cap` (hence `MAX_LIFE`) is **raised by rewards** (see §5). This is the pacing engine —
  see the invariant in §4.
- **Kills always pay full value regardless of how you killed** — chip it down or one-shot it,
  a 25-HP enemy is +25 lahm either way. One-shotting is just *faster/safer* per unit of lahm.

**Worked examples**
- Run start: `life = 100` → HP 100, Lahm 0.
- At full HP, kill a 25-HP enemy: `life = 125` → HP 100, Lahm 25 (overflow banks as lahm).
- Take 40 damage from 125: `life = 85` → HP 85, Lahm 0 (lahm absorbed first, then HP).
- Walk into a level at 30 life, gate costs 25: pass → 5 life → next level HP 5, Lahm 0.

---

## 3. Combat feel  **[CONFIRMED]**

- **Enemies are beefy on purpose.** Floor of **≥ 25 HP** each, so a normal swing doesn't
  delete them and the arena stays a grind you have to work. (Elites/bosses far higher.)
- **Normal attacks chip** — several hits to down a basic enemy.
- **Specials are heavy — most are one-shot kills** on basic enemies. So the rhythm is:
  normals to grind + stay safe, specials to burst-harvest when the moment's right (specials
  are gated by their own cost/cooldown, so you can't just special everything).
- Because lahm = enemy HP, **tankier enemies are worth more lahm** — a natural risk/reward:
  the dangerous ones feed you the most.

---

## 4. The level & the exit gate  **[CONFIRMED / BUILT]**

- A level is an **arena that keeps refilling**: it opens with a `start` pack, and **every time
  you clear all enemies, the next escalating wave spawns** (a puff marks each spot). Past the
  last authored wave, the hardest one repeats — so it never truly clears. (The fully-continuous
  timed-pressure variant is a later option; §7.6.)
- The **exit is a toll gate** priced in life (lahm/HP). You may leave **whenever you want**,
  as long as `life >= gate_cost`. Passing subtracts the cost; you carry the remainder forward.
  The gate reads **green when affordable, red when not**.
- **Every gate always grants a reward** (see §5).
- Leaving is the *only* way to complete a level. There is no "clear" state — the arena would
  bury you eventually; the skill is knowing **when to cash out**.

**The affordability invariant [OPEN — tune]**
To pass a gate you must be able to *reach* its cost, so:

```
MAX_LIFE (= 100 + lahm_cap)  must exceed  gate_cost,  with a survival margin
```

Otherwise the gate is impassable (you'd hit exactly 0 on the way out). Consequences:
- Gate tolls **rise each level**; therefore **`lahm_cap` must rise too** — that's why the
  "increase max lahm" reward is mandatory pacing, not optional flavor.
- Starting numbers implied by "first gate ~450": base `MAX_LIFE` ~**500** (base `lahm_cap`
  ~**400**), first `gate_cost` ~**450**, so a full-farm player leaves with ~50 life. Enemies
  at ~25 HP → farming ~15–18 kills to afford the first gate. **All tunable.**

---

## 5. Run structure & rewards  (from earlier design talks)

- **[CONFIRMED-ish] 3 stages**, each **~6–7 levels (± optional)**, each stage ending in a
  **boss** (a scripted, smarter enemy — see the enemy/boss system).
- **[CONFIRMED] Resting areas** between stages: choose character (locked after stage 1),
  heal, and buy/apply buffs (with money / exp).
- **[CONFIRMED] Every exit gate grants a reward.** Reward pool includes at least:
  **a buff, health (life), money, and "increase max lahm" (raise `lahm_cap`).** The
  cap-raise reward is what keeps future gates affordable (§4).
- **[CONFIRMED] Death = permadeath.** The whole run ends; you start over from scratch
  (roguelite). Meta-progression (exp, unlocks) persists across runs — details **[OPEN]**.

**The central player decision (the knob we want them sweating over) [CONFIRMED]**
Every moment in a level is: *bank more lahm (more buffer, but the arena keeps pressing and
you risk dying with it all)*, **vs** *leave now (spend the toll, take the reward, reset the
danger, but walk into the next level thinner)*. Greed vs. safety, priced in your own life.

---

## 6. HUD  **[CONFIRMED]**

- **HP bar** + a **lahm indicator right beside it.** Both always visible and clearly
  distinct, so the player reads their health and their banked lahm at a glance (and can see
  the overflow filling past 100 as they harvest).
- Should also surface the **current gate cost** so the player knows their target.

---

## 7. Open questions / to decide  **[OPEN]**

1. **Exact numbers** — base `lahm_cap`, gate cost curve, per-enemy HP/lahm values, special
   costs/cooldowns. Tune against §4's invariant.
2. **Currencies** — how do **lahm** (in-run life), **money** (gate reward, spent where?), and
   **exp** (meta, buffs in resting areas) relate? Are money/exp per-run or persistent?
3. **Pass-at-exactly-cost** — do we forbid passing when it would leave you at 0 (require
   `life > cost`), or allow a suicidal exit? Recommend requiring a ≥1 margin.
4. **Death spiral** — a low player who can't out-farm the arena will slowly die. Confirmed as
   a legit fail state; do we want any soft telegraph ("you're too thin, leave") or leave it raw?
5. **Optional levels** — the "± optional levels depending on the run" — what gates those?
6. **Spawn pacing** — cadence/scaling of the overwhelming spawn per level/stage (the reshaped
   "wave" system).
