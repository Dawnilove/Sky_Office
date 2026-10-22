"""하늘 오피스 M4 2세션째: 작업실 소품 + 건물 · 분위기 → .glb (+ 고르기용 미리보기)

실행 (OverLand 폴더에서):
  내보내기:  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_workroom.py -- SkyOffice/game/assets/models
  미리보기:  ... -P SkyOffice/tools/blender/build_workroom.py -- <폴더> --preview      (모델마다 A · B · C 나란히 렌더 → <폴더>/pick_<이름>.png)

- 단위 · 좌표 · 색 규칙은 build_office_props.py 와 같음 (1 단위 = 1칸, Blender -Y = 앞 = 카메라 쪽, 노랑 · 금색 · 주황 금지)
- 고른 모양 = 아래 CHOICE (사용자가 그림 보고 고름). 미리보기는 CHOICE 와 상관없이 전부 그림
- 이름 붙인 부품 (게임이 찾아 씀): Leds (랙 불빛) · Tube (망원경 경통, 원점 = 회전축) · Doodle (화이트보드 그림) · Item0~3 (개인 소품, 책상마다 일부만 보임)
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_office_props import (DARK, LEAF, POT, STEEL, WHITE, WOOD, WOOD_DARK, PANEL_TOP, Parts, clear, export, lin,  # noqa: E402
                                mat)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "assets_out")
PREVIEW = "--preview" in ARGS
os.makedirs(OUT, exist_ok=True)

CHOICE = {"rack": "B", "bookshelf": "B", "whiteboard": "B", "telescope": "A", "board": "B",   # 사용자 고름 (personal 이하 = 임시안, 고르면 바꿈)
          "personal": "C", "plant": "A", "rug": "A", "rock": "C", "sofa": "A", "table": "A", "mchair": "A"}

## 책 · 바인더 색 (채도 낮게, 노랑 · 주황 없음)
BOOKS = ["#7f93ad", "#8fa79a", "#a07c7c", "#6e7a8c", "#c9c2b5", "#5f6f66", "#8b7f9e", "#e9e6e1", "#4f5a6b"]
LED = "#7fd0c0"
NAVY = "#3f4c6b"


def emat(name, hexcol, strength=2.0):
    """스스로 빛나는 재질 (LED · 화면)"""
    m = mat(name, hexcol, 0.4)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


# ------------------------------------------------------------------ 서버 랙 (0.6 × 0.5, 높이 1.35) / 서버 선반 (초기 단계)
## 원점 = 바닥 가운데, 앞면 = -Y. LED = 따로 된 물체 Leds
def build_rack(v):
    body = mat("RackBody", "#45474d", 0.5)
    unit = mat("ServerUnit", "#5c6067", 0.5)
    bezel = mat("ServerBezel", "#7b8088", 0.45)
    steel = mat("Steel", STEEL, 0.4, 0.6)
    glass = mat("RackGlass", "#2a3138", 0.15)
    cable = [mat("CableBlue", "#5f7fa8", 0.8), mat("CableGray", "#9aa0a6", 0.8)]
    led = emat("Led", LED, 3.0)
    W, D = 0.58, 0.48
    r = Parts()
    l = Parts()
    if v == "C":   # 서버 선반: 낮은 금속 선반 3단 + 작은 서버 2대 + 공유기 + 선
        H = 0.9
        for x in (-W / 2 + 0.02, W / 2 - 0.02):
            for y in (-D / 2 + 0.02, D / 2 - 0.02):
                r.box(steel, (x, y, H / 2), (0.03, 0.03, H), bevel=0.004)
        for z in (0.06, 0.45, H - 0.02):
            r.box(steel, (0, 0, z), (W, D, 0.025), bevel=0.004)
        r.box(unit, (-0.08, 0, 0.06 + 0.14), (0.36, 0.4, 0.26))
        r.box(bezel, (-0.08, -0.205, 0.2), (0.32, 0.012, 0.22), bevel=0.004)
        r.box(unit, (0.0, 0, 0.45 + 0.07), (0.44, 0.38, 0.12))
        r.box(bezel, (0.0, -0.195, 0.52), (0.4, 0.012, 0.09), bevel=0.003)
        r.box(mat("Router", "#e9e6e1", 0.6), (0.05, 0, H + 0.03), (0.26, 0.16, 0.04))
        for k in (-1, 1):
            r.cyl(mat("Router", "#e9e6e1"), (0.05 + k * 0.1, 0.06, H + 0.05), 0.008, 0.12, seg=6)
        r.box(cable[0], (W / 2 - 0.06, D / 2 - 0.05, 0.45), (0.025, 0.025, 0.8), bevel=0.006)
        for k in range(3):
            l.box(led, (-0.18 + k * 0.05, -0.215, 0.29), (0.025, 0.01, 0.015), bevel=0)
            l.box(led, (-0.15 + k * 0.05, -0.205, 0.555), (0.025, 0.01, 0.015), bevel=0)
            l.box(led, (0.0 + k * 0.03, -0.085, H + 0.052), (0.015, 0.01, 0.008), bevel=0)
        return [r.obj("ServerShelf"), l.obj("Leds")]
    H = 1.33
    n_units = 7
    if v == "A":   # 닫힌 랙: 몸통 + 유리문 너머 서버 줄
        r.box(body, (0, 0.01, H / 2 + 0.03), (W, D - 0.02, H - 0.02), bevel=0.015)
        r.box(glass, (0, -D / 2 + 0.005, H / 2 + 0.03), (W - 0.08, 0.012, H - 0.14), bevel=0)
        r.box(steel, (W / 2 - 0.07, -D / 2 - 0.012, H * 0.55), (0.02, 0.02, 0.18), bevel=0.004)   # 손잡이
        for k in range(10):   # 위 통풍구
            r.box(mat("Vent", "#2f3136", 0.7), (-0.2 + k * 0.045, 0, H + 0.04), (0.02, D - 0.12, 0.004), bevel=0)
        front = -D / 2 + 0.02
    else:          # B 열린 프레임: 기둥 4 + 서버 + 옆 선 다발
        for x in (-W / 2 + 0.025, W / 2 - 0.025):
            for y in (-D / 2 + 0.025, D / 2 - 0.025):
                r.box(body, (x, y, H / 2 + 0.03), (0.04, 0.04, H), bevel=0.005)
        for z in (0.05, H + 0.02):
            r.box(body, (0, 0, z), (W, D, 0.04), bevel=0.008)
        for k, c in enumerate((cable[0], cable[1], cable[0])):
            r.box(c, (W / 2 - 0.06 - k * 0.025, D / 2 - 0.06, H / 2 + 0.05), (0.018, 0.018, H - 0.1), bevel=0.005)
        front = -D / 2 + 0.06
    for k in range(n_units):   # 서버 줄 (위로 갈수록 빈칸 1개)
        if k == 5:
            continue
        z = 0.12 + k * 0.165
        r.box(unit, (0, front + 0.21, z + 0.06), (W - 0.1, 0.42, 0.13), bevel=0.006)
        r.box(bezel, (0, front + 0.005, z + 0.06), (W - 0.12, 0.012, 0.11), bevel=0.003)
        for j in range(3):   # 서버마다 불빛 3개 (오른쪽)
            l.box(led, (0.12 + j * 0.04, front - 0.003, z + 0.08), (0.022, 0.008, 0.014), bevel=0)
        r.box(mat("Vent", "#2f3136"), (-0.08, front - 0.002, z + 0.04), (0.2, 0.006, 0.05), bevel=0)
    r.box(body, (0, 0, 0.015), (W, D, 0.03), bevel=0.004)
    return [r.obj("Rack"), l.obj("Leds")]


# ------------------------------------------------------------------ 책장 (0.75 × 0.35, 높이 1.25) — 원점 = 바닥 가운데, 앞면 = -Y
def build_bookshelf(v):
    rnd = random.Random(7)
    W, D, H = 0.74, 0.34, 1.24
    frame = mat("ShelfWhite", WHITE, 0.6) if v == "C" else mat("ShelfWood", WOOD, 0.7)
    back = mat("ShelfBack", "#d8d2c8", 0.8) if v == "C" else mat("ShelfBackWood", WOOD_DARK, 0.8)
    s = Parts()
    t = 0.03
    s.box(back, (0, D / 2 - 0.01, H / 2), (W, 0.02, H), bevel=0)
    for x in (-W / 2 + t / 2, W / 2 - t / 2):
        s.box(frame, (x, 0, H / 2), (t, D, H), bevel=0.006)
    levels = [0.05, 0.36, 0.66, 0.96, H - t / 2]
    for z in levels:
        s.box(frame, (0, 0, z), (W, D, t), bevel=0.005)

    def books(z0, x0, x1, tall=0.24, lean_end=True):
        x = x0
        while x < x1 - 0.03:
            w = rnd.uniform(0.028, 0.05)
            h = tall * rnd.uniform(0.75, 1.0)
            dd = rnd.uniform(0.2, 0.26)
            bi = rnd.randrange(len(BOOKS))
            s.box(mat("Book%d" % bi, BOOKS[bi], 0.8),
                  (x + w / 2, -D / 2 + 0.03 + dd / 2, z0 + h / 2), (w, dd, h), bevel=0.003)
            x += w + 0.004
        if lean_end:   # 마지막 한 권 기울임
            s.box(mat("Book1", BOOKS[1]), (x1 - 0.05, -0.02, z0 + 0.1), (0.035, 0.22, 0.22), bevel=0.003, rot_z=0)

    inner0, inner1 = -W / 2 + t, W / 2 - t
    for k, z in enumerate(levels[:-1]):
        z0 = z + t / 2
        gap = levels[k + 1] - z - t
        if v == "A":   # 꽉 찬 책
            books(z0, inner0, inner1 - (0.12 if k % 2 else 0.02), gap - 0.04, lean_end=False)
            if k % 2:
                s.box(mat("BookStack", BOOKS[3], 0.8), (inner1 - 0.06, -0.04, z0 + 0.03), (0.1, 0.18, 0.06), bevel=0.004)
        elif v == "B":   # 책 + 바인더 + 상자 섞음
            if k == 0:
                for j in range(2):
                    s.box(mat("Box", "#bfb6a8", 0.9), (inner0 + 0.17 + j * 0.34, -0.01, z0 + 0.12), (0.3, 0.26, 0.24), bevel=0.01)
            elif k == 1:
                for j in range(6):
                    c = ["#7f93ad", "#e9e6e1", "#7f93ad", "#8fa79a", "#e9e6e1", "#6e7a8c"][j]
                    s.box(mat("Binder%d" % j, c, 0.7), (inner0 + 0.04 + j * 0.065, -0.02, z0 + 0.13), (0.055, 0.24, 0.26), bevel=0.004)
                    s.box(mat("Label", "#f3f1ec", 0.8), (inner0 + 0.04 + j * 0.065, -0.142, z0 + 0.18), (0.03, 0.004, 0.06), bevel=0)
            else:
                books(z0, inner0, inner0 + 0.42, gap - 0.04)
        else:   # C 흰 틀 + 아래 바구니 + 위 책
            if k == 0:
                for j in range(2):
                    s.box(mat("Basket", "#a8998a", 0.95), (inner0 + 0.17 + j * 0.34, -0.01, z0 + 0.1), (0.3, 0.27, 0.2), bevel=0.02)
            else:
                books(z0, inner0, inner1 - 0.2, gap - 0.04)
                s.box(mat("Frame", DARK, 0.5), (inner1 - 0.09, 0.05, z0 + 0.08), (0.12, 0.02, 0.16), bevel=0.006)
    # 위: 작은 화분 (B · C) / 서류 상자 (A)
    top = H
    if v == "A":
        s.box(mat("Box", "#bfb6a8", 0.9), (-0.18, 0, top + 0.07), (0.28, 0.24, 0.14), bevel=0.01)
    else:
        s.cone(mat("Pot", POT, 0.9), (0.2, 0, top), 0.05, 0.065, 0.1)
        s.sphere(mat("Leaf", LEAF, 0.9), (0.2, 0, top + 0.16), 0.09, scale=(1, 1, 1.1))
    return [s.obj("Bookshelf")]


# ------------------------------------------------------------------ 화이트보드 (판 1.1 × 0.8, 판 아래 끝 0.45) — 원점 = 바닥 가운데, 앞면 = -Y
def build_whiteboard(v):
    """벽걸이 (M4 3세션째 — 뒷벽 2.1 로 높아짐). build_desk_kit 스타일: 두툼한 틀 · 둥근 모서리.
    원점 = 바닥, 뒷면 = y +0.05 (벽에 붙음), 앞 = -Y. A 나무 틀 · B 흰 둥근 틀 + 걸이 레일 · C 화이트보드 + 코르크판"""
    wood, wood_d = mat("KWood", "#9a7458", 0.7), mat("KWoodD", "#7d5d47", 0.75)
    light, metal = mat("WbFrame", "#ece9e3", 0.5), mat("WbMetal", "#5c6067", 0.45, 0.5)
    board = mat("Board", "#f6f5f1", 0.3)
    ink = [mat("InkBlue", "#4f6fa0", 0.6), mat("InkRed", "#a65e5e", 0.6), mat("InkDark", "#3b3d42", 0.6)]
    notes = [mat("NoteBlue", "#a9c6e0", 0.8), mat("NoteGreen", "#b5d3b0", 0.8), mat("NotePink", "#e3b5bd", 0.8)]
    Z0, BH = 0.44, 0.76          # 판 아래 · 높이 (뒷벽 가운데 호출 보드 (높이 1.72, 틀 아래 ≈ 1.44) 바로 밑, 레일 위 ≈ 1.32 — 사용자 실화면 '살짝 아래로')
    ZC = Z0 + BH / 2
    SZ = Z0 - 0.62               # 자석 · 포스트잇 · 코르크 종이 z 는 처음 (Z0 0.62) 기준 → 옮긴 만큼 더함
    BW = 1.45 if v != "C" else 0.72   # 사용자: 위 호출 보드 (1.5) 와 폭 맞춤   # C = 화이트보드 (왼) + 코르크판 (오)
    BX = 0.0 if v != "C" else -0.25
    w = Parts()
    fr = light if v == "B" else wood
    FT = 0.065                   # 틀 두께 (앞뒤)
    fy = 0.05 - FT / 2           # 틀 중심 y
    full = BW + 0.1 if v != "C" else 1.27
    fx = BX if v != "C" else 0.0
    w.box(fr, (fx, fy, ZC), (full, FT, BH + 0.1), bevel=0.035 if v == "B" else 0.028, seg=3)
    w.box(board, (BX, fy - FT / 2 + 0.006, ZC), (BW - 0.02, 0.012, BH - 0.02), bevel=0.006)
    tray_y = fy - FT / 2 - 0.035
    if v in "AC":   # 나무 펜 받침 (두툼 + 앞 턱)
        w.box(wood_d, (BX, tray_y, Z0 - 0.04), (BW * 0.75, 0.08, 0.035), bevel=0.014)
        w.box(wood, (BX, tray_y - 0.035, Z0 - 0.02), (BW * 0.75, 0.018, 0.03), bevel=0.008)
    else:           # 금속 받침 + 위 걸이 레일 · 집게 2
        w.box(metal, (BX, tray_y, Z0 - 0.045), (BW * 0.8, 0.07, 0.025), bevel=0.01)
        w.box(metal, (BX, fy, Z0 + BH + 0.1), (BW + 0.2, 0.04, 0.035), bevel=0.014)
        for x in (-0.3, 0.3):
            w.box(metal, (x, fy - 0.03, Z0 + BH + 0.065), (0.05, 0.03, 0.07), bevel=0.01)
    for k, m in enumerate(ink):   # 펜 3 + 지우개
        w.box(m, (BX - 0.2 + k * 0.085, tray_y, Z0 - 0.012), (0.07, 0.022, 0.022), bevel=0.008)
    w.box(mat("Eraser", "#5f646c", 0.8), (BX + 0.18, tray_y, Z0 - 0.002), (0.12, 0.045, 0.04), bevel=0.012)
    if v == "B":   # 둥근 자석 4
        for (x, z), m in zip(((0.2, 1.33), (0.27, 1.33), (0.63, 0.71), (-0.64, 0.71)), (notes[0], notes[2], notes[1], notes[0])):
            w.cyl(m, (x, fy - FT / 2 - 0.01, z + SZ), 0.022, 0.02, seg=12, rot=(90, 0, 0))
    if v == "C":   # 코르크판 + 꽂힌 종이 · 핀
        cx = 0.35
        w.box(wood_d, (cx - 0.24, fy - FT / 2 + 0.004, ZC), (0.03, 0.014, BH - 0.02), bevel=0.006)   # 가운데 칸 띠
        w.box(mat("Cork", "#b58f6b", 0.95), (cx, fy - FT / 2 + 0.006, ZC), (0.44, 0.012, BH - 0.02), bevel=0.006)
        for (x, z, sx, sz, rz), m in zip(((0.28, 1.2, 0.16, 0.2, 4), (0.45, 1.16, 0.14, 0.14, -6), (0.33, 0.9, 0.2, 0.15, -3),
                                         (0.48, 0.82, 0.12, 0.12, 5)), (board, notes[0], board, notes[1])):
            w.box(m, (x, fy - FT / 2 - 0.002, z + SZ), (sx, 0.006, sz), bevel=0.002, rot_z=0)
            w.sphere(ink[1] if m is board else ink[0], (x, fy - FT / 2 - 0.012, z + SZ + sz / 2 - 0.025), 0.013)
    # 포스트잇 (A · B: 판 모서리)
    if v in "AB":
        for (x, z), m in zip(((0.55, 1.24), (0.62, 1.16), (0.55, 1.08)), notes):
            w.box(m, (x, fy - FT / 2 - 0.002, z + SZ), (0.075, 0.006, 0.075), bevel=0.002)
    # 그림 (게임: 낙서 · 포스트잇이 생기면 숨김) — 제목 줄 · 막대그래프 · 할 일 목록 (사용자: 상자 2개 + 줄 = '안경 같다' → 바꿈)
    d = Parts()
    yy = fy - FT / 2 - 0.002
    k = 1.2 if v != "C" else 0.62   # 판 폭 1.45 에 맞춰 넓게
    green = mat("InkGreen", "#5f9a6e", 0.6)

    def dbox(m, x, z, sx, sz):   # x · z = 판 가운데 기준
        d.box(m, (BX + x * k, yy, ZC + z), (sx * k, 0.003, sz), bevel=0)
    dbox(ink[2], -0.3, 0.28, 0.34, 0.016)                      # 제목
    dbox(ink[1], -0.33, 0.245, 0.28, 0.01)                     # 밑줄
    dbox(ink[2], -0.44, 0.0, 0.012, 0.3)                       # 그래프 축
    dbox(ink[2], -0.3, -0.15, 0.29, 0.012)
    for i, h in enumerate((0.1, 0.17, 0.24)):                  # 막대 (오름)
        dbox(ink[0], -0.37 + i * 0.085, -0.144 + h / 2, 0.055, h)
    for i in range(3):                                         # 할 일 목록: 칸 + 줄 (위 2개 = 끝남 초록 칸)
        z = 0.1 - i * 0.11
        x0 = 0.0
        if i < 2:
            dbox(green, x0, z, 0.045, 0.045)
        else:
            for (ox, oz, sx, sz) in ((0, 0.022, 0.045, 0.008), (0, -0.022, 0.045, 0.008), (-0.022, 0, 0.008, 0.045), (0.022, 0, 0.008, 0.045)):
                dbox(ink[2], x0 + ox, z + oz, sx, sz)
        dbox(ink[0] if i < 2 else ink[2], x0 + 0.15, z, 0.2 - i * 0.03, 0.012)
    return [w.obj("Whiteboard"), d.obj("Doodle")]


# ------------------------------------------------------------------ 망원경 (0.4 × 0.4) — 원점 = 바닥 가운데. Tube 원점 = 회전축 (게임이 돌림)
def build_telescope(v):
    dark = mat("Dark", DARK, 0.5)
    steel = mat("Steel", STEEL, 0.4, 0.6)
    tube_m = mat("TubeWhite", WHITE, 0.4) if v == "A" else mat("TubeNavy", NAVY, 0.45)
    t = Parts()
    if v == "A":   # 삼각대
        PZ = 0.62
        for k in range(3):
            a = math.radians(90 + k * 120)
            x, y = 0.15 * math.cos(a), 0.15 * math.sin(a)
            ln = math.hypot(0.15, PZ)
            tilt = math.degrees(math.atan2(0.15, PZ))
            t.cyl(steel, (x, y, 0), 0.012, ln, seg=6, rot=(tilt * math.sin(a), -tilt * math.cos(a), 0))
        t.cyl(dark, (0, 0, PZ - 0.06), 0.035, 0.08)
    else:          # B 기둥 받침 (관측소)
        PZ = 0.6
        t.cyl(dark, (0, 0, 0), 0.14, 0.04, seg=16)
        t.cyl(steel, (0, 0, 0.04), 0.035, PZ - 0.1)
        t.cyl(dark, (0, 0, PZ - 0.08), 0.05, 0.08)
    stand = t.obj("TelescopeStand")
    u = Parts()
    L = 0.5 if v == "A" else 0.42
    R = 0.045 if v == "A" else 0.065
    # 경통: 원점에서 +Y (앞 = 하늘 쪽) 로, 30° 들림
    u.cyl(tube_m, (0, -L * 0.35, 0), R, L, seg=14, rot=(-90, 0, 0))
    u.cyl(dark, (0, -L * 0.35 + L, 0), R * 1.2, 0.07, seg=14, rot=(-90, 0, 0))     # 이슬막이 (앞 끝)
    u.cyl(dark, (0, -L * 0.35 - 0.06, 0), R * 0.45, 0.06, seg=10, rot=(-90, 0, 0))  # 접안 (뒤 끝)
    u.cyl(dark, (0, 0.02, R + 0.005), 0.012, 0.12, seg=8, rot=(-90, 0, 0))           # 파인더
    u.box(dark, (0, 0, -R / 2 - 0.01), (0.05, 0.06, R + 0.02), bevel=0.005)
    tube = u.obj("Tube")
    tube.location = (0, 0, PZ + 0.02)
    tube.rotation_euler = (math.radians(30), 0, math.radians(-25))
    return [stand, tube]


# ------------------------------------------------------------------ 호출 보드 틀 (1.8 × 0.6 판, 칸은 게임이 그림) — 원점 = 판 가운데, 앞면 = -Y
def build_board(v):
    """호출 보드 틀 1.5 × 0.5 (칸 12개는 게임 코드가 그림 — 판 앞 y -0.04). 원점 = 판 가운데, 뒷면 y +0.035.
    M4 3세션째 kit 스타일: A 나무 두 겹 틀 + 명판 · 종 / B 흰 둥근 틀 + 레일 · 종 (화이트보드 B 와 짝, 사용자 고름) / C 남색 현황판 + 머리판 · 램프"""
    BW, BH = 1.5, 0.5   # 사용자: 아래 화이트보드와 폭 맞춤 (칸 6×2 = 0.25 정사각)
    b = Parts()
    T, D = 0.032, 0.07   # 틀 굵기 · 깊이 (사용자 2번: 두꺼우면 화이트보드가 너무 아래 붙은 느낌 → 얇게)
    fy = 0.035 - D / 2
    if v == "A":
        fr, inner, bk = mat("KWood", "#9a7458", 0.7), mat("KWoodD", "#7d5d47", 0.75), mat("BoardBack", "#4d463f", 0.8)
    elif v == "B":
        fr, inner, bk = mat("WbFrame", "#ece9e3", 0.5), mat("WbFrameD", "#d4d0c8", 0.6), mat("BoardBackDark", "#3b3d42", 0.7)
    else:
        fr, inner, bk = mat("BoardFrameNavy", "#34405a", 0.6), mat("BoardInnerNavy", "#2a3349", 0.65), mat("BoardBackNavy", "#2f3646", 0.7)
    b.box(bk, (0, 0.01, 0), (BW, 0.05, BH), bevel=0.005)
    # 두툼한 바깥 틀 (위 · 아래 · 양옆, 둥근 모서리) + 안쪽 진한 띠
    for z in (BH / 2 + T / 2 - 0.01, -BH / 2 - T / 2 + 0.01):
        b.box(fr, (0, fy, z), (BW + 2 * T - 0.02, D, T), bevel=0.03, seg=3)
    for x in (BW / 2 + T / 2 - 0.01, -BW / 2 - T / 2 + 0.01):
        b.box(fr, (x, fy, 0), (T, D, BH + 0.02), bevel=0.03, seg=3)
    for z in (BH / 2 - 0.006, -BH / 2 + 0.006):
        b.box(inner, (0, fy + 0.01, z), (BW, D - 0.03, 0.02), bevel=0.006)
    silver = mat("BellSteel", "#c5ccd1", 0.3, 0.7)
    top = BH / 2 + T - 0.01
    if v == "A":   # 위 둥근 명판 (진한 나무) + 은색 종
        b.box(inner, (0, fy - 0.01, top + 0.06), (0.42, 0.06, 0.12), bevel=0.03, seg=3)
        b.box(mat("Plate", "#e6dfd2", 0.4), (0, fy - 0.045, top + 0.06), (0.32, 0.01, 0.06), bevel=0.01)
        b.cone(silver, (0.33, fy - 0.01, top), 0.06, 0.028, 0.08, seg=16)
        b.sphere(silver, (0.33, fy - 0.01, top + 0.095), 0.02)
    elif v == "B":   # 위 금속 레일 + 가운데 종 · 아래 얇은 선반
        metal = mat("WbMetal", "#5c6067", 0.45, 0.5)
        b.box(metal, (0, fy, top + 0.035), (BW + 0.3, 0.045, 0.04), bevel=0.016)
        b.cone(silver, (0, fy - 0.01, top + 0.055), 0.075, 0.032, 0.1, seg=16)
        b.sphere(silver, (0, fy - 0.01, top + 0.17), 0.024)
    else:          # 머리판 (빛 줄) + 양옆 둥근 램프
        b.box(fr, (0, fy, top + 0.08), (0.8, D, 0.16), bevel=0.04, seg=3)
        b.box(emat("BoardHeadLine", "#b9d3df", 0.8), (0, fy - D / 2 - 0.002, top + 0.08), (0.56, 0.004, 0.035), bevel=0)
        for x in (-BW / 2 - T - 0.08, BW / 2 + T + 0.08):
            b.cyl(inner, (x, fy + 0.02, 0.12), 0.06, 0.07, seg=20, rot=(90, 0, 0))
            b.cyl(emat("BoardLamp", "#cfe3ec", 0.9), (x, fy - 0.05, 0.12), 0.042, 0.012, seg=20, rot=(90, 0, 0))
    return [b.obj("CallBoardFrame")]


# ------------------------------------------------------------------ 잎 · 날 (화분용): +X 로 뻗는 휘어진 판 (가운데 접힘 + 끝으로 처짐, 부드러운 면)
def leaf_mesh(L, W, droop=0.0, fold=0.25, shape="oval", nl=7, nw=2):
    tb = bmesh.new()
    rows = []
    for i in range(nl + 1):
        t = i / nl
        if shape == "oval":
            half = W / 2 * (max(0.0, math.sin(math.pi * min(t * 1.05, 1.0))) ** 0.75)
        else:   # blade: 거의 같은 폭 → 끝만 뾰족
            half = W / 2 * (1.0 if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3) ** 0.8)
        x = L * t
        z = -droop * t * t
        row = []
        for j in range(-nw, nw + 1):
            s = j / nw
            row.append(tb.verts.new((x, s * half, z + fold * abs(s) * half)))
        rows.append(row)
    for i in range(nl):
        for j in range(2 * nw):
            f = tb.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            f.smooth = True
    return tb


def add_leaf(p, m, base, yaw, pitch, L, W, droop=0.0, fold=0.25, shape="oval", roll=0.0):
    """base 에서 yaw (도) 방향으로, pitch (도) 만큼 들어 올린 잎"""
    p._add(leaf_mesh(L, W, droop, fold, shape), m, Vector(base), (roll, -pitch, yaw))


def stem(p, m, a, b, r):
    """a → b 줄기 (원기둥)"""
    a, b = Vector(a), Vector(b)
    d = b - a
    yaw = math.degrees(math.atan2(d.y, d.x))
    pitch = math.degrees(math.atan2(math.hypot(d.x, d.y), d.z))
    p.cyl(m, tuple(a), r, d.length, seg=6, rot=(0, pitch, yaw))


def pot_round(p, r0, r1, h, col, rim_col=None):
    """둥근 도자기 화분: 받침 + 몸통 + 테두리 + 흙. 돌려줌 = 흙 윗면 높이"""
    body = mat("Pot_" + col, col, 0.55)
    rim = mat("PotRim_" + (rim_col or col), rim_col or col, 0.5)
    p.cyl(mat("Saucer", "#8f877c", 0.7), (0, 0, 0), r0 + 0.02, 0.015, seg=24)
    p.cone(body, (0, 0, 0.012), r0, r1, h, seg=24)
    p.cone(rim, (0, 0, 0.012 + h - 0.005), r1 + 0.008, r1 + 0.01, 0.03, seg=24)
    p.cyl(mat("Soil", "#4f4239", 1.0), (0, 0, 0.012 + h + 0.012), r1 - 0.004, 0.012, seg=24)
    return 0.012 + h + 0.024


def _slab(w, h, t):
    """세운 얇은 판 (가운데 원점, 폭 w · 높이 h · 두께 t)"""
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    bmesh.ops.scale(tb, vec=Vector((w, t, h)), verts=tb.verts)
    return tb


# ------------------------------------------------------------------ 개인 소품 (책상 기준 좌표 = desk_set 과 같음) — 업무 소품 위주
## Item0 서류 트레이 2단 · Item1 펜꽂이 · Item2 탁상 달력 · Item3 모니터 포스트잇 · Item4 사진 액자 · Item5 다육 화분
## 게임: 책상마다 이 중 일부만 보임 (id 로 고름). B = 칸막이 위 선반 (바인더 · 파일 상자) 추가
def _personal_old(v):
    TOP = 0.48
    dark = mat("TrayDark", "#4a4d53", 0.5)
    paper = mat("Paper", "#f3f1ec", 0.9)
    objs = []
    p = Parts()   # 0 서류 트레이 (왼쪽 뒤)
    x, y = -0.47, 0.0   # (M4 새 책상: 모니터 2대 · 와이드와 안 겹치게 왼쪽 앞)
    for k in range(2):
        z = TOP + k * 0.055
        p.box(dark, (x, y, z + 0.006), (0.17, 0.12, 0.012), bevel=0.003)
        for sx in (-1, 1):
            p.box(dark, (x + sx * 0.08, y, z + 0.025), (0.01, 0.12, 0.04), bevel=0.002)
        p.box(dark, (x, y + 0.055, z + 0.025), (0.17, 0.01, 0.04), bevel=0.002)
        p.box(paper, (x, y - 0.005, z + 0.018 + k * 0.004), (0.14, 0.1, 0.012 + k * 0.008), bevel=0)
    objs.append(p.obj("Item0"))
    p = Parts()   # 1 펜꽂이 + 펜 3
    x, y = -0.3, 0.04
    p.cyl(mat("PenCup", "#5f646c", 0.5), (x, y, TOP), 0.024, 0.07, seg=12)
    for k, c in enumerate(("#3b3d42", "#4f6fa0", "#a65e5e")):
        a = math.radians(k * 120)
        p.cyl(mat("Pen%d" % k, c, 0.5), (x + 0.008 * math.cos(a), y + 0.008 * math.sin(a), TOP + 0.03), 0.004, 0.09, seg=6,
              rot=(8 * math.sin(a), -8 * math.cos(a), 0))
    objs.append(p.obj("Item1"))
    p = Parts()   # 2 탁상 달력 (뒤 받침 + 기운 앞장 + 위 남색 띠 + 줄)
    x, y = 0.49, -0.21
    p.box(mat("CalBack", "#5f646c", 0.6), (x, y + 0.012, TOP + 0.04), (0.11, 0.006, 0.085), bevel=0)
    p._add(_slab(0.11, 0.085, 0.004), paper, Vector((x, y - 0.012, TOP + 0.042)), (-14, 0, 0))
    p._add(_slab(0.11, 0.02, 0.005), mat("CalHead", NAVY, 0.6), Vector((x, y - 0.02, TOP + 0.077)), (-14, 0, 0))
    for k in range(3):
        p._add(_slab(0.075, 0.004, 0.002), mat("CalLine", "#9aa0a6", 0.8), Vector((x, y - 0.019, TOP + 0.055 - k * 0.012)), (-14, 0, 0))
    objs.append(p.obj("Item2"))
    p = Parts()   # 3 포스트잇 (칸막이 천 왼쪽, 노랑 금지 → 하늘 · 분홍 · 민트)
    for k, c in enumerate(("#b9d3df", "#e3c4c8", "#bfe0cf")):
        p.box(mat("Note%d" % k, c, 0.9), (-0.42 + k * 0.05, 0.266, TOP + 0.24 - (k % 2) * 0.05), (0.04, 0.003, 0.04), bevel=0)
    objs.append(p.obj("Item3"))
    p = Parts()   # 4 사진 액자 (기댄 모양, 사진 = 하늘 + 들판)
    x, y = -0.52, -0.2
    p._add(_slab(0.09, 0.12, 0.012), mat("Frame", DARK, 0.5), Vector((x, y, TOP + 0.058)), (-12, 0, 195))
    p._add(_slab(0.07, 0.05, 0.003), mat("PhotoSky", "#9fb6c9", 0.6), Vector((x, y - 0.004, TOP + 0.074)), (-12, 0, 195))
    p._add(_slab(0.07, 0.045, 0.003), mat("PhotoLand", "#8fa79a", 0.6), Vector((x, y - 0.0045, TOP + 0.03)), (-12, 0, 195))
    objs.append(p.obj("Item4"))
    p = Parts()   # 5 다육 화분 (네모 흰 화분 + 로제트 잎)
    x, y = 0.47, -0.06
    p.box(mat("PotWhite", WHITE, 0.6), (x, y, TOP + 0.022), (0.05, 0.05, 0.044), bevel=0.006)
    succ = mat("Succulent", "#7f9c7a", 0.7)
    for k in range(7):
        add_leaf(p, succ, (x, y, TOP + 0.04), k * 51, 35 + (k % 2) * 15, 0.035, 0.022, fold=0.4)
    objs.append(p.obj("Item5"))
    if v == "B":   # 칸막이 위 선반 + 바인더 2 + 파일 상자
        s = Parts()
        z = PANEL_TOP + 0.02
        s.box(mat("ShelfWood", WOOD, 0.7), (-0.32, 0.27, PANEL_TOP + 0.012), (0.5, 0.12, 0.02), bevel=0.004)
        for k, c in enumerate(("#7f93ad", "#e9e6e1")):
            s.box(mat("Binder%d" % k, c, 0.7), (-0.52 + k * 0.05, 0.27, z + 0.09), (0.04, 0.1, 0.18), bevel=0.004)
            s.box(paper, (-0.52 + k * 0.05, 0.219, z + 0.12), (0.02, 0.003, 0.05), bevel=0)
        s.box(mat("FileBox", "#bfb6a8", 0.9), (-0.35, 0.27, z + 0.06), (0.14, 0.1, 0.12), bevel=0.006)
        s.box(paper, (-0.35, 0.27, z + 0.125), (0.11, 0.07, 0.02), bevel=0)
        objs.append(s.obj("PersonalShelf"))
    return objs


def _rbox(p, m, c, size, rot=(0, 0, 0), bevel=0.01, seg=2):
    """아무 방향으로 돌린 둥근 상자 (build_desk_kit.tbox 와 같음 — 그쪽이 이 파일을 불러서 여기 따로 둠)"""
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    bmesh.ops.scale(tb, vec=Vector(size), verts=tb.verts)
    if bevel > 0:
        bmesh.ops.bevel(tb, geom=list(tb.edges), offset=min(bevel, min(size) * 0.45), segments=seg, affect="EDGES", profile=0.5)
    p._add(tb, m, Vector(c), rot)


def build_personal(v):
    """A = 지금 (2세션째 임시 B) · B kit 두툼 (같은 6종을 두껍고 둥글게) · C kit + 개성 (머그 · 큐브 달력 · 헤드폰)
    이름은 그대로 Item0~5 + PersonalShelf (게임이 책상마다 일부만 보임)"""
    if v == "A":
        return _personal_old("B")
    TOP = 0.48
    C = v == "C"
    wood, wood_d = mat("KWood", "#9a7458", 0.7), mat("KWoodD", "#7d5d47", 0.75)
    paper = mat("Paper", "#f3f1ec", 0.9)
    gray = mat("KGray", "#5c6067", 0.5)
    objs = []
    p = Parts()   # 0 서류 트레이 2단 (두툼한 둥근 판 + 옆 기둥)
    x, y = -0.47, 0.0
    for k in range(2):
        z = TOP + k * 0.062
        p.box(gray, (x, y, z + 0.008), (0.18, 0.13, 0.016), bevel=0.007, seg=2)
        p.box(paper, (x, y - 0.006, z + 0.024 + k * 0.004), (0.15, 0.105, 0.016 + k * 0.008), bevel=0.003)
    for sx in (-1, 1):
        p.box(gray, (x + sx * 0.083, y + 0.045, TOP + 0.06), (0.016, 0.03, 0.12), bevel=0.007)
    objs.append(p.obj("Item0"))
    p = Parts()   # 1 펜꽂이 (B) / 머그 + 펜 (C)
    x, y = -0.3, 0.04
    if C:
        mug = mat("MugMint", "#8fa79a", 0.5)
        p.cyl(mug, (x, y, TOP), 0.036, 0.075, seg=16)
        p.cyl(mat("Coffee", "#6b5040", 0.4), (x, y, TOP + 0.07), 0.03, 0.006, seg=16)
        _rbox(p, mug, (x + 0.042, y, TOP + 0.038), (0.022, 0.014, 0.05), bevel=0.006)
    else:
        cup = mat("PenCupBlue", "#7f93ad", 0.5)
        p.cyl(cup, (x, y, TOP), 0.034, 0.085, seg=16)
        p.cyl(mat("PenCupRim", "#6a7d96", 0.5), (x, y, TOP + 0.08), 0.036, 0.01, seg=16)
        for k, c in enumerate(("#3b3d42", "#4f6fa0", "#a65e5e")):
            a = math.radians(k * 120)
            px, py = x + 0.012 * math.cos(a), y + 0.012 * math.sin(a)
            rot = (10 * math.sin(a), -10 * math.cos(a), 0)
            p.cyl(mat("Pen%d" % k, c, 0.5), (px, py, TOP + 0.03), 0.007, 0.1, seg=8, rot=rot)
    objs.append(p.obj("Item1"))
    p = Parts()   # 2 탁상 달력: B 텐트형 (두툼) / C 나무 큐브 달력
    x, y = 0.49, -0.21
    if C:
        _rbox(p, wood, (x, y, TOP + 0.012), (0.12, 0.06, 0.024), bevel=0.008)
        for k in range(2):
            cx = x - 0.026 + k * 0.052
            _rbox(p, paper, (cx, y, TOP + 0.048), (0.046, 0.046, 0.046), bevel=0.008)
            _rbox(p, mat("CalNum", "#4f6fa0", 0.6), (cx, y - 0.024, TOP + 0.048), (0.012 + k * 0.01, 0.003, 0.026), bevel=0)
    else:
        for sgn in (-1, 1):
            _rbox(p, paper if sgn < 0 else gray, (x, y + sgn * 0.016, TOP + 0.05), (0.13, 0.012, 0.1), rot=(sgn * 15, 0, 0), bevel=0.005)
        _rbox(p, mat("CalHead", NAVY, 0.6), (x, y - 0.026, TOP + 0.088), (0.13, 0.014, 0.026), rot=(-15, 0, 0), bevel=0.005)
        _rbox(p, mat("CalDay", "#a65e5e", 0.6), (x + 0.03, y - 0.032, TOP + 0.05), (0.026, 0.004, 0.022), rot=(-15, 0, 0), bevel=0)
        for k in range(2):
            _rbox(p, mat("CalLine", "#9aa0a6", 0.8), (x - 0.02, y - 0.03 + k * 0.003, TOP + 0.058 - k * 0.018), (0.06, 0.003, 0.006), rot=(-15, 0, 0), bevel=0)
    objs.append(p.obj("Item2"))
    p = Parts()   # 3 포스트잇 (칸막이 앞, 크게 · 살짝 기움, 노랑 금지)
    for k, c in enumerate(("#b9d3df", "#e3c4c8", "#bfe0cf")):
        _rbox(p, mat("Note%d" % k, c, 0.9), (-0.42 + k * 0.065, 0.264, TOP + 0.24 - (k % 2) * 0.06), (0.055, 0.005, 0.055),
              rot=(0, (-8, 6, -4)[k], 0), bevel=0.002)
    objs.append(p.obj("Item3"))
    p = Parts()   # 4 B 사진 액자 (두툼한 나무 틀) / C 헤드폰 (눕힘)
    x, y = -0.52, -0.2
    if C:
        hp, cushion = mat("Headphone", "#45484e", 0.5), mat("HpCushion", "#7f93ad", 0.7)
        for sx in (-1, 1):
            p.cyl(hp, (x + sx * 0.055, y, TOP), 0.034, 0.03, seg=16)
            p.cyl(cushion, (x + sx * 0.055, y, TOP + 0.03), 0.028, 0.008, seg=16)
        for k in range(9):   # 머리띠 (눕힌 반원, 뒤로)
            a = math.pi * k / 8
            _rbox(p, hp, (x - 0.055 * math.cos(a), y + 0.07 * math.sin(a), TOP + 0.012), (0.024, 0.024, 0.016), rot=(0, 0, math.degrees(a)), bevel=0.006)
    else:
        rot = (-12, 0, 195)
        _rbox(p, wood, (x, y, TOP + 0.062), (0.1, 0.022, 0.13), rot=rot, bevel=0.01, seg=2)
        _rbox(p, mat("PhotoSky", "#9fb6c9", 0.6), (x - 0.003, y - 0.011, TOP + 0.078), (0.072, 0.004, 0.05), rot=rot, bevel=0)
        _rbox(p, mat("PhotoLand", "#8fa79a", 0.6), (x - 0.003, y - 0.006, TOP + 0.036), (0.072, 0.004, 0.04), rot=rot, bevel=0)
    objs.append(p.obj("Item4"))
    p = Parts()   # 5 다육 (둥근 화분 + 통통한 잎)
    x, y = 0.47, -0.06
    top = pot_round(p, 0.03, 0.036, 0.05, "#e9e6e1", "#d8d2c8")
    for o in p.bm.verts:
        o.co.x += x
        o.co.y += y
        o.co.z += TOP
    succ = mat("Succulent", "#7f9c7a" if not C else "#8fae86", 0.7)
    for k in range(8):
        add_leaf(p, succ, (x, y, TOP + top - 0.005), k * 45, 30 + (k % 2) * 20, 0.042, 0.03, fold=0.45)
    objs.append(p.obj("Item5"))
    s = Parts()   # 칸막이 위 선반 (두툼한 나무 + 받침) + 바인더 + 파일 상자
    z = PANEL_TOP + 0.04
    s.box(wood, (-0.32, 0.27, z), (0.52, 0.13, 0.03), bevel=0.012, seg=2)
    for bx in (-0.52, -0.12):
        s.box(wood_d, (bx, 0.27, z - 0.03), (0.03, 0.1, 0.04), bevel=0.008)
    for k, c in enumerate(("#7f93ad", "#e9e6e1", "#8fa79a")):
        bx = -0.53 + k * 0.055
        s.box(mat("Binder%d" % k, c, 0.7), (bx, 0.27, z + 0.105), (0.048, 0.11, 0.18), bevel=0.01)
        s.box(paper, (bx, 0.213, z + 0.13), (0.026, 0.004, 0.05), bevel=0.002)
    s.box(mat("FileBox", "#bfb6a8", 0.9), (-0.3, 0.27, z + 0.075), (0.15, 0.11, 0.12), bevel=0.012)
    s.box(paper, (-0.3, 0.27, z + 0.14), (0.12, 0.08, 0.02), bevel=0.003)
    if C:
        f = Parts()
        t2 = pot_round(f, 0.03, 0.036, 0.05, "#a39587", "#8f8274")
        for o in f.bm.verts:
            o.co.x += -0.16
            o.co.y += 0.27
            o.co.z += z + 0.015
        for k in range(6):
            add_leaf(f, mat("Leaf", "#6f8a5a", 0.6), (-0.16, 0.27, z + 0.015 + t2 - 0.01), k * 60, 40, 0.06, 0.035, droop=0.03, fold=0.2)
        objs.append(f.obj("ShelfPlant"))
    objs.append(s.obj("PersonalShelf"))
    return objs


# ------------------------------------------------------------------ 화분 (바닥 0.3 × 0.3) — 원점 = 바닥 가운데
def build_plant(v):
    greens = [mat("Leaf", "#6f8a5a", 0.6), mat("LeafDark", "#56724a", 0.6), mat("LeafLight", "#86a06c", 0.6)]
    stem_m = mat("Stem", "#5d7a4c", 0.8)
    rnd = random.Random({"A": 3, "B": 5, "C": 8}[v])
    p = Parts()
    if v == "A":   # 몬스테라 (넓은 잎, 줄기 따로) + 흰 도자기 화분
        top = pot_round(p, 0.1, 0.125, 0.22, "#e9e6e1", "#d8d2c8")
        for k in range(11):
            a = k * 137.5 + rnd.uniform(-12, 12)
            ar = math.radians(a)
            reach = rnd.uniform(0.06, 0.15)
            h = top + rnd.uniform(0.18, 0.45)
            tip = (reach * math.cos(ar), reach * math.sin(ar), h)
            stem(p, stem_m, (0, 0, top - 0.01), tip, 0.006)
            add_leaf(p, greens[k % 3], tip, a, rnd.uniform(-5, 25), rnd.uniform(0.17, 0.24), rnd.uniform(0.14, 0.18),
                     droop=rnd.uniform(0.04, 0.08), fold=0.18, roll=rnd.uniform(-10, 10))
    elif v == "B":  # 고무나무 (키 큰 사무실 화분): 줄기 + 윤나는 타원 잎이 돌아가며
        top = pot_round(p, 0.09, 0.11, 0.26, "#5f646c", "#4a4d53")
        gloss = [mat("Gloss", "#4f6b45", 0.35), mat("GlossLight", "#668556", 0.35)]
        p.cyl(mat("Trunk", "#7a6a5a", 0.9), (0, 0, top - 0.01), 0.014, 0.6, seg=8)
        for k in range(16):
            z = top + 0.12 + k * 0.03
            add_leaf(p, gloss[k % 2], (0, 0, z), k * 137.5, rnd.uniform(15, 40) - k * 1.2, 0.12 + 0.03 * math.sin(k), 0.075,
                     droop=0.025, fold=0.12)
        add_leaf(p, gloss[1], (0, 0, top + 0.6), 0, 80, 0.09, 0.05, fold=0.1)
    else:           # 산세베리아: 세운 칼날 잎 + 회색 화분
        top = pot_round(p, 0.1, 0.12, 0.2, "#bdb8b0", "#a8a29a")
        blade = [mat("Blade", "#4f6b45", 0.6), mat("BladeLight", "#6f8a5a", 0.6)]
        for k in range(11):
            a = k * 137.5
            ar = math.radians(a)
            r = rnd.uniform(0.0, 0.06)
            add_leaf(p, blade[k % 2], (r * math.cos(ar), r * math.sin(ar), top - 0.01), a, rnd.uniform(70, 85),
                     rnd.uniform(0.3, 0.5), rnd.uniform(0.05, 0.065), droop=-0.02, fold=0.35, shape="blade",
                     roll=rnd.uniform(-30, 30))
    return [p.obj("Plant")]


# ------------------------------------------------------------------ 러그 (반지름 1 — 게임이 크기 맞춤) — 원점 = 바닥 가운데
def build_rug(v):
    r = Parts()

    def ring(m, rad, k, h=0.014):
        r.cone(m, (0, 0, k * 0.0004), rad, rad - 0.01, h, seg=48)   # 가장자리 살짝 둥글게

    if v == "A":   # 회청색 + 크림 이중 테두리
        base, line = mat("RugBlue", "#6f7f92", 0.95), mat("RugCream", "#e6dfd2", 0.95)
        for k, (rad, m) in enumerate(((1.0, base), (0.93, line), (0.9, base), (0.85, line), (0.835, base))):
            ring(m, rad, k)
        ring(mat("RugBlueDark", "#62728a", 0.95), 0.3, 5)
    elif v == "B":  # 짠 러그 (가는 동심원 3색, 아늑함)
        cols = [mat("Braid0", "#cfc3b0", 0.95), mat("Braid1", "#9aa58f", 0.95), mat("Braid2", "#8794a3", 0.95)]
        n = 14
        for k in range(n):
            ring(cols[k % 3] if k % 4 else cols[0], 1.0 - k * (0.95 / n), k)
    else:           # C 네모 + 기하 무늬 테두리 + 술
        base, pat = mat("RugBeige", "#d9cfbf", 0.95), mat("RugPattern", "#7f8ea3", 0.95)
        r.box(pat, (0, 0, 0.006), (2.0, 1.5, 0.012), bevel=0.004)
        r.box(base, (0, 0, 0.0065), (1.9, 1.4, 0.012), bevel=0)
        r.box(pat, (0, 0, 0.007), (1.6, 1.1, 0.012), bevel=0)
        r.box(base, (0, 0, 0.0075), (1.54, 1.04, 0.012), bevel=0)
        for k in range(14):   # 마름모 줄 (안쪽 테두리 따라)
            for yy in (-0.62, 0.62):
                r.box(pat, (-0.85 + k * 0.13, yy, 0.0075), (0.05, 0.05, 0.012), bevel=0, rot_z=math.radians(45))
        for k in range(19):
            for x in (-1.03, 1.03):
                r.box(base, (x, -0.72 + k * 0.08, 0.003), (0.07, 0.014, 0.005), bevel=0)
    return [r.obj("Rug")]


# ------------------------------------------------------------------ 바위 받침 (윗면 1 × 1, 게임이 건물 크기로 늘림) — 원점 = 윗면 가운데, 아래로 자람
## 높이 3.3 칸 (zones.json base: slab 0.3 + 5 단 × 0.6). 아래 끝에 크리스탈 (게임) 이 붙음
BASE_COLS = ["#8f7a63", "#7a6f66", "#6f655d", "#655c55", "#5b534d", "#524a45"]


def build_rock(v):
    """윗면 1 × 1, 높이 3.3 (아래로) — 게임이 건물 크기로 늘림. A 각진 바위 · B 두툼한 층 바위 (kit) · C 깎은 바위 + 잔디 테 (kit)"""
    if v == "B":
        return build_rock_layers()
    rnd = random.Random(11)
    H = 3.3
    rings = 9 if v != "C" else 5
    seg = 28 if v != "C" else 12
    bm = bmesh.new()
    rows = []
    for k in range(rings + 1):
        tt = k / rings
        z = -H * tt
        if v == "A":   # 각진 바위: 단마다 조금씩 좁아지고 울퉁불퉁
            f = 1.0 - 0.55 * tt ** 1.1
            jit = 0.05
        else:           # C 깎은 바위: 큰 면 · 크게 어긋남
            f = 1.0 - 0.62 * tt ** 1.2
            jit = 0.09
        if k == 0:
            f, jit = 1.0, 0.0
        if k == 1:
            f, z = 0.99, -0.3
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            # 모서리 둥근 네모 (윗면 1 × 1 에 맞춤)
            c, s = math.cos(a), math.sin(a)
            p = 6.0
            rr = 1.0 / ((abs(c) ** p + abs(s) ** p) ** (1 / p))
            x = 0.5 * rr * c * f * (1 + rnd.uniform(-jit, jit))
            y = 0.5 * rr * s * f * (1 + rnd.uniform(-jit, jit))
            ring.append(bm.verts.new((x, y, z + (rnd.uniform(-0.08, 0.08) * (2.5 if v == "C" else 1) if 1 < k < rings else 0))))
        rows.append(ring)
    tip = bm.verts.new((0, 0, -H - 0.12))   # 아래 끝 = 거의 평평 (크리스탈이 붙는 자리)
    top = bm.faces.new(rows[0])
    top.material_index = 0
    for k in range(rings):
        for j in range(seg):
            f = bm.faces.new((rows[k][j], rows[k][(j + 1) % seg], rows[k + 1][(j + 1) % seg], rows[k + 1][j]))
            f.material_index = min(k * len(BASE_COLS) // rings, len(BASE_COLS) - 1) if k > 0 else 0
    for j in range(seg):
        f = bm.faces.new((rows[-1][j], rows[-1][(j + 1) % seg], tip))
        f.material_index = len(BASE_COLS) - 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("RockBase")
    bm.to_mesh(me)
    bm.free()
    for i, c in enumerate(BASE_COLS):
        me.materials.append(mat("Rock%d" % i, c, 0.95))
    for poly in me.polygons:
        poly.use_smooth = False
    o = bpy.data.objects.new("RockBase", me)
    bpy.context.scene.collection.objects.link(o)
    if v != "C":
        return [o]
    g = Parts()   # 잔디 테 (윗면 가장자리, 떠 있는 섬 느낌) + 흙 띠
    g.box(mat("Grass", "#7d9a62", 0.9), (0, 0, -0.06), (1.03, 1.03, 0.12), bevel=0.03, seg=2)
    g.box(mat("Soil", "#8a6f57", 0.95), (0, 0, -0.2), (1.0, 1.0, 0.18), bevel=0.03, seg=2)
    return [o, g.obj("RockGrass")]


def build_rock_layers():
    """B 두툼한 층 바위: 아래로 좁아지는 둥근 판 6단 (단마다 살짝 어긋남) + 옆에 붙은 작은 돌"""
    rnd = random.Random(7)
    p = Parts()
    widths = [1.0, 0.92, 0.8, 0.66, 0.5, 0.32]
    z = 0.0
    for i, f in enumerate(widths):
        h = 0.62 if i else 0.45
        ox, oy = (rnd.uniform(-0.025, 0.025) for _ in range(2)) if i else (0.0, 0.0)
        p.box(mat("Rock%d" % i, BASE_COLS[i], 0.95), (ox, oy, z - h / 2), (f, f * (0.97 if i % 2 else 1.0), h), bevel=0.05, seg=3)
        z -= h * 0.92
    for k in range(7):   # 작은 돌 (층 가장자리)
        i = rnd.randrange(1, 5)
        a = rnd.uniform(0, 2 * math.pi)
        r = widths[i] / 2
        zz = -0.45 - (i - 0.5) * 0.57
        p.sphere(mat("Rock%d" % min(i + 1, 5), BASE_COLS[min(i + 1, 5)], 0.95),
                 (r * math.cos(a) * 0.98, r * math.sin(a) * 0.98, zz), 0.07, sub=1, scale=(1.4, 1.0, 0.8))
    return [p.obj("RockBase")]


# ------------------------------------------------------------------ 휴게: 소파 (1.3 × 0.45) · 원탁 (지름 1.0) · 회의 의자 — 원점 = 바닥 가운데, 앞면 = -Y (앉는 쪽)
## 두툼하게: 모서리 크게 깎음 (작은 화면에서 덩어리가 읽히게)
def build_sofa(v):
    fab = mat("SofaFabric", "#7f948f", 0.95)
    fab2 = mat("SofaCushion", "#8ea39e", 0.95)
    leg = mat("WoodDark", WOOD_DARK, 0.7)
    pil = [mat("Pillow0", "#e6dfd2", 0.95), mat("Pillow1", "#8794a3", 0.95)]
    W, D = 1.3, 0.45
    s = Parts()
    for x in (-W / 2 + 0.08, W / 2 - 0.08):
        for y in (-D / 2 + 0.06, D / 2 - 0.06):
            s.cone(leg, (x, y, 0), 0.022, 0.016, 0.07, seg=8)
    s.box(fab, (0, 0, 0.07 + 0.08), (W, D, 0.16), bevel=0.04)                           # 몸통
    s.box(fab, (0, D / 2 - 0.07, 0.42), (W, 0.14, 0.38), bevel=0.06)                     # 등받이
    for x in (-W / 2 + 0.06, W / 2 - 0.06):                                              # 팔걸이
        s.box(fab, (x, 0, 0.32), (0.12, D, 0.22), bevel=0.05)
    for x in (-0.28, 0.28):                                                              # 방석 2
        s.box(fab2, (x, -0.04, 0.26), (0.54, D - 0.14, 0.09), bevel=0.04)
    s._add(_slab(0.2, 0.2, 0.08), pil[0], Vector((-0.42, 0.08, 0.4)), (-20, 0, 12))      # 쿠션 2
    s._add(_slab(0.18, 0.18, 0.07), pil[1], Vector((0.44, 0.08, 0.39)), (-20, 0, -15))
    return [s.obj("Sofa")]


def build_round_table(v):
    wood = mat("DeskWood", WOOD, 0.6)
    dark = mat("Dark", DARK, 0.5)
    t = Parts()
    t.cone(wood, (0, 0, 0.41), 0.47, 0.5, 0.05, seg=36)          # 상판 (가장자리 살짝 경사)
    t.cyl(mat("WoodDark", WOOD_DARK, 0.7), (0, 0, 0.395), 0.44, 0.02, seg=36)
    t.cyl(dark, (0, 0, 0.03), 0.05, 0.37, seg=12)                 # 기둥
    t.cone(dark, (0, 0, 0), 0.24, 0.2, 0.035, seg=24)             # 받침
    t.cyl(mat("Vase", WHITE, 0.5), (0.12, 0.08, 0.46), 0.03, 0.08, seg=10)   # 가운데 작은 화병 + 잎
    t.sphere(mat("Leaf", LEAF, 0.8), (0.12, 0.08, 0.56), 0.045, scale=(1, 1, 1.1))
    return [t.obj("MeetingTable")]


def build_meeting_chair(v):
    wood = mat("WoodDark", WOOD_DARK, 0.7)
    seat = mat("ChairSeat", "#8794a3", 0.9)
    c = Parts()
    for x in (-0.12, 0.12):
        for y in (-0.12, 0.12):
            c.cone(wood, (x, y, 0), 0.016, 0.014, 0.22, seg=8)
    c.box(seat, (0, 0, 0.255), (0.34, 0.34, 0.07), bevel=0.03)                 # 방석
    c.box(wood, (0, 0.15, 0.46), (0.32, 0.05, 0.2), bevel=0.02)               # 등받이 (바깥쪽 = +Y)
    for x in (-0.13, 0.13):
        c.box(wood, (x, 0.15, 0.32), (0.03, 0.03, 0.12), bevel=0.006)
    return [c.obj("MeetingChair")]


BUILDERS = {"rack": build_rack, "bookshelf": build_bookshelf, "whiteboard": build_whiteboard, "telescope": build_telescope,
            "board": build_board, "personal": build_personal, "plant": build_plant, "rug": build_rug, "rock": build_rock,
            "sofa": build_sofa, "table": build_round_table, "mchair": build_meeting_chair}
FILES = {"rack": "server_rack", "bookshelf": "bookshelf", "whiteboard": "whiteboard", "telescope": "telescope",
         "board": "call_board", "personal": "desk_personal", "plant": "plant", "rug": "rug", "rock": "rock_base",
         "sofa": "sofa", "table": "meeting_table", "mchair": "meeting_chair"}
VARIANTS = {"rack": "ABC", "bookshelf": "ABC", "whiteboard": "ABC", "telescope": "AB", "board": "ABC",
            "personal": "ABC", "plant": "ABC", "rug": "ABC", "rock": "ABC",
            "sofa": "A", "table": "A", "mchair": "A"}
## 미리보기: (간격, 정사영 크기, 바라볼 높이)
VIEW = {"rack": (1.0, 1.7, 0.6), "bookshelf": (1.1, 1.7, 0.55), "whiteboard": (1.55, 1.5, 0.9), "telescope": (0.8, 1.1, 0.4),
        "board": (2.5, 1.2, -0.1), "personal": (1.6, 1.9, 0.5), "plant": (0.7, 1.0, 0.35), "rug": (2.6, 2.4, 0.1),
        "rock": (1.7, 1.2, -0.4)}


## 미리보기용 책상 (M4 desk kit: 책상 · 모니터 · 의자 — build_desk_kit.py --export)
DESK_GLBS = [os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models", "desk", f)
             for f in ("desk_a.glb", "monitor_b.glb", "chair_a.glb")]

## M4 에셋 회의 A 안 (사용자 결정): 휴게 층 · 화분 · 러그는 KayKit · Tiny Treats (build_kits.py) 로 대체 → 기본 내보내기에서 뺌 (이름을 주면 미리보기 · 비교용으로 만듦)
REPLACED = {"plant", "rug", "sofa", "table", "mchair"}


def preview(name):
    clear()
    gap, ortho, look_z = VIEW[name]
    vs = VARIANTS[name]
    for i, v in enumerate(vs):
        root = bpy.data.objects.new("V" + v, None)
        bpy.context.scene.collection.objects.link(root)
        x = (i - (len(vs) - 1) / 2) * gap
        for o in BUILDERS[name](v):
            o.parent = root
        if name == "personal":   # 진짜 책상 세트 2개 (앞줄 = 카메라 쪽에서 화면이 보임 · 뒷줄 = 180° 돌아 마주 봄)
            for k, (yy, rz) in enumerate(((0.0, 0.0), (0.6, math.pi))):
                pod = bpy.data.objects.new("Pod%d" % k, None)
                bpy.context.scene.collection.objects.link(pod)
                before = set(bpy.data.objects)
                for g in DESK_GLBS:
                    bpy.ops.import_scene.gltf(filepath=g)
                for o in set(bpy.data.objects) - before:
                    if o.parent is None:
                        o.parent = pod
                if k == 1:
                    for o in BUILDERS[name](v):
                        o.parent = pod
                pod.location = (0, yy, 0)
                pod.rotation_euler = (0, 0, rz)
                pod.parent = root
        if name == "rug":   # 나무 바닥 + 회의 탁자 (게임: 러그 반지름 = 탁자 1.1 × 0.85)
            root.scale = (0.935, 0.935, 1)
            f = Parts()
            f.box(mat("FloorWood", "#b8956f", 0.8), (0, 0, -0.01), (2.5, 2.5, 0.02), bevel=0)
            f.cyl(mat("TableTop", "#a8916f", 0.6), (0, 0, 0.42), 0.55, 0.06, seg=32)
            f.box(mat("Dark", DARK), (0, 0, 0.21), (0.12, 0.12, 0.42))
            fo = f.obj("Ctx")
            fo.location = (x, 0, 0)
        if name == "whiteboard":   # 벽 (게임 뒷벽 색 · 뒷면 y 0.05)
            c = Parts()
            c.box(mat("Wall", "#e6dccb", 0.9), (0, 0.08, 1.0), (1.5, 0.06, 2.0), bevel=0)
            c.obj("Ctx").parent = root
        if name == "board":   # 벽 + 12칸 (게임 색: 켜진 칸 · 꺼진 칸 · 덮개 칸)
            c = Parts()
            c.box(mat("Wall", "#e6dccb", 0.9), (0, 0.08, -0.4), (2.4, 0.06, 1.6), bevel=0)
            cols = ["#8fd18f", "#7fb8e0", "#4b4845", "#8fd18f", "#7a7066", "#7a7066",
                    "#4b4845", "#7fb8e0", "#7a7066", "#7a7066", "#7a7066", "#7a7066"]
            for k in range(12):
                cx = -0.9 + 0.3 * (k % 6 + 0.5)
                cz = 0.3 - 0.3 * (k // 6 + 0.5)
                m = emat("Cell" + cols[k], cols[k], 1.2) if cols[k] in ("#8fd18f", "#7fb8e0") else mat("Cell" + cols[k], cols[k], 0.6)
                c.box(m, (cx, -0.04, cz), (0.234, 0.04, 0.234), bevel=0)
            c.obj("Ctx").parent = root
        root.location = (x, 0, 0)
        if name == "rock":   # 실제 비율 (크기 10 건물 + 벽 ≈ 5.35 × 3.35)
            root.scale = (5.35 * 0.25, 3.35 * 0.25, 0.25)
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    rx, ry = 400 * len(vs), 460
    cam.data.ortho_scale = max(len(vs) * gap + 0.2, ortho * rx / ry)
    d = 10
    pitch = math.radians(55) if name != "rock" else math.radians(20)
    cam.location = (0, -d * math.cos(pitch), look_z + d * math.sin(pitch))
    cam.rotation_euler = (math.pi / 2 - pitch, 0, 0)
    vh = cam.data.ortho_scale * ry / rx   # 화면 세로 (단위)
    for i, v in enumerate(vs):   # 글자 = 카메라에 붙임 (아래 가장자리)
        txt = bpy.data.curves.new("T" + v, "FONT")
        txt.body = v
        txt.size = vh * 0.09
        txt.align_x = "CENTER"
        t = bpy.data.objects.new("T" + v, txt)
        t.data.materials.append(mat("Label", "#1f2329", 0.5))
        bpy.context.scene.collection.objects.link(t)
        t.parent = cam
        t.location = ((i - (len(vs) - 1) / 2) * gap, -vh * 0.47, -3)
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.6, 0.25, 0.4)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
    scn.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scn.render.resolution_x, scn.render.resolution_y = rx, ry
    scn.view_settings.view_transform = "Standard"
    scn.render.filepath = os.path.join(OUT, "pick_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[preview]", scn.render.filepath)


if __name__ == "__main__":
    only = [a for a in ARGS[1:] if not a.startswith("--")]
    names = only or [n for n in BUILDERS if n not in REPLACED]
    for n in names:
        if PREVIEW:
            preview(n)
        else:
            clear()
            objs = BUILDERS[n](CHOICE[n])
            export(FILES[n], objs, FILES[n].title().replace("_", ""))
            if n == "rack":   # 서버 선반 (초기 단계) 도 같이
                clear()
                export("server_shelf", BUILDERS[n]("C"), "ServerShelf")
