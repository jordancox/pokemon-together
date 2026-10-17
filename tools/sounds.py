#!/usr/bin/env python3
# The game's little sounds, made from sine waves and noise: python3 tools/sounds.py → ios/App/Sounds/*.wav
import wave
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parent.parent / 'ios/App/Sounds'
RATE = 22050


def tone(f0, f1, dur, shape='sine', decay=6.0):
    t = np.arange(int(RATE * dur)) / RATE
    f = np.linspace(f0, f1, t.size)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    w = np.sin(ph) if shape == 'sine' else np.sign(np.sin(ph)) * 0.5
    return w * np.exp(-decay * t / dur) * np.minimum(1, t * 400)


def noise(dur, decay=8.0, smooth=1):
    n = np.random.default_rng(7).uniform(-1, 1, int(RATE * dur))
    if smooth > 1: n = np.convolve(n, np.ones(smooth) / smooth, 'same')
    return n * np.exp(-decay * np.arange(n.size) / n.size)


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += [p, np.zeros(int(RATE * gap))]
    return np.concatenate(out)


def save(name, w, gain=0.8):
    w = w / max(1e-9, np.abs(w).max()) * gain
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((w * 32767).astype('<i2').tobytes())


OUT.mkdir(parents=True, exist_ok=True)
C5, E5, G5, C6, E6, G6 = 523, 659, 784, 1047, 1319, 1568
save('pop', tone(600, 1000, 0.09))
save('energy', seq(tone(C6, C6, 0.07), tone(E6, E6, 0.07), tone(G6, G6, 0.16), gap=0.01) + 0)
save('turn', seq(tone(G5, G5, 0.12, decay=4), tone(C6, C6, 0.22, decay=4)), gain=0.5)
save('whoosh', noise(0.22, decay=3, smooth=9) * np.sin(np.linspace(0, np.pi, int(RATE * 0.22))))
save('hit', tone(160, 60, 0.18, decay=5) + 0.5 * noise(0.18, decay=10, smooth=3))
save('bighit', tone(200, 40, 0.32, decay=4) + 0.7 * noise(0.32, decay=7, smooth=2), gain=0.95)
save('coin', seq(tone(1900, 1900, 0.06, decay=3), tone(2500, 2500, 0.3, decay=5)), gain=0.5)
save('heal', seq(tone(E5, E5, 0.1), tone(G5, G5, 0.1), tone(C6, C6, 0.1), tone(E6, E6, 0.25)), gain=0.6)
save('ko', tone(700, 120, 0.7, shape='square', decay=2), gain=0.5)
save('win', seq(tone(C5, C5, 0.13, 'square', 2), tone(E5, E5, 0.13, 'square', 2), tone(G5, G5, 0.13, 'square', 2),
                tone(C6, C6, 0.5, 'square', 1.5), gap=0.02), gain=0.55)
print('sounds →', OUT)
