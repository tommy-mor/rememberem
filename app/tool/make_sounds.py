"""Synthesises the practice-game sounds.

Run from app/:  python tool/make_sounds.py
Outputs: assets/sounds/right.wav  two soft woodblock taps, low then high
         assets/sounds/wrong.wav  a soft, low "nope"
         assets/sounds/listen_start.wav  a short high ding: dictation listens
         assets/sounds/listen_stop.wav   a short lower ding: dictation ended
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


def woodblock(freq, volume):
    """A short wooden tap: a quickly fading tone with an inharmonic
    overtone (a block, not a bell) and a tiny click of noise at the
    start."""
    n = int(RATE * 0.14)
    out = []
    seed = 12345
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.002)
        body = math.exp(-38 * t) * math.sin(2 * math.pi * freq * t)
        over = 0.35 * math.exp(-70 * t) * math.sin(2 * math.pi * freq * 2.76 * t)
        seed = (seed * 1103515245 + 12345) % 2**31
        noise = (seed / 2**30 - 1) * 0.25 * math.exp(-t / 0.003)
        out.append(volume * attack * (body + over + noise) / 1.6)
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
    # Two soft woodblock taps, low then high, quieter than a chime.
    write(
        "right.wav",
        mix((0, woodblock(523.3, 0.24)), (int(RATE * 0.09), woodblock(784.0, 0.24))),
    )
    # Two quick low notes, falling: gentle, not a buzzer.
    write(
        "wrong.wav",
        mix((0, tone(311.1, 0.16, 0.2, 14)), (int(RATE * 0.12), tone(233.1, 0.24, 0.2, 12))),
    )
    # Dictation: one short ding up as listening starts, one down as it ends.
    write("listen_start.wav", tone(1568.0, 0.18, 0.3, 18))
    write("listen_stop.wav", tone(1046.5, 0.18, 0.3, 18))
