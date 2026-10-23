#!/bin/bash
# 하늘 오피스 화면 밖 (오프스크린) 실행 — 사용자 화면에 창을 띄우지 않고 시험 · 그림 찍기
# 사용: bash tools/offscreen_test.sh <게임 인자...>
#   bash tools/offscreen_test.sh --scenario                     # 자동 점검 (지름 10)
#   bash tools/offscreen_test.sh --scenario --diameter=14       # 크기 14
#   bash tools/offscreen_test.sh --shot=C:/경로/d10.png --states=work,turn15,done,unknown --days=40,15,5,0
#   bash tools/offscreen_test.sh --fast-day                     # 하루 빨리 보기 (녹화 재생 → 장면 요약, 상한 넘으면 종료 코드 1)
#   ALL=1 bash tools/offscreen_test.sh --scenario               # 걸러 내지 않은 전체 출력
# 실행하는 동안만 game/override.cfg (1x1 · 포커스 없음) 를 만들었다 지움 → 이때 빌드 (build_release.sh) 를 같이 돌리지 말 것
# 게임 저장은 하지 않음 (--offscreen --fresh)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/game"
G="${GODOT:-/c/Users/<USER>/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe}"
[ -x "$G" ] || { echo "Godot 콘솔 실행 파일이 없음: $G (환경 변수 GODOT 로 지정)"; exit 1; }
printf "[display]\n\nwindow/size/window_width_override=1\nwindow/size/window_height_override=1\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(0, 0)\n" > "$P/override.cfg"
trap 'rm -f "$P/override.cfg"' EXIT
if [ "${ALL:-0}" = "1" ]; then
	timeout 180 "$G" --path "$P" -- --offscreen --fresh "$@"
else
	timeout 180 "$G" --path "$P" -- --offscreen --fresh "$@" 2>&1 | grep -E "SCENARIO|DAY|SHOT|SCRIPT ERROR|Parse Error|at: res://" | head -3000
fi
exit "${PIPESTATUS[0]}"
