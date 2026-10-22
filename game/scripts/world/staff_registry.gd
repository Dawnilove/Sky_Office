extends RefCounted
## 직원 배정 (PLAN 4-1 · 9-2 · 결정 4-1 · v2.0 검토 후 결정) — 순수 함수, 화면 · 파일과 상관없음
##   직원 = (에이전트, 프로젝트 키) 하나에 1명. 같은 조합 = 늘 같은 직원, 처음 보는 조합 = 빈 책상 순서대로 다음 직원
##   touch(기록, 에이전트, 프로젝트, 활동 시각, 지금) → 입사 · 복직 (책상은 sync 에서)
##   sync(기록, 책상 수, 지금) → 2주 안 쓴 직원 휴직 (책상 비움) → 책상 없는 직원에게 빈 책상 (낮은 id 부터), 없으면 파견
##   assign(기록, 에이전트 상태, 지금) → 세션 → 직원. 같은 조합 동시 세션의 두 번째부터 = 임시 파견
## 기록은 JSON 그대로 저장되는 사전 (state.json 의 "staff", 좌표 대신 책상 슬롯 id · 직원 id):
##   {"v": 1, "next": 다음 직원 id, "staff": [{id, agent, proj, desk, home, hired, last, leave, dispatch}]}
##   desk = 지금 책상 (layout.desks() 의 id, -1 = 없음) · home = 마지막으로 받은 책상 (복직 때 비어 있으면 그 자리)
## 빈 책상이 없을 때만 파견: 휴직이 책상을 비우므로 '빈 책상 없음' = '최근 2주 조합 > 책상 수' (결정 4-1)
## 송별 · 휴직 목록 화면은 나중 (1.0 자르는 순서: 송별 · 복직 연출 미루기)

const VERSION := 1
const AgentState := preload("res://scripts/world/agent_state.gd")


static func empty() -> Dictionary:
	return {"v": VERSION, "next": 0, "staff": [], "roles": {}}


## 휴직 기준 (초): timings.json staff_leave_days (14일)
static func leave_s() -> float:
	return float(AgentState.timings().staff_leave_days) * 86400.0


## (에이전트, 프로젝트) 직원의 목록 위치 (-1 = 없음)
static func find(reg: Dictionary, agent: String, proj: String) -> int:
	for i in reg.staff.size():
		if reg.staff[i].agent == agent and reg.staff[i].proj == proj:
			return i
	return -1


## 활동 1번 → 새 기록. 2주보다 오래된 활동으로는 입사하지 않음 (첫 실행 = 최근 2주 조합만)
static func touch(reg: Dictionary, agent: String, proj: String, t: float, now: float) -> Dictionary:
	var nr := reg.duplicate(true)
	if proj == "":
		return nr
	var i := find(nr, agent, proj)
	if i >= 0:
		var s: Dictionary = nr.staff[i]
		s.last = maxf(float(s.last), t)
		if s.leave and now - float(s.last) < leave_s():
			s.leave = false   # 같은 직원 복직 (책상은 sync)
		return nr
	if now - t >= leave_s():
		return nr
	nr.staff.append({"id": int(nr.next), "agent": agent, "proj": proj, "desk": -1, "home": -1,
			"hired": t, "last": t, "leave": false, "dispatch": false})
	nr.next = int(nr.next) + 1
	return nr


## 휴직 · 책상 배정 → 새 기록 (책상 수가 늘면 = 증축 → 파견 직원 정식 배정)
static func sync(reg: Dictionary, desks: int, now: float) -> Dictionary:
	var nr := reg.duplicate(true)
	var used := {}
	for s in nr.staff:
		if not s.leave and now - float(s.last) >= leave_s():
			s.leave = true   # 2주 안 씀 → 휴직 (소품 상자 보관, 책상 비움)
		if s.leave or int(s.desk) >= desks:
			s.desk = -1
		if int(s.desk) >= 0:
			used[int(s.desk)] = true
	for s in nr.staff:   # 목록 순서 = 입사 순서
		if s.leave:
			s.dispatch = false
			continue
		if int(s.desk) < 0:
			s.desk = _free_desk(used, desks, int(s.home))
			if int(s.desk) >= 0:
				used[int(s.desk)] = true
				s.home = int(s.desk)
		s.dispatch = int(s.desk) < 0
	return nr


static func _free_desk(used: Dictionary, desks: int, home: int) -> int:
	if home >= 0 and home < desks and not used.has(home):
		return home
	for d in desks:
		if not used.has(d):
			return d
	return -1


## 전문가 (서브에이전트 역할) 근속 (M6-4 R3): 같은 (프로젝트, 역할) 이 일한 날 수 — day = 지역 시각 기준 날 번호 (같은 날 여러 번은 1일)
static func touch_role(reg: Dictionary, proj: String, role: String, day: int) -> Dictionary:
	if proj == "" or role == "":
		return reg
	var nr := reg.duplicate(true)
	var roles: Dictionary = nr.get("roles", {})
	var k := proj + "|" + role
	var r: Dictionary = roles.get(k, {"days": 0, "day": -1})
	if int(r.day) != day:
		r.days = int(r.days) + 1
		r.day = day
	roles[k] = r
	nr.roles = roles
	return nr


static func role_days(reg: Dictionary, proj: String, role: String) -> int:
	return int(reg.get("roles", {}).get(proj + "|" + role, {}).get("days", 0))


## 지금 열린 세션 → {세션 id: {"staff": 직원 id, "temp": 임시 파견인지}} (입사 안 한 조합의 세션은 빠짐)
##   같은 조합 동시 세션: 먼저 연 세션이 그 직원, 나머지는 임시 파견 (회색 조끼, 4-1 예외)
static func assign(reg: Dictionary, state: Dictionary, now: float) -> Dictionary:
	var groups := {}
	for sid in state.sessions:
		var s: Dictionary = state.sessions[sid]
		if AgentState.view(s, now).state == "off":
			continue
		var i := find(reg, str(s.agent), str(s.proj))
		if i < 0:
			continue
		var id := int(reg.staff[i].id)
		if not groups.has(id):
			groups[id] = []
		groups[id].append([float(s.start), str(sid)])
	var out := {}
	for id in groups:
		var g: Array = groups[id]
		g.sort()
		for k in g.size():
			out[g[k][1]] = {"staff": id, "temp": k > 0}
	return out


## 직원 id → 기록 (없으면 {})
static func staff_by_id(reg: Dictionary, id: int) -> Dictionary:
	for s in reg.staff:
		if int(s.id) == id:
			return s
	return {}


## 저장된 기록 → 지금 버전 (연쇄 이전). 깨졌거나 모르는 모양이면 빈 기록
static func migrate(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("staff")) != TYPE_ARRAY:
		return empty()
	var d: Dictionary = data.duplicate(true)
	var v := int(d.get("v", 0))
	while v < VERSION:
		match v:
			0:   # 버전 번호가 없던 모양 (견본): home · dispatch 가 없음
				for s in d.staff:
					s["home"] = int(s.get("desk", -1))
					s["dispatch"] = false
		v += 1
	d.v = maxi(v, int(d.get("v", 0)))
	if not d.has("next"):
		d.next = d.staff.reduce(func(m, s): return maxi(m, int(s.id) + 1), 0)
	d.next = int(d.next)
	if typeof(d.get("roles")) != TYPE_DICTIONARY:
		d.roles = {}   # M6-4 전 저장 (SAVE_VERSION 그대로)
	for s in d.staff:   # JSON 은 숫자를 소수로 읽음 → id · 책상은 정수로
		for k in ["id", "desk", "home"]:
			s[k] = int(s.get(k, -1))
	return d
