# Entity scare audio credits

Public high-quality MP3 previews from Freesound. Original WAV files have not been downloaded. No edits made to these source copies.

All three sources are listed as CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . We credit the creators voluntarily.

- **Ghost Monster Scream** by **NachtmahrTV** ? https://freesound.org/people/NachtmahrTV/sounds/556701/
  Local file: `wrapper_source.mp3`; intended entity: wrapper.
- **monster sound 2.wav** by **ZyryTSounds** ? https://freesound.org/people/ZyryTSounds/sounds/237986/
  Local file: `clawman_source.mp3`; intended entity: clawman.
- **growl 2** by **balloonhead** ? https://freesound.org/people/balloonhead/sounds/362331/
  Local file: `ridgeback_source.mp3`; intended entity: ridgeback.

`scenes/ui/death_scare.gd` uses derived `wrapper_kill.wav`, `clawman_kill.wav`, and `ridgeback_kill.wav`. Each is a 1.5-second vocal excerpt, peak-normalized to 0.85 with edge fades using `tools/prepare_death_audio.gd`. The MP3 source files remain unchanged. Creator names also appear in the Escape menu.
