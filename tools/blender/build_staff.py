"""하늘 오피스 직원 (M2 분위기 조각) → staff.glb  (오버랜드 파일에 기대지 않는 단독 스크립트)

실행 (OverLand 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_staff.py -- SkyOffice/game/assets/models [미리보기.png]

- 귀여운 2등신 직원: 큰 머리 · 큰 눈 + 반짝이 · 볼터치 · 짧은 팔다리 (의자에 앉으면 발이 살짝 뜸)
- 매끈한 도형을 뼈마다 붙이는 방식 (책상 · 탕비와 같은 깔끔한 느낌)
- 동작: Idle · Walk · Sit (타자) · Stretch (기지개) · LookUp · SitScratch / Scratch (실패: 머리 긁기, M4) · SitTypeFast · SitFlip · SitWatch (도구별, M4 5세션) · ThumbsUp · SitStop · Clap · HoldBox · WalkBox (M5 2세션)
- 인턴 조끼 = 따로 된 메시 'Vest' (같은 뼈대에 붙음) — 게임이 인턴일 때만 보이게 함 (M4)
- 셔츠 · 머리 색은 게임에서 직원마다 바꿈 → 재질 이름 'Shirt' · 'Hair' 를 바꾸지 말 것
- 크기 단위 = m (게임에서 그대로). 좌표: Blender -Y 가 앞 → Godot +Z 가 앞
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "assets_out")
os.makedirs(OUT, exist_ok=True)

COL = {
    "skin": "#f2d0b6", "shirt": "#7d8fa6", "collar": "#f1efea", "pants": "#4b505a",
    "shoes": "#3a3532", "hair": "#3e322c", "eye": "#1f1b1b", "shine": "#ffffff",
    "blush": "#eab0a8", "mouth": "#9a5a52",
    "vest": "#8d8f91", "vest_dark": "#5d5f62",
}

## 뼈대 (이름 · 시작 · 끝 · 부모). 위로 선 뼈 (root · body · head) 는 rot X + = 앞으로 숙임,
## 아래로 선 뼈 (팔 · 다리) 는 rot X + = 뒤로 젖힘. 위치 이동 (loc) 의 y = 뼈 방향
HIP = 0.30
HEAD_DROP = 0.03
BONES = [("root", (0, 0, 0), (0, 0, 0.1), None),
         ("body", (0, 0.01, HIP), (0, 0.01, 0.62), "root"),
         ("head", (0, 0.0, 0.62), (0, 0.0, 0.98), "body"),
         ("arm_L", (0.125, 0.0, 0.56), (0.155, 0.0, 0.465), "body"),
         ("fore_L", (0.155, 0.0, 0.465), (0.16, -0.015, 0.375), "arm_L"),
         ("arm_R", (-0.125, 0.0, 0.56), (-0.155, 0.0, 0.465), "body"),
         ("fore_R", (-0.155, 0.0, 0.465), (-0.16, -0.015, 0.375), "arm_R"),
         ("thigh_L", (0.06, 0.01, HIP), (0.06, 0.01, 0.17), "root"),
         ("shin_L", (0.06, 0.01, 0.17), (0.06, 0.0, 0.04), "thigh_L"),
         ("thigh_R", (-0.06, 0.01, HIP), (-0.06, 0.01, 0.17), "root"),
         ("shin_R", (-0.06, 0.01, 0.17), (-0.06, 0.0, 0.04), "thigh_R")]


# ------------------------------------------------------------------ 재질 · 도형
def lin(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


_MATS = {}


def mat(name, hexcol, rough=0.75):
    if name not in _MATS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*lin(hexcol), 1)
        bsdf.inputs["Roughness"].default_value = rough
        _MATS[name] = m
    return _MATS[name]


class Body:
    """뼈마다 매끈한 도형을 붙여 한 메시로 (정점 가중치 = 그 뼈 100%)"""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []
        self.bone_of = []      # 정점 순서대로 뼈 이름
        self._tmp = bpy.data.meshes.new("_tmp")

    def _add(self, tb, m, bone):
        if m not in self.mats:
            self.mats.append(m)
        for f in tb.faces:
            f.material_index = self.mats.index(m)
            f.smooth = True
        tb.to_mesh(self._tmp)
        tb.free()
        self.bm.from_mesh(self._tmp)
        self.bone_of += [bone] * (len(self.bm.verts) - len(self.bone_of))

    def ell(self, m, bone, c, r, seg=(20, 12)):
        if bone == "head":   # 머리 부품 전체를 목 쪽으로 내림 (몸과 붙어 보이게)
            c = (c[0], c[1], c[2] - HEAD_DROP)
        tb = bmesh.new()
        bmesh.ops.create_uvsphere(tb, u_segments=seg[0], v_segments=seg[1], radius=1.0)
        bmesh.ops.transform(tb, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*r, 1)), verts=tb.verts)
        self._add(tb, m, bone)

    def cap(self, m, bone, p0, p1, r, seg=(16, 10)):
        """캡슐 (양 끝 둥근 원기둥) — 관절이 벌어져 보이지 않게"""
        p0, p1 = Vector(p0), Vector(p1)
        ln = (p1 - p0).length
        tb = bmesh.new()
        bmesh.ops.create_uvsphere(tb, u_segments=seg[0], v_segments=seg[1], radius=r)
        for v in tb.verts:
            v.co.z += ln / 2 if v.co.z > 1e-6 else (-ln / 2 if v.co.z < -1e-6 else 0)
        rot = Vector((0, 0, 1)).rotation_difference((p1 - p0).normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(tb, matrix=Matrix.Translation((p0 + p1) / 2) @ rot, verts=tb.verts)
        self._add(tb, m, bone)

    def obj(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        bpy.data.meshes.remove(self._tmp)
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        groups = {}
        for i, bn in enumerate(self.bone_of):
            if bn not in groups:
                groups[bn] = o.vertex_groups.new(name=bn)
            groups[bn].add([i], 1.0, "REPLACE")
        return o


# ------------------------------------------------------------------ 직원 몸
def build_body():
    M = {k: mat(k.capitalize() if k not in ("eye", "shine") else {"eye": "EyeBlack", "shine": "EyeShine"}[k], v, 0.3 if k in ("eye", "shine") else 0.75)
         for k, v in COL.items()}
    b = Body()
    # 머리: 큰 얼굴 + 머리카락 (뒤 · 위를 덮고 얼굴은 비움) + 앞머리 · 옆머리
    b.ell(M["skin"], "head", (0, 0, 0.8), (0.165, 0.155, 0.155), seg=(28, 18))
    b.ell(M["hair"], "head", (0, 0.03, 0.845), (0.176, 0.165, 0.15), seg=(28, 18))
    for x, z, rx in ((-0.07, 0.9, 0.09), (0.045, 0.905, 0.1), (0.11, 0.88, 0.06)):
        b.ell(M["hair"], "head", (x, -0.115, z), (rx, 0.05, 0.045))
    for s in (1, -1):
        b.ell(M["hair"], "head", (0.148 * s, 0.01, 0.8), (0.026, 0.07, 0.06))
        # 큰 눈 (세로로 긴 타원) + 반짝이 2개 + 볼터치
        b.ell(M["eye"], "head", (0.058 * s, -0.142, 0.79), (0.024, 0.014, 0.034))
        b.ell(M["shine"], "head", (0.052 * s, -0.154, 0.803), (0.009, 0.004, 0.01), seg=(10, 6))
        b.ell(M["shine"], "head", (0.065 * s, -0.153, 0.775), (0.005, 0.003, 0.005), seg=(8, 6))
        b.ell(M["blush"], "head", (0.1 * s, -0.122, 0.752), (0.028, 0.012, 0.016), seg=(12, 8))
    b.ell(M["mouth"], "head", (0, -0.152, 0.742), (0.014, 0.006, 0.006), seg=(10, 6))
    # 몸통: 둥근 셔츠 + 흰 깃 + 바지
    b.ell(M["shirt"], "body", (0, 0.01, 0.47), (0.13, 0.11, 0.15))
    b.ell(M["collar"], "body", (0, 0.005, 0.605), (0.085, 0.075, 0.03))
    b.ell(M["collar"], "body", (0, -0.085, 0.57), (0.025, 0.02, 0.04))      # 깃 앞
    b.ell(M["pants"], "root", (0, 0.01, 0.33), (0.122, 0.102, 0.085))
    for s, side in ((1, "L"), (-1, "R")):
        x = 0.06 * s
        b.cap(M["pants"], "thigh_" + side, (x, 0.01, HIP), (x, 0.01, 0.17), 0.048)
        b.cap(M["pants"], "shin_" + side, (x, 0.01, 0.17), (x, 0.0, 0.07), 0.042)
        b.ell(M["shoes"], "shin_" + side, (x, -0.02, 0.04), (0.048, 0.07, 0.038))
        b.cap(M["shirt"], "arm_" + side, (0.125 * s, 0.0, 0.56), (0.155 * s, 0.0, 0.465), 0.04)
        b.cap(M["shirt"], "fore_" + side, (0.155 * s, 0.0, 0.465), (0.16 * s, -0.015, 0.39), 0.036)
        b.ell(M["collar"], "fore_" + side, (0.16 * s, -0.015, 0.395), (0.04, 0.04, 0.014))   # 소맷부리
        b.ell(M["skin"], "fore_" + side, (0.16 * s, -0.018, 0.36), (0.038, 0.036, 0.04))
    return b.obj("Staff")


def build_vest(badge=False):
    """인턴 조끼: 셔츠 몸통보다 살짝 큰 회색 몸통 + 앞 V 자 (흰 셔츠가 보임) + 단추 2개 [+ 사원증 목걸이]"""
    vest = mat("Vest", COL["vest"])
    dark = mat("VestDark", COL["vest_dark"])
    shirt_v = mat("Collar", COL["collar"])
    b = Body()
    b.ell(vest, "body", (0, 0.01, 0.468), (0.138, 0.118, 0.128))
    b.ell(shirt_v, "body", (0, -0.104, 0.53), (0.03, 0.012, 0.06))     # 앞 V 자 사이로 보이는 셔츠
    for z in (0.47, 0.425):
        b.ell(dark, "body", (0, -0.117, z), (0.011, 0.006, 0.011), seg=(10, 6))
    if badge:
        b.cap(dark, "body", (-0.06, -0.09, 0.6), (0.0, -0.122, 0.46), 0.006, seg=(8, 6))
        b.cap(dark, "body", (0.06, -0.09, 0.6), (0.0, -0.122, 0.46), 0.006, seg=(8, 6))
        b.ell(shirt_v, "body", (0, -0.125, 0.43), (0.03, 0.006, 0.038), seg=(12, 8))
    return b.obj("Vest")


def build_thumb():
    """엄지척 엄지 (⑨, M4 5세션째): 오른손 공에 붙은 작은 캡슐 — 평소 숨김, ThumbsUp 때만 게임이 보임.
    쉬는 자세에서 앞 (조금 아래) 으로 두면 팔을 앞으로 올린 ThumbsUp (−110°) 에서 위를 가리킴"""
    skin = mat("Skin", COL["skin"])
    b = Body()
    c = Vector((-0.16, -0.03, 0.35))
    b.cap(skin, "fore_R", c, c + Vector((0, -0.94, -0.34)) * 0.05, 0.015, seg=(10, 8))
    return b.obj("Thumb")


def build_outfit(kind):
    """복장 덧입기 (M4 사용자: 직원 복장 3가지 · 출근마다 무작위 · '더 또렷하게 · 다른 색도')
    주 색 = 'Shirt' (직원 구분 색), 포인트 = 'Accent' (게임이 출근마다 무작위 색). 'Shirt' = 넥타이만 / 'Hoodie' / 'Knit'"""
    shirt = mat("Shirt", COL["shirt"])
    acc = mat("Accent", "#e07a5f")
    white = mat("Collar", COL["collar"])
    b = Body()
    if kind == "Shirt":   # 셔츠 + 포인트 색 넥타이
        b.ell(acc, "body", (0, -0.112, 0.525), (0.022, 0.012, 0.07))
        b.ell(acc, "body", (0, -0.11, 0.585), (0.017, 0.011, 0.014), seg=(10, 6))
        return b.obj("OutfitShirt")
    b.ell(shirt, "body", (0, 0.01, 0.466), (0.138, 0.118, 0.148))
    for s, side in ((1, "L"), (-1, "R")):
        b.cap(shirt, "arm_" + side, (0.125 * s, 0.0, 0.56), (0.155 * s, 0.0, 0.465), 0.045)
        b.cap(shirt, "fore_" + side, (0.155 * s, 0.0, 0.465), (0.16 * s, -0.015, 0.4), 0.041)
    if kind == "Hoodie":   # 큰 모자 (어깨 뒤 · 옆으로 보임) + 포인트 색 캥거루 주머니 · 끈
        b.ell(shirt, "body", (0, 0.07, 0.6), (0.135, 0.085, 0.07))
        b.ell(acc, "body", (0, 0.04, 0.612), (0.105, 0.09, 0.036))                  # 모자 안감 (목둘레)
        b.ell(acc, "body", (0, -0.112, 0.41), (0.085, 0.022, 0.045))               # 캥거루 주머니
        for s in (1, -1):
            b.cap(white, "body", (0.03 * s, -0.112, 0.59), (0.036 * s, -0.128, 0.505), 0.008, seg=(8, 6))
            b.ell(white, "body", (0.036 * s, -0.129, 0.5), (0.012, 0.009, 0.014), seg=(8, 6))
        for s, side in ((1, "L"), (-1, "R")):
            b.ell(acc, "fore_" + side, (0.16 * s, -0.015, 0.397), (0.045, 0.045, 0.018))
    else:   # Knit: 굵은 포인트 색 줄무늬 2 + 골지 목 · 밑단 · 소맷단
        b.ell(acc, "body", (0, 0.01, 0.607), (0.09, 0.08, 0.026))
        for z in (0.505, 0.455):
            b.ell(acc, "body", (0, 0.01, z), (0.143, 0.123, 0.018), seg=(24, 8))
        b.ell(acc, "body", (0, 0.01, 0.36), (0.13, 0.11, 0.026))
        for s, side in ((1, "L"), (-1, "R")):
            b.ell(acc, "fore_" + side, (0.16 * s, -0.015, 0.397), (0.045, 0.045, 0.018))
    return b.obj("Outfit" + kind)


def build_accessory(kind):
    """개인 장신구 (M4 사용자, 직원마다 고정 — 알아보기 표시): Glasses · Beanie · Ribbon · Headphones"""
    dark = mat("AccDark", "#3b3d42", 0.4)
    b = Body()
    hd = HEAD_DROP
    if kind == "Glasses":
        for s in (1, -1):   # 둥근 테 (고리)
            tb = bmesh.new()
            rows = []
            for i in range(20):
                a = 2 * math.pi * i / 20
                rows.append([tb.verts.new(((0.041 + 0.006 * math.cos(t)) * math.cos(a), 0.006 * math.sin(t), (0.041 + 0.006 * math.cos(t)) * math.sin(a)))
                             for t in (2 * math.pi * j / 8 for j in range(8))])
            for i in range(20):
                for j in range(8):
                    tb.faces.new((rows[i][j], rows[(i + 1) % 20][j], rows[(i + 1) % 20][(j + 1) % 8], rows[i][(j + 1) % 8]))
            bmesh.ops.translate(tb, vec=Vector((0.058 * s, -0.158, 0.79 - hd)), verts=tb.verts)
            b._add(tb, dark, "head")
        b.cap(dark, "head", (-0.018, -0.16, 0.795 - hd), (0.018, -0.16, 0.795 - hd), 0.005)
    elif kind == "Beanie":   # 비니 (포인트 색 아님 — 직원 고정 = 회청)
        bean = mat("BeanieKnit", "#6f8a96")
        b.ell(bean, "head", (0, 0.0, 0.885), (0.198, 0.21, 0.15), seg=(28, 16))   # 머리카락보다 크게 (뚫고 안 나오게)
        b.ell(mat("BeanieRib", "#5a7380"), "head", (0, -0.005, 0.86), (0.202, 0.214, 0.045), seg=(28, 8))
        b.ell(mat("BeaniePom", "#e9e6e1"), "head", (0, 0.03, 1.03), (0.045, 0.045, 0.04))
    elif kind == "Ribbon":   # 옆머리 리본 핀
        rib = mat("RibbonPink", "#d98a9a", 0.5)
        for s in (1, -1):   # 앞머리 위 옆쪽 (머리카락 밖으로)
            b.ell(rib, "head", (0.11 + 0.04 * s, -0.125, 0.925 + 0.01 * s), (0.04, 0.016, 0.03), seg=(12, 8))
        b.ell(rib, "head", (0.11, -0.135, 0.925), (0.016, 0.016, 0.016), seg=(10, 6))
    else:   # Headphones: 목에 건 헤드폰
        for s in (1, -1):
            b.cap(dark, "body", (0.07 * s, -0.03, 0.62), (0.085 * s, -0.07, 0.585), 0.03, seg=(14, 8))
        for k in range(9):
            a = math.pi * k / 8
            b.ell(dark, "body", (0.085 * math.cos(a), 0.03 + 0.06 * math.sin(a), 0.6), (0.014, 0.014, 0.012), seg=(8, 6))
    return b.obj("Acc" + kind)


def make_armature(name):
    arm = bpy.data.objects.new("Armature", bpy.data.armatures.new(name + "_Rig"))
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, h, t, parent in BONES:
        eb = arm.data.edit_bones.new(bname)
        eb.head, eb.tail, eb.roll = Vector(h), Vector(t), 0.0
        if parent:
            eb.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


# ------------------------------------------------------------------ 동작
def S(t, phase=0.0):
    return math.sin(2 * math.pi * (t + phase))


def ease(t):
    return math.sin(math.pi * t) ** 2


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def action(arm, name, frames, keyfn):
    """keyfn(t: 0~1) → {뼈: {'rot': (x, y, z) 도, 'loc': (x, y, z)}} — 8단계 키프레임, NLA 트랙으로 내보냄"""
    ad = arm.animation_data or arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad.action = act
    for i in range(9):
        reset_pose(arm)
        pose = keyfn(i / 8)
        for pb in arm.pose.bones:
            d = pose.get(pb.name, {})
            pb.rotation_euler = [math.radians(a) for a in d.get("rot", (0, 0, 0))]
            pb.location = d.get("loc", (0, 0, 0))
            pb.keyframe_insert("rotation_euler", frame=1 + frames * i / 8)
            pb.keyframe_insert("location", frame=1 + frames * i / 8)
    ad.nla_tracks.new().strips.new(name, 1, act)
    ad.nla_tracks[-1].name = name
    ad.action = None
    reset_pose(arm)


def actions(arm):
    action(arm, "Idle", 96, lambda t: {   # 숨쉬기 + 살짝 갸웃
        "body": {"rot": (1.5 * S(t * 2), 0, 0)},
        "head": {"rot": (2 * S(t, 0.2), 0, 10 * S(t))},
        "arm_L": {"rot": (3 * S(t * 2), 0, 6)}, "arm_R": {"rot": (-3 * S(t * 2), 0, -6)}})
    action(arm, "Walk", 24, lambda t: {   # 종종걸음 (몸 통통 튐)
        "root": {"loc": (0, 0.015 * abs(S(t)), 0)},
        "thigh_L": {"rot": (-28 * S(t), 0, 0)}, "thigh_R": {"rot": (28 * S(t), 0, 0)},
        "shin_L": {"rot": (max(0.0, 30 * S(t, 0.25)) + 4, 0, 0)},
        "shin_R": {"rot": (max(0.0, -30 * S(t, 0.25)) + 4, 0, 0)},
        "arm_L": {"rot": (24 * S(t), 0, 8)}, "arm_R": {"rot": (-24 * S(t), 0, -8)},
        "body": {"rot": (3, 0, 4 * S(t))}, "head": {"rot": (-2, 0, -4 * S(t))}})
    action(arm, "Sit", 48, lambda t: {    # 의자에 앉아 타자 (발은 살짝 뜬 채 까딱)
        "thigh_L": {"rot": (-88, 0, 0)}, "thigh_R": {"rot": (-88, 0, 0)},
        "shin_L": {"rot": (80 + 8 * S(t), 0, 0)}, "shin_R": {"rot": (80 - 8 * S(t), 0, 0)},
        "body": {"rot": (4 + 1 * S(t * 2), 0, 0)}, "head": {"rot": (6, 0, 4 * S(t * 0.5))},
        "arm_L": {"rot": (-55, 0, 10)}, "arm_R": {"rot": (-55, 0, -10)},
        "fore_L": {"rot": (-30 + 6 * S(t * 4), 0, 0)}, "fore_R": {"rot": (-30 - 6 * S(t * 4), 0, 0)}})
    action(arm, "Stretch", 72, lambda t: {   # 기지개
        "root": {"loc": (0, 0.015 * ease(t), 0)},
        "body": {"rot": (-10 * ease(t), 0, 0)}, "head": {"rot": (-14 * ease(t), 0, 0)},
        "arm_L": {"rot": (-165 * ease(t), 0, 24 * ease(t))}, "arm_R": {"rot": (-165 * ease(t), 0, -24 * ease(t))}})
    action(arm, "LookUp", 72, lambda t: {    # 올려다보기 (보드 · 하늘)
        "body": {"rot": (-6 + S(t * 2), 0, 0)}, "head": {"rot": (-24, 0, 8 * S(t))},
        "arm_R": {"rot": (-95, 0, 35)}, "fore_R": {"rot": (-75, 0, 0)}})
    def scratch(t):   # 오른손을 머리 옆으로 올려 벅벅 (1초에 4번) + 고개 갸웃
        return {"head": {"rot": (4, 0, -10)}, "body": {"rot": (2, 0, -3)},
                "arm_R": {"rot": (-160, 0, -40)}, "fore_R": {"rot": (0, 0, -70 + 15 * S(t * 4))}}   # 팔 각도 = 6가지 훑어 고름 (손이 머리 옆에 닿음)
    action(arm, "Scratch", 48, scratch)
    action(arm, "SitScratch", 48, lambda t: {**scratch(t),   # 앉은 채 (다리 = Sit, 왼손은 키보드)
        "thigh_L": {"rot": (-88, 0, 0)}, "thigh_R": {"rot": (-88, 0, 0)},
        "shin_L": {"rot": (80, 0, 0)}, "shin_R": {"rot": (80, 0, 0)},
        "arm_L": {"rot": (-55, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)}})
    action(arm, "Wave", 48, lambda t: {    # 손 흔들기 (퇴근 · 버스 앞, v2.8 인사 몸짓): 오른팔 들고 아래팔 좌우 2번
        "body": {"rot": (0, 0, -3)}, "head": {"rot": (-4, 0, 6)},
        "arm_R": {"rot": (-150, 0, -55)}, "fore_R": {"rot": (0, 0, 28 * S(t * 2))}})
    # ---- M4 4세션째: 쉬는 행동 · 인사 · 버릇 (손에 든 소품 = 게임이 fore_R 끝에 붙임)
    legs = {"thigh_L": {"rot": (-88, 0, 0)}, "thigh_R": {"rot": (-88, 0, 0)},
            "shin_L": {"rot": (80, 0, 0)}, "shin_R": {"rot": (80, 0, 0)}}
    hold = {"arm_R": {"rot": (-40, 0, -8)}, "fore_R": {"rot": (-60, 0, 0)}}   # 오른손에 든 채 앞으로 (컵 · 서류)
    action(arm, "Drink", 96, lambda t: {   # 서서 마시기: 컵을 입으로 → 고개 젖혀 한 모금 → 내림 (반복)
        "body": {"rot": (-2 * ease(t), 0, 0)}, "head": {"rot": (-14 * ease(t), 0, 0)},
        "arm_R": {"rot": (-40 - 30 * ease(t), 0, -8 - 10 * ease(t))}, "fore_R": {"rot": (-60 - 50 * ease(t), 0, 0)},
        "arm_L": {"rot": (2 * S(t), 0, 6)}})
    action(arm, "HoldIdle", 96, lambda t: {**hold,   # 들고 서 있기
        "body": {"rot": (1.5 * S(t * 2), 0, 0)}, "head": {"rot": (2 * S(t, 0.2), 0, 8 * S(t))},
        "arm_L": {"rot": (3 * S(t * 2), 0, 6)}})
    action(arm, "WalkCarry", 24, lambda t: {**hold,   # 들고 걷기 (오른팔은 고정, 왼팔만 흔듦)
        "root": {"loc": (0, 0.015 * abs(S(t)), 0)},
        "thigh_L": {"rot": (-28 * S(t), 0, 0)}, "thigh_R": {"rot": (28 * S(t), 0, 0)},
        "shin_L": {"rot": (max(0.0, 30 * S(t, 0.25)) + 4, 0, 0)},
        "shin_R": {"rot": (max(0.0, -30 * S(t, 0.25)) + 4, 0, 0)},
        "arm_L": {"rot": (24 * S(t), 0, 8)}, "body": {"rot": (3, 0, 4 * S(t))}, "head": {"rot": (-2, 0, -4 * S(t))}})
    action(arm, "Talk", 96, lambda t: {    # 수다: 양손 번갈아 손짓 + 끄덕 + 몸 흔들
        "body": {"rot": (0, 8 * S(t), 0)}, "head": {"rot": (5 * S(t * 2), 12 * S(t, 0.3), 0)},
        "arm_L": {"rot": (-35 - 20 * max(0.0, S(t)), 0, 15)}, "fore_L": {"rot": (-50 - 15 * max(0.0, S(t * 2)), 0, 0)},
        "arm_R": {"rot": (-35 - 20 * max(0.0, -S(t)), 0, -15)}, "fore_R": {"rot": (-50 - 15 * max(0.0, -S(t * 2)), 0, 0)}})
    action(arm, "RaiseHand", 36, lambda t: {   # 창구 도착 인사: 오른손 번쩍 1번 (사장 쪽)
        "head": {"rot": (-6 * ease(t), 0, 0)}, "body": {"rot": (0, 0, -3 * ease(t))},
        "arm_R": {"rot": (-165 * ease(t), 0, -20 * ease(t))}, "fore_R": {"rot": (-10 * ease(t), 0, 0)}})
    action(arm, "SitRest", 96, lambda t: {**legs,   # 앉아 쉬기 (소파 · 회의 탁자 · 느긋 의자 빙글): 등 기대고 팔 내림
        "body": {"rot": (-8 + 1.5 * S(t * 2), 0, 0)}, "head": {"rot": (-4, 0, 8 * S(t))},
        "arm_L": {"rot": (-20, 0, 14)}, "fore_L": {"rot": (-30, 0, 0)},
        "arm_R": {"rot": (-20, 0, -14)}, "fore_R": {"rot": (-30, 0, 0)}})
    action(arm, "SitWipe", 72, lambda t: {**legs,   # 부지런: 모니터 닦기 (오른손 앞으로 뻗어 좌우 3번)
        "body": {"rot": (8, 0, 4 * S(t * 3))}, "head": {"rot": (4, 0, 0)},
        "arm_R": {"rot": (-95, 0, -10 + 25 * S(t * 3))}, "fore_R": {"rot": (-20, 0, 0)},
        "arm_L": {"rot": (-55, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)}})
    action(arm, "SitLook", 96, lambda t: {**legs,   # 수다: 두리번거리며 옆자리 보기 (왼쪽 → 오른쪽)
        "body": {"rot": (2, 14 * S(t), 0)}, "head": {"rot": (0, 32 * S(t), 0)},   # 뼈 Y = 위쪽 축 → 좌우 돌림
        "arm_L": {"rot": (-45, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)},
        "arm_R": {"rot": (-45, 0, -10)}, "fore_R": {"rot": (-30, 0, 0)}})
    action(arm, "SitPen", 72, lambda t: {**legs,   # 조용: 턱 앞에서 펜 돌리기 + 생각하듯 고개 기울임
        "body": {"rot": (4, 0, 0)}, "head": {"rot": (6, 0, -8)},
        "arm_R": {"rot": (-110, 0, -12)}, "fore_R": {"rot": (-95, 0, 22 * S(t * 4))},
        "arm_L": {"rot": (-55, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)}})
    # ---- M4 5세션째: 도구별 책상 동작 (② 고치기 · 읽기 · 실행) · ⑨ 엄지척 · 멈춤 손 (C16)
    action(arm, "SitTypeFast", 24, lambda t: {**legs,   # 고치기: 앞으로 숙여 빠른 타자 (1초에 8번)
        "body": {"rot": (10, 0, 1.5 * S(t * 2))}, "head": {"rot": (10 + 2 * S(t * 4), 0, 0)},
        "arm_L": {"rot": (-60, 0, 10)}, "arm_R": {"rot": (-60, 0, -10)},
        "fore_L": {"rot": (-30 + 10 * S(t * 4), 0, 0)}, "fore_R": {"rot": (-30 - 10 * S(t * 4), 0, 0)}})
    action(arm, "SitFlip", 96, lambda t: {**legs,   # 읽기: 오른손에 서류 (게임이 붙임) · 고개 숙여 보다가 왼손으로 한 장 넘김
        "body": {"rot": (6, 0, 0)}, "head": {"rot": (16 + 2 * S(t * 2), 0, -4)},
        "arm_R": {"rot": (-55, 0, -4)}, "fore_R": {"rot": (-55, 0, 0)},
        "arm_L": {"rot": (-55 - 15 * ease(min(1.0, t * 2)), 0, 10 - 28 * ease(min(1.0, t * 2)))},
        "fore_L": {"rot": (-45, 0, 0)}})
    action(arm, "SitWatch", 96, lambda t: {**legs,   # 실행: 등 기대고 턱 괴고 화면 지켜보기 (검은 화면 초록 글자는 게임이 그림)
        "body": {"rot": (-5 + 1 * S(t * 2), 0, 0)}, "head": {"rot": (2, 0, -6 + 2 * S(t))},
        "arm_R": {"rot": (-115, 0, -14)}, "fore_R": {"rot": (-105, 0, 0)},
        "arm_L": {"rot": (-50, 0, 10)}, "fore_L": {"rot": (-35 + 4 * S(t * 2), 0, 0)}})
    up = lambda t: min(1.0, t * 3) if t < 0.75 else 1.0 - (t - 0.75) * 4   # 빨리 올려 멈췄다 내림
    action(arm, "ThumbsUp", 48, lambda t: {   # ⑨ 창구에서 사장이 답하면: 주먹 앞으로 척 (엄지 = 'Thumb' 메시, 게임이 이때만 보임) + 끄덕
        "head": {"rot": (8 * up(t), 0, 6 * up(t))}, "body": {"rot": (3 * up(t), 0, -3 * up(t))},
        "arm_R": {"rot": (-70 * up(t), 0, -25 * up(t))}, "fore_R": {"rot": (-40 * up(t), 0, 0)}})
    action(arm, "SitStop", 48, lambda t: {**legs,   # 멈춤 손 (Esc, is_interrupt): 손바닥 들고 '앗' 하듯 몸을 뒤로 (그대로 멈춤)
        "body": {"rot": (-7, 0, 0)}, "head": {"rot": (-6, 0, 4)},
        "arm_R": {"rot": (-100, 0, -10)}, "fore_R": {"rot": (-5, 0, 0)},   # 팔을 앞으로 쭉 ('잠깐!')
        "arm_L": {"rot": (-55, 0, 10)}, "fore_L": {"rot": (-30, 0, 0)}})
    # ---- M5 2세션째: 단계 상승 박수 · 짐 상자 (입사 · 송별 — 상자는 게임이 가슴 앞에 붙임)
    clap = lambda t: (1 + S(t * 4)) / 2   # 0 = 벌림 · 1 = 짝 (2초에 4번)
    action(arm, "Clap", 48, lambda t: {
        "head": {"rot": (-6 + 3 * S(t * 4), 0, 0)}, "body": {"rot": (-2, 0, 0)},
        "arm_L": {"rot": (-62, 0, 14 - 30 * clap(t))}, "fore_L": {"rot": (-45, 0, 0)},
        "arm_R": {"rot": (-62, 0, -14 + 30 * clap(t))}, "fore_R": {"rot": (-45, 0, 0)}})
    box = {"arm_L": {"rot": (-48, 0, -4)}, "fore_L": {"rot": (-50, 0, 0)},
           "arm_R": {"rot": (-48, 0, 4)}, "fore_R": {"rot": (-50, 0, 0)}}   # 두 손으로 상자 받쳐 들기
    action(arm, "HoldBox", 96, lambda t: {**box,
        "body": {"rot": (-3 + 1 * S(t * 2), 0, 0)}, "head": {"rot": (2 * S(t), 0, 4 * S(t))}})
    action(arm, "WalkBox", 24, lambda t: {**box,
        "root": {"loc": (0, 0.015 * abs(S(t)), 0)},
        "thigh_L": {"rot": (-28 * S(t), 0, 0)}, "thigh_R": {"rot": (28 * S(t), 0, 0)},
        "shin_L": {"rot": (max(0.0, 30 * S(t, 0.25)) + 4, 0, 0)},
        "shin_R": {"rot": (max(0.0, -30 * S(t, 0.25)) + 4, 0, 0)},
        "body": {"rot": (-4, 0, 3 * S(t))}, "head": {"rot": (-2, 0, -3 * S(t))}})


def export(arm, *objs):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(OUT, "staff.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_apply=False)
    print(f"[staff] -> {path}  faces={sum(len(o.data.polygons) for o in objs)}")


# ------------------------------------------------------------------ 미리보기 (동작 4개 + 앉은 모습 의자)
def preview(arm, path, names=None):
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.location = (0.9, -2.0, 1.25)
    cam.rotation_euler = (math.radians(68), 0, math.radians(24))
    cam.data.lens = 50
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.7, 0.2, 0.5)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.78, 0.82, 1)
    scn.render.resolution_x, scn.render.resolution_y = 1200, 500
    scn.render.film_transparent = False
    ad = arm.animation_data
    names = names or [("Idle", 1), ("Walk", 7), ("Sit", 12), ("Stretch", 37)]
    for tr in ad.nla_tracks:
        tr.mute = True
    # 동작마다 복제해서 옆으로 늘어놓기 대신, 한 장씩 렌더 후 합침
    import numpy as np
    tiles = []
    for nm, f in names:
        for tr in ad.nla_tracks:
            tr.mute = tr.name != nm
        scn.frame_set(f)
        out = os.path.join(os.path.dirname(path), "_tile.png")
        scn.render.resolution_x, scn.render.resolution_y = 300, 500
        scn.render.filepath = out
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(out)
        tiles.append(np.array(img.pixels[:]).reshape(500, 300, 4))
        bpy.data.images.remove(img)
    sheet = np.concatenate(tiles, axis=1)
    im = bpy.data.images.new("sheet", 300 * len(names), 500, alpha=True)
    im.pixels = sheet.flatten().tolist()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    os.remove(os.path.join(os.path.dirname(path), "_tile.png"))
    print("[staff] 미리보기 ->", path)


def outfit_preview(arm, vest, outfits, folder):
    import numpy as np
    scn = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.15
    cam.location = (0.0, -3.0, 0.9)
    cam.rotation_euler = (math.radians(84), 0, math.radians(0))
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (0.7, 0.2, 0.4)
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.8, 0.88, 1)
    scn.view_settings.view_transform = "Standard"
    scn.render.resolution_x, scn.render.resolution_y = 400, 480
    vest.hide_render = True
    tiles = []
    accent = {"Accent": None}
    ## 색 조합 후보 (사용자 "옷 색이 밤티") — `--palette=A|B|C`: (직원 색, 포인트 색) 6쌍
    PAL = {"A": [("#a9c8e8", "#ffffff"), ("#9fd8c8", "#3f4c6b"), ("#c7b6e6", "#ffffff"), ("#f4b8a0", "#3f4c6b"), ("#f2a8b8", "#ffffff"), ("#b8d89c", "#3f4c6b")],
           "B": [("#3f4c6b", "#e9e3d8"), ("#4a4f57", "#9fc3d6"), ("#e9e3d8", "#3f4c6b"), ("#8fa79a", "#e9e3d8"), ("#7f93ad", "#e9e3d8"), ("#b79c8a", "#3f4c6b")],
           "C": [("#7fa8d6", "#3f6595"), ("#7cc4b0", "#3c8573"), ("#a99ad6", "#62539a"), ("#e89c86", "#b0573e"), ("#e58fa6", "#a8456a"), ("#94c47e", "#557f42")]}
    pal = next((x.split("=")[1] for x in ARGS if x.startswith("--palette=")), "A")
    combos = [(0, 3), (1, 4), (2, 5), (1, -1), (2, 3), (0, -1)]
    for k, (oi, ai) in enumerate(combos):
        shirt_col, ac = PAL[pal][k]
        for i, o in enumerate(outfits):
            o.hide_render = i not in (oi, ai)
        bsdf = next(n for n in bpy.data.materials["Accent"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*lin(ac), 1)
        bsdf = next(n for n in bpy.data.materials["Shirt"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*lin(shirt_col), 1)
        out = os.path.join(folder, "_o.png")
        scn.render.filepath = out
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(out)
        tiles.append(np.array(img.pixels[:]).reshape(480, 400, 4))
        bpy.data.images.remove(img)
    sheet = np.concatenate(tiles, axis=1)
    im = bpy.data.images.new("sheet", 400 * len(tiles), 480, alpha=True)
    im.pixels = sheet.flatten().tolist()
    im.filepath_raw = os.path.join(folder, "pick_outfits_%s.png" % pal)
    im.file_format = "PNG"
    im.save()
    os.remove(os.path.join(folder, "_o.png"))
    print("[staff] 복장 미리보기 ->", im.filepath_raw)


if __name__ == "__main__":
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    arm = make_armature("Staff")
    obj = build_body()
    obj.parent = arm
    obj.modifiers.new("Armature", "ARMATURE").object = arm
    vest = build_vest(badge=True)   # 인턴 = 흰 셔츠 + 회색 조끼 + 사원증 목걸이 (M4 1세션째 사용자)
    vest.parent = arm
    vest.modifiers.new("Armature", "ARMATURE").object = arm
    outfits = []
    for o in [build_outfit(k) for k in ("Shirt", "Hoodie", "Knit")] + [build_accessory(k) for k in ("Glasses", "Ribbon", "Headphones")]:   # 비니 = 사용자 "모자는 빼자" (builder 는 남김)
        o.parent = arm   # 복장 (출근마다 무작위 하나) · 장신구 (직원마다 고정 하나 또는 없음) — 게임이 보이기를 정함
        o.modifiers.new("Armature", "ARMATURE").object = arm
        outfits.append(o)
    thumb = build_thumb()
    thumb.parent = arm
    thumb.modifiers.new("Armature", "ARMATURE").object = arm
    actions(arm)
    if "--poses5" in ARGS:   # 미리보기는 셔츠만 (덧입기가 겹쳐 보이지 않게)
        for o in outfits[1:]:
            o.hide_render = True
        vest.hide_render = True
    if "--outfits" in ARGS:   # 복장 미리보기: 셔츠 · 후드티 · 니트 나란히 (내보내기 없이)
        outfit_preview(arm, vest, outfits, ARGS[ARGS.index("--outfits") + 1])
        sys.exit(0)
    export(arm, obj, vest, thumb, *outfits)
    if len(ARGS) >= 2 and not ARGS[1].startswith("--"):
        poses = [("Drink", 48), ("WalkCarry", 7), ("Talk", 24), ("RaiseHand", 18), ("SitRest", 12), ("SitWipe", 18),
                 ("SitLook", 24), ("SitPen", 18)] if "--poses" in ARGS else None   # M4 4세션째 새 동작
        if "--poses5" in ARGS:   # M4 5세션째 새 동작
            poses = [("Sit", 12), ("SitTypeFast", 6), ("SitFlip", 30), ("SitWatch", 24), ("ThumbsUp", 18), ("SitStop", 12)]
        if "--poses-m5" in ARGS:   # M5 2세션째 새 동작
            poses = [("Clap", 1), ("Clap", 7), ("HoldBox", 12), ("WalkBox", 7)]
        preview(arm, os.path.abspath(ARGS[1]), poses)
