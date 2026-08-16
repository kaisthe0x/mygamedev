class_name SfxWorld

## RUN / UI / ENVIRONMENT sounds -- PURE DATA (read by the `Sfx` service). `key` -> path, played by
## code on an event (`Sfx.play("level_cleared")`). Add a line per sound.

const CUES := {
	"level_cleared": "res://sfx/world/level_cleared.wav",  # last required enemy down, exit opens (RunManager)
	# Launch orb (traversal thing) -- both PLACEHOLDER. `launch_orb` is the ambient hum it emits ON LOOP
	# (positional, via Sfx.make_loop_2d in LaunchOrb); `launch_orb_use` is the one-shot when Khalid uses it.
	"launch_orb": "res://sfx/things/traversal/launch_orb/launch_orb.wav", # PLACEHOLDER -- looping emitter hum
	"launch_orb_use": "res://sfx/things/traversal/launch_orb/launch_orb_use.wav", # PLACEHOLDER -- on use
}
