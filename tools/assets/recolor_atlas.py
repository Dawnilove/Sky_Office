"""외부 팩 텍스처 (색 칸 아틀라스) 를 '하늘 오피스 색' 으로 다시 칠함 — M4 에셋 회의 A 안 (KayKit · Tiny Treats)

실행 (OverLand 폴더에서):  python SkyOffice/tools/assets/recolor_atlas.py
  → SkyOffice/tools/assets_src/<팩>/<텍스처>_sky.png 를 만듦 (원본은 그대로). 그다음 build_kits.py (Blender)
규칙 (PLAN 3-3): 노랑 · 주황 · 금색 금지 (= '내 차례' 신호 전용), 분홍 · 빨강은 회청색 천으로, 채도 낮게
필요: Pillow (pip install pillow)
"""
import colorsys
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets_src")
ATLASES = [("kaykit_furniture", "furniturebits_texture.png"), ("kaykit_restaurant", "restaurantbits_texture.png"),
           ("tinytreats_plants", "tiny_treats_texture_1.png")]


def remap(r, g, b):
    """sRGB 0~1 → 게임 팔레트 쪽 색"""
    h, sat, v = colorsys.rgb_to_hsv(r, g, b)
    hd = h * 360
    if sat > 0.12:
        if 15 <= hd < 70:
            if v > 0.8 and hd > 35:      # 밝은 노랑 → 세이지
                hd, sat, v = 95, min(sat, 0.22), v * 0.75
            else:                         # 주황 · 나무 → 나무 갈색 (#9a8068 근처)
                hd, sat, v = 28, min(sat, 0.32), min(v * 0.88, 0.62)
        elif hd >= 300 or hd < 15:        # 분홍 · 빨강 → 회청색 천 (#8e98a3 근처)
            hd, sat, v = 212, 0.18, min(v * 0.85, 0.66)
        else:                             # 초록 · 파랑 · 보라: 채도만 낮춤
            sat, v = min(sat, 0.35), v * 0.88
    else:
        v = v * 0.92
    return colorsys.hsv_to_rgb(hd / 360, sat, v)


def recolor(src, dst):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[:3] not in cache:
                cache[c[:3]] = tuple(int(round(max(0.0, min(1.0, v)) * 255)) for v in remap(*(k / 255 for k in c[:3])))
            px[x, y] = cache[c[:3]] + (c[3],)
    im.save(dst)
    print(f"[recolor] {os.path.basename(dst)}  색 {len(cache)}개")


if __name__ == "__main__":
    for pack, tex in ATLASES:
        src = os.path.join(ROOT, pack, tex)
        recolor(src, src.replace(".png", "_sky.png"))
