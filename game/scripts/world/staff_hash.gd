extends RefCounted
## 해시 직원 (PLAN 5-7 C20, M5 3세션째) — 순수 함수
##   SHA-256(솔트 | 에이전트 | 프로젝트 해시) 의 바이트로 이름 · 얼굴 (머리색 + 장신구) · 셔츠 색 · 성격 · 자동 팀 이름을 고름
##   솔트 = 설치 때 1번 (Game.firm.salt) → 같은 PC 에선 늘 같은 직원, 다른 PC 와는 다름 (얼굴로 프로젝트 추측 불가)
##   이름이 겹치면 먼저 입사한 직원 (id 작은 쪽) 이 갖고 뒤 직원은 해시 순서로 다음 이름
##   옷 모양 (셔츠 · 후드 · 니트) 은 출근마다 무작위 그대로 (4-2)

## 기본 이름 36개 (4-2 '기본 이름 목록에서 자동')
const NAMES := ["민준", "서연", "도윤", "하은", "지호", "수아", "예준", "지우", "시우", "서윤", "주원", "하린",
		"은우", "지아", "유준", "채원", "건우", "다은", "선우", "윤서", "연우", "소율", "이안", "예린",
		"준서", "나은", "현우", "가은", "로운", "시아", "태오", "하윤", "도현", "아린", "우진", "새봄"]
## 자동 팀 이름 (입사식에서 비우면) — '구름팀'
const TEAMS := ["구름", "바람", "별빛", "햇살", "노을", "새벽", "물결", "단풍", "솔잎", "은하", "무지개", "초승달"]
## 고르는 칸 수 (office.gd 의 SHIRTS · HAIRS · ACCESSORIES · idle_weights personalities 와 같은 길이)
const N_SHIRT := 12
const N_HAIR := 6
const N_ACC := 4
const N_PERSON := 4


static func digest(salt: String, agent: String, proj: String) -> PackedByteArray:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(("%s|%s|%s" % [salt, agent, proj]).to_utf8_buffer())
	return c.finish()


## 바이트 2개 → 0 ~ n-1
static func _pick(b: PackedByteArray, at: int, n: int) -> int:
	return (int(b[at]) * 256 + int(b[at + 1])) % n


## 겉모습 번호: {"name": 이름 번호, "shirt", "hair", "acc", "person", "team"}
static func look(salt: String, agent: String, proj: String) -> Dictionary:
	var b := digest(salt, agent, proj)
	return {"name": _pick(b, 0, NAMES.size()), "shirt": _pick(b, 2, N_SHIRT), "hair": _pick(b, 4, N_HAIR),
			"acc": _pick(b, 6, N_ACC), "person": _pick(b, 8, N_PERSON), "team": _pick(b, 10, TEAMS.size())}


## 자동 팀 이름
static func team_name(lk: Dictionary) -> String:
	return TEAMS[int(lk.team)] + "팀"


## 직원 기록 → {직원 id: {"look": 겉모습 번호, "name": 보일 이름, "team": 보일 팀 이름}}
##   plates = Game.firm.plates (명패에서 바꾼 이름 · 팀, 빈 글자 = 자동). 자동 이름 · 자동 팀은 서로 안 겹치게 (입사 순서대로)
static func staff_looks(reg: Dictionary, salt: String, plates: Dictionary) -> Dictionary:
	var out := {}
	var ids: Array = []
	for s in reg.get("staff", []):
		ids.append([int(s.id), s])
	ids.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var used := {}
	var used_team := {}
	for p in plates.values():
		if str(p.get("name", "")) != "":
			used[str(p.name)] = true   # 직접 지은 이름은 자동 이름이 피함
		if str(p.get("team", "")) != "":
			used_team[str(p.team)] = true
	for e in ids:
		var s: Dictionary = e[1]
		var lk := look(salt, str(s.agent), str(s.proj))
		var pl: Dictionary = plates.get(str(e[0]), {})
		var nm := str(pl.get("name", ""))
		if nm == "":
			var k := int(lk.name)
			for j in NAMES.size():   # 해시 자리부터 차례로 빈 이름
				if not used.has(NAMES[(k + j) % NAMES.size()]):
					k = (k + j) % NAMES.size()
					break
			nm = NAMES[k]
		used[nm] = true
		var tm := str(pl.get("team", ""))
		if tm == "":
			for j in TEAMS.size():   # 자동 팀도 해시 자리부터 차례로 빈 이름 (12팀 넘으면 겹침 허용)
				var t2: String = TEAMS[(int(lk.team) + j) % TEAMS.size()] + "팀"
				if not used_team.has(t2):
					tm = t2
					break
			if tm == "":
				tm = team_name(lk)
		used_team[tm] = true
		out[e[0]] = {"look": lk, "name": nm, "team": tm}
	return out
