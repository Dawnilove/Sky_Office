extends RefCounted
## 에이전트 상태 판단 (PLAN 5장 · 7장 · 9-2) — 순수 함수 2개, 화면 · 파일과 상관없음 → 녹화한 이벤트로 시험
##   reduce(상태, 이벤트) → 새 상태   (이벤트 1개를 상태에 적용. 들어온 상태는 바꾸지 않음)
##   decide(상태, 지금)   → 세션별 표시 상태 (우선순위 · 내 차례 단계 · 끝 30초 · 무소식 · 퇴근)
## 상태는 JSON 으로 그대로 저장되는 사전 (스냅샷, 7-1). 시각은 모두 유닉스 초 (float)
## 이벤트 = bell.exe 기록을 줄인 사전: {"t", "event", "sess", "proj", "ntype", "tool", "bg_running", "is_interrupt", "agent_type", "aid", "reason"}
##   관찰 모드 = {"t", "event": "jsonl", "sess", "proj", "mtime", "closed"} (세션 기록 .jsonl 수정 시각, 7-6)
##     closed = .jsonl 마지막 줄 종류가 cost-state (Claude 가 꺼질 때 씀). 앱 꺼짐 · 튕김은 SessionEnd 가 안 와서 이걸로 퇴근 (M4 사용자 결정)
## 3초 유지 · 이동 · 소리 제한은 표현 층 (office_routine, M3 3세션째) 이 맡음. 여기선 '지금 무엇인가' 만

const TIMINGS := "res://data/timings.json"

## 표시 상태 우선순위 (5-3, 결정 12): 내 차례 > 일하는 중 > 끝 > 쉼. 회사 일과는 M5
const PRIORITY := ["turn", "unknown", "work", "watch", "done", "rest", "off"]
## '내 차례' 를 푸는 확실한 신호 (5-2)
const RELEASE := ["UserPromptSubmit", "Stop", "StopFailure", "SessionEnd"]
## 하는 일이 있다는 신호 (무소식 시계를 다시 맞춤)
const ACTIVE := ["UserPromptSubmit", "PostToolUse", "PostToolUseFailure", "SubagentStart", "SubagentStop", "PreCompact"]
## 처리하는 이벤트 (7-4 등록 훅 11개 + 관찰 모드). 나머지는 무시
const KNOWN := ["SessionStart", "UserPromptSubmit", "PostToolUse", "PostToolUseFailure", "Notification", "Stop", "StopFailure",
		"SubagentStart", "SubagentStop", "PreCompact", "SessionEnd", "jsonl"]

static var _tm := {}


static func timings() -> Dictionary:
	if _tm.is_empty():
		_tm = JSON.parse_string(FileAccess.get_file_as_string(TIMINGS))
	return _tm


static func empty() -> Dictionary:
	return {"v": 1, "sessions": {}, "last_file": ""}


## 새 세션 (첫 신호에서 프로젝트 고정, 7-3)
static func _new_session(e: Dictionary) -> Dictionary:
	var t := float(e.get("t", 0.0))
	return {
		"proj": str(e.get("proj", "")), "agent": str(e.get("agent", "claude")),
		"hooked": false,     # 훅 신호를 한 번이라도 받았는지 (아니면 관찰 모드만)
		"phase": "idle",     # idle (쉼) · work · done · off — 마지막 신호로 정한 바탕 상태
		"start": t, "last": t, "work_start": -1.0, "done_at": -1.0, "long": false,
		"turn_at": -1.0,     # 내 차례 알림 시각 (-1 = 아님)
		"turn_aid": "",      # 내 차례를 낸 서브에이전트 (aid, 본 에이전트 = "")
		"turn_count": 0, "released": "",   # 마지막 해제 방법 (시험 · 직원 카드용): signal · tool · jsonl
		"bg": 0, "tool": "", "tool_at": -1.0, "fail_at": -1.0, "stop_at": -1.0, "compact_at": -1.0,   # stop_at = Esc (is_interrupt, 멈춤 손 C16)
		"jsonl": -1.0, "end_at": -1.0, "closed": false,   # closed = .jsonl 로 본 꺼짐 (다시 열면 풀림)
		"agent_types": [],   # 서브에이전트 역할 이름 — 1.0 은 기록만 (5-1)
		"subagents": 0, "envelopes": [],   # 끝난 서브에이전트 시각 (봉투 연출용, 최근 4개)
		"subs": {},          # 지금 일하는 서브에이전트 {aid: {type, t, tool, tool_at}} — 역할 이름 있는 것만 (M6-1 전문가 직원)
		"prompt_at": -1.0,   # 마지막으로 일을 준 시각 (UserPromptSubmit → 종이비행기 연출, v2.8 C4)
	}


## 이벤트 1개 적용 → 새 상태. 모르는 이벤트는 그대로 돌려줌
static func reduce(state: Dictionary, e: Dictionary) -> Dictionary:
	var ns := state.duplicate(true)
	var sid := str(e.get("sess", ""))
	var ev := str(e.get("event", ""))
	if sid == "" or not (ev in KNOWN):
		return ns
	var t := float(e.get("t", 0.0))
	var tm := timings()
	if not ns.sessions.has(sid):
		ns.sessions[sid] = _new_session(e)
	var s: Dictionary = ns.sessions[sid]
	if not s.has("subs"):
		s.subs = {}   # M6-1 전의 저장 스냅샷
	if ev == "jsonl":
		var mt := float(e.get("mtime", t))
		s.jsonl = maxf(float(s.jsonl), mt)
		if bool(e.get("closed", false)):   # 꺼짐 (보관은 SessionEnd 도 옴) → 바로 퇴근
			s.phase = "off"
			s.closed = true
			s.end_at = mt
			s.last = maxf(float(s.last), mt)
			s.bg = 0
			s.subagents = 0
			s.subs = {}
			s.turn_at = -1.0
			return ns
		if bool(s.get("closed", false)) and s.phase == "off" and mt > float(s.end_at):
			s.closed = false   # 꺼졌던 세션을 다시 엶 (마지막 줄 뒤에 새 줄) → 쉼부터
			s.phase = "idle"
			s.last = mt
			return ns
		if not s.hooked:
			s.last = maxf(float(s.last), mt)
			if s.phase == "off":
				s.phase = "idle"
		elif float(s.turn_at) >= 0.0 and mt > float(s.turn_at):
			_release(s, "jsonl", mt)   # 거절 · Esc 는 훅 신호가 없고 .jsonl 만 바뀜 (M0) → '처리됨 (추정)'
		return ns
	s.hooked = true
	if ev in ACTIVE:
		s.last = t
		if s.phase in ["idle", "done", "off"] and ev != "SubagentStop":
			s.phase = "work"
			if float(s.work_start) < 0.0 or ev == "UserPromptSubmit":
				s.work_start = t
	match ev:
		"SessionStart":
			s.phase = "idle"
			s.start = t
			s.last = t
			s.end_at = -1.0
			s.closed = false
		"UserPromptSubmit":
			s.work_start = t
			s.prompt_at = t
			s.phase = "work"
		"PostToolUse", "PostToolUseFailure":
			s.tool = str(e.get("tool", ""))
			s.tool_at = t
			var sub_id := str(e.get("aid", ""))
			if s.subs.has(sub_id):
				s.subs[sub_id].tool = str(e.get("tool", ""))
				s.subs[sub_id].tool_at = t
			if ev == "PostToolUseFailure" and not bool(e.get("is_interrupt", false)):
				s.fail_at = t
			elif ev == "PostToolUseFailure":
				s.stop_at = t   # Esc 로 멈춤 → 손 들고 멈춤 (실패 땀방울 아님)
			# 알림 2초 뒤 이후의 도구 신호만 해제 (병렬 도구의 늦은 신호가 진짜 '내 차례' 를 지우지 않게, 5-2)
			# 서브에이전트 (aid) 도구 신호는 부모와 같은 세션으로 옴 → 알림을 낸 쪽 (같은 aid) 의 도구 신호만 해제 (v2.8 ①)
			if float(s.turn_at) >= 0.0 and t - float(s.turn_at) >= float(tm.turn_release_after_s) \
					and str(e.get("aid", "")) == str(s.get("turn_aid", "")):
				_release(s, "tool", t)
		"Notification":
			match str(e.get("ntype", "")):
				"permission_prompt":   # 허락 · AskUserQuestion 둘 다 (M0)
					if float(s.turn_at) < 0.0:
						s.turn_at = t   # 이미 내 차례면 처음 시각 유지 ("14:02부터")
						s.turn_count = int(s.turn_count) + 1
						s.turn_aid = str(e.get("aid", ""))   # 누가 불렀나 (본 에이전트 = "")
					s.last = t
					if s.phase in ["idle", "done", "off"]:
						s.phase = "work"
				"idle_prompt":   # Stop 60초 뒤 (M0) → 쉼
					if s.phase == "done":
						s.phase = "idle"
		"Stop", "StopFailure":
			s.last = t
			s.bg = int(e.get("bg_running", 0))
			if int(s.bg) > 0:
				s.phase = "work"   # 백그라운드 작업이 돌고 있으면 '끝' 이 아니라 '작업 중' (M0 확정 규칙 ①)
			else:
				s.phase = "done"
				s.done_at = t
				s.long = float(s.work_start) >= 0.0 and t - float(s.work_start) > float(tm.long_work_s)
				s.work_start = -1.0
		"SubagentStart":
			var at := str(e.get("agent_type", ""))
			if at != "" and not (at in s.agent_types):
				s.agent_types.append(at)
			s.subagents = int(s.subagents) + 1
			if at != "" and str(e.get("aid", "")) != "":   # 역할 이름 없는 것은 전문가로 안 보임 (실측: 빈 이름 Stop 38건)
				s.subs[str(e.aid)] = {"type": at, "t": t, "tool": "", "tool_at": -1.0}
		"SubagentStop":
			s.subagents = maxi(0, int(s.subagents) - 1)
			s.subs.erase(str(e.get("aid", "")))
			s.envelopes.append(t)
			if s.envelopes.size() > 4:
				s.envelopes = s.envelopes.slice(-4)
		"PreCompact":
			s.compact_at = t
		"SessionEnd":
			s.phase = "off"
			s.end_at = t
			s.last = t
			s.bg = 0
			s.subs = {}
	if ev in RELEASE and float(s.turn_at) >= 0.0:
		_release(s, "signal", t)
	return ns


static func _release(s: Dictionary, how: String, t: float) -> void:
	s.turn_at = -1.0
	s.released = how
	s.last = maxf(float(s.last), t)   # 내 차례 대기 중엔 무소식 시간을 세지 않음 (결정 9) → 풀린 때부터 다시 셈


## 지금 각 세션이 어떻게 보여야 하는지: {세션 id: {"state", "since", "stage", "tool", "fail", "check", "long", "guess"}}
##   state: turn · unknown · work · watch (관찰 모드 '활동 중' 추정) · done · rest · off
##   stage (turn 만): 0 = 즉시 (자리에서 작은 "!") · 1 = 15초 (창구 · '딩') · 2 = 3분 (한 번 다시 알림)
static func decide(state: Dictionary, now: float) -> Dictionary:
	var out := {}
	for sid in state.sessions:
		out[sid] = view(state.sessions[sid], now)
	return out


static func view(s: Dictionary, now: float) -> Dictionary:
	var tm := timings()
	var v := {"state": "off", "since": float(s.last), "stage": 0, "tool": "", "fail": false, "stop": false, "check": false, "long": false, "guess": false}
	if s.phase == "off" or now - float(s.last) >= float(tm.leave_s):
		return v   # 퇴근: SessionEnd 또는 신호 없음 1시간 (M4 사용자 결정, 전 3시간)
	if not s.hooked:   # 관찰 모드: '활동 중' (반투명 = 추정) / '쉼' 두 가지만 (5-1)
		var active := now - float(s.jsonl) < float(tm.watch_active_s)
		v.state = "watch" if active else "rest"
		v.guess = true
		return v
	var turn_at := float(s.turn_at)
	if turn_at >= 0.0:
		var el := now - turn_at
		v.since = turn_at
		if el >= float(tm.turn_limit_s):
			v.state = "unknown"   # 30분 상한 → 회색 "?" (결정 9 보완)
		else:
			v.state = "turn"
			v.stage = 0 if el < float(tm.turn_walk_s) else (1 if el < float(tm.turn_remind_s) else 2)
		return v
	match str(s.phase):
		"work":
			v.tool = str(s.tool)
			v.fail = float(s.fail_at) >= 0.0 and now - float(s.fail_at) < float(tm.fail_show_s)
			v.stop = float(s.get("stop_at", -1.0)) >= 0.0 and now - float(s.stop_at) < float(tm.get("stop_show_s", 4))
			if int(s.bg) == 0 and int(s.subagents) == 0 and now - float(s.last) >= float(tm.quiet_s):
				v.state = "unknown"   # 무소식 12분 → 꾸벅 + 회색 "?" (모르면 모른다고)
			else:
				v.state = "work"
				v.since = float(s.work_start) if float(s.work_start) >= 0.0 else float(s.last)
		"done":
			var el := now - float(s.done_at)
			v.since = float(s.done_at)
			v.state = "done" if el < float(tm.done_rest_s) else "rest"
			v.check = el < float(tm.done_check_s)   # ✓ 는 30분 뒤 사라짐
			v.long = bool(s.long)
		_:
			v.state = "rest"
			v.since = float(s.last)
			v.check = float(s.done_at) >= 0.0 and now - float(s.done_at) < float(tm.done_check_s)
	return v


## 둘 중 더 급한 표시 상태 (같은 직원 · 칩 바 순서용)
static func more_urgent(a: String, b: String) -> String:
	return a if PRIORITY.find(a) <= PRIORITY.find(b) else b


## 오래 꺼진 세션 지우기 (스냅샷이 끝없이 커지지 않게) — 직원 기록은 staff_registry 가 따로 가짐
static func prune(state: Dictionary, now: float) -> Dictionary:
	var ns := state.duplicate(true)
	var keep := float(timings().forget_off_s)
	for sid in ns.sessions.keys():
		var s: Dictionary = ns.sessions[sid]
		if now - float(s.last) >= keep:
			ns.sessions.erase(sid)
	return ns


## 녹화 줄 (bell.exe --record 를 줄인 fixture) → 상태. 시험 · 다시 켤 때 공통
static func replay(lines: Array, state := {}) -> Dictionary:
	var st := empty() if state.is_empty() else state
	for e in lines:
		st = reduce(st, e)
	return st
