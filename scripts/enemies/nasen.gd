class_name Nasen
extends Enemy

## Nasen: a stationary SLEEPER (idle only, no patrol). He dozes in place until the player
## gets within `rage_zone`, then wakes and RAGES -- a ground AoE erupts around him (rising
## floor particles + a hitbox) on the attack's hit frame, and the attack loops. If the
## player dodges out of the zone he keeps raging for `rage_linger` more seconds, then dozes
## off again.
##
## MELEE hits STUN him: the rage halts for `rage_stun_time`, then he wakes and starts the
## attack over. RANGED hits (projectiles) only chip his health -- so shooting him from a
## distance is the safe way in. (The melee/ranged split reads `Hit.ranged`.)
##
## Reuses everything in Enemy (sprite/hurtbox/health-bar/hit-flash/death/hit-stop); only the
## AI (_act) and the attack/hurt hooks are overridden.

@export_group("Nasen")
## Horizontal reach (px) at which the player disturbs his sleep and he starts raging.
@export var rage_zone: float = 100.0
## Extra seconds he keeps raging after the player leaves the zone before dozing off.
@export var rage_linger: float = 2.0
## How long a melee hit halts his rage before he wakes back up and starts over.
@export var rage_stun_time: float = 1.5
## The AoE that erupts around him each rage cycle: damage/knockback and the ground box's
## half-size (centred on him). The particle LOOK comes from the Emitters config (`nasen -> rage`),
## like every enemy emitter -- not an export here.
@export var rage_damage: float = 14.0
@export var rage_knockback: float = 130.0
@export var rage_extents := Vector2(52, 22)

var _rage_left := 0.0  ## seconds of rage remaining; refreshed while the player is in the zone


## Stationary sleeper AI -- no patrol. Wake + rage when the player is in the zone (and on
## our level); the linger timer keeps him raging a bit after they leave. He never moves.
func _act(delta: float) -> void:
	velocity.x = 0.0  # rooted -- he only ever sleeps or rages in place
	_rage_left = maxf(_rage_left - delta, 0.0)

	var player := _player()
	if player != null:
		var to := player.global_position - global_position
		if absf(to.y) <= attack_align_y and absf(to.x) <= rage_zone:
			_rage_left = rage_linger  # disturbed -> (re)fill the linger timer
			if to.x != 0.0:
				_face(int(sign(to.x)))

	# Start a rage cycle when disturbed and currently asleep. The RAGE->IDLE exit (and the
	# loop) is handled in _on_anim_finished so a swing always completes before he dozes.
	if _rage_left > 0.0 and _state == State.IDLE:
		_engaged = true
		_start_rage()  # first cycle: the full attack, including the wake-up


## Play (a cycle of) the rage attack. `from_frame` is the EMITTED frame to begin at -- 0 for
## the first cycle (plays the wake), rage_loop_from for every replay (skips it, looping the
## yell). Each cycle re-arms the AoE (`_attack_fired`/`_impacted`).
func _start_rage(from_frame := 0) -> void:
	_set_state(State.RAGE)
	_attack_fired = false
	_impacted = false
	_replay_from(&"attack", from_frame)  # base helper: skip to `from_frame`, then play to the end


## Erupt the AoE on the attack's hit frame while raging.
func _on_frame_changed() -> void:
	if _state == State.RAGE and not _attack_fired and _sprite.frame in _hit_frames(&"attack"):
		_attack_fired = true
		_spawn_rage_aoe()
		_begin_hitstop()


## The rage swing finished: loop it if still raging, else doze off. (DEAD -> vanish once the
## death anim has played out, matching the base.)
func _on_anim_finished() -> void:
	if _state == State.DEAD:
		queue_free()  # death anim done -> disappear immediately (no lingering hold/fade)
		return
	if _state == State.RAGE:
		if _rage_left > 0.0:
			# keep raging -- loop from the anim's loop_from (gen_spriteframes), so the
			# wake-up plays once and only the yell repeats.
			_start_rage(_loop_from(&"attack"))
		else:
			_engaged = false
			_set_state(State.IDLE)  # doze off


## Melee halts him (stun -> rage restarts after); a projectile only chips health, so ranged
## is the safe approach. Death is handled the same as any enemy.
func _on_hurt(hit: Hit) -> void:
	if _state == State.DEAD:
		return
	health = maxf(health - hit.amount, 0.0)
	_bar.set_ratio(health / max_health)
	flash(_sprite)
	if health <= 0.0:
		_die()
		return
	if not hit.ranged:
		# a strike/melee jolts him out of his rage; when the stun lapses he wakes and, if the
		# player is still in the zone, starts the attack over.
		_stun_left = rage_stun_time
		_set_state(State.STUN)


## Build the rage AoE: a hostile Strike centred on nasen with a wide ground hitbox, plus the
## particle-only `rage_effect` for the look. Same activation pattern as Enemy's melee strike.
func _spawn_rage_aoe() -> void:
	var strike := Strike.new()
	strike.hostile = true
	strike.friendly_fire = friendly_fire
	strike.lifetime = 0.5
	strike.source = self
	var hb := Hitbox.new()
	hb.damage = rage_damage
	hb.knockback = rage_knockback
	hb.source = self
	hb.add_child(Shapes.make_box(rage_extents * 2.0, Vector2(0, -rage_extents.y)))
	strike.add_child(hb)
	var fx := _make_vfx("rage")  # rage LOOK + emit point from the Emitters config (null if none)
	if fx != null:
		strike.add_child(fx)
	add_child(strike)  # centred on nasen (his feet); Strike._ready sets team layers, frees itself
	hb.activate()
