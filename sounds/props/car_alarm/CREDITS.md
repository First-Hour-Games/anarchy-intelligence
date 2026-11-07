# Car alarm audio credits

The alarm of a car that one of the alt route's downtown Ridgebacks lands on (scenes/chapters/alt_route/rooftop_street.gd).

A public high-quality MP3 preview from Freesound. The original WAV file has not been downloaded. No edits made to this source copy. `sources.json` lists its page, download link and checksum.

The source is listed as CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . We credit the creator voluntarily.

- **Car alarm shift** by **itinerantmonk108** - https://freesound.org/people/itinerantmonk108/sounds/733086/
  Local file: `car_alarm_source.mp3`.

`tools/prepare_ridgeback_pig_audio.gd` makes `car_alarm_loop.wav` from it: the whole pulses from 0.98 to 4.9 seconds, peak-normalized to 0.9 and faded for 5 ms at each end. Its import settings loop it.
