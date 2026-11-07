# Ridgeback audio credits

The voices of the alt route's Ridgebacks on the road, the pack that ambushes Thomas among the cars past the gate, and the sounds of the downtown Ridgebacks hitting the road off the roofs.

Public high-quality MP3 previews from Freesound: the pigs from Jarred Gibb's *Animal Farm* recordings, and the splat, gore and bone recordings listed after them. Original WAV files have not been downloaded. No edits made to these source copies. `sources.json` lists each one's page, download link and checksum.

All sources are listed as CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . We credit the creator voluntarily.

- **Pig - Scream 1 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233155/
  Local file: `pig_scream_1_source.mp3`.
- **Pig - Scream 2 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233152/
  Local file: `pig_scream_2_source.mp3`.
- **Pig - Scream 3 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233153/
  Local file: `pig_scream_3_source.mp3`.
- **Pig - Scream 4 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233149/
  Local file: `pig_scream_4_source.mp3`.
- **Pig - Scream 5 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233151/
  Local file: `pig_scream_5_source.mp3`.
- **Pig - Multiple Squeals 1 (2 pigs) - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233178/
  Local file: `pig_squeals_source.mp3`.
- **Pig - Grunt 1 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233169/
  Local file: `pig_grunt_1_source.mp3`.
- **Pig - Grunt 2 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233170/
  Local file: `pig_grunt_2_source.mp3`.
- **Pig - Grunt 5 (deep) - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233173/
  Local file: `pig_grunt_deep_source.mp3`.
- **Pig - Grunt and Squeal 4 - 96kHz.wav** by **JarredGibb** - https://freesound.org/people/JarredGibb/sounds/233177/
  Local file: `pig_grunt_squeal_source.mp3`.
- **Wet Splat 1.mp3** by **nebulasnails** - https://freesound.org/people/nebulasnails/sounds/495118/
  Local file: `body_splat_source.mp3`.
- **Gore Impact - "LOT OF HEART"** by **magnuswaker** - https://freesound.org/people/magnuswaker/sounds/641046/
  Local file: `gore_impact_source.mp3`.
- **squelch watermelon** by **MaddieCooper** - https://freesound.org/people/MaddieCooper/sounds/739184/
  Local file: `squelch_source.mp3`.
- **Bone Breaking** by **wackoME** - https://freesound.org/people/wackoME/sounds/413430/
  Local file: `bone_break_source.mp3`.
- **bone break_5.wav** by **Vinni_R** - https://freesound.org/people/Vinni_R/sounds/630594/
  Local file: `bone_crackle_source.mp3`.

`tools/prepare_ridgeback_pig_audio.gd` makes the derived WAVs from these sources. Each one mixes spans of the recordings played slower, so lower, with a soft clip for grit, and is then peak-normalized and faded:

- `ridgeback_grunt_1.wav` to `ridgeback_grunt_3.wav`: the grunts from behind the cars, from Grunt 1, Grunt 2 and Grunt 5.
- `ridgeback_shriek_1.wav` to `ridgeback_shriek_3.wav`: the shrieks on the roofs, from Scream 5, Scream 2 and the first of the Multiple Squeals.
- `ridgeback_roar_1.wav` to `ridgeback_roar_3.wav`: the roar of a pounce. Each is Scream 1, 2 or 5 played at about 0.6 speed, over Grunt 5, 2 or 1 played lower still.
- `ridgeback_pain_1.wav` and `ridgeback_pain_2.wav`: the squeals of one that is hit, from Scream 3 and the Grunt and Squeal.
- `ridgeback_death_1.wav` and `ridgeback_death_2.wav`: the screams of one dying, Scream 2 and Scream 4 sinking in pitch as they play.
- `ridgeback_road_kill.wav`: the scream `scenes/ui/death_scare.gd` plays when one kills Thomas, 1.5 seconds of Scream 5 and Scream 1 over Grunt 5.
- `ridgeback_splat_1.wav` to `ridgeback_splat_3.wav`: a body off a roof hitting the road. The Wet Splat played at 0.8 speed, the Gore Impact at 0.82, and the Gore Impact at 0.55 under the Wet Splat.
- `ridgeback_bones_1.wav` and `ridgeback_bones_2.wav`: the bones breaking under it, from Bone Breaking and bone break_5.
- `ridgeback_squelch.wav`: a crawler taking a hit, from the squelch.

`ridgeback_strike.wav`, played when a pounce lands, is made by `tools/prepare_ridgeback_audio.gd`. It mixes the loudest 0.42 seconds of `pig_scream_5_source.mp3`, played at 0.72 speed, with a body slam and claw scratches the tool synthesizes, peak-normalized to 0.9.

`scenes/monsters/the_ridgeback/ridgeback_ambusher.tscn` plays them all. The MP3 source files remain unchanged.
