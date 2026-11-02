"""Synthesises the practice-game sounds.

Run from app/:  python tool/make_sounds.py
Outputs: assets/sounds/right.wav  a short rising two-note chime
         assets/sounds/wrong.wav  a soft, low "nope"
"""

import math
import os
import struct
import wave

RATE = 22050


def tone(freq, seconds, volume, decay):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.008)
        env = attack * math.exp(-decay * t)
        # A bell-ish tone: fundamental plus a soft octave.
        s = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t)
        out.append(volume * env * s / 1.3)
    return out


def mix(*parts):
    length = max(offset + len(p) for offset, p in parts)
    out = [0.0] * length
    for offset, p in parts:
        for i, s in enumerate(p):
            out[offset + i] += s
    return out


def write(name, samples):
    os.makedirs("assets/sounds", exist_ok=True)
    with wave.open(f"assets/sounds/{name}", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples)
        )


if __name__ == "__main__":
    # E6 then A6, overlapping: a sweet little "ding-ding".
    write(
        "right.wav",
        mix((0, tone(1318.5, 0.35, 0.35, 9)), (int(RATE * 0.09), tone(1760.0, 0.45, 0.35, 7))),
    )
    # Two quick low notes, falling: gentle, not a buzzer.
    write(
        "wrong.wav",
        mix((0, tone(311.1, 0.16, 0.3, 14)), (int(RATE * 0.12), tone(233.1, 0.24, 0.3, 12))),
    )
