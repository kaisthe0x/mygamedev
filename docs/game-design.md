# Game Design — premise & the Lahm system

> Living design doc. Captures the confirmed premise and the core economy. Numbers are
> **starting points to tune**, not final. Working name candidate that fits the theme:
> **"Way of All Flesh."** ("Lahm" = لحم, Arabic for *flesh / meat* — you harvest biomass
> off the things you kill.)

Status legend: **[CONFIRMED]** decided · **[OPEN]** still to tune/decide.

> **Built so far (vertical slice):** the full loop is playable — 5 data-driven levels, the
> **decoupled HP + lahm economy** (lahm as decaying blocks), damage-dealt paying lahm,
> wave-refill-on-clear, the exit toll priced in blocks, and the reward pick. Code + data live in
> [`scripts/run/`](../scripts/run/README.md) (one folder). Press F5. Numbers are placeholders to tune.

---

## 1. The one-line premise

A roguelite arena crawler where **life is the currency.** You drop into levels that
spawn enemies to overwhelm you, harvest their flesh (**lahm**) by killing them, and spend
that same life-force to pass each level's **exit toll**. Stay to bank more (greedy, risky)
or leave once you can afford the door (safe, less reward). Die and the run is over.

---

## 2. Lahm & HP — the heart of it  **[CONFIRMED — reworked]**

> **Design pivot.** Lahm used to be "HP above 100" — one pool. That let you tank hits and farm
> the same lahm back as health forever: camp one level, never leave, never die. **Fixed** by making
> lahm a *separate, decaying* resource. Now HP is your body and lahm is harvested fuel that **rots**.

**Two independent pools:**

```
HP    : 0 .. max_health (100).  Damage hits HP ONLY. Heals ONLY from rewards. 0 HP -> run over.
lahm  : 0 .. lahm_cap.  A currency, shown in BLOCKS (1 block = 50 lahm).
```

| Event | Effect |
|---|---|
| **Deal damage to an enemy** | `lahm += damage_dealt` (1 lahm per point; capped at `lahm_cap`) |
| **Lahm decay (always)** | `lahm -= 15/sec`, floored at 0 — flat, regardless of how much you hold |
| **Take damage** | `HP -= amount`. **Lahm is not a shield.** No heal. |
| **Pass an exit gate** | `lahm -= gate_cost`. HP untouched. |
| **Death** | `HP <= 0` → **run over, start from scratch** |

Notes:
- **Lahm is per-damage, not per-kill.** Chipping a 60-HP enemy pays 60 lahm total, delivered as you
  hit it. Overkill isn't paid (a 5-HP enemy hit for 25 gives 5). This makes the decay a *race*: your
  damage-per-second must beat the 15/sec rot to build toward the toll.
- **Decay = the time mechanic.** You can't take your time. Banking is pointless (it rots); you farm
  a burst of blocks and rush the gate. Decay pauses only while the tree is paused (reward popup) and
  during the spawn-in grace.
- **The only heal is a reward** — so exiting (the only way to reach rewards) is also the only way to
  mend. Camping earns nothing and slowly bleeds you to the endless waves. That's the pull forward.
- **Lahm carries** between levels (the leftover after paying the toll) — but it keeps rotting, so in
  practice you arrive near-empty and re-farm. The **run** starts at 100 HP / 0 lahm.
- `lahm_cap` is raised by a reward (see §5); base **10 blocks (500)**, enough headroom above the
  priciest gate to build a buffer before the door.

**Worked examples** (decay ignored for clarity)
- Run start: HP 100, lahm 0 (0 blocks).
- Chip three 60-HP enemies to death: +180 lahm → 3.6 blocks (while ~15/sec drains).
- Take 40 damage: HP 60, lahm unchanged. No way to heal it but a reward.
- Reach a 6-block gate (300) with 6.4 blocks, walk in: pay 300 → 0.4 blocks left, HP intact, reward
  offered (maybe a heal). Next level starts from there.

---

## 3. Combat feel  **[CONFIRMED]**

- **Enemies are beefy on purpose.** Floor of **≥ 25 HP** each, so a normal swing doesn't
  delete them and the arena stays a grind you have to work. (Elites/bosses far higher.)
- **Normal attacks chip** — several hits to down a basic enemy.
- **Specials are heavy — most are one-shot kills** on basic enemies. So the rhythm is:
  normals to grind + stay safe, specials to burst-harvest when the moment's right (specials
  are gated by their own cost/cooldown, so you can't just special everything).
- Because lahm = **damage you deal**, an enemy's full HP is its total lahm — so **tankier enemies
  are worth more**, but they take longer to fell, which is exactly the tension against the decay:
  the dangerous ones feed you the most *if* you can burst them before the rot eats your lead.

---

## 4. The level & the exit gate  **[CONFIRMED / BUILT]**

- A level is an **arena that keeps refilling**: it opens with a `start` pack, and **every time
  you clear all enemies, the next escalating wave spawns** (a puff marks each spot). Past the
  last authored wave, the hardest one repeats — so it never truly clears. (The fully-continuous
  timed-pressure variant is a later option; §7.6.)
- The **exit is a toll gate** priced in **lahm blocks**. You may leave whenever `lahm >= gate_cost`.
  Passing subtracts the cost (HP untouched); the remainder carries (and keeps rotting). The gate
  reads **green when affordable, red when not** — and because lahm decays, affordability *flickers*,
  so you build a buffer and rush the door.
- **Every gate always grants a reward** (see §5) — including the only source of healing.
- Leaving is the *only* way to complete a level. There is no "clear" state — the arena refills
  forever; the skill is **out-racing the decay to the toll, then cashing out**.

**The affordability invariant [tuned]**
`lahm_cap` must exceed `gate_cost` with headroom to build a buffer *and* walk to the gate while it
rots. Current ramp — **base cap 10 blocks (500)**; gate costs **4 / 5 / 6 / 7 / 8 blocks**
(200/250/300/350/400). The priciest gate (8) leaves 2 blocks of headroom; the `+2 blocks` reward
(§5) keeps that comfortable as tolls rise. Your **damage-per-second vs 15 lahm/sec** decides whether
you can ever reach a toll — a weak build can't, and slowly dies. That's the fail state working.

---

## 5. Run structure & rewards  (from earlier design talks)

- **[CONFIRMED-ish] 3 stages**, each **~6–7 levels (± optional)**, each stage ending in a
  **boss** (a scripted, smarter enemy — see the enemy/boss system).
- **[CONFIRMED] Resting areas** between stages: choose character (locked after stage 1),
  heal, and buy/apply buffs (with money / exp).
- **[CONFIRMED] Every exit gate grants a reward.** Since HP now heals *only* here, the pool leads
  with a **heal (Mend +40 HP)** and **+max HP** — the run's lifeline — plus **+damage** (farm lahm
  faster), **+2 lahm blocks** (raise `lahm_cap`, keeps tolls affordable), **+air jump**, **+run
  speed**. Built in [`rewards.gd`](../scripts/run/rewards.gd); money/exp meta rewards are later.
- **[BUILT] Loadout swaps + tiers.** Every attack/special/movement has a **tier** —
  **Typical → Elite → Broken** ([`loadout.gd`](../configs/loadout.gd)). Characters start on their
  **Typical** defaults; when a category has more than one option, a gate can offer a **swap card**
  (tier-badged) to trade up. The swap system spans attacks, specials, and movements (dash/run/jump/
  slam). Give a character a second attack/special in `moves.gd` (with a `tier`), or a movement
  variant in `loadout.gd` (`MOVEMENT_EXTRAS`), and it's instantly offerable. Loadout resets to
  defaults on death (`begin_run`). *(This repo ships **Khalid only**; he already has swaps a gate can offer — an alternate **attack**
  (the `ora_ora` flurry vs the Elite `spear` combo) and an Elite **special** (`stay`, a 5s-stun blast).)*
- **[CONFIRMED] Death = permadeath.** The whole run ends; you start over from scratch
  (roguelite). Meta-progression (exp, unlocks) persists across runs — details **[OPEN]**.

**The central player decision (the knob we want them sweating over) [CONFIRMED]**
Every moment in a level is: *bank more lahm (more buffer, but the arena keeps pressing and
you risk dying with it all)*, **vs** *leave now (spend the toll, take the reward, reset the
danger, but walk into the next level thinner)*. Greed vs. safety, priced in your own life.

---

## 6. HUD  **[CONFIRMED / BUILT]**

- **HP bar** + a **lahm BLOCK meter** beside it: discrete cells (one per block) that fill and drain
  partially, so you read health and banked blocks at a glance and *see the rot* live. Not a raw
  number — blocks, to match how you think about the toll.
- The **exit gate shows its cost in blocks** (e.g. "EXIT · 6 ▮"), green/red by affordability, so the
  target is always visible. Built in [`hud.gd`](../scripts/hud.gd) + [`exit_gate.gd`](../scripts/run/exit_gate.gd).

---

## 7. Open questions / to decide  **[OPEN]**

1. **Exact numbers** — base `lahm_cap`, gate cost curve, per-enemy HP/lahm values, special
   costs/cooldowns. Tune against §4's invariant.
2. **Currencies** — how do **lahm** (in-run life), **money** (gate reward, spent where?), and
   **exp** (meta, buffs in resting areas) relate? Are money/exp per-run or persistent?
3. ~~Pass-at-exactly-cost~~ **[RESOLVED]** — moot now: paying the toll spends lahm only and never
   touches HP, so `lahm >= cost` is safe. No survival margin needed.
4. **Death spiral** **[CONFIRMED — it's the decay]** — a low-damage build can't out-race the 15/sec
   rot to any toll, bleeds to the waves, and dies. Legit fail state. Open: any soft telegraph
   ("your damage can't beat the rot") or leave it raw? Currently raw.
5. **Optional levels** — the "± optional levels depending on the run" — what gates those?
6. **Spawn pacing** — cadence/scaling of the overwhelming spawn per level/stage (the reshaped
   "wave" system).
