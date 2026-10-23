extends Node
## 전역 게임 상태 (autoload "Game")
## 설정 · 게임 시각 · 통계를 보관하고 user://save.dat (암호화) 에 저장/불러오기
## 하늘 오피스 M1: 오버랜드의 농장 · 재화 · 레벨 · 확장 상태를 걷어 낸 틀 (회사 · 직원 상태는 M3 · M5 에서)

signal changed              ## 값이 바뀜 → HUD·패널 갱신
signal settings_changed     ## 설정이 바뀜 → 창 모드·FPS 등 적용
signal toast(text: String)  ## 화면 위에 잠깐 띄울 알림
signal away_started         ## 자리 비움 시작 (presence.gd)
signal away_ended(minutes: int)   ## 자리 비움에서 돌아옴

const SAVE_PATH := "user://save.dat"          ## 암호화된 저장 (메모장 등으로 고쳐 쓰지 못하게)
const BACKUP_PATH := "user://save.bak.dat"
const DAY_BACKUP_PATH := "user://save.day.dat"   ## 하루 1번: 그날 처음 저장할 때 직전 저장을 복사 (설정 > 정보에서 되돌리기)
const SAVE_KEY := Identity.SAVE_KEY   ## 저장 파일 암호 (오피스 전용, identity.gd)
const SAVE_VERSION := 2   ## 저장 형식. 형식을 바꾸면 +1 하고 migrations() 에 이전 함수 · fixtures/saves 에 견본 추가 (PLAN 9-2). 2 = firm (M5 3세션째)
const Company := preload("res://scripts/world/company.gd")
const Firm := preload("res://scripts/game/firm.gd")

signal firm_changed         ## 회사 이름 · 명패 · 결재함이 바뀜 (간판 · 이름판 · 결재함 패널)

var settings := {
	"window_mode": 0,        # 0 일반 / 1 항상 위 / 2 바탕화면 고정
	"fps": 30,
	"ui_visible": true,
	"bgm": false,             # 음악 · 환경음 기본 끔 (PLAN 5-6 · 8장, v2.8)
	"ambience": false,
	"volume": 0.7,            # 음악 · 환경음 음량
	"alert_volume": 0.7,      # 알림 소리 ('딩') 음량 — 따로
	"weather": "clear",      # 1.1 창밖 연출용으로 남김 — 1.0 사무실은 맑음 고정 (사용자 2026-10-16), 설정 화면에 없음
	"window_pos": null,
	# 화면
	"size": 0.8,               # 섬 크기: 직접 바꾼 적 없으면(size_set) 항상 "작게"로 시작
	"pause_fullscreen": true,
	"low_power": "auto",       # "auto" 배터리일 때 / "on" 항상 / "off" 끄기
	"mini_mode": true,         # 다른 창에 가려지면 오른쪽 아래 작은 섬 (구경만)
	"mini_opacity": 0.7,       # 미니 섬 투명도 (0.3~1.0)
	"update_check": true,      # 새 버전 자동 확인 (켠 지 1분 뒤 + 24시간마다, GitHub 릴리스) — 설정 > 정보
	"quiet": false,            # 조용히 모드 (C36, M5 5세션째): 회사 생활 연출 줄임 — 부르는 장면은 그대로. 설정 > 화면 > 보이는 것
	"show_project": true,      # 명패에 작업 폴더 이름 ('서연 · OverLand') — 기본 켬 (M5 5세션째 사용자, 전 결정 14 기본 숨김), 끄면 이름만. 설정 > 화면 > 보이는 것
	"show_model": true,        # 명패 아래 모델 칩 ('Opus 4.7') — 기본 켬, 모델을 모르면 (관찰 모드) 칩 없음. 설정 > 화면 > 보이는 것
	# 시간 = 늘 PC 시각 · 계절 · 비행석 없음 (사용자 2026-10-16)
	"city": "",                # 실제 날씨용 도시 (1.1 창밖 연출)
	# 기능 켜기/끄기
	"sway": true,              # 옮길 때 섬 흔들림
	"idle_detect": true,       # 자리 비움 감지
	"idle_minutes": 5,
	"language": "ko",
	"claude_command": false,  # 게임 안 한 줄 명령 (로드맵 ⑤, 선택 기능) — 기본 꺼짐, 설정 > 회사. 명령 · 결과는 저장 안 함 (켜짐 값만)
}

var stats := {}                     ## 통계 (최고 기록 등)
var company := Company.empty()      ## 근무일 · 게임 하루 (company.gd, M5)
var firm := Firm.empty()            ## 회사 이름 · 솔트 · 명패 · 결재함 (firm.gd, M5 3세션째)
var offline_minutes := 0            ## 게임을 꺼 둔 시간(분) — 불러올 때 계산

## 저장하지 않는 실행 중 상태
var runtime := {"hidden": false, "low_power": false, "mini": false}

var no_save := false                ## true 면 저장하지 않음 (이미 실행 중인 게임이 있어 곧 꺼지는 경우)
var _autosave := 0.0
var _defaults := {}
var _prof_t := 0


## 개발용 시간 재기 (`--profile`): 단계 이름과 걸린 시간을 출력
func prof(label: String) -> void:
	if not "--profile" in dev_args():
		return
	var now := Time.get_ticks_msec()
	print("[PROF] %-28s %6d ms  (+%d)" % [label, now, now - _prof_t])
	_prof_t = now


## 개발용 시작 옵션: 개발 실행(디버그 빌드)에서만 쓰고, 배포판에선 무시 → 테스트 기능이 열리지 않음
func dev_args() -> PackedStringArray:
	# "devtest" = 배포판과 똑같이 암호화해 내보낸 점검용 빌드 (배포하지 않음)
	return OS.get_cmdline_user_args() if OS.is_debug_build() or OS.has_feature("devtest") else PackedStringArray()


var _keep_all: Translation = preload("res://scripts/ui/keep_all.gd").new()


## 끝낼 때 번역(스크립트)이 엔진보다 먼저 사라지면 튕김 → 먼저 떼어 냄
func _exit_tree() -> void:
	TranslationServer.remove_translation(_keep_all)


func _ready() -> void:
	TranslationServer.set_locale("ko")   # 한글 줄바꿈: 낱말 가운데서 안 끊기게 (keep_all.gd)
	TranslationServer.add_translation(_keep_all)
	_defaults = _snapshot()   # "처음부터 다시"용 기본값
	load_game()
	_ensure_salt()


func _process(delta: float) -> void:
	_autosave += delta
	if _autosave >= 30.0:
		_autosave = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if is_inside_tree():
			save_game()


# ------------------------------------------------------------------ 통계
func stat(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n


func set_stat_max(key: String, value: int) -> void:
	if value > int(stats.get(key, 0)):
		stats[key] = value


# ------------------------------------------------------------------ 설정
## 실제로 적용할 화면 갱신 수 (숨김 = 5: 다시 나타날 때 빨리 반응하도록, 저전력 = 최대 15)
func effective_fps() -> int:
	if runtime.hidden:
		return 5
	var f := int(settings.fps)
	return mini(f, 15) if runtime.low_power or runtime.get("mini", false) else f


func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	save_game()


# ------------------------------------------------------------------ 저장
func _snapshot() -> Dictionary:
	return {"settings": settings.duplicate(true), "stats": stats.duplicate(true), "company": company.duplicate(true), "firm": firm.duplicate(true)}


## 저장 이전 함수: {n: 버전 n → n+1 로 바꾸는 Callable}
static func migrations() -> Dictionary:
	return {1: _v1_to_v2}


## 1 → 2 (M5 3세션째): firm 칸 추가 — 솔트를 이때 1번 만듦 (1.0 설치 = 아직 솔트 없음), 창업 화면은 아직 안 봄
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var f := Firm.empty()
	f.salt = Firm.new_salt()
	d["firm"] = f
	return d


## 솔트는 설치 때 1번 (C20). 시험 · 미리 보기 실행은 고정값 (그림이 실행마다 바뀌지 않게) · 개발 `--salt=글자`
func _ensure_salt() -> void:
	for a in dev_args():
		if a.begins_with("--salt="):
			firm.salt = a.get_slice("=", 1)
			return
	if is_test_run():
		firm.salt = "skyoffice-test"
	elif str(firm.salt) == "":
		firm.salt = Firm.new_salt()


## firm 바꾸기 (Firm 의 순수 함수 결과) → 알림 + 저장
func set_firm(f: Dictionary, save := true) -> void:
	firm = f
	firm_changed.emit()
	if save:
		save_game()


## 연쇄 이전: 저장 버전부터 target 까지 한 단계씩 (시험 ③ 은 가짜 이전 함수를 넣어 부름)
## 이전 함수가 빠졌으면 거기서 멈춤 · 더 새 버전 (예전 게임으로 되돌린 경우) 은 그대로 두고 아는 키만 씀
static func migrate(data: Dictionary, steps := migrations(), target := SAVE_VERSION) -> Dictionary:
	var d := data.duplicate(true)
	var v := int(d.get("version", 1))
	while v < target:
		if not steps.has(v):
			push_warning("저장 이전 함수 없음: 버전 %d → %d" % [v, v + 1])
			break
		d = (steps[v] as Callable).call(d)
		v += 1
		d["version"] = v
	return d


## 처음부터 다시: 저장 파일 지우고 기본값으로 → 장면 다시 불러오기 (창 위치·모드·크기는 유지)
func reset_game() -> void:
	var keep := {"window_mode": settings.window_mode, "window_pos": settings.window_pos, "size": settings.get("size", 0.8), "size_set": settings.get("size_set", false)}
	var salt := str(firm.salt)   # 솔트는 남김 — 처음부터 다시 해도 같은 PC = 같은 직원 (폐업 정리 때만 지움)
	_apply_data(_defaults.duplicate(true))
	firm.salt = salt
	for k in keep:
		settings[k] = keep[k]
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_game()
	get_tree().reload_current_scene()


## 테스트·미리 보기 실행 (개발용 옵션) — 실제 저장 파일을 건드리지 않음
func is_test_run() -> bool:
	for a in dev_args():
		if a in ["--offscreen", "--fresh"]:
			return true
	return false


func save_game() -> void:
	if no_save or is_test_run():
		return
	write_save(SAVE_PATH)


## 지금 상태를 path 에 암호화해 씀 (하루 백업 · .bak · 임시 파일 바꿔치기 포함 — 쓰는 도중 꺼져도 안전)
func write_save(path: String) -> bool:
	settings["saved_at"] = Time.get_unix_time_from_system()
	var data := _snapshot()
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	if path == SAVE_PATH:
		var today := Time.get_date_string_from_system()
		if FileAccess.file_exists(SAVE_PATH) and str(settings.get("day_backup", "")) != today:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(DAY_BACKUP_PATH))
			settings["day_backup"] = today
			data["settings"]["day_backup"] = today
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var tmp := path + ".tmp"
	var f := FileAccess.open_encrypted_with_pass(tmp, FileAccess.WRITE, SAVE_KEY)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func load_game() -> void:
	if "--fresh" in dev_args():
		return
	var data = read_save(SAVE_PATH)
	if data == null and FileAccess.file_exists(BACKUP_PATH):
		push_warning("저장 파일이 손상되어 백업에서 불러옵니다")
		data = read_save(BACKUP_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		if FileAccess.file_exists(SAVE_PATH):
			push_warning("저장 파일을 읽지 못해 새로 시작합니다")
		return
	_apply_data(data)
	offline_minutes = int(maxf(0.0, Time.get_unix_time_from_system() - float(data.get("saved_at", Time.get_unix_time_from_system()))) / 60.0)


## 하루 백업 정보: {"ok": 있음, "when": "10월 14일 09:03"} (설정 > 정보)
func day_backup_info() -> Dictionary:
	var data = read_save(DAY_BACKUP_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false}
	var dt := Time.get_datetime_dict_from_unix_time(int(float(data.get("saved_at", 0.0)) + Time.get_time_zone_from_system().bias * 60))
	return {"ok": true, "when": "%d월 %d일 %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]}


## 백업으로 되돌리기: 그 저장을 불러와 지금 저장으로 쓰고 장면을 다시 만듦 (지금 모습은 save.bak 에 한 번 남음)
func restore_backup(path := DAY_BACKUP_PATH, reload := true) -> bool:
	var data = read_save(path)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_apply_data(data)
	settings["day_backup"] = Time.get_date_string_from_system()   # 바로 다음 저장이 이 백업을 덮어쓰지 않게
	save_game()
	if reload:
		get_tree().reload_current_scene()
	return true


## 암호화된 저장 읽기 (없거나 손상·암호 불일치면 null)
func read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SAVE_KEY)
	if f == null:
		return null
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else null


func _apply_data(raw: Dictionary) -> void:
	var data := migrate(raw)
	stats = data.get("stats", {})
	company = Company.normalize(data.get("company"))
	firm = Firm.normalize(data.get("firm"))
	var s: Dictionary = data.get("settings", {})
	for k in s:
		if settings.has(k) or k in ["size_set", "saved_at", "day_backup"]:   # 모르는 키(예전 형식)는 버림
			settings[k] = s[k]
	if not settings.get("size_set", false):   # 크기를 직접 바꾼 적 없으면 기본 "작게"
		settings["size"] = 0.8
	changed.emit()
