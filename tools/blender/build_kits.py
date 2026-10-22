"""외부 팩 (CC0) → 게임 glb: 게임 색 텍스처로 바꾸고 칸 단위로 줄임 — M4 에셋 회의 A 안 (휴게 층 · 화분)

실행 (OverLand 폴더에서, recolor_atlas.py 먼저):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P SkyOffice/tools/blender/build_kits.py -- SkyOffice/game/assets/models/kit

- 원본: SkyOffice/tools/assets_src/<팩>/ (쓰는 모델만 + LICENSE). KayKit = Kay Lousberg, Tiny Treats = Isa Lousberg, 둘 다 CC0
- 크기: KayKit 1 단위 ≈ 1m 이고 2등신 직원에 맞추면 의자 높이 0.63 칸 → × 0.501 (같은 규격인 Tiny Treats 도 같은 배율)
- 텍스처는 256² 로 줄임 (작은 화면에서 차이 없음, 메모리 절약)
"""
import os
import sys

import bpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else "kit_out"
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets_src")
S = 0.501
## (팩, 원본 이름, 게임 파일 이름, 텍스처)
MODELS = [
    ("kaykit_furniture", "couch_pillows", "kit_sofa", "furniturebits_texture"),
    ("kaykit_furniture", "armchair", "kit_armchair", "furniturebits_texture"),
    ("kaykit_furniture", "rug_oval_A", "kit_rug", "furniturebits_texture"),
    ("kaykit_restaurant", "table_round_A", "kit_table_round", "restaurantbits_texture"),
    ("kaykit_restaurant", "chair_A", "kit_chair", "restaurantbits_texture"),
    ("tinytreats_plants", "monstera_plant_medium_potted", "kit_plant_monstera", "tiny_treats_texture_1"),
    ("tinytreats_plants", "pothos_plant_medium_potted", "kit_plant_pothos", "tiny_treats_texture_1"),
    ("tinytreats_plants", "monstera_plant_small_potted", "kit_plant_small", "tiny_treats_texture_1"),
]
os.makedirs(OUT, exist_ok=True)
_tex = {}


def sky_tex(pack, name):
    if name not in _tex:
        im = bpy.data.images.load(os.path.join(SRC, pack, name + "_sky.png"))
        im.scale(256, 256)
        _tex[name] = im
    return _tex[name]


for pack, src, dst, tex in MODELS:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, pack, src + ".gltf"))
    objs = list(bpy.data.objects)
    for o in objs:
        for sl in getattr(o, "material_slots", []):
            if sl.material and sl.material.use_nodes:
                for nd in sl.material.node_tree.nodes:
                    if nd.type == "TEX_IMAGE":
                        nd.image = sky_tex(pack, tex)
    for r in (o for o in objs if o.parent is None):
        r.scale = tuple(v * S for v in r.scale)
        r.location = tuple(v * S for v in r.location)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, dst + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True)
    faces = sum(len(o.data.polygons) for o in objs if o.type == "MESH")
    print(f"[kit] {dst}.glb  faces={faces}")
