# music/

Background music tracks. Drop track files here and register them in
`scripts/audio/music.gd` (`TRACKS`), then play with `Music.play("key")`.

- The gameplay bed is keyed **`"level"`** and expected at **`music/level.mp3`** —
  drop your track there and it fades in on run start (`RunManager._ready`).
- `.mp3` and `.ogg` loop cleanly; the service forces looping automatically.
- Until a track file exists, `Music.play` is a silent no-op (no crash).
