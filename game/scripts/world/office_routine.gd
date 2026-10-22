extends Node
## 직원 일과 (M3 3세션째, PLAN 5장 · 4-1 · 결정 6 · 7 · 8 · 12) — 감지기 스냅샷 → 직원별 표시 → office.set_state
##   판단 (agent_state.decide) · 배정 (staff_registry.assign) 은 '지금 무엇인가' 만. 여기서는 '어떻게 보이나':
##   ① 팀원 = 메인 세션 (먼저 연 것, 고정) · 인턴 = 같은 조합의 나머지 세션. 인턴 보고 (내 차례 · 끝 · 봉투) 는 팀원을 거쳐서만 (M4 사용자 결정)
##   ② decide 이름 → office LOOK 이름 (look_of)
##   ③ 최소 3초 유지, 내 차례만 즉시 (결정 7) · 쉬다가 일이 오면 끼어들기 3가지 (결정 8, 바로 반응)
##   ④ '딩' = 창구 도착 · 3분 다시 알림, 여럿이 불러도 30초에 1번 (5-6)
##   ⑤ 봉투 (서브에이전트 끝): 동시 2개 · 누가 내 차례면 멈춤 (5-1 v2.5)
##   ⑤-2 종이비행기 (일 받기, v2.8 C4): 일을 주면 (UserPromptSubmit) 사장 책상 → 그 직원 책상, 받으면 꾸벅. 동시 2개
##   ⑥ 마우스 올림 (ray_pick): 이름판 + 정해진 짧은 말풍선 (3-3)
## 순수 함수 (static) 는 화면 없이 시험 (scenario.gd _m3_routine). 시각은 유닉스 초

const AgentState := preload("res://scripts/world/agent_state.gd")
const StaffRegistry := preload("res://scripts/world/staff_registry.gd")
const Office := preload("res://scripts/world/office.gd")
const RayPick := preload("res://scripts/util/ray_pick.gd")
const StaffHash := preload("res://scripts/world/staff_hash.gd")

signal counted(kind: String, staff_id: int)   ## 결재함 · 돌아오면 요약 (M5 3세션째): "done" 일 끝 · "turn" 내 차례 · "staff" 출근

const HOLD_S := 3.0           ## 깜빡임 방지: 한 번 바뀌면 3초 유지 (결정 7)
const DING_GAP_S := 30.0      ## '딩' 은 30초에 1번까지 (5-6)
const ENVELOPE_MAX := 2       ## 봉투 동시 2개 (5-1)
const INTERN_IDLE_S := 60.0   ## 인턴 (손님) 이 쉬면 1분 뒤 숨김 — 짧은 쉼에 깜빡이지 않게 (M3 4세션째 사용자 결정)
const FAV_DAYS := 5           ## 전문가 단골 자리: 역할 근속 이만큼부터 늘 같은 책상을 먼저 (R5-lite, 직급이 붙는 날과 같음)
const SPEC_MAX := 3           ## 한 세션에서 한꺼번에 보이는 전문가 (서브에이전트) 최대 (M6-1)
const INTERN_MAX := 2        ## 대기 의자에 보이는 인턴 최대 (넘치면 '+N'). 내 차례 인턴은 상한 없이 창구로
## 프로젝트 색 (이름판 왼쪽 줄, M3 5세션째) — 상태 색 (노랑 · 초록 · 하늘색 · 회색) 과 안 헷갈리는 차분한 6색, 직원 id 순서
const PROJECT_COLORS := ["8c64c8", "e07a5f", "4f5d9c", "d46a9f", "2f9e94", "a0785a"]
const TURN_LOOKS := ["turn", "turn15"]
const BUSY := ["work", "watch", "unknown", "turn", "turn15"]   ## '일이 옴' (끼어들기 대상)
const RESTING := ["done", "rest", "meet"]                     ## 휴게 코너 · 회의 탁자에서 쉬는 중
## 끼어들기 (결정 8): 잠깐 문구 · 걷기 전 멈춤 (초). 모두 3초 안에 도착
const INTERRUPT := {
	"cup":  {"say": "컵 들고 갈게요", "delay": 0.0},   # 커피 중 → 컵 들고 자리로
	"jump": {"say": "벌떡!", "delay": 1.0},           # 소파 · 회의 탁자 → 벌떡 · 기지개 1초 → 자리로
	"oops": {"say": "앗!", "delay": 0.0},             # 퇴근 중 → 돌아서 자리로
}
## 말풍선: 도구 종류별 정해 둔 짧은 문구 (12자 이하, 실제 작업 문장 · 파일 · 폴더 이름은 영구 제외, 3-3)
const TOOL_TEXT := {
	"Edit": "고치는 중", "Write": "고치는 중", "MultiEdit": "고치는 중", "NotebookEdit": "고치는 중",
	"Read": "읽는 중", "Grep": "읽는 중", "Glob": "읽는 중", "LS": "읽는 중",
	"Bash": "실행 중", "PowerShell": "실행 중", "BashOutput": "실행 중", "Monitor": "실행 중",
	"WebFetch": "찾아보는 중", "WebSearch": "찾아보는 중",
	"Task": "맡기는 중", "Agent": "맡기는 중", "TodoWrite": "계획 세우는 중",
}

var office: Node3D
var sound: Node               ## sound.gd (없으면 소리 없이 횟수만)
var watch: Node               ## agent_watch.gd (없으면 시험이 apply 를 직접 부름)
var camera: Camera3D
var shown := {}               ## 직원 키 → {"look", "at", "stage"} — 화면에 지금 보이는 것
var slot := {}                ## 직원 키 → office.staff 번호 ("s:직원id" = 책상 번호 · 손님은 add_guest)
var last_ding := -1.0e18
var dings := 0                ## 울린 '딩' 수 (시험용)
var said: Array = []          ## 끼어들기 기록 [키, 종류] (시험용)
var seen_env := {}            ## 세션 → 마지막으로 본 봉투 시각
var seen_done := {}           ## 인턴 세션 → 마지막으로 본 일 끝 시각 (보고 서류 → 팀원 책상)
var env_queue: Array = []     ## 날릴 봉투 (office 번호)
var env_flying := 0
var seen_prompt := {}         ## 세션 → 마지막으로 본 일 준 시각 (종이비행기)
var plane_queue: Array = []   ## 날릴 종이비행기 (office 번호)
var plane_flying := 0
var planes := 0               ## 날린 종이비행기 수 (시험용)
var hover_i := -1
var _acc := 0.0
var _hover_acc := 0.0
var _started := false
var _bound := {}              ## 세션 → 맡은 직원 id (살아 있는 동안 유지, 저장 안 함 — 1.1 풀 B)
var _reg := {}                ## 마지막 직원 기록 (이름판 프로젝트 이름 찾기)
var borrowed := {}            ## 인턴 키 → 빌린 책상 번호 (M3 5세션째)
var known := {}               ## 직원 id → {"leave", "desk"} — 짐 상자 (입사 · 송별, M5) 판단용
var looks := {}               ## 직원 id → {look, name, team} — 해시 직원 · 명패 (staff_hash, M5 3세션째)


func setup(o: Node3D, snd: Node, w: Node, cam: Camera3D) -> void:
	office = o
	sound = snd
	watch = w
	camera = cam
	if watch:
		watch.updated.connect(refresh)


func _process(delta: float) -> void:
	if watch == null:
		return
	_acc += delta
	if _acc >= 1.0:   # 내 차례 15초 · 끝 30초 같은 단계는 신호 없이 시간으로 바뀜 → 1초마다 다시 봄
		_acc = 0.0
		refresh()
	_hover_acc += delta
	if _hover_acc >= 0.1:
		_hover_acc = 0.0
		_hover_tick()


func refresh() -> void:
	var snap: Dictionary = watch.snap
	if snap.is_empty():
		return
	apply(snap.get("agent", AgentState.empty()), snap.get("staff", StaffRegistry.empty()), Time.get_unix_time_from_system())


# ------------------------------------------------------------------ 순수 판단 (시험 가능)
## 세션 → 직원 단위 표시: {키: decide 결과 + staff · temp · sess (+ relay)}. 키 = "s:직원id" (인턴 = "t:세션id")
##   팀원 (책상 직원) = 그 조합의 메인 세션 = 살아 있는 세션 중 먼저 연 것 (assign, 고정 — 급한 순으로 안 바뀜). 메인이 퇴근하면 다음 세션이 승격
##   인턴 = 같은 조합의 나머지 세션 (데스크톱 하위 세션 포함 — 훅에 부모 정보가 없어 같은 프로젝트로 묶음). M4 사용자 결정:
##   "팀원은 메인 세션을 맡고, 인턴은 그 하위 세션. 하위 세션은 팀원을 통해서만 보고" → 인턴 '내 차례' 는 팀원이 창구로 (relay = 인턴 세션)
static func views(agent: Dictionary, reg: Dictionary, now: float, prev := {}) -> Dictionary:
	var dec := AgentState.decide(agent, now)
	var asg := StaffRegistry.assign(reg, agent, now, prev)
	var out := {}
	for sid in asg:
		var a: Dictionary = asg[sid]
		var key := ("t:" + str(sid)) if a.temp else ("s:%d" % int(a.staff))
		var v: Dictionary = dec[sid].duplicate()
		v.staff = int(a.staff)
		v.temp = bool(a.temp)
		v.solo = bool(a.solo)      # 직원 없는 인턴 (책상 직원이 모자람): 보고할 팀원이 없어 내 차례면 직접 창구로
		v.cover = bool(a.cover)    # 지원 근무: 단골이 아닌 프로젝트를 맡은 책상 직원
		v.sess = str(sid)
		v.agent = str(agent.sessions[sid].agent)
		v.proj = str(agent.sessions[sid].proj)
		v.model = str(agent.sessions[sid].get("model", ""))
		out[key] = v
	for sid in asg:   # 전문가 (M6-1): 일하는 서브에이전트 = 손님 직원 "x:aid" (이름 = 역할, 인턴과 같은 대기 의자 · 빈 책상 빌리기). 무소식 12분이면 끝 신호를 놓친 것으로 봄
		var sess: Dictionary = agent.sessions[sid]
		if str(dec[sid].state) == "off":
			continue
		var subs: Dictionary = sess.get("subs", {})
		var ids := subs.keys().filter(func(a): return now - maxf(float(subs[a].t), float(subs[a].tool_at)) < float(AgentState.timings().quiet_s))
		ids.sort_custom(func(a, b): return float(subs[a].t) < float(subs[b].t))
		for aid in ids.slice(0, SPEC_MAX):
			var sv := {"state": "work", "since": float(subs[aid].t), "stage": 0, "tool": str(subs[aid].tool), "fail": false, "stop": false,
					"check": false, "long": false, "guess": false, "staff": int(asg[sid].staff), "temp": true, "sess": str(sid), "spec": str(subs[aid].type), "proj": str(sess.proj)}
			out["x:" + str(aid)] = sv
	for key in out:   # 인턴 보고 → 팀원: 인턴이 내 차례면 팀원이 대신 창구로 (둘 다면 먼저 부른 쪽 시각)
		var v: Dictionary = out[key]
		var tk := "s:%d" % int(v.staff)
		if not v.temp or v.state != "turn" or not out.has(tk):
			continue
		var t: Dictionary = out[tk]
		if t.state != "turn" or float(v.since) < float(t.since):
			for f in ["state", "since", "stage"]:
				t[f] = v[f]
			t.relay = v.sess
	return out


## decide 이름 → office LOOK 이름. 손님 (인턴 · 대기 의자) 은 내 차례만 움직이고 일함은 대기 (4-1),
##   쉼 · 끝은 now 가 있으면 1분 뒤 숨김 (`hide` = 정류장으로 걸어 나감)
static func look_of(v: Dictionary, guest := false, now := -1.0) -> String:
	var look := "off"
	match str(v.get("state", "off")):
		"turn":
			look = "turn15" if int(v.stage) >= 1 else "turn"   # 15초 → 창구
		"unknown":
			look = "unknown"
		"work":
			look = "work"
		"watch":
			look = "watch"
		"done":
			look = "done0"   # 끝 0~30초: 자리에서 기지개 + ✓
		"rest":
			look = "done" if bool(v.check) else "rest"   # 30초 뒤 휴게 코너 (✓ 는 30분까지)
	if guest and bool(v.get("temp", false)) and not bool(v.get("solo", false)) and look in TURN_LOOKS:
		look = "wait"   # 인턴은 창구에 안 감 — 팀원이 대신 (views relay)
	elif guest and not (look in TURN_LOOKS or look == "off"):
		var idle := not (look in BUSY)
		look = "hide" if idle and now >= 0.0 and now - float(v.get("since", now)) >= INTERN_IDLE_S else "wait"
	return look


## 대기 의자 인턴은 최대 INTERN_MAX 명: 일하는 인턴 · 지금 보이는 인턴 먼저. 넘친 인턴은 숨기고 그 수 ('+N') 를 돌려줌
##   쉬는 인턴은 새로 나타나지 않음 (이미 의자에 있던 인턴만 1분 유지 — 책상 주인이 바뀔 때 끝난 세션이 걸어 들어오지 않게)
static func cap_interns(want: Dictionary, cur: Dictionary) -> int:
	var busy := func(k) -> bool: return str(want[k].get("v", {}).get("state", "")) in ["work", "watch", "unknown", "turn"]
	var ws := []
	for k in want:
		if want[k].look != "wait" or want[k].has("borrow"):
			continue   # 책상 빌린 인턴은 의자 상한에 안 셈
		if not busy.call(k) and cur.get(k, {}).get("look", "") != "wait":
			want[k].look = "hide"
			continue
		ws.append(k)
	var rank := func(k) -> int:
		return (0 if busy.call(k) else 2) + (0 if cur.get(k, {}).get("look", "") == "wait" else 1)
	ws.sort_custom(func(a, b) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		return ra < rb if ra != rb else str(a) < str(b))
	for k in ws.slice(INTERN_MAX):
		want[k].look = "hide"
	return maxi(0, ws.size() - INTERN_MAX)


## 인턴 책상 빌려 앉기 (M3 5세션째 사용자 결정): 주인이 퇴근한 빈 책상 (free) 을 인턴에게 → {키: 책상 번호}.
##   이미 빌린 책상이 아직 비어 있으면 그대로 (자리 안 바뀌게), 새로 빌리는 건 일하는 인턴만 (일함 · 내 차례 먼저, 그다음 키 순)
##   단골 자리 (1.1 R5-lite): 근속 5일 넘은 전문가 (fav_key) 는 새로 빌릴 때 늘 같은 책상 (fav_key % 책상 수) 이 비었으면 그 자리 먼저 — 주인 아님, 저장 안 함
static func borrow_plan(want: Dictionary, free: Array, cur: Dictionary, n_desks := 0) -> Dictionary:
	var out := {}
	var left := free.duplicate()
	var can := func(k) -> bool: return want.has(k) and bool(want[k].get("guest", false)) and not (str(want[k].look) in ["off", "hide"])
	for k in cur:
		if can.call(k) and int(cur[k]) in left:
			out[k] = int(cur[k])
			left.erase(int(cur[k]))
	var ks := []
	for k in want:
		if not out.has(k) and can.call(k) and str(want[k].get("v", {}).get("state", "")) in ["work", "watch", "unknown", "turn"]:
			ks.append(k)
	ks.sort()
	for k in ks:
		if left.is_empty():
			break
		var fav: int = int(want[k].get("fav_key", -1)) % n_desks if n_desks > 0 and int(want[k].get("fav_key", -1)) >= 0 else -1
		if fav in left:
			out[k] = fav
			left.erase(fav)
		else:
			out[k] = left.pop_front()
	return out


## 모든 직원의 바라는 표시: {키: {look, stage, guest, desk, staff, name, sess, v}}. 휴직 직원 빼고, 세션 없으면 off (퇴근)
##   lks = staff_hash.staff_looks 결과 (없으면 예전 이름 목록)
static func targets(agent: Dictionary, reg: Dictionary, now: float, lks := {}, prev := {}) -> Dictionary:
	var out := {}
	for st in reg.staff:
		if st.leave:
			continue
		var id := int(st.id)
		var lk: Dictionary = lks.get(id, {})
		out["s:%d" % id] = {"look": "off", "stage": 0, "guest": int(st.desk) < 0, "desk": int(st.desk), "staff": id,
				"name": str(lk.get("name", Office.name_of(id))), "team": str(lk.get("team", "")), "hash": lk.get("look", {}), "sess": "", "v": {}}
	var vs := views(agent, reg, now, prev)
	for key in vs:
		var v: Dictionary = vs[key]
		var st := StaffRegistry.staff_by_id(reg, int(v.staff))
		var guest: bool = v.temp or int(st.get("desk", -1)) < 0
		var e: Dictionary = out.get(key, {})
		if e.is_empty():
			e = {"desk": -1, "staff": int(v.staff), "name": str(v.get("spec", "인턴"))}
		e.guest = guest
		e.look = look_of(v, guest, now)
		e.stage = int(v.stage)
		e.sess = v.sess
		e.v = v
		out[key] = e
	return out


## 전문가 역할 이름 → 한글 직함 (모르는 이름은 그대로). 이름만 알고 하는 일은 모름 (훅에 설명 없음)
const ROLE_KO := {"Explore": "탐색", "Plan": "설계", "general-purpose": "범용", "statusline-setup": "상태줄", "claude-code-guide": "안내",
		"summarizer": "요약", "code-reviewer": "리뷰"}


static func role_label(role: String) -> String:
	return str(ROLE_KO.get(role, role))


## 전문가 (M6-4): 고정 이름 · 머리색 · 장신구 (R2, 해시 = 솔트 | 역할 | 프로젝트) + 명패 역할 줄 (R1 · R3). 책상 직원은 'PM'
##   직급은 역할 근속 5일부터 (사원은 안 붙임 — M3 사용자 '사원은 별로')
static func spec_looks(want: Dictionary, reg: Dictionary, salt: String) -> void:
	for k in want:
		var w: Dictionary = want[k]
		var is_spec: bool = (w.get("v", {}) as Dictionary).has("spec")
		if is_spec:
			var proj := str(w.v.get("proj", StaffRegistry.staff_by_id(reg, int(w.staff)).get("proj", "")))
			var role := str(w.v.spec)
			var lk := StaffHash.look(salt, "spec:" + role, proj)
			w.hash = lk
			w.name = StaffHash.NAMES[int(lk.name)]
			var days := StaffRegistry.role_days(reg, proj, role)
			if days >= FAV_DAYS:
				w.fav_key = absi((proj + "|" + role).hash())   # 단골 자리 (R5-lite)
			w.role = role_label(role) + " 전문가"   # 직책 = 전문가 (직급 주임 등은 안 붙임, 이름도 안 넣음 — 사용자 2026-10-22). 근속일은 저장만
		elif not bool(w.get("guest", true)) and int(w.get("desk", -1)) >= 0:
			w.role = "PM (지원)" if bool(w.get("v", {}).get("cover", false)) else "PM"


## 3초 유지 (결정 7): 바뀐 지 3초가 안 됐으면 그대로. 내 차례 · 끼어들기 · 출근은 바로.
##   leaving = {키: 퇴근 걸음 중}. 결과 = 새 shown (화면에 보일 것)
static func step(cur: Dictionary, want: Dictionary, now: float, leaving := {}) -> Dictionary:
	var out := {}
	var keys := cur.keys()
	for k in want:
		if not (k in keys):
			keys.append(k)
	for k in keys:
		var w: Dictionary = want.get(k, {})
		var look: String = w.get("look", "off")
		var stage := int(w.get("stage", 0))
		if not cur.has(k):
			if not (look in ["off", "hide"]):
				out[k] = {"look": look, "at": now, "stage": stage}   # 처음 보임 (출근)
			continue
		var c: Dictionary = cur[k]
		if c.look == look:
			if look == "off" and not want.has(k):
				continue   # 퇴근 다 한 임시 파견 → 지움
			out[k] = {"look": look, "at": c.at, "stage": stage}
			continue
		var now_ok: bool = look in TURN_LOOKS or now - float(c.at) >= HOLD_S \
				or interrupt(c.look, look, false, bool(leaving.get(k, false))) != ""
		out[k] = {"look": look, "at": now, "stage": stage} if now_ok else c.duplicate()
	return out


## 끼어들기 종류 (결정 8): 쉬다가 일이 옴 → cup (커피 중) · jump (소파 · 회의 탁자) · oops (퇴근 중) · "" (아님)
static func interrupt(prev: String, next: String, at_pantry: bool, leaving: bool) -> String:
	if not (next in BUSY):
		return ""
	if prev in ["off", "hide"] and leaving:
		return "oops"
	if prev in ["done", "rest"]:
		return "cup" if at_pantry else "jump"
	if prev == "meet":
		return "jump"
	return ""


## '딩' 할 때인지: 누가 창구에 새로 섰거나 (15초) · 3분 다시 알림 단계에 막 들어감. 30초 안에 울렸으면 안 울림
static func ding_due(before: Dictionary, after: Dictionary, last: float, now: float) -> bool:
	var want := false
	for k in after:
		var a: Dictionary = after[k]
		if a.look != "turn15":
			continue
		var b: Dictionary = before.get(k, {})
		if b.get("look", "") != "turn15" or (int(a.stage) >= 2 and int(b.get("stage", 0)) < 2):
			want = true
	return want and now - last >= DING_GAP_S


## 말풍선 문구 (12자 이하 한 줄씩). 내 차례 = 안내 + 시각 ("14:02부터", 5-6)
static func bubble_text(look: String, v: Dictionary, bias_min := 0) -> String:
	match look:
		"turn", "turn15":
			return "터미널에서 확인하세요\n%s부터" % clock(float(v.get("since", 0.0)), bias_min)
		"work":
			if bool(v.get("fail", false)):
				return "앗, 다시 해 볼게요"
			return TOOL_TEXT.get(str(v.get("tool", "")), "일하는 중")
		"watch":
			return "일하는 것 같아요"
		"unknown":
			return "소식이 없어요"
		"done0", "done":
			return "끝났어요"
		"rest":
			return "쉬는 중"
		"wait":
			return "전문가 대기 중" if v.has("spec") else "인턴 대기 중"
	return ""


## 유닉스 초 → "14:02" (bias_min = 표준시와 UTC 차이 분, Time.get_time_zone_from_system().bias)
static func clock(t: float, bias_min := 0) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + bias_min * 60)
	return "%02d:%02d" % [d.hour, d.minute]


# ------------------------------------------------------------------ 화면에 적용
## 창구에서 부르는 (내 차례 15초 단계) 직원 수 — 트레이 점 · 미니 모드 표시 (5-1, M4 1세션째)
static func calling(sh: Dictionary) -> int:
	var c := 0
	for k in sh:
		if str(sh[k].get("look", "")) == "turn15":
			c += 1
	return c


func apply(agent: Dictionary, reg: Dictionary, now: float) -> void:
	_reg = reg
	staff_moves(reg)
	looks = StaffHash.staff_looks(reg, str(Game.firm.salt), Game.firm.plates)
	var want := targets(agent, reg, now, looks, _bound)
	spec_looks(want, reg, str(Game.firm.salt))
	_bound = {}
	for k in want:   # 붙은 배정 (살아 있는 세션 동안 직원을 안 바꿈, 저장 안 함)
		var wv: Dictionary = want[k].get("v", {})
		if wv.has("sess") and not bool(wv.temp) and not wv.has("spec"):
			_bound[str(wv.sess)] = int(wv.staff)
	var free := []   # 주인이 퇴근한 책상 (주인도 off 로 바라고, 화면에서도 off · 걷는 중 아님)
	for j in office.desk_count:
		var owner_off := true
		for k in want:
			if not want[k].guest and int(want[k].desk) == j and want[k].look != "off":
				owner_off = false
		if owner_off and office.staff[j].state == "off" and not office.is_leaving(j):
			free.append(j)
	borrowed = borrow_plan(want, free, borrowed, office.desk_count)
	for k in borrowed:
		want[k].borrow = borrowed[k]
		if str(want[k].v.get("state", "")) in ["work", "watch", "unknown"]:
			want[k].look = look_of(want[k].v, false)   # 빌린 책상에선 앉아서 일함 (대기 아님)
	office.set_more(cap_interns(want, shown))
	_bind(want)
	var leaving := {}
	for k in shown:
		if slot.has(k):
			leaving[k] = office.is_leaving(slot[k])
	var before := shown
	shown = step(shown, want, now, leaving)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	for k in shown:
		var i := int(slot.get(k, -1))
		if i < 0:
			continue
		var look: String = shown[k].look
		_count(k, before.get(k, {}).get("look", "off"), look, want.get(k, {}))
		if office.staff[i].state != look:
			var prev: String = before.get(k, {}).get("look", "off")
			var kind := interrupt(prev, look, office.at_pantry(i), bool(leaving.get(k, false)))
			office.set_state(i, look, true, float(INTERRUPT[kind].delay) if kind != "" else 0.0)
			if kind != "":
				office.say(i, INTERRUPT[kind].say)
				said.append([k, kind])
		office.set_bubble(i, bubble_text(look, want.get(k, {}).get("v", {}), bias))
		office.set_fail(i, look in ["work", "watch", "unknown"] and bool(want.get(k, {}).get("v", {}).get("fail", false)))   # 머리 긁기 + 땀방울 3초 (M4)
		office.set_tool(i, str(want.get(k, {}).get("v", {}).get("tool", "")) if look == "work" else "")   # ② 도구별 책상 동작 + 아이콘 (M4 5세션째)
		office.set_stop(i, look == "work" and bool(want.get(k, {}).get("v", {}).get("stop", false)))   # 멈춤 손 (Esc, C16)
	for k in slot.keys():   # 다 퇴근한 임시 파견 · 사라진 직원 → 자리 반납
		if not shown.has(k):
			var i := int(slot[k])
			slot.erase(k)
			if i >= office.desk_count:
				office.set_borrow(i, -1, false)
			if office.staff[i].state != "off" and not _owned(i):
				office.set_state(i, "off", true)
	if ding_due(before, shown, last_ding, now):
		last_ding = now
		dings += 1
		if sound:
			sound.play_sfx("chime")
	_envelopes(agent, want)
	_started = true


## 결재함 · 돌아오면 요약 셈 (M5 3세션째): 책상 직원만 (인턴 보고는 팀원을 거침). 출근 = 처음 보임 · 일 끝 = 끝 0초 · 내 차례 = 부르기 시작
func _count(k: String, prev: String, look: String, w: Dictionary) -> void:
	if not k.begins_with("s:") or prev == look:
		return
	var id := int(w.get("staff", -1))
	if prev in ["off", "hide"] and not (look in ["off", "hide"]):
		counted.emit("staff", id)
	if look == "done0":
		counted.emit("done", id)
	elif look in TURN_LOOKS and not (prev in TURN_LOOKS):
		counted.emit("turn", id)


## 짐 상자 (M5): 처음 보는 책상 직원 = 입사 (다음 출근에 상자) · 휴직으로 바뀐 직원 = 송별 (자리에서 상자 들고 버스).
##   켜고 첫 확인은 기록만 (이미 있던 직원은 입사 아님)
func staff_moves(reg: Dictionary) -> void:
	for st in reg.staff:
		var id := int(st.id)
		var desk := int(st.desk)
		var old: Dictionary = known.get(id, {})
		if _started and old.is_empty() and not st.leave and desk >= 0 and desk < office.desk_count:
			office.mark_hire(desk)
		elif _started and not old.is_empty() and st.leave and not old.leave and int(old.desk) >= 0 and int(old.desk) < office.desk_count:
			office.farewell(int(old.desk))
		known[id] = {"leave": bool(st.leave), "desk": desk if desk >= 0 else int(old.get("desk", -1))}


## 직원 키 → office 번호 · 이름. 책상 직원 = 책상 번호, 손님 = 빈 손님 자리 (모자라면 add_guest)
func _bind(want: Dictionary) -> void:
	for k in want:
		var w: Dictionary = want[k]
		var i := -1
		if not w.guest and int(w.desk) >= 0 and int(w.desk) < office.desk_count:
			i = int(w.desk)
		elif slot.has(k) and int(slot[k]) >= office.desk_count:
			i = int(slot[k])
		elif not (w.look in ["off", "hide"]) or shown.has(k):
			i = _free_guest()
		if i < 0:
			continue
		if slot.get(k, -1) != i:
			for other in slot.keys():   # 책상이 바뀌어 다른 키가 쓰던 번호면 그 키는 놓음
				if other != k and int(slot[other]) == i:
					slot.erase(other)
					shown.erase(other)
			slot[k] = i
		office.set_staff_name(i, str(w.name))
		office.set_staff_role(i, str(w.get("role", "")))
		if i >= office.desk_count:
			office.set_guest_look(i, w.get("hash", {}) if w.v.has("spec") else {})
		office.set_staff_team(i, str(w.get("team", "")))
		if not (w.get("hash", {}) as Dictionary).is_empty() and i < office.desk_count:
			office.set_look(i, w.hash)
		office.set_staff_project(i, _project_of(w))
		var wv2: Dictionary = w.get("v", {})
		var ckey: int = StaffRegistry.color_key(_reg, str(wv2.agent), str(wv2.proj)) if wv2.has("proj") and wv2.has("agent") else int(w.staff)
		office.set_staff_color(i, PROJECT_COLORS[ckey % PROJECT_COLORS.size()])
		office.set_staff_agent(i, str(wv2.get("agent", "")))
		if i >= office.desk_count:
			office.set_borrow(i, int(w.get("borrow", -1)))


## 이름판 프로젝트 이름: 설정 '이름판에 프로젝트 이름' 을 켰을 때만 (기본 숨김, 결정 14). 감지기가 디스크에서 찾은 이름
func _project_of(w: Dictionary) -> String:
	if (w.get("v", {}) as Dictionary).has("spec"):
		return role_label(str(w.v.spec))   # 전문가 명패 둘째 줄 = 역할 이름 (폴더 설정과 상관없이, M6-4)
	if watch == null or not bool(Game.settings.get("show_project", true)):
		return ""
	var st := StaffRegistry.staff_by_id(_reg, int(w.staff))
	return str(watch.labels.get(str(w.get("v", {}).get("proj", st.get("proj", ""))), ""))


func _free_guest() -> int:
	var used := {}
	for k in slot:
		used[int(slot[k])] = true
	for i in range(office.desk_count, office.staff.size()):
		if not used.has(i) and office.staff[i].state == "off" and not office.is_leaving(i):
			return i
	return office.add_guest()


func _owned(i: int) -> bool:
	for k in slot:
		if int(slot[k]) == i:
			return true
	return false


## 봉투: 새로 끝난 서브에이전트 → 그 직원 책상으로. 인턴 것 (서브에이전트 끝 · 인턴 일 끝) 은 팀원 책상으로 (보고는 팀원을 거쳐서만).
##   처음 켤 땐 지난 봉투를 날리지 않음
func _envelopes(agent: Dictionary, want: Dictionary) -> void:
	for k in want:
		var sid: String = want[k].sess
		if sid == "" or not agent.sessions.has(sid) or want[k].get("v", {}).has("spec"):
			continue   # 전문가 (M6-1) 의 봉투 · 종이비행기 · 보고는 부모 키가 맡음
		var s: Dictionary = agent.sessions[sid]
		var to := str(k)
		if bool(want[k].get("v", {}).get("temp", false)) and not bool(want[k].get("v", {}).get("solo", false)):
			to = "s:%d" % int(want[k].staff)
		var news := []
		var last := float(seen_env.get(sid, -1.0))
		for t in s.get("envelopes", []):
			if float(t) > last:
				news.append(t)
				last = float(t)
		seen_env[sid] = last
		if to != str(k):   # 인턴 일 끝 = 보고 서류 1장
			var da := float(s.get("done_at", -1.0))
			if da > float(seen_done.get(sid, -1.0)):
				news.append(da)
				seen_done[sid] = da
		if _started and slot.has(to):
			for t in news:
				env_queue.append(int(slot[to]))
		if not slot.has(k):
			continue
		var pa := float(agent.sessions[sid].get("prompt_at", -1.0))   # 일 받기 (처음 켤 땐 지난 일은 안 날림)
		if pa > float(seen_prompt.get(sid, -1.0)):
			if _started:
				plane_queue.append(int(slot[k]))
			seen_prompt[sid] = pa
	_launch()
	_launch_planes()


func _launch_planes() -> void:
	while plane_flying < ENVELOPE_MAX and not plane_queue.is_empty():
		var i: int = plane_queue.pop_front()
		if office.staff[i].state == "off":
			continue
		plane_flying += 1
		planes += 1
		var tw: Tween = office.fly_plane(i)
		tw.finished.connect(func() -> void:
			plane_flying -= 1
			_launch_planes())


func _launch() -> void:
	var turn := shown.values().any(func(s): return s.look in TURN_LOOKS)
	while not turn and env_flying < ENVELOPE_MAX and not env_queue.is_empty():   # 누가 내 차례면 멈춤
		var i: int = env_queue.pop_front()
		if office.staff[i].state == "off":
			continue
		env_flying += 1
		var tw: Tween = office.fly_envelope(i)
		tw.finished.connect(func() -> void:
			env_flying -= 1
			_launch())


# ------------------------------------------------------------------ 마우스 올림 (ray_pick)
## 광선이 닿는 가장 가까운 직원 번호 (-1 = 없음). 실제 모델 면으로 판정 (상자보다 정확)
func pick(origin: Vector3, dir: Vector3) -> int:
	var best := INF
	var who := -1
	for i in office.staff.size():
		var node: Node3D = office.staff[i].node
		if not node.visible:
			continue
		var d := RayPick.distance(node, origin, dir)
		if d < best:
			best = d
			who = i
	return who


func pick_at(screen: Vector2) -> int:
	return pick(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func set_hover(i: int) -> void:
	if i == hover_i:
		return
	if hover_i >= 0 and hover_i < office.staff.size():
		office.set_hover(hover_i, false)
	hover_i = i
	if i >= 0:
		office.set_hover(i, true)


func _hover_tick() -> void:
	if camera == null:
		return
	var vp := camera.get_viewport()
	var m := vp.get_mouse_position()
	var inside := Rect2(Vector2.ZERO, vp.get_visible_rect().size).has_point(m)
	set_hover(pick_at(m) if inside else -1)
