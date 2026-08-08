# Future enhancements & fixes

A running parking lot for ideas and fixes that are **not being built yet**. Drop new ideas here
the moment they come up; promote one into a real task when it's time. Newest at the top is fine.

---

## Game modes: Normal vs. Hard ("Attrition")

Two run modes. Names are placeholders — want something more evocative than "Normal / Hard".

### Hard mode — passive health drain ("Attrition")

The player is **actively, slowly dying**: HP ticks down on its own as time passes. **Killing an
enemy restores a small chunk of HP.** This forces aggression — you can't camp; you have to keep
killing to stay alive.

- The drain **stops when only one enemy (or none) remains** in the level. So the player can leave
  the last enemy alive and take a breather / reposition without bleeding out.
- Intended as the **Hard** mode only; Normal mode has no drain.

**Rough implementation shape (for when we build it):**
- A run-level `mode` flag (Normal / Hard) chosen at run start.
- In Hard mode, drain HP at `drain_rate` HP/sec while `alive_enemy_count > 1`; pause otherwise.
- Heal `kill_heal` HP on each enemy death (hook the existing `Enemy.died` / RunManager kill path).
- Tune `drain_rate` vs `kill_heal` so a competent player nets positive while fighting, negative
  while idling. Surface the drain in the HUD (e.g. a subtle red vignette pulse or a downward HP
  tick) so it's readable.
- Consider: does the special-meter / reward economy differ by mode? (Probably Hard just adds the
  drain on top of the same loop.)

---

<!-- Add future ideas below this line. -->
