extends Node
## 전화 = 내 차례 알림 플러그인 (PLAN 7-5 · 8장 · 5-7 '배포에 회사 옷', M5 4세션째)
##   개통: 게임 안 원본 (res://plugin/) → %USERPROFILE%\.skyoffice\plugin\<버전> 으로 복사 → Claude Code 공식 명령으로 로컬 마켓플레이스 추가 · 설치
##         (게임은 ~/.claude/settings.json 을 직접 고치지 않음 — 읽기만)
##   무결성: 설치 폴더 파일 4개의 SHA-256 = 게임 안 원본 (암호화된 PCK) 과 같아야 함 → 다르면 불통 + inbox 멈춤 (agent_watch.paused)
##   상태: none (미개통 · 회색) / on (개통 · 불빛) / broken (불통 · 수화기 내려감 + X)
##   폐업 정리: 플러그인 제거 · 마켓 제거 → ~/.skyoffice 전부 · 게임 저장 (솔트 포함) · 자동 실행 지움 (흔적 0)
## 시험은 base · claude_home 을 임시 폴더로, 명령은 run_cmd 를 바꿔 끼움 (사용자 Claude 설정을 건드리지 않음)

signal changed   ## 상태가 바뀜 (전화기 불빛 · 패널)
signal job_done(kind: String, ok: bool, msg: String)   ## 개통 · 폐업 명령이 끝남 (스레드 → call_deferred)

const PLUGIN_VER := "0.2.0"   ## 플러그인 버전 (게임 버전과 따로 — 바꿀 땐 다시 개통 = 다시 동의, 7-5)
const BUNDLE := "res://plugin/"
const MARKET := "skyoffice"
const PLUGIN_ID := "skyoffice-bell@skyoffice"
## 설치 폴더 안 자리 → 게임 안 원본 이름
const FILES := {
	"bell/bell.exe": "bell.exe",
	"bell/hooks/hooks.json": "hooks.json",
	"bell/.claude-plugin/plugin.json": "plugin.json",
	".claude-plugin/marketplace.json": "marketplace.json",
}
const QUIET_S := 600.0    ## .jsonl 은 움직이는데 훅 신호가 이만큼 없으면 불통 (7-6 연결 끊김)
const GRACE_S := 120.0    ## 개통 직후 이만큼은 신호가 없어도 기다림 (8장 '2분')
const CHECK_S := 60.0     ## 상태 다시 보기 (해시는 파일이 바뀌었을 때만)

var base := ""            ## %USERPROFILE%\.skyoffice
var claude_home := ""     ## ~/.claude (CLAUDE_CONFIG_DIR 따름)
var watch: Node           ## agent_watch (paused · 신호 시각)
var window_layer: Node    ## C# WindowLayer (폐업 정리 때 자동 실행 끄기)
var status := {"state": "none", "reason": "", "files": {}, "paused": false}
var busy := ""            ## 지금 도는 일 ("install" · "close" · "")
var log_lines: Array = [] ## 마지막 명령 결과 (패널에 짧게)
var run_cmd: Callable     ## (exe, args) -> [종료 코드, 출력]. 기본 = OS.execute (시험은 가짜)
var _acc := 0.0
var _hash_key := ""       ## 마지막 해시 확인 때의 파일 크기 · 수정 시각 (같으면 다시 안 셈)
var _thread: Thread


static func home() -> String:
	var h := OS.get_environment("USERPROFILE")
	return h if h != "" else OS.get_environment("HOME")


static func default_claude_home() -> String:
	var c := OS.get_environment("CLAUDE_CONFIG_DIR")
	return c if c != "" else home().path_join(".claude")


func setup(base_dir: String, claude_dir: String, w: Node) -> void:
	base = base_dir
	claude_home = claude_dir
	watch = w
	if not run_cmd.is_valid():
		run_cmd = _os_run
	refresh(true)


func root() -> String:
	return base.path_join("plugin").path_join(PLUGIN_VER)


func bell_path() -> String:
	return root().path_join("bell/bell.exe")


# ------------------------------------------------------------------ 무결성 (순수에 가깝게)
## 게임 안 원본의 SHA-256 (설치 폴더 자리 → 해시)
static func expected() -> Dictionary:
	var out := {}
	for rel in FILES:
		out[rel] = FileAccess.get_sha256(BUNDLE + FILES[rel])
	return out


## 설치 폴더 확인: {자리: "ok" | "diff" | "missing"} + 실제 해시
static func check_files(dir: String, want: Dictionary) -> Dictionary:
	var files := {}
	var got := {}
	for rel in want:
		var p := dir.path_join(rel)
		if not FileAccess.file_exists(p):
			files[rel] = "missing"
			continue
		got[rel] = FileAccess.get_sha256(p)
		files[rel] = "ok" if got[rel] == want[rel] and want[rel] != "" else "diff"
	return {"files": files, "got": got}


static func norm_path(p: String) -> String:
	return p.replace("\\", "/").trim_suffix("/").to_lower()


## Claude Code 쪽 (읽기만): 마켓 'skyoffice' 가 가리키는 폴더 · 플러그인 켜짐
static func claude_side(dir: String) -> Dictionary:
	var out := {"market": "", "enabled": false, "known": false}
	var km = _read_json(dir.path_join("plugins/known_marketplaces.json"))
	if typeof(km) == TYPE_DICTIONARY and typeof(km.get(MARKET)) == TYPE_DICTIONARY:
		var m: Dictionary = km[MARKET]
		out.known = true
		out.market = str(m.get("installLocation", ""))
		if out.market == "" and typeof(m.get("source")) == TYPE_DICTIONARY:
			out.market = str(m.source.get("path", ""))
	var st = _read_json(dir.path_join("settings.json"))
	if typeof(st) == TYPE_DICTIONARY and typeof(st.get("enabledPlugins")) == TYPE_DICTIONARY:
		out.enabled = st.enabledPlugins.get(PLUGIN_ID, false) == true
	return out


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## 상태 판단 (순수): 파일 확인 · Claude 쪽 · 신호 시각 → {state, reason, paused}
##   sig = {"hook_t": 마지막 훅 신호, "jsonl_t": 마지막 .jsonl 수정, "since": 개통 시각, "now": 지금}
static func judge(files: Dictionary, side: Dictionary, root_dir: String, sig: Dictionary) -> Dictionary:
	var vals := files.values()
	var mine: bool = side.market != "" and norm_path(side.market) == norm_path(root_dir)
	if not side.known and not side.enabled:
		return {"state": "none", "reason": "개통 전이에요.", "paused": false}
	if side.known and not mine:
		return {"state": "broken", "reason": "다른 판 전화기예요. 다시 개통해 주세요.", "paused": true}
	if vals.has("diff"):
		return {"state": "broken", "reason": "전화기 파일이 바뀌었어요. 신호를 멈췄어요.", "paused": true}
	if vals.has("missing"):
		return {"state": "broken", "reason": "전화기 파일이 없어요. 다시 개통해 주세요.", "paused": true}
	if not side.enabled:
		return {"state": "broken", "reason": "Claude Code 에서 꺼져 있어요.", "paused": false}
	var now := float(sig.get("now", 0.0))
	var hook_t := maxf(float(sig.get("hook_t", 0.0)), float(sig.get("since", 0.0)) + GRACE_S - QUIET_S)
	var jt := float(sig.get("jsonl_t", 0.0))
	if jt > 0.0 and now - jt < QUIET_S and jt - hook_t > QUIET_S:
		return {"state": "broken", "reason": "신호가 안 와요. Claude Code 를 다시 켜 보세요.", "paused": false}
	return {"state": "on", "reason": "정상이에요.", "paused": false}


# ------------------------------------------------------------------ Codex 연결 (복사 안내, 7-5 같은 철학: 게임이 ~/.codex/hooks.json 을 직접 안 고침)
const CODEX_EVENTS := ["SessionStart", "UserPromptSubmit", "PostToolUse", "Stop", "Interrupt", "SessionEnd"]   ## PreToolUse · PermissionRequest 는 영구 금지, notify 안 씀


static func codex_home() -> String:
	var c := OS.get_environment("CODEX_HOME")
	return c if c != "" else home().path_join(".codex")


## Codex hooks.json 에 붙일 내용 (사용자가 직접). bell 경로는 따옴표로 감쌈 (한글 · 띄어쓰기). Interrupt · SessionEnd 는 제한 3초라 timeout 2
static func codex_snippet(bell_exe: String) -> String:
	var cmd := "\"%s\" --agent codex" % bell_exe.replace("/", "\\")
	var hooks := {}
	for e in CODEX_EVENTS:
		hooks[e] = [{"hooks": [{"type": "command", "command": cmd, "commandWindows": cmd, "async": true, "timeout": 2 if e in ["Interrupt", "SessionEnd"] else 5}]}]
	return JSON.stringify({"hooks": hooks}, "  ", false)


## Codex 쪽 (읽기만): hooks.json 이 있는지 · 그 안에 우리 bell 이 있는지 (내용은 저장 안 함)
static func codex_side(dir: String) -> Dictionary:
	var p := dir.path_join("hooks.json")
	return {"file": FileAccess.file_exists(p), "bell": FileAccess.file_exists(p) and FileAccess.get_file_as_string(p).contains("bell.exe")}


## Codex 훅 신호를 받은 적이 있나 (세션 중 agent == codex 이고 hooked)
func codex_hooked() -> bool:
	var ss: Dictionary = (watch.snap.get("agent", {}) as Dictionary).get("sessions", {}) if watch else {}
	return ss.values().any(func(s) -> bool: return str(s.get("agent", "")) == "codex" and bool(s.get("hooked", false)))


# ------------------------------------------------------------------ 상태 갱신
func _process(delta: float) -> void:
	if base == "":
		return
	_acc += delta
	if _acc >= CHECK_S:
		_acc = 0.0
		refresh()


## 상태 다시 보기 (force = 해시도 다시). 바뀌면 changed
func refresh(force := false) -> void:
	if busy != "":
		return
	var key := ""
	for rel in FILES:
		var p := root().path_join(rel)
		key += "%s:%d:%d|" % [rel, FileAccess.get_size(p) if FileAccess.file_exists(p) else -1, FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else 0]
	var files: Dictionary = status.files
	if force or key != _hash_key or files.is_empty():
		_hash_key = key
		files = check_files(root(), expected()).files
	var sig := signal_times()
	var j := judge(files, claude_side(claude_home), root(), sig)
	j.files = files
	var was := status.duplicate()
	status = j
	if watch:
		watch.paused = bool(j.paused)
	if was.get("state") != j.state or was.get("reason") != j.reason or was.get("files") != j.files:
		changed.emit()


func signal_times() -> Dictionary:
	var ph: Dictionary = watch.snap.get("phone", {}) if watch else {}
	var b := bell_path()
	return {"hook_t": float(ph.get("hook_t", 0.0)), "jsonl_t": float(ph.get("jsonl_t", 0.0)),
			"since": float(FileAccess.get_modified_time(b)) if FileAccess.file_exists(b) else 0.0, "now": Time.get_unix_time_from_system()}


## 연결 상태 패널용: 최근 신호 [[이벤트, 시각]…] (최신 먼저, 10개)
func recent() -> Array:
	var r: Array = (watch.snap.get("phone", {}).get("recent", []) as Array).duplicate() if watch else []
	r.reverse()
	return r


# ------------------------------------------------------------------ 개통 · 폐업 명령
## Claude Code 실행 파일 ("" = 못 찾음 → 명령 복사 안내). [exe, 앞 인자]
static func claude_exe() -> Array:
	for d in OS.get_environment("PATH").split(";", false):
		for n in ["claude.exe", "claude.cmd"]:
			var p := d.strip_edges().path_join(n)
			if FileAccess.file_exists(p):
				return [p, []] if n.ends_with(".exe") else ["cmd.exe", ["/c", p]]
	var lb := home().path_join(".local/bin/claude.exe")
	return [lb, []] if FileAccess.file_exists(lb) else ["", []]


## 개통 명령 [이름, 인자, 실패해도 계속] — 예전 'skyoffice' 마켓 (M0 시험판 등) 은 먼저 뺌
func install_steps(side: Dictionary) -> Array:
	var s := []
	if side.enabled or side.known:
		s.append(["plugin", "uninstall", PLUGIN_ID, true])
	if side.known:
		s.append(["plugin", "marketplace", "remove", MARKET, true])
	s.append(["plugin", "marketplace", "add", root().replace("/", "\\"), false])
	s.append(["plugin", "install", PLUGIN_ID, "--scope", "user", false])
	return s


func uninstall_steps() -> Array:
	return [["plugin", "uninstall", PLUGIN_ID, true], ["plugin", "marketplace", "remove", MARKET, true]]


## 사용자가 직접 붙여 넣을 명령 (PowerShell) — claude 를 못 찾거나 직접 하고 싶을 때
static func command_text(steps: Array) -> String:
	var lines := []
	for st in steps:
		var a: Array = (st as Array).slice(0, (st as Array).size() - 1)
		lines.append("claude " + " ".join(a.map(func(x): return "\"%s\"" % x if str(x).contains(" ") or str(x).contains("\\") else str(x))))
	return "\n".join(lines)


## 게임 안 원본 → 설치 폴더 복사 (예전 판 폴더 · M0 시험판 자리는 지움)
func copy_bundle() -> bool:
	for rel in FILES:
		var dst := root().path_join(rel)
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var data := FileAccess.get_file_as_bytes(BUNDLE + FILES[rel])
		var f := FileAccess.open(dst, FileAccess.WRITE)
		if f == null or data.is_empty():
			return false
		f.store_buffer(data)
		f.close()
	var pd := base.path_join("plugin")
	for d in DirAccess.get_directories_at(pd):
		if d != PLUGIN_VER:
			_rm_tree(pd.path_join(d))
	return true


## 개통 (스레드에서 명령 → job_done). claude 를 못 찾으면 false (명령 복사 안내)
func install() -> bool:
	if busy != "":
		return false
	var exe := claude_exe()
	if not copy_bundle():
		job_done.emit("install", false, "파일 복사 실패")
		return false
	if str(exe[0]) == "" and run_cmd == _os_run:
		refresh(true)
		return false
	_start("install", exe, install_steps(claude_side(claude_home)))
	return true


## 폐업 정리 1단계 (명령) — 끝나면 job_done("close") → close_files()
func close_business() -> void:
	if busy != "":
		return
	_start("close", claude_exe(), uninstall_steps())


func _start(kind: String, exe: Array, steps: Array) -> void:
	busy = kind
	log_lines = []
	if Game.is_test_run() and run_cmd == _os_run:   # 화면 밖 · 시험 실행은 진짜 명령을 돌리지 않음
		_finish(kind, false, "시험 실행에선 명령을 돌리지 않아요.")
		return
	_thread = Thread.new()
	_thread.start(_run_steps.bind(kind, exe, steps))


func _run_steps(kind: String, exe: Array, steps: Array) -> void:
	var ok := true
	var msg := ""
	if str(exe[0]) == "" and run_cmd == _os_run:
		call_deferred("_finish", kind, false, "claude 명령을 찾지 못함")
		return
	for st in steps:
		var args: Array = (exe[1] as Array) + (st as Array).slice(0, (st as Array).size() - 1)
		var r: Array = run_cmd.call(str(exe[0]), args)
		log_lines.append("%s → %d" % [" ".join((st as Array).slice(1, 3)), int(r[0])])
		if int(r[0]) != 0 and not bool(st[st.size() - 1]):
			ok = false
			msg = str(r[1]).strip_edges().get_slice("\n", 0).left(120)
			break
	call_deferred("_finish", kind, ok, msg)


func _finish(kind: String, ok: bool, msg: String) -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	busy = ""
	refresh(true)
	job_done.emit(kind, ok, msg)


func _os_run(exe: String, args: Array) -> Array:
	var out := []
	var code := OS.execute(exe, PackedStringArray(args.map(func(x): return str(x))), out, true)
	return [code, "\n".join(out)]


# ------------------------------------------------------------------ 연결 점검 (bell 을 시험 신호로 1번)
## 해시가 맞을 때만 실행 (바뀐 exe 는 돌리지 않음). 성공 = inbox 에 SelfTest 파일이 생김 → true
func self_test(inbox := "") -> Dictionary:
	refresh(true)
	if status.files.values().any(func(v): return v != "ok"):
		return {"ok": false, "msg": "해시가 달라 실행 안 함"}
	var dir := inbox if inbox != "" else base.path_join("inbox")
	var before := Array(DirAccess.get_files_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	var t0 := Time.get_ticks_msec()
	var p := OS.execute_with_pipe(bell_path(), PackedStringArray(), true)
	if p.is_empty():
		return {"ok": false, "msg": "bell 실행 실패"}
	var io := p.stdio as FileAccess
	io.store_buffer("{\"hook_event_name\":\"SelfTest\"}".to_utf8_buffer())
	io.close()
	while OS.is_process_running(int(p.pid)) and Time.get_ticks_msec() - t0 < 3000:
		OS.delay_msec(5)
	var ms := Time.get_ticks_msec() - t0
	for n in DirAccess.get_files_at(dir):
		if not (n in before) and n.ends_with(".json"):
			var line = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(n)))
			if typeof(line) == TYPE_DICTIONARY and str(line.get("event", "")) == "SelfTest":
				return {"ok": true, "msg": "정상 (%d ms)" % ms, "ms": ms, "file": n}
	return {"ok": false, "msg": "신호 파일 없음"}


# ------------------------------------------------------------------ 폐업 정리 2단계 (파일)
## 지울 곳 목록 (확인 카드 · 시험). 사진 폴더는 내가 찍은 것이라 남김
func close_targets() -> Array:
	return [base, ProjectSettings.globalize_path("user://")]


## ~/.skyoffice 전부 · 게임 저장 폴더 (솔트 포함) · 자동 실행. 열려 있어 못 지운 파일은 게임이 꺼진 뒤 지움 (cmd)
func close_files(quit := true) -> Array:
	var left := []
	if watch:
		watch.base = ""   # 감지기 멈춤 (다시 쓰지 않게)
	_rm_tree(base)
	if DirAccess.dir_exists_absolute(base):
		left.append(base)
	# Claude Code 의 플러그인 복사본 (uninstall 이 바로 안 지움 — 실제 시험에서 확인). 우리 마켓 폴더 하나만
	_rm_tree(claude_home.path_join("plugins/cache").path_join(MARKET))
	Game.firm.salt = ""
	if not Game.is_test_run():
		Game.no_save = true   # 끄면서 다시 저장하지 않게
		var ud := ProjectSettings.globalize_path("user://")
		_rm_tree(ud)
		if DirAccess.dir_exists_absolute(ud):
			left.append(ud)
		if window_layer:
			window_layer.call("SetAutoStart", false)   # HKCU ...\Run 값 지움
		if not left.is_empty():   # 로그 파일 등 열려 있는 것 — 3초 뒤 (게임이 꺼진 뒤) 지움
			var cmd := "ping -n 4 127.0.0.1 >nul"
			for d in left:
				cmd += " & rmdir /s /q \"%s\"" % str(d).replace("/", "\\")
			OS.create_process("cmd.exe", ["/c", cmd])
		if quit:
			Engine.get_main_loop().quit()
	return left


static func _rm_tree(dir: String) -> void:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm_tree(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
