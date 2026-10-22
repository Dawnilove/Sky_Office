#!/usr/bin/env bash
# 하늘 오피스 배포판 만들기 (Git Bash에서: bash tools/build_release.sh) — 반드시 사용자 허락을 받은 뒤 실행
#   [0/5] 이전 배포판 zip · .sig 는 release/old 로 (release/NEW = 최신만)
#   [1/5] 게임 내보내기 (암호화)          → SkyOffice/release/NEW/SkyOffice/SkyOffice.exe
#   [2/5] 점검용 빌드 (암호화+개발 옵션)  → ${TMPDIR:-/tmp}/gb/office_devtest/ (배포하지 않음, 오버랜드 점검용 폴더와 따로)
#   [3/5] 점검용 빌드로 화면 밖 실행 확인
#   [4/5] 암호화 확인: exe 안에 원본 코드·경로가 보이면 안 됨
#   [5/5] zip + 자동 업데이트용 .zip.sig (오피스 전용 키) → SkyOffice/release/NEW/
# 주의: off-screen 점검이 override.cfg 를 만드는 동안 내보내기를 같이 돌리지 않기 (배포판에 섞여 들어갈 수 있음)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # SkyOffice
VER=$(python -I -c "import re,sys; print(re.search(r'config/version=\"([^\"]+)\"', open(sys.argv[1], encoding='utf-8').read()).group(1))" "$ROOT/game/project.godot")
ZIP="SkyOffice-$VER-windows-x64.zip"   # identity.gd ZIP_FORMAT 과 같게
GD="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
export PATH="/c/Program Files/dotnet:$PATH"
LOG="$ROOT/tools/logs"; mkdir -p "$LOG"
W="$(cd "$ROOT" && pwd -W)"

python -I "$ROOT/tools/fix_paths.py"   # 폴더를 옮겼어도 암호화 템플릿 경로를 지금 위치로
[ -f "$ROOT/game/override.cfg" ] && { echo "FAIL override.cfg 가 남아 있음 (화면 밖 점검 중?) — 지우고 다시"; exit 1; }

# [0/5] 이전 배포판 → release/old
OUT="$ROOT/release/NEW"; mkdir -p "$OUT" "$ROOT/release/old"
for f in "$OUT"/*.zip "$OUT"/*.zip.sig; do [ -f "$f" ] && mv -f "$f" "$ROOT/release/old/"; done

# [1/5] 게임
rm -rf "$OUT/SkyOffice" && mkdir -p "$OUT/SkyOffice"
"$GD" --headless --path "$ROOT/game" --export-release "Windows Desktop" ../release/NEW/SkyOffice/SkyOffice.exe > "$LOG/export_release.log" 2>&1
[ -f "$OUT/SkyOffice/SkyOffice.exe" ] || { echo "FAIL [1/5] 게임 내보내기 ($LOG/export_release.log)"; exit 1; }
echo "[1/5] 게임 내보내기 완료 ($VER)"

# [2/5] 점검용
T=${TMPDIR:-/tmp}/gb/office_devtest; rm -rf "$T" && mkdir -p "$T"
"$GD" --headless --path "$ROOT/game" --export-release "Windows Test (devtest)" "$T/SkyOffice.exe" > "$LOG/export_test.log" 2>&1
[ -f "$T/SkyOffice.exe" ] || { echo "FAIL [2/5] 점검용 내보내기"; exit 1; }
echo "[2/5] 점검용 빌드 완료"

# [3/5] 실행 확인
printf "[display]\n\nwindow/size/window_width_override=1\nwindow/size/window_height_override=1\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(0, 0)\n" > "$T/override.cfg"
(cd "$T" && timeout 120 ./SkyOffice.exe -- --offscreen --fresh --autotest --duration=6 > run.log 2>&1)
rm -f "$T/override.cfg"
ok=1
grep -aq "미리보기 저장" "$T/run.log" || { echo "FAIL [3/5] 실행 실패 ($T/run.log)"; ok=0; }
grep -aq "SkyOffice" "$T/run.log" || { echo "FAIL [3/5] 저장 위치가 SkyOffice 가 아님"; ok=0; }
grep -aqi "script error" "$T/run.log" && { echo "FAIL [3/5] 스크립트 오류"; grep -ai "script error" "$T/run.log" | head -3; ok=0; }
[ $ok = 1 ] && echo "[3/5] 점검용 실행 OK (저장 위치 %APPDATA%\\SkyOffice)"

# [4/5] 암호화 확인
python -I - "$OUT/SkyOffice/SkyOffice.exe" <<'EOF'
import sys
probe = [b"res://scripts/main.gd", b"extends Node3D", b"func _ready", b"island_builder", b"UPDATE_PUBLIC_KEY",
         b"SAVE_KEY", b"mini_mode", b"identity.gd", b"OverlandSkyFarm"]
d = open(sys.argv[1], "rb").read()
found = [p.decode() for p in probe if p in d]
print("[4/5] 암호화 확인: %s" % ("통과 (원본 흔적 없음)" if not found else "주의: %s" % found))
EOF
# [4/5] 개인정보 · 비밀 확인 (걸리면 멈춤): 배포 폴더 모든 파일 + 내보내기 원본 (game/, .godot 빼고 — 암호화돼서 나중엔 못 봄)
#   사용자 이름 · 이메일 · 사용자 폴더 경로 / 진짜 비밀 키 블록 (머리말 상수만 있는 건 통과) · API 토큰 / 키 · 인증서 파일
python -I - "$OUT/SkyOffice" "$ROOT/game" "$(basename "$HOME")" <<'EOF' || exit 1
import os, re, sys
plain = [sys.argv[3].encode(), b"C:" + bytes([92]) + b"Users" + bytes([92]), b"C:/Users/"]
plain += [p.decode().encode("utf-16-le") for p in plain]
secret = re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----\s*[A-Za-z0-9+/=]{40}|sk-ant-[A-Za-z0-9_-]{10}|ghp_[A-Za-z0-9]{20}|github_pat_[A-Za-z0-9_]{20}|AKIA[0-9A-Z]{16}|(?i:password|passwd|api[_-]?key)\s*[:=]\s*[\"'][^\"']{6}")
keyfile = re.compile(r"\.(key|pfx|p12|snk|env)$|private[_.-]?key|credential", re.I)
bad = []
for top, check_plain in ((sys.argv[1], True), (sys.argv[2], False)):
    for root, dirs, files in os.walk(top):
        dirs[:] = [d for d in dirs if d != ".godot"]
        for f in files:
            if keyfile.search(f): bad.append("키 파일 " + f)
            d = open(os.path.join(root, f), "rb").read()
            if check_plain and any(p in d for p in plain): bad.append("개인정보 " + f)
            if secret.search(d): bad.append("비밀 " + f)
print("[4/5] 개인정보 · 비밀 확인: %s" % ("통과" if not bad else "FAIL %s" % bad))
sys.exit(1 if bad else 0)
EOF

# [5/5] zip + 서명 (오피스 전용 비밀 키 — 오버랜드 키 아님)
python -I - "$OUT/SkyOffice" "$OUT/$ZIP" <<'EOF'
import zipfile, os, sys
src, dst = sys.argv[1], sys.argv[2]
if os.path.exists(dst):
    os.remove(dst)
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for r, _, files in os.walk(src):
        for f in files:
            p = os.path.join(r, f)
            z.write(p, os.path.join("SkyOffice", os.path.relpath(p, src)))
print("[5/5] zip:", os.path.getsize(dst) // 1048576, "MB")
EOF
# 비밀 키 = 프로젝트 밖 (v2.8 ③): 환경 변수 SKYOFFICE_SIGN_KEY, 없으면 ~/.skyoffice-signing/update_private.key (게임 데이터 폴더 ~/.skyoffice 와 따로)
KEY="${SKYOFFICE_SIGN_KEY:-$HOME/.skyoffice-signing/update_private.key}"
[ -f "$KEY" ] || { echo "FAIL [5/5] 비밀 키 없음: $KEY (SKYOFFICE_SIGN_KEY 로 경로 지정)"; exit 1; }
"$GD" --headless --script "$W/tools/signing/sign_file.gd" -- "$W/release/NEW/$ZIP" "$(cygpath -m "$KEY" 2>/dev/null || echo "$KEY")" 2>&1 | grep -a "서명\|실패"
[ -f "$OUT/$ZIP.sig" ] || { echo "FAIL [5/5] zip 서명 실패"; exit 1; }
echo "ALL_DONE → SkyOffice/release/NEW/$ZIP (+ .sig)"
