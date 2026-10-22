#!/bin/bash
# bell.exe NativeAOT 빌드 → game/plugin/bell.exe (게임 안 원본 = 무결성 기준, PLAN 7-2 · 7-5)
# 필요: .NET 10 SDK + VS 2022 Build Tools (C++). 사용: bash tools/build_bell.sh
# bell 을 바꾸면 phone.gd PLUGIN_VER + game/plugin/plugin.json version 도 올림 (다시 개통 = 다시 동의)
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$PATH:/c/Program Files (x86)/Microsoft Visual Studio/Installer"   # ILCompiler 가 vswhere 로 링커를 찾음
cd "$ROOT/m0/bell"
dotnet publish -c Release -r win-x64 -o out/aot | tail -2
cp out/aot/bell.exe "$ROOT/game/plugin/bell.exe"
python -c "import hashlib,sys;print('bell.exe SHA-256', hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$ROOT/game/plugin/bell.exe"
