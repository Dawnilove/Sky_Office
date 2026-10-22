extends Node
## 감지기 (PLAN 7-1 · 7-6 · 9-2): 1초마다 inbox 확인 → 이름 순으로 agent_state.reduce + 직원 touch
##   → 스냅샷 원자 저장 (임시 파일 → 이름 바꾸기) → inbox 파일 삭제. 다시 켜도 빠짐 · 중복 없음
## 상한 정리: 24시간 지난 파일 · 200개 넘는 오래된 파일은 처리하지 않고 지움 (bell.exe 는 쓰기만, 7-1)
## 관찰 모드 (7-6): ~/.claude/projects/<폴더>/<세션>.jsonl 의 수정 시각만 봄. 내용은 열지 않고 (예외: 마지막 줄 종류 = 꺼짐, closed_tail), 폴더 · 파일 이름은 해시만
##   (bell.exe 와 같은 해시 = SHA-256 앞 8바이트 → 훅을 켜도 같은 직원, 7-3)
## 스냅샷 = %USERPROFILE%\.skyoffice\state.json:
##   {"v": 1, "agent": agent_state 상태, "staff": staff_registry 기록, "batch": [마지막으로 적용한 파일 이름], "seen": {"프로젝트/세션": 수정 시각},
##    "phone": {"hook_t": 마지막 훅 신호, "jsonl_t": 마지막 .jsonl 수정, "recent": [[이벤트 이름, 시각]… 10개]}}
## 화면 연결 (office_routine) 은 M3 3세션째. 무결성 확인 (7-5, phone.gd) 은 M5 — 다르면 paused = true 로 inbox 처리 멈춤 (관찰 모드는 계속)

signal updated   ## 상태가 바뀜 (3세션째 office_routine 이 받음)
signal activity(kind: String, t: float)   ## 근무일 신호 (company.gd, M5): "prompt" · "jsonl" · "rate_limit" · "resume"

const AgentState := preload("res://scripts/world/agent_state.gd")
const StaffRegistry := preload("res://scripts/world/staff_registry.gd")
const VERSION := 1
const TICKS_UNIX := 621355968000000000   ## 1970-01-01 의 .NET 틱 (bell 파일 이름 · t_start)
const MAX_FILES := 200
const MAX_AGE_S := 86400.0
## bell 줄에서 꺼내는 필드 (tools/replay_fixture.py 와 같음). 폴더 이름 · 모양 정보 (_shape) 는 버림
const KEEP := ["event", "sess", "proj", "ntype", "tool", "bg_running", "is_interrupt", "agent_type", "aid", "reason", "error_kind"]
## 직원이 아닌 프로젝트 폴더 (Claude 임시 폴더: claude -p · 스크래치 작업 공간) — ~/.claude/projects 폴더 이름 안 글자
const SKIP_DIRS := ["-AppData-Local-Temp", "-AppData-Roaming-Claude-scratch-workspaces-"]
const WORKTREE := "--claude-worktrees-"   ## <프로젝트>\.claude\worktrees\<이름> → 원래 프로젝트 직원
## 한꺼번에 바뀐 .jsonl (M3 4세션째 실화면: 앱이 오래된 대화 파일 수십 개의 수정 시각을 1분 안에 바꿈) — 이 안에 프로젝트 4곳 넘으면 무시
const BULK_WINDOW_S := 60.0
const BULK_PROJECTS := 4
const RECENT_MAX := 10   ## 연결 상태 패널 '최근 신호' (이벤트 이름 · 시각만, 8장)

var base := ""             ## %USERPROFILE%\.skyoffice (inbox · state.json)
var projects := ""         ## ~/.claude/projects ("" = 관찰 모드 끔)
var desks := 4             ## 책상 수 (layout.desks().size())
var paused := false        ## true = inbox 처리 멈춤 (무결성 경고, M5)
var snap := {}
var _acc := 0.0
var _alias := {}           ## 프로젝트 해시 → 직원으로 볼 해시 ("" = 직원 아님). projects 폴더 이름에서 만듦
var labels := {}           ## 프로젝트 해시 → 실제 폴더 이름 ("OverLand"). 메모리에만 (스냅샷에 안 씀), 이름판 설정이 켜졌을 때만 화면에


static func home() -> String:
	var h := OS.get_environment("USERPROFILE")
	return h if h != "" else OS.get_environment("HOME")


## 해시 (bell.exe Hash 와 같음)
static func hash16(s: String) -> String:
	return s.sha256_text().substr(0, 16)


## bell 파일 이름 (<UTC 100ns>-<pid>.json) → 유닉스 초 (-1 = 모양이 다름)
static func name_time(name: String) -> float:
	var ticks := name.get_slice("-", 0)
	if not name.ends_with(".json") or not ticks.is_valid_int():
		return -1.0
	return float(ticks.to_int() - TICKS_UNIX) / 1e7


## 프로젝트 폴더 이름 → 직원으로 볼 폴더 이름 ("" = 직원 아님): 임시 폴더는 빼고, worktree 는 원래 프로젝트로
static func canon_folder(folder: String) -> String:
	for s in SKIP_DIRS:
		if folder.findn(s) >= 0:
			return ""
	var w := folder.findn(WORKTREE)
	return folder if w < 0 else folder.substr(0, w)


## 경로 → ~/.claude/projects 폴더 이름 규칙 (영문 · 숫자 말고는 모두 '-')
static func encode_path(s: String) -> String:
	var out := ""
	for c in s:
		out += c if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") else "-"
	return out


## projects 폴더 이름 ("C--Users-me-Desktop-Physical-AI-Learnig-Machine") → 실제 폴더 끝 이름 ("Physical-AI-Learnig-Machine").
##   '-' 가 구분자인지 이름의 일부인지 몰라서 디스크를 한 칸씩 내려가며 맞춰 봄 (한글 이름도 됨). 못 찾으면 ""
static func real_name(folder: String) -> String:
	if folder.length() < 4 or folder.substr(1, 2) != "--":
		return ""
	var dir := folder.left(1) + ":/"
	var rest := folder.substr(3)
	var last := ""
	while rest != "":
		var best := ""
		for e in DirAccess.get_directories_at(dir):
			var en := encode_path(e)
			if (rest == en or rest.begins_with(en + "-")) and en.length() > encode_path(best).length():
				best = e
		if best == "":
			return ""
		dir = dir.path_join(best)
		last = best
		rest = rest.substr(mini(encode_path(best).length() + 1, rest.length()))
	return last


## 한꺼번에 바뀜: e 앞뒤 BULK_WINDOW_S 안에 바뀐 파일의 프로젝트가 BULK_PROJECTS 곳 넘음
static func is_bulk(fresh: Array, e: Dictionary) -> bool:
	var projs := {}
	for x in fresh:
		if absf(float(x.t) - float(e.t)) <= BULK_WINDOW_S:
			projs[x.proj] = true
	return projs.size() > BULK_PROJECTS


## .jsonl 마지막 줄이 cost-state 인지 (= Claude 가 꺼짐). 끝 8KB 에서 마지막 줄의 '종류' 만 봄 — 대화 내용은 읽지 않음 (M4 사용자 결정, 7-6 예외)
const CLOSED_HEAD := "{\"type\":\"cost-state\""
const TAIL_BYTES := 8192


static func closed_tail(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var n := f.get_length()
	f.seek(maxi(0, n - TAIL_BYTES))
	var tail := f.get_buffer(n - f.get_position()).get_string_from_utf8().strip_edges(false, true)
	f.close()
	var nl := tail.rfind("\n")
	if nl < 0 and n > TAIL_BYTES:
		return false   # 마지막 줄이 8KB 보다 김 = cost-state 아님
	return tail.substr(nl + 1).begins_with(CLOSED_HEAD)


## bell 줄 → agent_state 이벤트 (모르는 모양이면 {})
static func to_event(line: Variant) -> Dictionary:
	if typeof(line) != TYPE_DICTIONARY or not line.has("event") or not line.has("t_start"):
		return {}
	var e := {"t": (float(line.t_start) - float(TICKS_UNIX)) / 1e7}
	for k in KEEP:
		if line.has(k):
			e[k] = line[k]
	return e


func setup(base_dir: String, projects_dir := "", desk_count := 4) -> void:
	base = base_dir
	projects = projects_dir
	desks = desk_count
	DirAccess.make_dir_recursive_absolute(inbox_dir())
	snap = _load()


func inbox_dir() -> String:
	return base.path_join("inbox")


func state_path() -> String:
	return base.path_join("state.json")


func _process(delta: float) -> void:
	if base == "":
		return
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		tick(Time.get_unix_time_from_system())


## 한 번 확인 (시험은 시각을 넣어 바로 부름). 바뀐 게 있으면 true
func tick(now: float) -> bool:
	var before: Dictionary = snap.duplicate(true)
	var done: Array = []
	var scan := projects != "" and DirAccess.dir_exists_absolute(projects)
	if scan:
		_build_alias()
	if not paused:
		done = _read_inbox(now)
	if scan:
		_scan_projects(now)
	snap.agent = AgentState.prune(snap.agent, now)
	snap.staff = StaffRegistry.sync(snap.staff, desks, now)
	if not done.is_empty():
		snap.batch = done
	var changed: bool = snap != before
	if changed and not _save():
		push_warning("상태 스냅샷을 저장하지 못함: " + state_path())
		return false   # 저장 못 하면 inbox 파일을 지우지 않음 → 다음에 다시
	for n in done:   # 적용 → 저장 → 삭제 (7-1)
		DirAccess.remove_absolute(inbox_dir().path_join(n))
	if changed:
		updated.emit()
	return changed


## inbox → 적용한 파일 이름 목록. 지난번 저장 뒤 못 지운 파일 (batch 에 있음) 은 다시 적용하지 않고 지우기만
func _read_inbox(now: float) -> Array:
	var names := Array(DirAccess.get_files_at(inbox_dir()))
	names.sort()
	var keep := []
	for n in names:
		var p := inbox_dir().path_join(n)
		var t := name_time(n)
		if n.begins_with("."):   # bell 이 쓰는 중인 임시 파일 — 오래 남은 것만 지움
			if now - float(FileAccess.get_modified_time(p)) > MAX_AGE_S:
				DirAccess.remove_absolute(p)
		elif t < 0.0 or now - t > MAX_AGE_S:
			DirAccess.remove_absolute(p)   # 상한 정리: 24시간 지남 · 모르는 파일
		else:
			keep.append(n)
	while keep.size() > MAX_FILES:   # 상한 정리: 오래된 것부터
		DirAccess.remove_absolute(inbox_dir().path_join(keep.pop_front()))
	var done := []
	for n in keep:
		done.append(n)
		if n in snap.batch:
			continue   # 이미 적용함 (저장 뒤 삭제 전에 꺼졌던 경우)
		var line = JSON.parse_string(FileAccess.get_file_as_string(inbox_dir().path_join(n)))
		_note_hook(line, name_time(n))
		var e := to_event(line)
		if not e.is_empty():
			_apply(e, now)
		snap.agent.last_file = maxs_name(str(snap.agent.last_file), n)
	return done


## 이벤트 → 근무일 신호 종류 (company.gd). 해당 없으면 ""
static func company_kind(e: Dictionary) -> String:
	match str(e.get("event", "")):
		"UserPromptSubmit":
			return "prompt"
		"jsonl":
			return "" if e.get("closed", false) else "jsonl"   # 앱 꺼짐 줄은 활동 아님
		"StopFailure":
			return "rate_limit" if str(e.get("error_kind", "")) == "rate_limit" else ""
		"Notification":
			return "resume" if str(e.get("ntype", "")) == "quota_auto_resume_fired" else ""
	return ""


## 전화 (phone.gd): 훅 신호 시각 · 최근 신호 (이벤트 이름 · 시각만 — 내용 없음). 연결 점검 (SelfTest) 도 여기 남음
func _note_hook(line: Variant, t: float) -> void:
	if typeof(line) != TYPE_DICTIONARY or not line.has("event"):
		return
	snap.phone.hook_t = maxf(float(snap.phone.hook_t), t)
	var r: Array = snap.phone.recent
	r.append([str(line.event).left(32), t])
	while r.size() > RECENT_MAX:
		r.pop_front()


static func empty_phone() -> Dictionary:
	return {"hook_t": 0.0, "jsonl_t": 0.0, "recent": []}


static func maxs_name(a: String, b: String) -> String:
	return a if a > b else b


func _build_alias() -> void:
	_alias = {}
	for folder in DirAccess.get_directories_at(projects):
		var c := canon_folder(folder)
		if c != folder:
			_alias[hash16(folder)] = "" if c == "" else hash16(c)
		if c != "" and not labels.has(hash16(c)):
			labels[hash16(c)] = real_name(c)   # 한 번만 (디스크 확인)


func _apply(e: Dictionary, now: float) -> void:
	var p := str(e.get("proj", ""))
	if _alias.has(p):
		if _alias[p] == "":
			return   # Claude 임시 폴더 세션 = 직원 아님
		e = e.duplicate()
		e.proj = _alias[p]
	snap.agent = AgentState.reduce(snap.agent, e)
	var kind := company_kind(e)
	if kind != "":
		activity.emit(kind, float(e.t))
	var s: Dictionary = snap.agent.sessions.get(str(e.get("sess", "")), {})
	if not s.is_empty():   # 세션 → 프로젝트는 첫 신호에서 고정 (7-3)
		snap.staff = StaffRegistry.touch(snap.staff, str(s.agent), str(s.proj), float(e.t), now)


## 관찰 모드: 수정 시각이 바뀐 .jsonl 만 이벤트로. 처음 보는 오래된 파일은 기억만 (하루 넘으면 세션도 안 만듦)
func _scan_projects(now: float) -> void:
	var seen := {}
	var fresh := []   # 이번에 수정 시각이 바뀐 파일 → 한꺼번에 바뀐 것인지 본 뒤 적용
	for folder in DirAccess.get_directories_at(projects):
		var proj := hash16(folder)
		var canon := canon_folder(folder)
		var dir := projects.path_join(folder)
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".jsonl"):
				continue
			var sess := hash16(f.get_basename())
			var key := proj + "/" + sess
			var mt := float(FileAccess.get_modified_time(dir.path_join(f)))
			seen[key] = mt
			if canon == "" or mt <= float(snap.seen.get(key, -1.0)):
				continue
			fresh.append({"t": mt, "event": "jsonl", "mtime": mt, "sess": sess, "proj": hash16(canon), "closed": closed_tail(dir.path_join(f))})
	fresh.sort_custom(func(a, b) -> bool: return float(a.t) < float(b.t))   # 근무일은 시각 순서로 (company.gd)
	for e in fresh:
		if is_bulk(fresh, e):
			continue
		if not e.closed:
			snap.phone.jsonl_t = maxf(float(snap.phone.jsonl_t), float(e.t))
		if now - float(e.t) < float(AgentState.timings().forget_off_s):
			_apply(e, now)
		else:
			snap.staff = StaffRegistry.touch(snap.staff, "claude", e.proj, e.t, now)   # 첫 실행: 최근 2주 조합만 입사
	snap.seen = seen   # 지워진 파일은 잊음


func _empty() -> Dictionary:
	return {"v": VERSION, "agent": AgentState.empty(), "staff": StaffRegistry.empty(), "batch": [], "seen": {}, "phone": empty_phone()}


func _load() -> Dictionary:
	var out := _empty()
	var data = JSON.parse_string(FileAccess.get_file_as_string(state_path())) if FileAccess.file_exists(state_path()) else null
	if typeof(data) != TYPE_DICTIONARY:
		return out
	if typeof(data.get("agent")) == TYPE_DICTIONARY and typeof(data.agent.get("sessions")) == TYPE_DICTIONARY:
		out.agent = data.agent
	out.staff = StaffRegistry.migrate(data.get("staff"))
	if typeof(data.get("batch")) == TYPE_ARRAY:
		out.batch = data.batch
	if typeof(data.get("seen")) == TYPE_DICTIONARY:
		out.seen = data.seen
	if typeof(data.get("phone")) == TYPE_DICTIONARY and typeof(data.phone.get("recent")) == TYPE_ARRAY:
		out.phone = {"hook_t": float(data.phone.get("hook_t", 0.0)), "jsonl_t": float(data.phone.get("jsonl_t", 0.0)), "recent": data.phone.recent}
	return out


## 원자 저장: 임시 파일 → 이름 바꾸기 (쓰는 도중 꺼져도 예전 스냅샷이 남음). full_precision = 유닉스 초 소수점 유지
func _save() -> bool:
	var tmp := state_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snap, "", true, true))
	f.close()
	return DirAccess.rename_absolute(tmp, state_path()) == OK
