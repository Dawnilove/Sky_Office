extends RefCounted
## 회사 옷 (PLAN 5-7 C20 · C21 · C29 · 6-2 · 6-4, M5 3세션째) — 저장 파일의 "firm" 칸, 순수 함수 (시험 가능)
##   name = 회사 이름 ("" = 기본 이름) · founded = 창업 화면을 거쳤는지 · salt = 해시 직원 솔트 (설치 때 1번)
##   plates = {직원 id 글자: {"name", "team"}} — 명패 (빈 글자 = 자동). 키가 있으면 입사식을 마친 직원
##   today = 오늘 (게임 하루) 기록 {"day": win_start, "staff": [직원 id], "done", "turn"} → 하루가 바뀌면 결재함 한 장 (ledger)
##   ledger = 결재함 [{"day": 출근부 n일째, "t": 하루 시작, "staff": [직원 이름], "done", "turn"}] 최근 LEDGER_MAX 장
## 폴더 (프로젝트) 이름은 여기에 넣지 않음 (5-7 명패)

const DEFAULT_NAME := "하늘 오피스"
const NAME_MAX := 8          ## 회사 이름 최대 글자 (간판에 들어가게)
const PLATE_MAX := 6         ## 직원 · 팀 이름 최대 글자 (이름판 줄 길이)
const LEDGER_MAX := 7        ## 결재함은 최근 7장만 (자동 정리, 비우기 클릭 없음)


static func empty() -> Dictionary:
	return {"name": "", "founded": false, "salt": "", "plates": {}, "today": empty_today(-1.0), "ledger": []}


static func empty_today(day: float) -> Dictionary:
	return {"day": day, "staff": [], "done": 0, "turn": 0}


## 솔트 = 무작위 16바이트 (hex 32자). 같은 PC 에선 늘 같은 직원, 얼굴로 프로젝트 이름 추측 불가 (C20)
static func new_salt() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## 저장에서 불러온 값 → 모르는 키 버리고 빠진 키 채움
static func normalize(v: Variant) -> Dictionary:
	var out := empty()
	if typeof(v) == TYPE_DICTIONARY:
		for k in out:
			if v.has(k) and typeof(v[k]) == typeof(out[k]):
				out[k] = v[k]
	out.name = clean_name(str(out.name), NAME_MAX)
	var t: Dictionary = empty_today(-1.0)
	for k in t:
		if out.today.has(k):
			t[k] = out.today[k]
	t.done = int(t.done)
	t.turn = int(t.turn)
	t.staff = (t.staff as Array).map(func(x): return int(x))
	out.today = t
	var pl := {}
	for id in out.plates:
		var p = out.plates[id]
		if typeof(p) == TYPE_DICTIONARY:
			pl[str(id)] = {"name": clean_name(str(p.get("name", "")), PLATE_MAX), "team": clean_name(str(p.get("team", "")), PLATE_MAX)}
	out.plates = pl
	if out.ledger.size() > LEDGER_MAX:
		out.ledger = out.ledger.slice(out.ledger.size() - LEDGER_MAX)
	return out


## 이름 다듬기: 앞뒤 공백 · 줄바꿈 빼고 n 글자까지
static func clean_name(s: String, n: int) -> String:
	return s.replace("\n", " ").replace("\t", " ").strip_edges().left(n)


## 간판 글자
static func sign_name(f: Dictionary) -> String:
	var n := str(f.get("name", ""))
	return n if n != "" else DEFAULT_NAME


## 오늘 기록에 더하기 (kind = "done" · "turn" · "staff") → 새 firm
static func count(f: Dictionary, kind: String, staff_id: int, day: float, names := {}) -> Dictionary:
	var nf := f.duplicate(true)
	if float(nf.today.day) != day:
		nf = close_day(nf, -1, names, day)   # 하루가 바뀐 뒤 첫 기록 (day_started 를 놓친 경우 — 예: 꺼져 있었음)
	match kind:
		"done", "turn":
			nf.today[kind] = int(nf.today[kind]) + 1
	if staff_id >= 0 and not (staff_id in nf.today.staff):
		nf.today.staff.append(staff_id)
	return nf


## 하루 마감 → 결재함 한 장 (기록이 없는 날은 안 꽂음) · 새 오늘. days = 그날 출근부 번호 (-1 = 모름 → 이전 장 + 1)
##   names = {직원 id: 이름} — 장에는 이름만 (폴더 이름 없음)
static func close_day(f: Dictionary, days: int, names: Dictionary, next_day: float) -> Dictionary:
	var nf := f.duplicate(true)
	var t: Dictionary = nf.today
	if next_day >= 0.0 and float(t.day) == next_day:
		return nf   # 이미 그 하루 (셈이 먼저 마감함) — 두 번 마감하지 않음
	if float(t.day) >= 0.0 and (int(t.done) > 0 or int(t.turn) > 0 or not (t.staff as Array).is_empty()):
		if days < 0:
			days = int(nf.ledger[-1].day) + 1 if not nf.ledger.is_empty() else 1
		var who: Array = []
		for id in t.staff:
			who.append(str(names.get(int(id), names.get(str(id), "직원 %d" % (int(id) + 1)))))
		nf.ledger.append({"day": days, "t": float(t.day), "staff": who, "done": int(t.done), "turn": int(t.turn)})
		if nf.ledger.size() > LEDGER_MAX:
			nf.ledger = nf.ledger.slice(nf.ledger.size() - LEDGER_MAX)
	nf.today = empty_today(next_day)
	return nf


## 입사식이 필요한 직원 id (명패가 아직 없는 책상 직원, 입사 순)
static func need_ceremony(f: Dictionary, reg: Dictionary) -> Array:
	var out: Array = []
	for s in reg.get("staff", []):
		if not bool(s.leave) and int(s.desk) >= 0 and not f.plates.has(str(int(s.id))):
			out.append(int(s.id))
	return out


## 명패 정하기 (빈 글자 = 자동) → 새 firm
static func set_plate(f: Dictionary, staff_id: int, plate_name: String, team: String) -> Dictionary:
	var nf := f.duplicate(true)
	nf.plates[str(staff_id)] = {"name": clean_name(plate_name, PLATE_MAX), "team": clean_name(team, PLATE_MAX)}
	return nf


## 돌아오면 요약 글 ("" = 띄울 것 없음): "비운 동안: 완료 2 · 기다림 1" (6-4)
static func away_text(done: int, turn: int) -> String:
	var parts: Array = []
	if done > 0:
		parts.append("완료 %d" % done)
	if turn > 0:
		parts.append("기다림 %d" % turn)
	return "" if parts.is_empty() else "비운 동안: " + " · ".join(parts)
