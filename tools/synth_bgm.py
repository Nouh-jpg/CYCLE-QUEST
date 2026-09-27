#!/usr/bin/env python3
"""Original neon-avenue loop for Cycle Quest.

Two equal-length stereo WAVs, synthesized here (no samples from songs):
  assets/audio/bgm_loop.wav  — pad, bass, sparse melody, soft drums
  assets/audio/bgm_drive.wav — hats, arp, shaker; mixed up as speed/danger rise

8 bars of Am–F–C–G at 100 BPM. Loop length is exact so the layers stay locked.
"""

from pathlib import Path

import numpy as np

SR = 22050
BPM = 100.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 8
DUR = BAR * BARS  # 19.2 s
N = int(round(SR * DUR))
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"

# Am F C G, twice.
CHORDS = [
    (57, 60, 64),  # A3 C4 E4
    (53, 57, 60),  # F3 A3 C4
    (48, 52, 55),  # C3 E3 G3
    (55, 59, 62),  # G3 B3 D4
] * 2
BASS_MIDI = [45, 41, 36, 43, 45, 41, 36, 43]  # A2 F2 C2 G2

# (bar, beat, midi, beats, velocity) — A minor pentatonic, sparse.
MELODY = [
    (0, 0.0, 69, 1.4, 0.22),
    (0, 2.0, 72, 0.9, 0.18),
    (0, 3.25, 76, 0.55, 0.16),
    (1, 0.5, 74, 1.1, 0.18),
    (1, 2.25, 72, 1.2, 0.16),
    (2, 0.0, 76, 0.7, 0.2),
    (2, 1.0, 74, 0.5, 0.14),
    (2, 2.0, 72, 1.4, 0.17),
    (3, 0.75, 67, 1.0, 0.15),
    (3, 2.25, 69, 1.3, 0.18),
    (4, 0.0, 72, 1.2, 0.2),
    (4, 2.0, 76, 0.8, 0.16),
    (4, 3.0, 74, 0.7, 0.14),
    (5, 0.5, 69, 1.3, 0.17),
    (5, 2.5, 72, 1.1, 0.15),
    (6, 0.0, 76, 0.6, 0.2),
    (6, 1.25, 79, 0.45, 0.16),
    (6, 2.25, 76, 1.2, 0.15),
    (7, 0.5, 74, 0.8, 0.16),
    (7, 1.75, 72, 0.7, 0.14),
    (7, 2.75, 69, 1.0, 0.18),
]


def midi_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def write_wav(path: Path, stereo: np.ndarray) -> None:
    pcm = np.clip(stereo, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    data = pcm.tobytes()
    import struct

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(data),
        b"WAVE",
        b"fmt ",
        16,
        1,
        2,
        SR,
        SR * 4,
        4,
        16,
        b"data",
        len(data),
    )
    path.write_bytes(header + data)


def place(buf: np.ndarray, start: int, sig: np.ndarray, pan: float) -> None:
    n = sig.shape[0]
    if start >= N or n <= 0:
        return
    if start < 0:
        sig = sig[-start:]
        start = 0
        n = sig.shape[0]
    n = min(n, N - start)
    sig = sig[:n]
    ang = (pan + 1.0) * np.pi * 0.25
    buf[start : start + n, 0] += sig * np.cos(ang)
    buf[start : start + n, 1] += sig * np.sin(ang)


def env_pluck(n: int, decay: float) -> np.ndarray:
    tt = np.arange(n) / SR
    return np.exp(-tt * decay) * (1.0 - np.exp(-tt * 90.0))


def add_pad(buf: np.ndarray) -> None:
    for bar, chord in enumerate(CHORDS):
        t0 = bar * BAR
        t1 = t0 + BAR
        n0 = int(t0 * SR)
        n1 = min(N, int((t1 + 0.42) * SR))
        count = n1 - n0
        tt = np.arange(count) / SR
        attack = np.clip(tt / 0.32, 0.0, 1.0)
        rel = np.clip((BAR + 0.2 - tt) / 0.45, 0.0, 1.0)
        env = attack * rel
        for note in chord:
            freq = midi_hz(note)
            for det, pan, amp in (
                (-0.006, -0.62, 0.045),
                (0.0, -0.15, 0.05),
                (0.005, 0.2, 0.05),
                (0.011, 0.7, 0.04),
            ):
                sig = np.sin(2.0 * np.pi * freq * (1.0 + det) * tt)
                sig += 0.18 * np.sin(2.0 * np.pi * freq * 2.0 * (1.0 + det) * tt)
                place(buf, n0, sig * env * amp, pan)
            # Octave shimmer, quieter.
            high = freq * 2.0
            shimmer = np.sin(2.0 * np.pi * high * tt) * env * 0.02
            place(buf, n0, shimmer, 0.35 if bar % 2 == 0 else -0.35)


def add_bass(buf: np.ndarray, octave: bool) -> None:
    for bar, root in enumerate(BASS_MIDI):
        for beat in range(4):
            start = int((bar * BAR + beat * BEAT) * SR)
            dur = int(BEAT * 0.92 * SR)
            tt = np.arange(dur) / SR
            freq = midi_hz(root)
            env = np.exp(-tt * (2.4 if beat % 2 == 0 else 3.4))
            env *= 1.0 - np.exp(-tt * 70.0)
            sig = np.sin(2.0 * np.pi * freq * tt)
            if octave and beat % 2 == 1:
                sig += 0.35 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
            else:
                sig += 0.08 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
            amp = 0.34 if beat in (0, 2) else 0.22
            if octave:
                amp *= 0.55
            sig = np.tanh(sig * 1.35) * env * amp
            place(buf, start, sig, 0.0)


def add_melody(buf: np.ndarray) -> None:
    for bar, beat, note, beats, vel in MELODY:
        start = int((bar * BAR + beat * BEAT) * SR)
        n = int(beats * BEAT * SR)
        tt = np.arange(n) / SR
        freq = midi_hz(note)
        env = np.exp(-tt * 3.1) * (1.0 - np.exp(-tt * 40.0))
        sig = np.sin(2.0 * np.pi * freq * tt)
        sig += 0.28 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
        sig += 0.08 * np.sin(2.0 * np.pi * freq * 3.0 * tt)
        pan = -0.45 if (bar + int(beat)) % 2 == 0 else 0.5
        place(buf, start, sig * env * vel, pan)


def add_kick(buf: np.ndarray, amp: float) -> None:
    n = int(0.22 * SR)
    tt = np.arange(n) / SR
    phase = 2.0 * np.pi * (42.0 * tt + (70.0 / 14.0) * (1.0 - np.exp(-tt * 14.0)))
    env = np.exp(-tt * 10.0)
    sig = np.sin(phase) * env * amp
    for bar in range(BARS):
        for beat in (0, 2):
            place(buf, int((bar * BAR + beat * BEAT) * SR), sig, 0.0)


def add_snare(buf: np.ndarray, amp: float, rng: np.random.Generator) -> None:
    n = int(0.16 * SR)
    tt = np.arange(n) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    # One-pole so it isn't a raw hiss.
    for i in range(1, n):
        noise[i] = noise[i - 1] * 0.55 + noise[i] * 0.45
    env = np.exp(-tt * 16.0)
    tone = np.sin(2.0 * np.pi * 188.0 * tt) * np.exp(-tt * 22.0)
    sig = (noise * 0.8 + tone * 0.35) * env * amp
    for bar in range(BARS):
        for beat in (1, 3):
            place(buf, int((bar * BAR + beat * BEAT) * SR), sig, 0.05)


def add_hats(buf: np.ndarray, step: float, amp: float, rng: np.random.Generator, swing: float) -> None:
    n = int(0.045 * SR)
    tt = np.arange(n) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    for i in range(1, n):
        noise[i] = noise[i - 1] * 0.2 + noise[i] * 0.8
    env = np.exp(-tt * 70.0)
    sig = noise * env * amp
    t = 0.0
    i = 0
    while t < DUR - 0.01:
        offset = swing if i % 2 == 1 else 0.0
        place(buf, int((t + offset) * SR), sig, 0.55 if i % 2 == 0 else -0.35)
        t += step
        i += 1


def add_arp(buf: np.ndarray) -> None:
    for bar, chord in enumerate(CHORDS):
        order = chord if bar % 2 == 0 else tuple(reversed(chord))
        for step in range(8):
            note = order[step % 3] + 12
            start = int((bar * BAR + step * (BEAT * 0.5)) * SR)
            n = int(BEAT * 0.42 * SR)
            tt = np.arange(n) / SR
            freq = midi_hz(note)
            env = np.exp(-tt * 8.0) * (1.0 - np.exp(-tt * 120.0))
            sig = np.sin(2.0 * np.pi * freq * tt)
            sig += 0.22 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
            place(buf, start, sig * env * 0.11, -0.6 if step % 2 == 0 else 0.6)


def add_air(buf: np.ndarray, rng: np.random.Generator, amp: float) -> None:
    noise = rng.uniform(-1.0, 1.0, N)
    # Slow lowpass wash.
    out = np.empty(N)
    acc = 0.0
    for i in range(N):
        acc = acc * 0.985 + noise[i] * 0.015
        out[i] = acc
    # Gentle swell so the loop seam is quiet air, not a noise pop.
    lfo = 0.65 + 0.35 * np.sin(2.0 * np.pi * (np.arange(N) / SR) / BAR)
    sig = out * lfo * amp
    place(buf, 0, sig, -0.4)
    place(buf, 0, sig * 0.8, 0.45)


def seam(buf: np.ndarray) -> None:
    fade_n = int(0.05 * SR)
    head = buf[:fade_n].copy()
    fade_out = np.linspace(1.0, 0.0, fade_n)[:, None]
    fade_in = np.linspace(0.0, 1.0, fade_n)[:, None]
    buf[-fade_n:] = buf[-fade_n:] * fade_out + head * fade_in


def normalize(buf: np.ndarray, peak: float) -> None:
    m = float(np.max(np.abs(buf)))
    if m > 1e-6:
        buf *= peak / m


def main() -> None:
    rng = np.random.default_rng(7)
    bed = np.zeros((N, 2), dtype=np.float64)
    add_air(bed, rng, 0.55)
    add_pad(bed)
    add_bass(bed, octave=False)
    add_melody(bed)
    add_kick(bed, 0.42)
    add_snare(bed, 0.16, rng)
    add_hats(bed, BEAT / 2.0, 0.035, rng, 0.0)
    seam(bed)
    normalize(bed, 0.9)

    drive = np.zeros((N, 2), dtype=np.float64)
    add_hats(drive, BEAT / 4.0, 0.16, rng, 0.012)
    add_arp(drive)
    add_bass(drive, octave=True)
    add_air(drive, np.random.default_rng(11), 0.22)
    seam(drive)
    normalize(drive, 0.85)

    OUT.mkdir(parents=True, exist_ok=True)
    write_wav(OUT / "bgm_loop.wav", bed)
    write_wav(OUT / "bgm_drive.wav", drive)
    print(f"wrote {N} frames ({DUR:.2f}s) bed+drive")


if __name__ == "__main__":
    main()
