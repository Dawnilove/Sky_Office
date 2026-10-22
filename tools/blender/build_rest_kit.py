"""M4 4세션째: 휴게 · 작은 소품 — 탕비 카운터 (옛 build_office_props.build_pantry 대신)
(스타일 = build_desk_kit.py: 두툼한 판 · 크게 둥근 모서리 · 단순한 덩어리)

미리보기 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_rest_kit.py -- <출력 폴더> --pantry
  → pick_pantry.png (탕비 카운터 A 카페 바 · B 흰 미니 주방 · C 남색 카페 카트, 옆에 직원 키 막대)
내보내기: ... -P SkyOffice/tools/blender/build_rest_kit.py -- SkyOffice/game/assets/models --pantry-export  → pantry.glb
- 좌표 = 옛 pantry 와 같음: 0.5 (x, 깊이) × 1.4 (y, 길이), 상판 P_TOP, 앞 (직원 쪽) = +X, 뒤 = 벽
- 색 규칙: 노랑 · 금색 · 주황 금지 (노랑 = '내 차례' 전용)
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_office_props import Parts, clear, export, mat  # noqa: E402
import build_desk_kit as K  # noqa: E402
from build_counter_kit import render, place, _label, emit, LEATHER, LEATHER_D, SKY, PAPER  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGV[0]) if ARGV else "."

P_W, P_L, P_TOP = 0.5, 1.4, 0.55
STONE, STEEL, DARK = "#d5d2cc", "#8b9097", "#3b3d42"
CUPS = ["#f1efe9", "#8fa79a", "#7f93ad", "#d9a7ae"]
PANTRY = "A"   # 사용자 고름 (2026-10-16): A 카페 바


def M(n, c, r=0.7, metal=0.0):
    return mat(n, c, r, metal)


def mug(p, m, x, y, z, r=0.032, h=0.065, handle=True):
    p.cyl(m, (x, y, z), r, h, seg=12)
    if handle:
        p.box(m, (x, y + r + 0.008, z + h * 0.5), (0.012, 0.018, h * 0.55), bevel=0.005)


def coffee_machine(p, body, x, y, z, light=None):
    steel = M("Steel", STEEL, 0.35, 0.7)
    p.box(body, (x - 0.04, y, z + 0.16), (0.2, 0.24, 0.32), bevel=0.035, seg=3)
    p.box(steel, (x + 0.06, y, z + 0.27), (0.1, 0.22, 0.06), bevel=0.015)                  # 앞 머리
    p.cyl(steel, (x + 0.08, y, z + 0.2), 0.022, 0.05)                                     # 추출구
    p.box(steel, (x + 0.07, y, z + 0.012), (0.12, 0.18, 0.024), bevel=0.006)              # 받침
    mug(p, M("Cup0", CUPS[0], 0.4), x + 0.08, y, z + 0.024, handle=False)
    if light:
        p.box(light, (x + 0.061, y + 0.07, z + 0.27), (0.004, 0.035, 0.02), bevel=0)


def plant(p, x, y, z, s=1.0):
    leaf, pot = M("Leaf", "#6f9a6a", 0.9), M("Pot", "#e6dfd2", 0.8)
    p.cyl(pot, (x, y, z), 0.06 * s, 0.1 * s, seg=12)
    p.sphere(leaf, (x, y, z + 0.17 * s), 0.09 * s, scale=(1, 1, 1.25))
    p.sphere(leaf, (x + 0.03 * s, y + 0.05 * s, z + 0.13 * s), 0.06 * s)


# ------------------------------------------------------------------ 탕비 카운터 A · B · C
def pantry(v, p):
    wood, wtop, wd = M("KWood", K.WOOD), M("KWoodTop", K.WOOD_TOP, 0.6), M("KWoodD", K.WOOD_D, 0.75)
    stone, steel, dark = M("Stone", STONE, 0.5), M("Steel", STEEL, 0.35, 0.7), M("Dark", DARK, 0.5)
    sky = emit("SkyLight", SKY, 0.9)
    T = P_TOP
    if v == "A":   # 카페 바: 나무 세로 판 몸통 + 돌 상판 + 뒤 선반 (머그 걸이)
        p.box(wd, (0, 0, 0.03), (P_W - 0.06, P_L - 0.06, 0.06), bevel=0.01)
        p.box(wood, (0, 0, (T - 0.04) / 2 + 0.03), (P_W, P_L, T - 0.1), bevel=0.03, seg=3)
        for k in range(9):                                                                 # 앞 세로 판
            y = -P_L / 2 + 0.1 + k * (P_L - 0.2) / 8
            p.box(wd, (P_W / 2 + 0.004, y, 0.29), (0.012, 0.02, T - 0.16), bevel=0.004)
        p.box(stone, (0.01, 0, T - 0.02), (P_W + 0.06, P_L + 0.06, 0.05), bevel=0.02, seg=3)
        for y in (-P_L / 2 + 0.06, P_L / 2 - 0.06):                                        # 뒤 선반 기둥
            p.box(wd, (-P_W / 2 + 0.05, y, T + 0.3), (0.04, 0.04, 0.6), bevel=0.01)
        p.box(wtop, (-P_W / 2 + 0.09, 0, T + 0.5), (0.14, P_L - 0.04, 0.04), bevel=0.015)  # 선반
        p.box(wtop, (-P_W / 2 + 0.09, 0, T + 0.22), (0.12, P_L - 0.04, 0.03), bevel=0.012)
        for k in range(5):                                                                  # 선반 위 머그 · 병
            mug(p, M("Cup%d" % (k % 4), CUPS[k % 4], 0.4), -P_W / 2 + 0.09, -0.5 + k * 0.17, T + 0.52)
        for k in range(3):                                                                  # 아래 선반 유리병 (원두)
            p.cyl(M("Jar", "#cfd9dc", 0.15), (-P_W / 2 + 0.09, 0.25 + k * 0.14, T + 0.235), 0.04, 0.1)
            p.cyl(wd, (-P_W / 2 + 0.09, 0.25 + k * 0.14, T + 0.335), 0.042, 0.02)
        coffee_machine(p, M("MachNavy", LEATHER, 0.5), 0.0, -0.42, T, sky)
        for k in range(3):                                                                  # 쌓은 컵
            mug(p, M("Cup%d" % k, CUPS[k], 0.4), 0.1, -0.08, T + k * 0.05, 0.034, 0.05, handle=False)
        p.cyl(M("Jar", "#cfd9dc", 0.15), (0.05, 0.18, T), 0.06, 0.12, seg=14)              # 과자 병
        p.cyl(wd, (0.05, 0.18, T + 0.12), 0.064, 0.025, seg=14)
        for k in range(3):
            p.cyl(M("Cookie", "#b89a80", 0.8), (0.05, 0.18, T + 0.01 + k * 0.03), 0.04, 0.02)
        plant(p, 0.02, P_L / 2 - 0.16, T)
    elif v == "B":   # 흰 미니 주방: 흰 문 + 나무 상판 · 작은 냉장고 · 개수대 · 위 열린 장
        white, line = M("Cabinet", "#ece9e3", 0.55), M("CabLine", "#cfcac2", 0.7)
        cream = M("Fridge", "#dfe6e4", 0.45)
        p.box(wd, (0, 0, 0.03), (P_W - 0.06, P_L - 0.06, 0.06), bevel=0.01)
        p.box(white, (0, 0.17, (T - 0.04) / 2 + 0.03), (P_W, P_L - 0.36, T - 0.1), bevel=0.03, seg=3)
        p.box(cream, (0, -P_L / 2 + 0.17, (T - 0.04) / 2 + 0.03), (P_W, 0.33, T - 0.1), bevel=0.04, seg=3)   # 냉장고
        p.box(steel, (P_W / 2 + 0.01, -P_L / 2 + 0.29, 0.3), (0.016, 0.02, 0.2), bevel=0.006)
        for k in range(3):                                                                  # 문 3 + 손잡이
            y = -0.15 + k * 0.32
            p.box(line, (P_W / 2 + 0.003, y + 0.16, 0.29), (0.01, 0.008, T - 0.16), bevel=0)
            p.box(steel, (P_W / 2 + 0.012, y + 0.11, 0.42), (0.014, 0.016, 0.1), bevel=0.004)
        p.box(wtop, (0.01, 0, T - 0.02), (P_W + 0.06, P_L + 0.06, 0.05), bevel=0.02, seg=3)
        p.box(steel, (0.02, 0.3, T + 0.002), (0.26, 0.3, 0.012), bevel=0.01)               # 개수대 + 수도
        p.cyl(steel, (-0.17, 0.3, T), 0.015, 0.16)
        p.box(steel, (-0.12, 0.3, T + 0.16), (0.12, 0.024, 0.024), bevel=0.008)
        # 위 열린 장 (벽에 붙음)
        p.box(white, (-P_W / 2 + 0.1, 0, T + 0.62), (0.2, P_L - 0.1, 0.26), bevel=0.03, seg=3)
        p.box(M("CabIn", "#d8d3cb", 0.7), (-P_W / 2 + 0.13, 0, T + 0.62), (0.16, P_L - 0.22, 0.2), bevel=0.01)
        for k in range(4):
            mug(p, M("Cup%d" % k, CUPS[k], 0.4), -P_W / 2 + 0.15, -0.45 + k * 0.3, T + 0.525)
        # 상판 위: 주전자 · 머그 나무 · 사과
        p.cyl(steel, (0.0, -0.25, T), 0.06, 0.13, seg=14)
        p.cone(steel, (0.0, -0.25, T + 0.13), 0.06, 0.02, 0.04, seg=14)
        p.box(dark, (-0.07, -0.25, T + 0.09), (0.03, 0.02, 0.08), bevel=0.005)
        p.cyl(wd, (0.05, -0.02, T), 0.012, 0.22)
        for k in range(3):
            a = math.radians(k * 120 + 30)
            mug(p, M("Cup%d" % (k + 1), CUPS[k + 1], 0.4), 0.05 + 0.05 * math.cos(a), -0.02 + 0.05 * math.sin(a), T + 0.06 + k * 0.04, 0.026, 0.05, handle=False)
        p.cyl(M("Bowl", "#c9c4bc", 0.6), (0.06, P_L / 2 - 0.16, T), 0.09, 0.04, seg=14)
        for k in range(3):
            a = math.radians(k * 120)
            p.sphere(M("Apple", "#86a35f", 0.6), (0.06 + 0.04 * math.cos(a), P_L / 2 - 0.16 + 0.04 * math.sin(a), T + 0.06), 0.035)
        coffee_machine(p, white, -0.02, -0.5, T + 0.0, sky)
    else:   # 남색 카페 카트: 둥근 끝 · 흰 상판 · 하늘빛 띠 + 줄무늬 차양 · 빵 유리 덮개 · 메뉴판
        navy, white = M("Navy", LEATHER, 0.55), M("TopWhite", "#efece6", 0.45)
        hw = P_L / 2 - P_W / 2
        p.box(navy, (0, 0, 0.3), (P_W - 0.02, 2 * hw, 0.5), bevel=0.02)
        for s in (-1, 1):
            p.cyl(navy, (0, s * hw, 0.05), P_W / 2 - 0.01, 0.5, seg=24)
            p.cyl(white, (0.01, s * hw, T - 0.045), P_W / 2 + 0.03, 0.05, seg=24)
        p.box(white, (0.01, 0, T - 0.02), (P_W + 0.06, 2 * hw, 0.05), bevel=0.0)
        p.box(sky, (P_W / 2 - 0.005, 0, T - 0.09), (0.01, P_L - 0.3, 0.025), bevel=0)         # 하늘빛 띠
        p.box(dark, (0, 0, 0.025), (P_W - 0.06, P_L - 0.1, 0.05), bevel=0.02)                 # 받침
        for s in (-1, 1):                                                                   # 바퀴
            p.cyl(dark, (P_W / 2 - 0.06, s * (hw + 0.1), 0.0), 0.05, 0.04, seg=12, rot=(90, 0, 0))
        for y in (-P_L / 2 + 0.12, P_L / 2 - 0.12):                                          # 차양 기둥 + 줄무늬 지붕
            p.cyl(steel, (-P_W / 2 + 0.04, y, T), 0.014, 0.66)
        for k in range(7):
            col = M("AwnNavy", LEATHER_D, 0.7) if k % 2 == 0 else M("AwnWhite", "#f3f1ec", 0.7)
            K.tbox(p, col, (-0.02, -P_L / 2 + 0.1 + k * (P_L - 0.2) / 6, T + 0.68), (0.5, (P_L - 0.2) / 6 + 0.002, 0.03), rot=(0, 14, 0), bevel=0.006)
        coffee_machine(p, M("MachSilver", "#c3c8ce", 0.3, 0.4), -0.02, -0.4, T, sky)
        p.cyl(wd, (0.04, 0.2, T), 0.12, 0.02, seg=20)                                       # 빵 유리 덮개
        for k, c in enumerate(("#efe3cf", "#d9a7ae", "#b89a80")):
            a = math.radians(k * 120)
            p.sphere(M("Bun%d" % k, c, 0.7), (0.04 + 0.05 * math.cos(a), 0.2 + 0.05 * math.sin(a), T + 0.05), 0.04, scale=(1, 1, 0.7))
        p.sphere(M("Glass", "#dce8ec", 0.05), (0.04, 0.2, T + 0.02), 0.11, scale=(1, 1, 0.95))
        K.tbox(p, M("Chalk", "#2f3a36", 0.8), (0.12, 0.48, T + 0.13), (0.02, 0.18, 0.22), rot=(0, -12, 0), bevel=0.01)   # 메뉴판
        K.tbox(p, M("ChalkLine", "#e9ecef", 0.8), (0.133, 0.48, T + 0.16), (0.004, 0.12, 0.012), rot=(0, -12, 0), bevel=0)
        K.tbox(p, M("ChalkLine", "#e9ecef", 0.8), (0.137, 0.48, T + 0.12), (0.004, 0.09, 0.01), rot=(0, -12, 0), bevel=0)
        for k in range(3):
            mug(p, M("Cup%d" % k, CUPS[k], 0.4), 0.12, -0.12, T + k * 0.05, 0.034, 0.05, handle=False)


def staff_bar(x, y):
    """직원 키 (≈ 1.0) 비교 막대"""
    p = Parts()
    p.box(M("Ref", "#9aa6b2", 0.8), (0, 0, 0.5), (0.12, 0.12, 1.0), bevel=0.04)
    place([p.obj("StaffRef")], x, y)


def pantry_preview():
    clear()
    for i, v in enumerate("ABC"):
        c = Parts()
        pantry(v, c)
        place([c.obj("Pantry" + v)], (i - 1) * 1.9, 0.4, math.radians(-90))   # 앞 (+X) 이 카메라를 봄
        _label(i, "탕비 " + v, (i - 1) * 1.9, -0.45)
    staff_bar(2.85, 0.4)
    render("pick_pantry", 6.4, look=(0.1, 0.3, 0.5), res=(1700, 900))


def pantry_export():
    clear()
    p = Parts()
    pantry(PANTRY, p)
    export("pantry", [p.obj("Pantry")], "PantrySet")   # 메시 이름 Pantry = 시나리오가 찾음


# ================================================================== 작은 소품 6 (직원이 손에 듦 · 책상에 놓임) — 원점 = 바닥 가운데, 단위 = 칸 (직원 키 ≈ 1.0)
## 미리보기: ... -- <폴더> --props → pick_props.png (위 줄 A · 아래 줄 B, 4배 크게 + 오른쪽 실제 크기)
## 내보내기: ... -- SkyOffice/game/assets/models/props --props-export
PROPS = {"cup": "B", "papers": "B", "envelope": "A", "box": "B", "bag": "A", "noodle": "A"}   # 사용자 고름 (2026-10-16)
KRAFT, CARD, CARD_D = "#c8b49a", "#c9ab8c", "#a98d72"


def prop(kind, v, p):
    white, navy, sky = M("PWhite", "#f3f1ec", 0.5), M("PNavy", LEATHER, 0.55), M("PSky", SKY, 0.5)
    paper = M("Paper", PAPER, 0.9)
    lid = M("Lid", "#e1ddd6", 0.5)
    if kind == "cup":
        if v == "A":   # 머그: 흰 몸 + 하늘 띠 + 손잡이
            p.cyl(white, (0, 0, 0), 0.03, 0.07, seg=16)
            p.cyl(sky, (0, 0, 0.022), 0.0305, 0.018, seg=16)
            p.cyl(M("Coffee", "#6b5444", 0.4), (0, 0, 0.064), 0.026, 0.004, seg=16)
            K.tbox(p, white, (0.036, 0, 0.036), (0.014, 0.012, 0.04), bevel=0.005)
        else:          # 테이크아웃 컵: 흰 컵 + 남색 슬리브 + 뚜껑
            p.cone(white, (0, 0, 0), 0.024, 0.032, 0.085, seg=16)
            p.cone(navy, (0, 0, 0.025), 0.0275, 0.0305, 0.032, seg=16)
            p.cyl(lid, (0, 0, 0.085), 0.034, 0.012, seg=16)
            p.cyl(lid, (0, 0, 0.097), 0.026, 0.008, seg=16)
    elif kind == "papers":
        if v == "A":   # 클립보드 + 종이
            p.box(M("Board", K.WOOD, 0.7), (0, 0, 0.006), (0.16, 0.22, 0.012), bevel=0.006)
            p.box(paper, (0, -0.008, 0.014), (0.14, 0.18, 0.004), bevel=0.001)
            p.box(M("Clip", "#9aa1a8", 0.35, 0.6), (0, 0.095, 0.02), (0.06, 0.025, 0.012), bevel=0.004)
            for k in range(4):
                p.box(M("Ink", "#9aa6b2", 0.8), (-0.01, 0.04 - k * 0.03, 0.0165), (0.09 - (k % 2) * 0.03, 0.006, 0.001), bevel=0)
        else:          # 하늘색 파일 폴더 + 삐져나온 종이
            p.box(sky, (0, 0, 0.004), (0.16, 0.21, 0.008), bevel=0.003)
            for k in range(3):
                K.tbox(p, paper, (0.004 * k, 0.006 * k, 0.012 + k * 0.01), (0.15, 0.2, 0.006), rot=(0, 0, (k - 1) * 4), bevel=0.002)
            p.box(sky, (0, 0, 0.046), (0.16, 0.21, 0.006), bevel=0.003)
            p.box(sky, (-0.03, 0.1, 0.05), (0.06, 0.02, 0.006), bevel=0.002)
    elif kind == "envelope":
        if v == "A":   # 흰 봉투 + 하늘색 봉인 스티커
            p.box(white, (0, 0, 0.005), (0.2, 0.13, 0.01), bevel=0.003)
            K.tbox(p, M("Flap", "#e6e2da", 0.6), (0, 0.025, 0.0105), (0.2, 0.08, 0.002), bevel=0.001)
            p.cyl(sky, (0, -0.012, 0.0105), 0.018, 0.003, seg=16)
        else:          # 크라프트 서류 봉투 + 단추 끈
            p.box(M("Kraft", KRAFT, 0.8), (0, 0, 0.006), (0.16, 0.22, 0.012), bevel=0.003)
            p.box(M("KraftD", "#b8a288", 0.8), (0, 0.07, 0.0125), (0.16, 0.07, 0.002), bevel=0.001)
            for y in (0.04, 0.0):
                p.cyl(M("Btn", "#8a7360", 0.6), (0, y, 0.012), 0.012, 0.004, seg=12)
            p.box(M("Str", "#f3f1ec", 0.8), (0, 0.02, 0.0135), (0.004, 0.05, 0.002), bevel=0)
    elif kind == "box":
        card, card_d = M("Card", CARD, 0.85), M("CardD", CARD_D, 0.85)
        if v == "A":   # 열린 골판지 상자: 뚜껑 날개 + 화분 · 액자 · 머그
            p.box(card, (0, 0, 0.09), (0.3, 0.22, 0.18), bevel=0.01)
            p.box(M("CardIn", "#8f7660", 0.9), (0, 0, 0.175), (0.27, 0.19, 0.012), bevel=0)
            for sx in (-1, 1):
                K.tbox(p, card_d, (sx * 0.17, 0, 0.21), (0.012, 0.21, 0.09), rot=(0, sx * 35, 0), bevel=0.004)
            plant(p, -0.07, 0.03, 0.15, 0.7)
            K.tbox(p, M("Frame", "#7a5a46", 0.7), (0.06, 0.04, 0.22), (0.1, 0.012, 0.09), rot=(-10, 0, 0), bevel=0.005)
            mug(p, M("Cup2", CUPS[2], 0.4), 0.08, -0.05, 0.17)
        else:          # 닫힌 상자 + 테이프 + 손잡이 구멍 + 이름표
            p.box(card, (0, 0, 0.09), (0.3, 0.22, 0.18), bevel=0.012)
            p.box(M("Tape", "#e6e2da", 0.5), (0, 0, 0.18), (0.31, 0.05, 0.004), bevel=0)
            for sx in (-1, 1):
                p.box(card_d, (sx * 0.151, 0, 0.13), (0.004, 0.08, 0.025), bevel=0.006)
            p.box(M("Tag", PAPER, 0.8), (0, -0.111, 0.08), (0.1, 0.002, 0.06), bevel=0)
    elif kind == "bag":
        dk = M("PNavyD", LEATHER_D, 0.6)
        if v == "A":   # 남색 백팩
            p.box(navy, (0, 0, 0.12), (0.2, 0.1, 0.24), bevel=0.045, seg=3)
            p.box(dk, (0, -0.055, 0.08), (0.15, 0.04, 0.1), bevel=0.02, seg=2)
            p.box(sky, (0, -0.076, 0.11), (0.1, 0.004, 0.008), bevel=0)
            K.tbox(p, dk, (0, 0.0, 0.25), (0.06, 0.02, 0.03), rot=(0, 90, 0), bevel=0.008)
        else:          # 갈색 서류 가방
            br, brd = M("Leather", "#7a5a46", 0.55), M("LeatherD", "#5e4636", 0.6)
            p.box(br, (0, 0, 0.1), (0.26, 0.08, 0.18), bevel=0.02, seg=3)
            p.box(brd, (0, -0.041, 0.15), (0.26, 0.004, 0.06), bevel=0.002)
            for x in (-0.06, 0.06):
                p.box(M("Clasp", "#9aa1a8", 0.35, 0.6), (x, -0.044, 0.13), (0.02, 0.006, 0.02), bevel=0.003)
            K.tbox(p, brd, (0, 0, 0.205), (0.1, 0.02, 0.04), bevel=0.01)
    elif kind == "noodle":
        soup = M("Soup", "#c9b39a", 0.6)
        if v == "A":   # 흰 컵라면 + 하늘 띠 + 뚜껑 반쯤 + 젓가락
            p.cone(white, (0, 0, 0), 0.036, 0.05, 0.1, seg=18)
            p.cone(sky, (0, 0, 0.04), 0.043, 0.047, 0.03, seg=18)
            p.cyl(soup, (0, 0, 0.096), 0.046, 0.004, seg=18)
            K.tbox(p, lid, (-0.045, 0, 0.12), (0.003, 0.09, 0.05), rot=(0, -20, 0), bevel=0.001)
            for y in (-0.008, 0.008):
                K.tbox(p, M("Stick", "#a98468", 0.6), (0.02, y, 0.13), (0.006, 0.006, 0.16), rot=(0, 25, 0), bevel=0.002)
        else:          # 넓은 그릇형 + 남색 띠
            p.cone(white, (0, 0, 0), 0.04, 0.065, 0.07, seg=18)
            p.cone(navy, (0, 0, 0.03), 0.054, 0.061, 0.022, seg=18)
            p.cyl(soup, (0, 0, 0.066), 0.06, 0.004, seg=18)
            K.tbox(p, lid, (0.0, 0.07, 0.1), (0.12, 0.004, 0.06), rot=(-20, 0, 0), bevel=0.001)
        for k in range(3):   # 김 (게임에선 코드로 움직임)
            p.sphere(M("Steam", "#ffffff", 0.9), (0.01 * (k - 1), 0, 0.15 + k * 0.035), 0.016 - k * 0.003)


PROP_NAMES = [("cup", "컵"), ("papers", "서류"), ("envelope", "봉투"), ("box", "짐 상자"), ("bag", "가방"), ("noodle", "컵라면")]


def props_preview():
    clear()
    G, S = 1.15, 4.0
    for i, (kind, ko) in enumerate(PROP_NAMES):
        x = (i - 2.5) * G
        for j, v in enumerate("AB"):
            p = Parts()
            prop(kind, v, p)
            r = place([p.obj("%s%s" % (kind, v))], x, 0.75 - j * 1.35)
            r.scale = (S, S, S)
            _label(10 * i + j, "%s %s" % (ko, v), x, 0.75 - j * 1.35 - 0.62, 0.13)
    staff_bar(3.75, -0.3)
    for j, v in enumerate("AB"):   # 실제 크기 (직원 옆)
        for i, (kind, _) in enumerate(PROP_NAMES[:3]):
            p = Parts()
            prop(kind, v, p)
            place([p.obj("r%s%s" % (kind, v))], 3.95 + j * 0.25, -0.5 + i * 0.25)
    render("pick_props", 8.4, look=(0.3, -0.1, 0.2), res=(1800, 1000))


def props_export():
    for kind, _ in PROP_NAMES:
        clear()
        p = Parts()
        prop(kind, PROPS[kind], p)
        root = kind.capitalize()
        export(kind, [p.obj(root)], root + "Prop")


if __name__ == "__main__" and "--props-export" in ARGV:
    props_export()
elif __name__ == "__main__" and "--props" in ARGV:
    props_preview()
elif __name__ == "__main__" and "--pantry-export" in ARGV:
    pantry_export()
elif __name__ == "__main__" and "--pantry" in ARGV:
    pantry_preview()
