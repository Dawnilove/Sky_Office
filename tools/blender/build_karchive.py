"""kArchive 가구 (자료: kArchive · 출처: 쓰레드 dogfooter) → 게임 glb — 단계 36 · 44 가구 (② 가구 모델, docs/v1_1/모델_초안.md)

실행 (SkyOffice 폴더에서):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/build_karchive.py -- game/assets/models/karchive

- 원본: tools/assets_src/karchive/*.glb (git 에 안 넣음 — 원본 재판매 금지). 여기서는 크기 · 삼각형 · 텍스처만 줄여 변형본을 만듦
- 크기 단위 = m (게임에서 _prop 이 unit_m 을 곱함). 원점 = 바닥 가운데 (원본이 이미 그러함)
"""
import os
import sys

import bpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else "karchive_out"
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets_src", "karchive")
## (원본 이름, 게임 파일 이름, 높이 m, 삼각형 상한)
MODELS = [
    ("angular-convenience-coffee-vending-unit-ready", "capsule_coffee", 0.46, 3000),
    ("angular-convenience-hot-water-dispenser-counter-streamline-normal", "water_dispenser", 0.72, 3000),
    ("angular-onsen-capsule-sleeping-pod-pavilion-streamline-normal", "sleep_pod", 0.9, 3500),
    ("angular-restaurant-undercounter-fridge-closed", "snack_fridge", 0.7, 3000),   # 1.2 단계 64 복지 가구
    ("common-furniture-television-media-console-streamline-normal", "tv_console", 0.94, 3500),
]
os.makedirs(OUT, exist_ok=True)

for src, dst, height, cap in MODELS:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, src + ".glb"))
    ob = next(o for o in bpy.data.objects if o.type == "MESH")
    # 원본 y-up → Blender z-up 으로 들어와 있음: 높이 = dimensions.z
    k = height / ob.dimensions.z
    ob.scale = (k, k, k)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > cap:
        md = ob.modifiers.new("dec", "DECIMATE")
        md.ratio = cap / tris
        bpy.ops.object.modifier_apply(modifier=md.name)
    for im in bpy.data.images:
        if im.size[0] > 256:
            im.scale(256, 256)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, dst + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_image_format="JPEG", export_jpeg_quality=80)
    print(f"[karchive] {dst}.glb  tris {tris} -> {sum(len(p.vertices) - 2 for p in ob.data.polygons)}  h={height}")
