Each player ability has a default state and a buffed state, both of which can be upgraded throughout the player's run. Abilities can be buffed either temporarily for a set number of levels or permanently for the entire run.

This behavior is controlled through a duration field:
If null, the buff is permanent.
If set to a number, it represents how many levels the buff will last.

Every ability — buffed or default — displays an icon and a name to the player.

Regardless of state, each ability has its own SFX, VFX, and Area2D/hitbox (where applicable). Buffs range from straightforward stat boosts — such as damage, speed, and jump height — to custom-scripted effects that trigger unique, specialized behaviors.
Ability Tiers
All ability buffs will be tiered.
Common: No color
Rare: Blue
Hot: Orange
Sensational: Purple
Epic: Red

Some examples;
Assume the player picks up an ability that buffs their damage by 12%. A Rare version of that ability would increase it to 20%, Hot to 30%, Sensational to 50%, and Epic to 75%.
Assume the player picks up an ability where their redere frisbee deals 15% more damage. A Rare version would increase this to 17% and bounce off one additional enemy, Hot to 20% and bounce off 3 enemies, Sensational to 25% and bounce off 4 enemies, and Epic to 30% and bounce off 5 enemies.

# Dash

The player can dash through enemies and in mid-air. While dashing, they briefly blink in & out of visibility, becoming immune to all damage while traversing levels more quickly and fluidly. The player starts with a basic dash — one use per cool-down cycle.

Buffs
On Dash
Player becomes immune to damage for 1 second.
Player can immediately dash again with no cool-down.
Passing through enemies deals damage to them.
Passing through enemies steals their health.
Passing through enemies stuns them for 2 seconds.
Player can leave behind a 3-second trap that stuns enemies.
Player can leave behind a 3-second trap that weakens enemies by 25%.
Player can leave behind a 5-second trap that continuously damages enemies within its area.
Player can leave behind a one-time burst trap that explodes upon enemy contact, dealing damage.
On Perfect Dodge (last-second dodge after dash)
40% speed boost for 5 seconds.
50% damage boost for 7 seconds.
Damage immunity for 3 seconds.

# Jump

The player can jump twice in a row — once off the ground and once mid-air. This enables easier traversal across the level and allows them to reach greater heights.
Buffs
On Ground Jump
Player becomes immune to damage for 1 second.
Player can jump 30% higher.
Player can leave behind a 3-second trap that stuns enemies.
Player can leave behind a 3-second trap that weakens enemies by 25%.
Player can leave behind a 5-second trap that continuously damages enemies within its area.
Player can leave behind a one-time burst trap that explodes upon enemy contact, dealing damage.
On Air Jump:
Player can air-jump one more time.
At the peak, player can hear a sound effect that, if he decided to trigger a slam right then and there, slam damage increases by 50%.

# Slam

The player can slam down onto enemies from a sufficient height, dealing damage across a predetermined area. The higher they are, the more damage they can do.
Buffs
On Slam Trigger
Player launches 5 projectiles downward, damaging enemies below (player still slams down).
Player slam damage is boosted by 20%.
On Slam Land:
Player becomes immune to damage for 2 seconds.
Surviving enemies are stunned for 2 seconds.
Player gains 10% of current health per enemy killed.
Player gains a 50% boost to ground jump height.
Player attack damage is boosted by 50% for 1 second.

# Attack

The player can choose from a wide variety of attack forms — whether it's a standard melee strike, a burst, a burst with a cool-down, a projectile, or anything in between. Attacks are designed with ultimate flexibility in mind. The one guarantee: if it doesn't deal damage, it isn't an attack.
Buffs for attacks cover all the basics — leaving behind traps, throwing extra projectiles, increasing run speed, stunning enemies longer — with virtually no limit.
 
That said, some attacks also come with custom-built buffs tailored specifically to their mechanics. For example, Bakshen is a burst of energy that deals immense damage to close-proximity enemies, with a 3-second cool-down. A custom buff for this could reduce that cool-down — or remove it entirely while decreasing the damage output to keep it balanced.
Buffs (General for all attacks)
On Attack Trigger:
Attack hitbox reach is increased by 50%.
On the First 7 Seconds of Each Level:
Attack damage is doubled.
On Hit:
Damage dealt is multiplied by 1.25x for every hit.
Become immune to damage for 0.25 seconds.
On Attack Animation End:
Become immune to damage for 1 second.
Buffs (Per Attack)
Zahluq
Burst forward, damaging any enemies in your path.
Type: Single click; Burst forward followed by a cool-down.

On Attack Animation End:
If the player finds himself out of bounds and about to fall off the platform after the attack, boost them upward so they can dash back onto the platform.
On Hit:
Steal 5% of the health from each enemy hit.
On Miss:
Cool-down is reset instantly instead of waiting the full 3 seconds.
Ora Ora
A flurry of punches.
Type: Hold the attack button to continuously punch.

On Hit:
Punches release projectiles that fly at a fast pace. Individually, they deal minimal damage — but collectively, they can inflict serious damage.
Grab 2% of the damage dealt to the enemy for each hit.
On Miss:
Create a wall of air between you and nearby enemies, preventing them from advancing toward you.
Spear
A 3-hit combo spear with great reach and moderate damage.
Type: Click the attack button repeatedly to perform each hit.

On Animation End:
Release a spear projectile on the final combo hit.
On Hit:
Hitting an enemy from behind deals 2x damage.
On Miss:
Release a spear projectile for each missed hit.
Bakshen
A devastating burst of pure energy that deals more damage than any other attack — released all at once in a single, explosive strike.
Type: Single-click attack followed by a cool-down.

On Hit:
Cooldown time is 1 second less.

# Surge

General Buff Ideas (All Surges):
Trigger surge at the start of each level, or at the start of the next level.

# Special

Specials function like standard attacks but with unique twists. They can include AoE attacks, magical effects, and powerful tools that make the player even more formidable.

Just like attacks, though, they have general buffs and tailored buffs for certain specials.

Buffs (Per Special)
Come Closer
On Trigger:
Magnetize 1 extra enemy.
