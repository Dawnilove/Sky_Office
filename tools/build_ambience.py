# -*- coding: utf-8 -*-
"""환경음 합성 (M5 5세션째, 사용자 결정 '코드로 합성') — 오버랜드 농장 소리 대신 잔잔한 사무실 소리

사용 (SkyOffice 폴더에서):
    python tools/build_ambience.py            # game/assets/sounds/ ambience · night · rain.wav 덮어씀
    python tools/build_ambience.py C:/임시     # 다른 폴더에 (들어 보기용)

- 다운로드 · 외부 소리 없음 (라이선스 걱정 0). 22050Hz · 모노 · 16비트 (예전 파일과 같은 형식 → .import 그대로, 반복 재생)
- 이음매 없음: 소음은 원형 FFT 로 걸러 만들고 (끝 = 처음), 소리 조각은 길이를 넘으면 앞으로 감음
- ambience (40초) = 실내 공기 소리 + 먼 타자 묶음 + 종이 넘김 · night (30초) = 더 작은 실내 소리 + 바깥 바람
  rain (30초) = 창에 빗소리 + 빗방울 톡톡. 난수 고정 (seed) → 다시 만들어도 같은 소리
- 필요: numpy
"""
import os
import sys
import wave

import numpy as np

SR = 22050


def shaped_noise(rng, n, shape):
    """원형 (반복해도 이음매 없는) 색 소음: shape(f) = 주파수별 크기"""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1.0
    out = np.fft.irfft(spec * shape(f), n)
    return out / (np.max(np.abs(out)) + 1e-9)


def slow_lfo(n, cycles, depth, phase=0.0):
    """길이 안에 정수 번 도는 느린 흔들림 (반복 이음매 없음)"""
    t = np.arange(n) / n
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t + phase))


def add_wrap(buf, snd, at):
    n = len(buf)
    for i in range(0, len(snd), n):
        part = snd[i:i + n]
        idx = (at + i + np.arange(len(part))) % n
        buf[idx] += part


def click(rng, ms, lo, hi, gain):
    """짧은 소리 조각 (타자 · 빗방울): 띠 거른 소음 + 빠른 감쇠"""
    m = int(SR * ms / 1000)
    x = rng.standard_normal(m * 4)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec, len(x))[:m]
    env = np.exp(-np.arange(m) / (m / 5.0))
    env[: max(1, m // 20)] *= np.linspace(0, 1, max(1, m // 20))
    x = x * env
    return gain * x / (np.max(np.abs(x)) + 1e-9)


def room_tone(rng, n, gain):
    """실내 공기 (환기 · 멀리 웅웅): 낮은 쪽으로 기운 소음 + 아주 작은 흔들림"""
    x = shaped_noise(rng, n, lambda f: 1.0 / np.sqrt(f) * np.exp(-f / 900.0))
    return gain * x * slow_lfo(n, 3, 0.15)


def ambience(rng, secs=40):
    n = SR * secs
    buf = room_tone(rng, n, 0.10)
    # 먼 타자 묶음: 4번, 한 번에 6~18타 (초당 6~9타)
    for b in range(4):
        at = int(n * (b + rng.uniform(0.1, 0.6)) / 4)
        for _ in range(int(rng.integers(6, 19))):
            add_wrap(buf, click(rng, rng.uniform(10, 18), 1500, 6000, rng.uniform(0.035, 0.06)), at)
            at += int(SR / rng.uniform(6, 9))
    # 종이 넘김 2번 (0.35초 쉬익)
    for at in (int(n * 0.33), int(n * 0.8)):
        m = int(SR * 0.35)
        x = shaped_noise(rng, m, lambda f: ((f > 1200) & (f < 7000)).astype(float))
        env = np.sin(np.linspace(0, np.pi, m)) ** 2
        add_wrap(buf, 0.045 * x * env, at)
    return buf


def night(rng, secs=30):
    n = SR * secs
    buf = room_tone(rng, n, 0.06)
    wind = shaped_noise(rng, n, lambda f: np.exp(-((f - 350.0) / 220.0) ** 2))   # 바깥 바람 (낮은 쉬이)
    buf += 0.05 * wind * slow_lfo(n, 2, 0.7) * slow_lfo(n, 5, 0.3, 1.3)
    return buf


def rain(rng, secs=30):
    n = SR * secs
    buf = 0.09 * shaped_noise(rng, n, lambda f: np.clip(f / 2500.0, 0.2, 1.0) * np.exp(-f / 7000.0)) * slow_lfo(n, 2, 0.2)
    buf += room_tone(rng, n, 0.05)
    for _ in range(int(secs * 7)):   # 창에 톡톡 (초당 7번쯤)
        add_wrap(buf, click(rng, rng.uniform(4, 9), 2500, 8000, rng.uniform(0.02, 0.06)), int(rng.integers(0, n)))
    return buf


def write(path, x, peak=0.32):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak   # 잔잔하게: 최대 -10dBFS 근처
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
    for name, fn, peak, seed in (("ambience", ambience, 0.30, 11), ("night", night, 0.22, 12), ("rain", rain, 0.28, 13)):
        p = os.path.join(out, name + ".wav")
        write(p, fn(np.random.default_rng(seed)), peak)
        print("만듦", os.path.normpath(p))


if __name__ == "__main__":
    main()
