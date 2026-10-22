# -*- coding: utf-8 -*-
"""배경음악 합성 (M5, 사용자 '코드로 합성') — 잔잔한 사무실 음악 약 53초, 이음매 없는 반복

사용 (SkyOffice 폴더에서):
    python tools/build_bgm.py             # game/assets/sounds/bgm.wav 덮어씀
    python tools/build_bgm.py C:/임시      # 다른 폴더에 (들어 보기용)

- 다운로드 · 외부 음원 없음 (라이선스 걱정 0). 22050Hz · 모노 · 16비트 (예전 bgm.wav 와 같은 형식 → .import 그대로)
- 72 BPM 16마디 (53.3초): 코드 4개 (Cmaj7 · Am7 · Fmaj7 · G6) 를 4번 + 전자 피아노 느낌 아르페지오 + 느린 패드 + 5음 멜로디
- 소리 꼬리는 처음으로 감아서 (add_wrap) 반복해도 끊기지 않음. 난수 고정 (seed) → 다시 만들어도 같은 음악
- 필요: numpy
"""
import os
import sys
import wave

import numpy as np

SR = 22050
BPM = 72
BEAT = 60.0 / BPM
BARS = 16
N = int(SR * BEAT * 4 * BARS)

# 코드 (MIDI 음): 아르페지오용 낮은 음 4개 · 패드용 · 멜로디 후보 (C 장조 5음 음계)
CHORDS = [
    ([48, 55, 59, 64], [60, 64, 67, 71]),   # Cmaj7
    ([45, 52, 55, 60], [57, 60, 64, 67]),   # Am7
    ([41, 48, 52, 57], [57, 60, 65, 69]),   # Fmaj7
    ([43, 50, 55, 59], [55, 59, 62, 67]),   # G6
]
PENTA = [72, 74, 76, 79, 81, 84]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def add_wrap(buf, snd, at):
    n = len(buf)
    for i in range(0, len(snd), n):
        part = snd[i:i + n]
        idx = (at + i + np.arange(len(part))) % n
        buf[idx] += part


def epiano(m, secs, gain):
    """전자 피아노 느낌: 기본음 + 2배음 (빨리 사라짐) + 부드러운 감쇠"""
    k = int(SR * secs)
    t = np.arange(k) / SR
    f = hz(m)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6) + 0.1 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 10)
    env = np.exp(-t * 2.2)
    env[: int(SR * 0.008)] *= np.linspace(0, 1, int(SR * 0.008))
    return gain * x * env


def pad(ms, secs, gain):
    """느린 패드: 부드럽게 커졌다 작아지는 사인 여러 개"""
    k = int(SR * secs)
    t = np.arange(k) / SR
    x = sum(np.sin(2 * np.pi * hz(m) * t + i) for i, m in enumerate(ms)) / len(ms)
    env = np.sin(np.pi * np.arange(k) / k) ** 2
    return gain * x * env


def bgm(rng):
    buf = np.zeros(N)
    bar = int(SR * BEAT * 4)
    eighth = int(SR * BEAT / 2)
    for b in range(BARS):
        low, high = CHORDS[b % 4]
        start = b * bar
        add_wrap(buf, pad(high, BEAT * 4.5, 0.10), start)
        for i in range(8):   # 8분음표 아르페지오 (위 아래로)
            m = low[[0, 1, 2, 3, 2, 1, 2, 1][i]]
            add_wrap(buf, epiano(m, 1.6, 0.16 if i % 2 == 0 else 0.11), start + i * eighth)
        if b % 2 == 1 or b >= 8:   # 멜로디: 쉬엄쉬엄 (홀수 마디 · 뒤쪽 마디는 매번)
            for i in (0, 3, 5):
                if rng.random() < 0.7:
                    m = int(rng.choice(PENTA))
                    add_wrap(buf, epiano(m, 2.0, 0.12), start + i * eighth + int(rng.integers(-300, 300)))
    return buf


def write(path, x, peak=0.30):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "game", "assets", "sounds")
    os.makedirs(out, exist_ok=True)
    p = os.path.join(out, "bgm.wav")
    write(p, bgm(np.random.default_rng(21)))
    print("만듦", os.path.normpath(p), "(%.1f초)" % (N / SR))


if __name__ == "__main__":
    main()
