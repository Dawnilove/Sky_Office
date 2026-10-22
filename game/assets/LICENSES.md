# 에셋 출처 및 라이선스

| 경로 | 제작 | 출처 | 라이선스 |
|---|---|---|---|
| `models/*.glb` (섬·집·나무·소품·확장 섬·다리·풍차·비행선·로봇 등) | 직접 제작 (`tools/blender/build_assets.py`, `build_extras.py`) | — | 프로젝트 소유 |
| `models/theme_*.glb` (확장 섬 테마 6종) | 직접 제작 (`tools/blender/build_themes.py`) | — | 프로젝트 소유 |
| `models/{pantry,service_counter,staff}.glb` · `models/desk/*.glb` (책상 · 모니터 · 의자, `build_desk_kit.py`) · 작업실 · 분위기 (`server_rack` · `server_shelf` · `bookshelf` · `whiteboard` · `telescope` · `call_board` · `desk_personal` · `rock_base`) | 직접 제작 (`tools/blender/build_office_props.py`, `build_staff.py`, `build_workroom.py`) | — | 프로젝트 소유 |
| `models/kit/kit_{sofa,armchair,rug}.glb` | Kay Lousberg — KayKit Furniture Bits 1.0 (색 · 크기 수정: `tools/assets/recolor_atlas.py` · `tools/blender/build_kits.py`) | https://kaylousberg.itch.io/furniture-bits | CC0 1.0 (원본 `tools/assets_src/kaykit_furniture/`) |
| `models/kit/kit_{table_round,chair}.glb` | Kay Lousberg — KayKit Restaurant Bits 1.0 (색 · 크기 수정) | https://kaylousberg.itch.io/restaurant-bits | CC0 1.0 (원본 `tools/assets_src/kaykit_restaurant/`) |
| `models/kit/kit_plant_*.glb` | Isa Lousberg — Tiny Treats House Plants 1.0 (색 · 크기 수정) | https://tinytreats.itch.io/house-plants | CC0 1.0 (원본 `tools/assets_src/tinytreats_plants/`) |
| `models/animals/{cat,goat,owl,chicken,deer,whale,farmer}.glb` | 직접 제작 (`tools/blender/build_animals.py`) | — | 프로젝트 소유 |
| `models/animals/{horse,cow,pig,sheep,llama,pug,zebra}.glb` | Quaternius — Farm Animal Pack | https://poly.pizza/bundle/Farm-Animal-Pack-1kUvRTPLzT | CC0 1.0 (퍼블릭 도메인) |
| `sounds/{ambience,night,rain}.wav` | 직접 합성 (`tools/build_ambience.py`) | — | 프로젝트 소유 |
| `sounds/bgm.wav` | 직접 합성 (`tools/build_bgm.py`, seed 고정) | — | 프로젝트 소유 |
| `ui/theme_*.png`, `app/overland*` (테마 미리보기·앱 아이콘) | 게임 화면을 렌더링해 만듦 | — | 프로젝트 소유 |

UI 창 글꼴은 Windows 기본 글꼴(맑은 고딕)을 사용하며 게임에 포함하지 않음. 게임 안 글자는 아래 주아 (포함).

## 글꼴
- **주아 (Jua)** — `fonts/Jua-Regular.ttf`, Copyright 2018 The Jua Project Authors, SIL Open Font License 1.1 (`fonts/OFL_Jua.txt`). 출처: github.com/google/fonts (ofl/jua). 게임 안 글자 (말풍선 · 간판 · 이름판), M4 사용자 2026-10-16
