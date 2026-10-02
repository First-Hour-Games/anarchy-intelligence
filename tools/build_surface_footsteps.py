"""Deterministic, original synthesized footsteps; no external recordings required."""
from pathlib import Path
import math, random, struct, wave

root = Path(__file__).resolve().parents[1] / 'sounds/footsteps'
rate = 44100
for surface in ('concrete', 'tile', 'dirt'):
    folder = root / surface
    folder.mkdir(parents=True, exist_ok=True)
    for variant in range(3):
        rng = random.Random(f'{surface}/{variant}')
        duration = 0.30 if surface != 'dirt' else 0.37
        samples, low = [], 0.0
        pitch = 1 + rng.uniform(-0.08, 0.08)
        for index in range(int(rate * duration)):
            t = index / rate
            noise = rng.uniform(-1, 1)
            low += 0.11 * (noise - low)
            attack = min(1, t / 0.003)
            body = math.sin(2 * math.pi * (92 if surface == 'dirt' else 135) * pitch * t) * math.exp(-t * 38)
            if surface == 'concrete':
                sample = (0.45 * low * math.exp(-t * 22) + 0.16 * noise * math.exp(-t * 120) + 0.25 * body) * attack
            elif surface == 'tile':
                reflection = math.exp(-abs(t - 0.045) * 180)
                sample = (0.30 * noise * math.exp(-t * 100) + 0.21 * low * math.exp(-t * 26) + 0.2 * body + 0.07 * noise * reflection) * attack
            else:
                crunch = (0.3 + 0.7 * abs(math.sin(t * 220))) * math.exp(-t * 14)
                sample = (0.46 * low * crunch + 0.11 * noise * crunch + 0.22 * body) * attack
            samples.append(sample)
        gain = 0.68 / max(abs(sample) for sample in samples)
        with wave.open(str(folder / f'{surface}_{variant + 1}.wav'), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(rate)
            output.writeframes(b''.join(struct.pack('<h', int(sample * gain * 32767)) for sample in samples))
