class_name SfxWorld

## RUN / UI / ENVIRONMENT sounds -- PURE DATA (read by the `Sfx` service). `key` -> path, played by
## code on an event (`Sfx.play("level_cleared")`). Add a line per sound.

const CUES := {
	"level_cleared": "res://sfx/world/level_cleared.wav",  # last required enemy down, exit opens (RunManager)
}
