# -*- coding: utf-8 -*-
"""녹화 (bell.exe --record · m0 viewer) → 재생 시험용 fixture (agent_state.gd 가 읽는 모양)

사용 (SkyOffice 폴더에서):
    python tools/replay_fixture.py SkyOffice/m0/recordings/20261015.jsonl SkyOffice/game/scripts/dev/fixtures/replay_m0.jsonl

- 필요한 필드만 남김: 폴더 이름 · 오류 문구 (error_kind) · 모양 정보 (_shape) 등은 버림 (개인정보, 7-2)
- 시각 = 유닉스 초. bell 의 t_start (.NET 100ns, 0001년 기준) 를 바꿈. jsonl 줄은 수정 시각을 그대로 씀
- 시각 순으로 정렬
"""
import json
import sys

TICKS_UNIX = 621355968000000000  # 1970-01-01 의 .NET 틱
KEEP = ("event", "sess", "proj", "ntype", "tool", "bg_running", "is_interrupt", "agent_type", "aid", "reason")


def convert(line: dict):
    if "jsonl_mtime" in line:
        m = float(line["jsonl_mtime"])
        return {"t": round(m, 3), "event": "jsonl", "mtime": round(m, 3), "sess": line.get("sess", ""), "proj": line.get("proj", "")}
    if "event" not in line or "t_start" not in line:
        return None
    out = {"t": round((int(line["t_start"]) - TICKS_UNIX) / 1e7, 3)}
    for k in KEEP:
        if k in line:
            out[k] = line[k]
    return out


def main(src: str, dst: str) -> None:
    rows = []
    with open(src, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if raw:
                r = convert(json.loads(raw))
                if r:
                    rows.append(r)
    rows.sort(key=lambda r: r["t"])
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"{len(rows)}줄 → {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
