extends Node
## 자동 업데이트: GitHub 릴리스에서 새 버전 확인 → 받기 → (서명 확인) → 설치
## - 주소 · 파일명 · 서명 키는 모두 identity.gd (오버랜드와 섞이지 않게)
## - 확인: 켠 지 1분 뒤 + 켜 둔 동안 24시간마다 (설정 → 정보 → "자동으로 확인"), "새 버전 확인" 버튼
## - Identity.ZIP_FORMAT zip + .zip.sig (오피스 전용 비밀 키로 서명) → 서명이 맞을 때만 설치
##   설치 = 압축을 풀어 두고 → 작은 PowerShell 스크립트가 게임이 끝나길 기다렸다 파일을 덮어쓰고 → 다시 켬
##   저장(%APPDATA%\<Identity.USER_DIR>)은 게임 폴더 밖이라 그대로
## - 버전은 "Latest" 표시가 아니라 태그 이름으로 찾음: v1.2.0 / V1.2.0
## 개발용: `--update-feed=<json 파일>` (GitHub 응답 대신, 파일 주소는 로컬 경로 가능) · `--update-now` (바로 확인→받기→설치)

signal changed   ## 상태가 바뀜 (설정 화면 다시 그리기 · 메뉴 빨간 점)
signal progressed   ## 받는 중 진행률 (progress)

const API := Identity.UPDATE_API
const PAGE := Identity.UPDATE_PAGE
const DIR := "user://update"
const FIRST_DELAY := 60.0
const EVERY := 24.0 * 3600.0
const RESULT := "user://update/result.txt"

var state := "idle"        ## idle · checking · latest · available · downloading · ready · error
var message := ""          ## 화면에 보일 한 줄 (오류 등)
var game: Dictionary = {}  ## 새 게임 버전 {version, zip, sig, size, page}
var progress := 0.0        ## 받는 중 0~1
var checked_at := ""       ## 마지막으로 확인한 시각 (화면 표시용)

var _http: HTTPRequest
var _timer := 0.0
var _feed := ""
var _now := false
var _relaunch := ""
var _jobs: Array = []      ## 받을 것 [[주소, 저장 경로]]
var _after: Callable


func _ready() -> void:
	for a in Game.dev_args():
		if a.begins_with("--update-feed="):
			_feed = a.get_slice("=", 1)
		if a == "--update-now":
			_now = true
		if a.begins_with("--update-relaunch="):   # 개발용: 설치 뒤 다시 켤 때 붙일 인자 (점검 실행이 저절로 끝나게)
			_relaunch = a.substr(18)
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_timer = EVERY - (3.0 if _now else FIRST_DELAY)   # 켠 지 1분 뒤 첫 확인
	_report_last_install.call_deferred()


func enabled() -> bool:
	if _feed != "":
		return true
	return OS.has_feature("template") and not Game.is_test_run()   # 배포판에서만 (개발·점검 실행은 인터넷에 묻지 않음)


func auto_on() -> bool:
	return bool(Game.settings.get("update_check", true))


func _process(delta: float) -> void:
	if state == "downloading" and _http.get_body_size() > 0:
		var p := clampf(float(_http.get_downloaded_bytes()) / float(_http.get_body_size()), 0.0, 1.0)
		if absf(p - progress) >= 0.01:
			progress = p
			progressed.emit()
	if not enabled() or not auto_on():
		return
	_timer += delta
	if _timer >= EVERY:
		_timer = 0.0
		if state in ["idle", "latest", "error"]:
			check(false)


# ------------------------------------------------------------------ 확인
func check(manual: bool) -> void:
	if not enabled():
		_state_to("error", "개발 실행에서는 업데이트를 확인하지 않아요")
		return
	if state in ["checking", "downloading"]:
		return
	_state_to("checking", "")
	_manual = manual
	if _feed != "":
		var txt := FileAccess.get_file_as_string(_feed)
		_on_list(JSON.parse_string(txt))
		return
	var err := _http.request(API, ["User-Agent: %s/%s" % [Identity.USER_AGENT, Identity.version()], "Accept: application/vnd.github+json"])
	if err != OK:
		_state_to("error", "업데이트 정보를 받지 못했어요 (인터넷 연결 확인)")


var _manual := false


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state == "checking":
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_state_to("error", "업데이트 정보를 받지 못했어요 (%s)" % ("인터넷 연결 확인" if result != HTTPRequest.RESULT_SUCCESS else "GitHub %d" % code))
			return
		_on_list(JSON.parse_string(body.get_string_from_utf8()))
	elif state == "downloading":
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_jobs.clear()
			_state_to("error", "받다가 끊겼어요. 잠시 뒤 다시 눌러 주세요")
			return
		_next_job()


func _on_list(list) -> void:
	if typeof(list) != TYPE_ARRAY:
		_state_to("error", "업데이트 정보를 읽지 못했어요")
		return
	game = pick(list, Identity.version())
	checked_at = Time.get_datetime_string_from_system(false, true).substr(5, 11).replace("T", " ")
	if game.is_empty():
		_state_to("latest", "")
		if _manual:
			Game.toast.emit("지금 최신 버전이에요 (%s)" % Identity.version())
		return
	_state_to("available", "")
	Game.toast.emit("새 버전 %s 이 나왔어요 — 설정 → 정보에서 받을 수 있어요" % game.version)
	if _now:
		download()


## GitHub 릴리스 목록 → 새 버전 {version, zip, sig, size, name, page} 또는 {} (가장 높은 버전 하나, 지금보다 높을 때만)
static func pick(list: Array, current: String) -> Dictionary:
	var best := {}
	var re_game := RegEx.create_from_string("^[vV](\\d+\\.\\d+\\.\\d+)$")
	for rel in list:
		if typeof(rel) != TYPE_DICTIONARY or rel.get("draft", false) or rel.get("prerelease", false):
			continue
		var m := re_game.search(str(rel.get("tag_name", "")))
		if not m:
			continue
		var assets := {}
		for a in rel.get("assets", []):
			assets[str(a.get("name", ""))] = a
		var v := m.get_string(1)
		var zn := Identity.ZIP_FORMAT % v
		if Identity.version_at_least(v, current) and v != current and assets.has(zn) and assets.has(zn + ".sig") \
				and (best.is_empty() or Identity.version_at_least(v, best.version)):
			best = {"version": v, "zip": str(assets[zn].browser_download_url), "sig": str(assets[zn + ".sig"].browser_download_url),
					"size": int(assets[zn].get("size", 0)), "name": zn, "page": str(rel.get("html_url", PAGE))}
	return best


# ------------------------------------------------------------------ 받기
func download() -> void:
	if state in ["checking", "downloading"] or game.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_jobs.clear()
	if not install_dir_writable():
		_state_to("error", "게임 폴더에 쓸 수 없어서 자동 설치를 못 해요. '받으러 가기'로 직접 받아 주세요")
		return
	_jobs.append([game.zip, DIR.path_join(game.name)])
	_jobs.append([game.sig, DIR.path_join(game.name + ".sig")])
	_after = _verify_game
	progress = 0.0
	_state_to("downloading", "")
	_next_job()


func _next_job() -> void:
	if _jobs.is_empty():
		_after.call()
		return
	var j: Array = _jobs.pop_front()
	var url: String = j[0]
	var dst: String = j[1]
	if not url.begins_with("http"):   # 개발용 피드: 로컬 파일
		var e := DirAccess.copy_absolute(url, ProjectSettings.globalize_path(dst))
		if e != OK:
			_jobs.clear()
			_state_to("error", "받지 못했어요 (%s)" % url.get_file())
			return
		_next_job.call_deferred()
		return
	_http.download_file = ProjectSettings.globalize_path(dst)
	var err := _http.request(url, ["User-Agent: %s/%s" % [Identity.USER_AGENT, Identity.version()]])
	if err != OK:
		_jobs.clear()
		_state_to("error", "받기를 시작하지 못했어요")


func _verify_game() -> void:
	_http.download_file = ""
	var zip := DIR.path_join(game.name)
	if not verify_file(zip, FileAccess.get_file_as_bytes(zip + ".sig")):
		_clean()
		_state_to("error", "받은 파일의 서명이 맞지 않아 설치하지 않았어요")
		return
	var staging := DIR.path_join("staging")
	_remove_dir(ProjectSettings.globalize_path(staging))
	var src := _unzip(zip, staging)
	if src == "":
		_state_to("error", "압축을 풀지 못했어요")
		return
	_staged = src
	_state_to("ready", "")
	if _now:
		install()


var _staged := ""


# ------------------------------------------------------------------ 설치 (게임)
## 압축 푼 새 게임으로 바꾸기: 스크립트를 띄우고 게임을 끔 → 스크립트가 덮어쓰고 다시 켬
func install() -> void:
	if state != "ready" or _staged == "":
		return
	var ps1 := ProjectSettings.globalize_path(DIR.path_join("update.ps1"))
	var f := FileAccess.open(ps1, FileAccess.WRITE)
	if f == null:
		_state_to("error", "설치 준비에 실패했어요")
		return
	f.store_string(PS1)
	f.close()
	var exe := OS.get_executable_path()
	var args := ["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", ps1,
			"-GamePid", str(OS.get_process_id()), "-Src", ProjectSettings.globalize_path(_staged), "-Dst", exe.get_base_dir(),
			"-Exe", exe, "-Log", ProjectSettings.globalize_path(RESULT), "-Ver", str(game.version)]
	if _relaunch != "":
		args += ["-RunArgs", _relaunch]
	var pid := OS.create_process("powershell.exe", args)
	if pid <= 0:
		_state_to("error", "설치를 시작하지 못했어요")
		return
	print("[UPDATE] 설치 시작 → %s (%s)" % [game.version, exe.get_base_dir()])
	var m := get_tree().current_scene
	if m and m.has_method("quit_game"):
		m.quit_game()
	else:
		Game.save_game()
		get_tree().quit()


## 덮어쓰기 스크립트 (ASCII 만): 게임이 끝나길 기다림 → robocopy 로 덮어쓰기(잠겨 있으면 몇 번 더) → 결과 기록 → 다시 켬
const PS1 := """param([int]$GamePid, [string]$Src, [string]$Dst, [string]$Exe, [string]$Log, [string]$Ver, [string]$RunArgs = "")
try { Wait-Process -Id $GamePid -Timeout 90 -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 800
$ok = $false
$code = -1
for ($i = 0; $i -lt 10 -and -not $ok; $i++) {
	& robocopy $Src $Dst /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
	$code = $LASTEXITCODE
	if ($code -lt 8) { $ok = $true } else { Start-Sleep -Seconds 1 }
}
if ($ok) { Set-Content -LiteralPath $Log -Value ("ok " + $Ver) -Encoding UTF8 }
else { Set-Content -LiteralPath $Log -Value ("fail robocopy " + $code) -Encoding UTF8 }
if ($RunArgs -ne "") { Start-Process -FilePath $Exe -ArgumentList $RunArgs -WorkingDirectory $Dst }
else { Start-Process -FilePath $Exe -WorkingDirectory $Dst }
"""


## 지난번 설치 결과 알림 (다시 켠 뒤 한 번) + 받은 파일 정리
func _report_last_install() -> void:
	if not FileAccess.file_exists(RESULT):
		return
	var r := FileAccess.get_file_as_string(RESULT).strip_edges().trim_prefix("﻿")
	if r.begins_with("ok"):
		print("[UPDATE] 업데이트 완료 " + r)
		await get_tree().create_timer(2.0).timeout
		Game.toast.emit("%s 버전으로 업데이트했어요" % Identity.version())
	else:
		print("[UPDATE] 업데이트 실패 " + r)
		await get_tree().create_timer(2.0).timeout
		Game.toast.emit("업데이트를 끝내지 못했어요 — 설정 → 정보 → '받으러 가기'로 직접 받아 주세요")
	_clean()


func _clean() -> void:
	_remove_dir(ProjectSettings.globalize_path(DIR))


func open_page() -> void:
	OS.shell_open(str(game.get("page", PAGE)) if not game.is_empty() else PAGE)


func install_dir_writable() -> bool:
	var p := OS.get_executable_path().get_base_dir().path_join(".skyoffice_write_test")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(p)
	return true


# ------------------------------------------------------------------ 도구
## 파일 전체의 SHA-256 에 대한 서명 확인 (오피스 전용 공개 키)
static func verify_file(path: String, sig: PackedByteArray) -> bool:
	if sig.is_empty() or not FileAccess.file_exists(path):
		return false
	var key := CryptoKey.new()
	if key.load_from_string(Identity.UPDATE_PUBLIC_KEY, true) != OK:
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		hc.update(f.get_buffer(1 << 20))
	f.close()
	return Crypto.new().verify(HashingContext.HASH_SHA256, hc.finish(), sig, key)


## zip 풀기 → Identity.EXE 가 들어 있는 폴더 경로 (없으면 "")
func _unzip(zip: String, to: String) -> String:
	var z := ZIPReader.new()
	if z.open(zip) != OK:
		return ""
	var root := ProjectSettings.globalize_path(to)
	var exe_dir := ""
	for n in z.get_files():
		var out := root.path_join(n)
		if n.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var w := FileAccess.open(out, FileAccess.WRITE)
		if w == null:
			z.close()
			return ""
		w.store_buffer(z.read_file(n))
		w.close()
		if n.get_file() == Identity.EXE:
			exe_dir = out.get_base_dir()
	z.close()
	return exe_dir


static func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _state_to(s: String, msg: String) -> void:
	state = s
	message = msg
	if s == "error":
		print("[UPDATE] " + msg)
	changed.emit()
