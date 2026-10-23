extends RefCounted
## 직원 배정 (PLAN 4-1 · 9-2 · 결정 4-1 · v2.0 검토 후 결정) — 순수 함수, 화면 · 파일과 상관없음
##   직원 = (에이전트, 프로젝트 키) 하나에 1명. 같은 조합 = 늘 같은 직원, 처음 보는 조합 = 빈 책상 순서대로 다음 직원
##   touch(기록, 에이전트, 프로젝트, 활동 시각, 지금) → 입사 · 복직 (책상은 sync 에서)
##   sync(기록, 책상 수, 지금) → 2주 안 쓴 직원 휴직 (책상 비움) → 책상 없는 직원에게 빈 책상 (낮은 id 부터), 없으면 파견
##   assign(기록, 에이전트 상태, 지금, 붙은 배정) → 세션 → 직원. 1.1 직원 풀 B (단골 우선): 단골 직원이 비어 있으면 그 직원, 아니면 놀고 있는 직원이 지원 근무, 없으면 인턴.
##     같은 조합 동시 세션의 두 번째부터 = 인턴 (메인 직원을 거쳐 보고)
## 기록은 JSON 그대로 저장되는 사전 (state.json 의 "staff", 좌표 대신 책상 슬롯 id · 직원 id):
##   {"v": 1, "next": 다음 직원 id, "staff": [{id, agent, proj, desk, home, hired, last, leave, dispatch}]}
##   desk = 지금 책상 (layout.desks() 의 id, -1 = 없음) · home = 마지막으로 받은 책상 (복직 때 비어 있으면 그 자리)
## 빈 책상이 없을 때만 파견: 휴직이 책상을 비우므로 '빈 책상 없음' = '최근 2주 조합 > 책상 수' (결정 4-1)
## 송별 · 휴직 목록 화면은 나중 (1.0 자르는 순서: 송별 · 복직 연출 미루기)

const VERSION := 1
const SERVE_STEP_S := 600.0
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
##   desks >= 0 이면 직원이 책상 수만큼 찼을 때 새 조합은 입사 안 함 (1.1 풀 B — 그 조합은 지원 근무 · 인턴이 맡음)
static func touch(reg: Dictionary, agent: String, proj: String, t: float, now: float, desks := -1) -> Dictionary:
	var nr := reg.duplicate(true)
	if proj == "":
		return nr
	var i := find(nr, agent, proj)
	if i >= 0:
		var s: Dictionary = nr.staff[i]
		s.last = maxf(float(s.last), t)
		if s.get("done", false) and t > float(s.get("done_at", 0.0)):
			s.done = false   # 끝낸 프로젝트를 다시 열면 원래 직원이 단골로 복귀 (1.3 [프로젝트 완료])
		if s.leave and now - float(s.last) < leave_s():
			s.leave = false   # 같은 직원 복직 (책상은 sync)
		return nr
	if now - t >= leave_s():
		return nr
	if desks >= 0 and nr.staff.filter(func(s): return not s.leave).size() >= desks:
		return nr
	nr.staff.append({"id": int(nr.next), "agent": agent, "proj": proj, "desk": -1, "home": -1,
			"hired": t, "last": t, "leave": false, "dispatch": false})
	nr.next = int(nr.next) + 1
	return nr


## [프로젝트 완료] (1.3): 그 직원의 단골 표시를 뺌 (직원은 남음 · 놀고 있는 직원으로 지원 근무). 같은 프로젝트의 새 활동이 오면 touch 가 원래 직원을 복귀시킴
static func finish(reg: Dictionary, id: int, now: float) -> Dictionary:
	var nr := reg.duplicate(true)
	for s in nr.staff:
		if int(s.id) == id:
			s.done = true
			s.done_at = now
	return nr


## 휴직 · 책상 배정 → 새 기록 (책상 수가 늘면 = 증축 → 파견 직원 정식 배정)
static func sync(reg: Dictionary, desks: int, now: float, serving := []) -> Dictionary:
	var nr := reg.duplicate(true)
	var used := {}
	for s in nr.staff:
		if int(s.id) in serving and now - float(s.last) >= SERVE_STEP_S:
			s.last = now   # 지원 근무 · 살아 있는 세션을 맡은 직원은 휴직 안 함 (저장이 매 확인마다 바뀌지 않게 10분 단위)
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


## 지금 열린 세션 → {세션 id: {"staff": 직원 id (-1 = 직원 없음), "temp": 인턴인지, "solo": 직원 없는 인턴, "cover": 지원 근무}} (1.1 풀 B)
##   같은 조합 (에이전트 + 프로젝트) 의 먼저 연 세션 = 메인, 나머지 = 인턴 (메인 직원을 거쳐 보고, 4-1)
##   메인의 직원: ① 붙은 배정 (prev — 세션이 살아 있는 동안 안 놓음) ② 단골 직원 (그 조합으로 입사한 직원) ③ 놀고 있는 직원 중 가장 오래 쉰 직원 (지원 근무) ④ 없으면 직원 없는 인턴
static func assign(reg: Dictionary, state: Dictionary, now: float, prev := {}) -> Dictionary:
	var live := []
	for sid in state.sessions:
		var s: Dictionary = state.sessions[sid]
		if AgentState.view(s, now).state == "off" or str(s.proj) == "":
			continue
		live.append([float(s.start), str(sid)])
	live.sort()
	var mains := {}   # 조합 → 메인 세션 id
	var order := []   # 메인 세션 (먼저 연 순)
	for e in live:
		var s: Dictionary = state.sessions[e[1]]
		var ck := str(s.agent) + "|" + str(s.proj)
		if not mains.has(ck):
			mains[ck] = e[1]
			order.append(e[1])
	var emp := {}     # 메인 세션 → 직원 id
	var taken := {}
	for sid in order:   # ① 붙은 배정
		var st := staff_by_id(reg, int(prev.get(sid, -1)))
		if not st.is_empty() and not st.leave and not st.get("done", false) and not taken.has(int(st.id)):
			emp[sid] = int(st.id)
			taken[int(st.id)] = true
	for sid in order:   # ② 단골
		if emp.has(sid):
			continue
		var s: Dictionary = state.sessions[sid]
		var i := find(reg, str(s.agent), str(s.proj))
		if i >= 0 and not reg.staff[i].leave and not reg.staff[i].get("done", false) and not taken.has(int(reg.staff[i].id)):
			emp[sid] = int(reg.staff[i].id)
			taken[int(reg.staff[i].id)] = true
	for sid in order:   # ③ 지원 근무
		if emp.has(sid):
			continue
		var pick := {}
		for st in reg.staff:
			if st.leave or int(st.desk) < 0 or taken.has(int(st.id)):
				continue
			if pick.is_empty() or float(st.last) < float(pick.last):
				pick = st
		if not pick.is_empty():
			emp[sid] = int(pick.id)
			taken[int(pick.id)] = true
	var out := {}
	for e in live:
		var sid: String = e[1]
		var s: Dictionary = state.sessions[sid]
		var main: String = mains[str(s.agent) + "|" + str(s.proj)]
		var id := int(emp.get(main, -1))
		var st := staff_by_id(reg, id)
		var is_main := main == sid
		out[sid] = {"staff": id, "temp": not is_main or id < 0, "solo": id < 0,
				"cover": is_main and id >= 0 and (str(st.agent) != str(s.agent) or str(st.proj) != str(s.proj))}
	return out


## 지금 살아 있는 세션을 맡은 (인턴 아닌) 직원 id 목록 — sync 가 휴직에서 지킴
static func serving(reg: Dictionary, state: Dictionary, now: float) -> Array:
	var out := []
	var asg := assign(reg, state, now)
	for sid in asg:
		if not asg[sid].temp:
			out.append(int(asg[sid].staff))
	return out


## 이름판 색 줄의 기준 (1.1 풀 B): 단골 직원이 있는 프로젝트 = 그 직원 id (예전 색 그대로), 없으면 프로젝트 해시. 누가 맡든 같은 프로젝트 = 같은 색
static func color_key(reg: Dictionary, agent: String, proj: String) -> int:
	var i := find(reg, agent, proj)
	return int(reg.staff[i].id) if i >= 0 else absi(proj.hash())


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
