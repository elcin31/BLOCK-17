"""Create the original looping soundscape; no third-party samples."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 11025
seconds = 8
rng = random.Random(17)
frames = bytearray()
wind = 0.0
for i in range(rate * seconds):
    t = i / rate
    wind = wind * 0.96 + rng.uniform(-0.04, 0.04)
    envelope = max(0.0, math.sin(t * math.tau / seconds)) ** 24
    bird = math.sin(t * (3900 + math.sin(t * 17) * 700)) * envelope * 0.15
    fade = min(1.0, t * 8, (seconds - t) * 8)
    sample = (wind + math.sin(t * math.tau * 48) * 0.025 + bird) * fade
    frames.extend(struct.pack('<h', int(max(-1, min(1, sample)) * 32767)))
with wave.open(str(Path(__file__).resolve().parents[1] / 'assets/city-ambience.wav'), 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(rate)
    out.writeframes(frames)
