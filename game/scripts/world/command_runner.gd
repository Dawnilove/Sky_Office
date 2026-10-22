extends Node
## 게임 안 한 줄 명령 (로드맵 ⑤ · 설계 docs/v1_2/게임안명령_설계.md · PLAN 결정 29) — 선택 기능, 기본 꺼짐
##   프로젝트 폴더 한 곳에서 `claude -p` 를 1번 부르고 결과 요약 몇 줄만 돌려줌.
##   권한 = dontAsk + Read(./**) (그 폴더 안 읽기만 — 5-0 실측: 그냥 Read 는 폴더 밖도 읽음), 5턴 · $0.50 · 120초, claude.exe 만 (.cmd 안 씀, 셸 없음)
##   입력 · 결과는 메모리에만 (result) — 저장 · 로그 · inbox 에 안 씀. 직원 연출은 bell 훅이 알아서 (새 코드 없음)
## 프로세스는 C# ProcRunner (작업 폴더 · 시간 제한 · 취소 · 프로세스 트리 종료). 시험은 exe_path 를 가짜 claude 로 바꿔 끼움 (토큰 0)

signal finished(res: Dictionary)   ## 끝남 (성공 · 실패 · 취소 · 시간 초과 모두)

const AgentWatch := preload("res://scripts/world/agent_watch.gd")
const AgentState := preload("res://scripts/world/agent_state.gd")
const Runner := preload("res://scripts/world/ProcRunner.cs")

const TIMEOUT_S := 120
const MAX_CHARS := 65536     ## 출력 읽기 상한 — 넘으면 종료
const PROMPT_MAX := 300
const MAX_TURNS := "5"
const MAX_USD := "0.50"
const SHOW_LINES := 6        ## 결과 패널 줄 수
const LINE_MAX := 90

var watch: Node              ## agent_watch (직원 · 일하는 중 · projects 폴더)
var exe_path := ""           ## "" = claude.exe 를 PATH 에서 찾음. 시험은 가짜
var timeout_s := TIMEOUT_S   ## 시험만 줄임
var running := false
var result: Dictionary = {}  ## 마지막 결과 {ok, kind, lines, cost, msg, folder} — 메모리만, 패널 닫으면 지움
var started_ms := 0
var skip := {}               ## 폴더 해시 → 취소 · 시간 초과 시각. 그 뒤로 새로 시작한 세션만 '일하는 중' 으로 봄 (끊긴 실행이 남긴 유령 막기)
var _runner: Node
var _folder := ""            ## 지금 도는 폴더 이름 (결과에 붙임)
var _hash := ""
var _t0 := 0.0               ## 이번 실행을 시작한 시각 (유닉스 초)


func setup(w: Node) -> void:
	watch = w
	_runner = Runner.new()
	_runner.name = "ProcRunner"
	add_child(_runner)
	_runner.connect("Done", _on_done)


func enabled() -> bool:
	return bool(Game.settings.get("claude_command", false))


# ------------------------------------------------------------------ claude.exe (cmd 래퍼는 안 씀 — 사용자 글이 셸을 거치지 않게)
func claude_exe() -> String:
	if exe_path != "":
		return exe_path
	for d in OS.get_environment("PATH").split(";", false):
		var p := d.strip_edges().path_join("claude.exe")
		if FileAccess.file_exists(p):
			return p
	var lb := OS.get_environment("USERPROFILE").path_join(".local/bin/claude.exe")
	return lb if FileAccess.file_exists(lb) else ""


## 켤 수 있나 / 보낼 수 있나 ("" = 가능, 아니면 이유 한 줄)
func unavailable() -> String:
	if claude_exe() == "":
		return "claude.exe 를 못 찾았어요."
	if Game.is_test_run() and exe_path == "" and not "--command-real" in Game.dev_args():   # 시험 실행은 진짜 claude 안 부름 (진짜 한 번 점검 = 개발 인자 `--command-real`)
		return "시험 실행에선 안 불러요."
	return ""


# ------------------------------------------------------------------ 폴더 (직원이 있는 프로젝트만)
## ~/.claude/projects 폴더 이름 → 실제 전체 경로 ("" = 못 찾음). agent_watch.real_name 과 같은 방식으로 디스크를 한 칸씩 내려감
##   shortcut: 글자만 같은 두 이름 (예: a-b 와 a_b) 이 한 폴더에 같이 있으면 긴 쪽을 고름, 틀리면 못 찾음으로 끝 — 그런 폴더가 나오면 경로를 projects 안 기록에서 읽는 쪽으로
static func real_path(folder: String) -> String:
	if folder.length() < 4 or folder.substr(1, 2) != "--":
		return ""
	var dir := folder.left(1) + ":/"
	var rest := folder.substr(3)
	while rest != "":
		var best := ""
		for e in DirAccess.get_directories_at(dir):
			var en := AgentWatch.encode_path(e)
			if (rest == en or rest.begins_with(en + "-")) and en.length() > AgentWatch.encode_path(best).length():
				best = e
		if best == "":
			return ""
		dir = dir.path_join(best)
		rest = rest.substr(mini(AgentWatch.encode_path(best).length() + 1, rest.length()))
	return dir


## [{name, path, hash, busy}] — 직원(휴직 아님)이 있고 실제 폴더가 있는 곳만. 이름 순
func folders() -> Array:
	var out := []
	if watch == null or str(watch.projects) == "" or not DirAccess.dir_exists_absolute(watch.projects):
		return out
	var staff := {}
	for s in (watch.snap.get("staff", {}) as Dictionary).get("staff", []):
		if str(s.agent) == "claude" and not bool(s.get("leave", false)):
			staff[str(s.proj)] = true
	for f in DirAccess.get_directories_at(watch.projects):
		if AgentWatch.canon_folder(f) != f:
			continue
		var h := AgentWatch.hash16(f)
		if not staff.has(h):
			continue
		var p := real_path(f)
		if p != "":
			out.append({"name": p.get_file(), "path": p, "hash": h, "busy": is_busy(h)})
	out.sort_custom(func(a, b) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


## 그 폴더 직원이 일하는 중인가 (work · watch) — 내 차례 · 쉼은 아님. 끊은 실행이 남긴 세션은 뺌 (skip)
func is_busy(h: String) -> bool:
	if watch == null:
		return false
	var now := Time.get_unix_time_from_system()
	var sess: Dictionary = (watch.snap.get("agent", {}) as Dictionary).get("sessions", {})
	var t0 := float(skip.get(h, 0.0))
	for sid in sess:
		var s: Dictionary = sess[sid]
		if str(s.proj) == h and float(s.last) > t0 and AgentState.view(s, now).state in ["work", "watch"]:
			return true
	return false


# ------------------------------------------------------------------ 실행
static func args() -> PackedStringArray:
	return PackedStringArray(["-p", "--output-format", "json", "--permission-mode", "dontAsk", "--allowedTools", "Read(./**)",
			"--max-turns", MAX_TURNS, "--max-budget-usd", MAX_USD, "--no-session-persistence"])


## 입력 글 정리: 줄바꿈 · 제어 문자는 공백, 앞뒤 공백 없애고 PROMPT_MAX 글자까지
static func clean_prompt(s: String) -> String:
	var out := ""
	for c in s:
		out += " " if c.unicode_at(0) < 32 else c
	return out.strip_edges().left(PROMPT_MAX)


## 시작. "" = 시작함, 아니면 이유 한 줄 (카드에 보여 줌)
func start(entry: Dictionary, prompt: String) -> String:
	if not enabled():
		return "꺼져 있어요."
	if running:
		return "이미 하나 돌고 있어요."
	var why := unavailable()
	if why != "":
		return why
	var text := clean_prompt(prompt)
	if text == "":
		return "한 줄을 적어 주세요."
	var cur: Dictionary = {}
	for f in folders():   # 보내는 순간 다시 확인 (직원 · 폴더 · 일하는 중)
		if f.hash == str(entry.get("hash", "")):
			cur = f
	if cur.is_empty():
		return "그 폴더에 직원이 없어요."
	if bool(cur.busy):
		return "그 폴더 직원이 일하는 중이에요."
	result = {}
	if not _runner.Start(claude_exe(), args(), str(cur.path), text, timeout_s * 1000, MAX_CHARS):
		return "Claude 를 시작하지 못했어요."
	running = true
	started_ms = Time.get_ticks_msec()
	_t0 = Time.get_unix_time_from_system()
	_folder = str(cur.name)
	_hash = str(cur.hash)
	return ""


func cancel() -> void:
	if running:
		_runner.Cancel()


func clear_result() -> void:
	result = {}


func _on_done(code: int, out: String, _err: String, timed_out: bool, canceled: bool, too_big: bool) -> void:
	running = false
	if timed_out or canceled:
		skip[_hash] = Time.get_unix_time_from_system()
		get_tree().create_timer(3.0).timeout.connect(end_ghosts)   # 마지막 훅 신호가 감지기에 닿은 뒤
	result = parse(out, code, timed_out, canceled, too_big)
	result.folder = _folder
	finished.emit(result)


## 끊은 실행 (취소 · 시간 초과) 은 Stop · SessionEnd 훅이 안 와서 그 직원이 '일하는 중' 으로 남음 (5-0 실측) →
##   그 실행이 만든 세션만 (이 실행을 시작한 뒤 생긴, 이 폴더의 세션) bell 파일 모양의 SessionEnd 를 감지기 inbox 에 넣어 퇴근시킴. 다른 세션은 안 건드림
func end_ghosts() -> void:
	if watch == null or watch.get("base") in [null, ""]:
		return
	var sess: Dictionary = (watch.snap.get("agent", {}) as Dictionary).get("sessions", {})
	for sid in sess:
		var s: Dictionary = sess[sid]
		if str(s.proj) == _hash and float(s.start) >= _t0 - 2.0 and str(s.phase) != "off":
			_write_end(str(sid))


## bell 와 같은 방식: 점(.) 이름으로 쓰고 → 이름 바꾸기 (감지기가 쓰는 중인 파일을 안 읽게)
func _write_end(sess: String) -> void:
	var ticks := int(Time.get_unix_time_from_system() * 1e7) + AgentWatch.TICKS_UNIX
	var n := "%d-%d.json" % [ticks, OS.get_process_id()]
	var dir: String = watch.inbox_dir()
	var f := FileAccess.open(dir.path_join("." + n), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"v": 1, "t_start": ticks, "event": "SessionEnd", "reason": "other", "sess": sess, "proj": _hash}))
	f.close()
	DirAccess.rename_absolute(dir.path_join("." + n), dir.path_join(n))


# ------------------------------------------------------------------ 결과 해석 (순수)
## json 한 덩어리 → {ok, kind, lines, cost, msg}. kind: ok · error · login · timeout · canceled · toobig · bad
static func parse(out: String, code: int, timed_out := false, canceled := false, too_big := false) -> Dictionary:
	var r := {"ok": false, "kind": "bad", "lines": [], "cost": -1.0, "msg": ""}
	if canceled:
		r.kind = "canceled"
		r.msg = "취소했어요."
		return r
	if timed_out:
		r.kind = "timeout"
		r.msg = "시간이 넘어 멈췄어요 (%d초)." % TIMEOUT_S
		return r
	if too_big:
		r.kind = "toobig"
		r.msg = "답이 너무 길어 멈췄어요."
		return r
	var j = JSON.parse_string(out.strip_edges())
	if typeof(j) != TYPE_DICTIONARY:
		r.msg = ("Claude 가 오류로 끝났어요 (코드 %d)." % code) if code != 0 else "알 수 없는 답이 왔어요."
		return r
	if j.has("total_cost_usd"):
		r.cost = float(j.total_cost_usd)
	var text := str(j.get("result", ""))
	if bool(j.get("is_error", false)) or code != 0:
		var low := text.to_lower()
		var st = j.get("api_error_status")
		if low.contains("authenticate") or low.contains("oauth") or low.contains("log in") or low.contains("login") or (st != null and int(st) == 401):
			r.kind = "login"
			r.msg = "Claude 로그인이 필요해요. 터미널에서 claude 를 열어 /login 해 주세요."
		else:
			r.kind = "error"
			r.msg = _first_line(text).left(120) if text.strip_edges() != "" else "Claude 가 오류로 끝났어요."
		return r
	r.ok = true
	r.kind = "ok"
	r.lines = summary(text)
	return r


static func _first_line(t: String) -> String:
	for l in t.split("\n"):
		if l.strip_edges() != "":
			return l.strip_edges()
	return ""


## 답 → 보여 줄 줄 (SHOW_LINES 줄, 한 줄 LINE_MAX 글자). 마크다운 표시는 걷어냄. 넘치면 마지막 줄 끝에 …
static func summary(text: String) -> Array:
	var lines := []
	var more := false
	for l in text.replace("**", "").replace("`", "").split("\n"):
		var t := l.strip_edges().lstrip("#>").strip_edges()
		if t == "":
			continue
		if lines.size() >= SHOW_LINES:
			more = true
			break
		lines.append(t.left(LINE_MAX - 1) + "…" if t.length() > LINE_MAX else t)
	if more:
		lines[lines.size() - 1] = str(lines[lines.size() - 1]).trim_suffix("…") + " …"
	return lines


## 비용 한 줄 ("" = 모름). 추정치라 청구와 다를 수 있음
static func cost_text(cost: float) -> String:
	if cost < 0.0:
		return ""
	return "약 $%.2f · 추정" % cost


func _exit_tree() -> void:
	if running:
		_runner.Cancel()
