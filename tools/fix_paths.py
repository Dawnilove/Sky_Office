"""폴더를 옮겨도 빌드가 되게: export_presets.cfg 의 암호화 템플릿 경로를 지금 위치로 맞춤

build_release.sh · dlc_signing/build_dlc.sh 가 내보내기 전에 자동으로 부름.
실행: python -I dev/tools/fix_paths.py
"""
import io
import os
import re

DEV = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PRESETS = os.path.join(DEV, "game", "export_presets.cfg")
TEMPLATE = os.path.join(DEV, "tools", "godot_template", "windows_release_x86_64_encrypted.exe").replace("\\", "/")

raw = open(PRESETS, "rb").read()
nl = "\r\n" if b"\r\n" in raw else "\n"
text = io.open(PRESETS, encoding="utf-8").read()
new, n = re.subn(r'^(custom_template/release=)"[^"]*godot_template/[^"]*"$', lambda m: m.group(1) + '"%s"' % TEMPLATE, text, flags=re.M)
if new != text:
    io.open(PRESETS, "w", encoding="utf-8", newline=nl).write(new)
    print("[경로] 암호화 템플릿 경로를 지금 위치로 고침 (%d곳)" % n)
if not os.path.isfile(TEMPLATE):
    print("[경로] 주의: 템플릿 파일이 없음 → %s" % TEMPLATE)
