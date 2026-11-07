# Shotgun audio credits

Public high-quality MP3 previews from Freesound. Original WAV files have not been downloaded. No edits made to these source copies.

Both sources are listed as CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . We credit the creators voluntarily.

- **G35-03-Shotgun Blasts.wav** by **craigsmith** - https://freesound.org/people/craigsmith/sounds/438567/
  Local file: `blasts_source.mp3`; a run of vintage shotgun blasts.
- **Single Barreled Shotgun Loading.wav** by **sentryx86** - https://freesound.org/people/sentryx86/sounds/52202/
  Local file: `break_action_source.mp3`; a break-action shotgun opened, closed, cocked, dry-fired, opened, loaded, closed and opened again, ejecting the shell.

`scenes/player/weapons/shotgun_weapon.gd` uses the derived WAVs, cut from these sources with `tools/prepare_shotgun_audio.gd`:

- `shotgun_blast_1.wav`, `shotgun_blast_2.wav`, `shotgun_blast_3.wav`: three of the blasts, played at random for each shot.
- `shotgun_break_open.wav`, `shotgun_shells_out.wav`, `shotgun_shells_in.wav` and `shotgun_snap_shut.wav`: the action opening, the shell being ejected, the shell going in and the action closing, played during the reload.
- `shotgun_dry_fire.wav`: the dry fire, played when the gun is fired empty.

Each is peak-normalized, with a short fade in and a fade out. The MP3 source files remain unchanged.
