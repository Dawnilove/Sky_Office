extends Node
## 회사 연출 (M5 2세션째, PLAN 6-1 · 6-3): 단계 상승 · 아침 조회 · 점심 · 퇴근 (일찍 퇴근)
##   company.gd 신호 (day_started · left_early) + 창 진행률 → office 연출. 일정 판단 (due) 은 순수 함수 → 시나리오가 바로 시험
##   일정은 하루 (창) 에 한 번씩. 쉬는 직원만 움직이고, 누가 내 차례면 모임 · 점심을 건너뜀 (말 걸기가 먼저, 5-7)
##   할지 말지는 연출 감독 (director.gd scene, M5 5세션째) — 조용히 모드면 조회 · 점심 없음 · 단계 상승은 가구 · 팝업만
##   단계 상승 = 쉬는 직원 모임 → 박수 + 팝업 → 가구 '뿅' (대단계면 간판 교체). 모두 일하는 중이거나 내 차례면 미룸
##   노을 (75%~) 은 day_night 조명 · 야근 스탠드는 일하는 직원 책상 불 (기존) — 여기서 따로 안 함
##   개발 인자: `--window=0.5` (창 진행률 고정 → 그 때 일정) · `--rhythm=day|assembly|lunch|end|early` (3초 뒤 그 장면)
##             `--stage-up` (3초 뒤 단계 상승 1번, `--stage=N` 과 같이)

const Company := preload("res://scripts/world/company.gd")
const Director := preload("res://scripts/world/director.gd")
const ASSEMBLY_MAX_P := 0.1   ## 아침 조회는 창 10% (30분) 안일 때만 — 늦게 켜면 건너뜀
const LUNCH_P := 1.0 / 3.0    ## 점심 = 12시
const LUNCH_MAX_P := 0.45
const ARRIVE_S := 4.0         ## 출근 버스에서 내려 자리까지 기다림
const WALK_S := 3.2           ## 모임 자리까지 걷기 (3초 안 + 맞춤)
const CLAP_S := 3.0
const BOW_S := 1.6
const NUM := ["①", "②", "③"]

var office: Node3D
var auto := false             ## 실제 실행 (Company 있음) 또는 `--window` — 아니면 개발 인자 장면만
var day := -1.0               ## 지금 하루 (win_start) — 바뀌면 일정 다시
var done := {}                ## 오늘 한 일정 {"assembly" · "lunch" · "end"}
var busy := false             ## 모임 연출 중
var history: Array = []       ## 한 연출 기록 (시험 · 실화면 확인) "assembly" · "stage:2" · "lunch" · "end" · "early" · "day"
var stage_target := -1        ## 개발 `--stage-up` · 시험: 이 단계까지 올림 (-1 = 저장의 shown_stage)
var k := 1.0                  ## 연출 시간 배율 (시험은 줄여서)
var _acc := 0.0
var _fixed_p := -2.0          ## `--window` 값 (-2 = 없음, -1 = off)
var _wait_until := 0.0


func setup(o: Node3D, company: Node) -> void:
	office = o
	for a in Game.dev_args():
		if a.begins_with("--window="):
			var v := a.get_slice("=", 1)
			_fixed_p = -1.0 if v == "off" else clampf(float(v), 0.0, 1.0)
	auto = company != null or _fixed_p > -2.0
	if company:
		company.day_started.connect(on_day_started)
		company.left_early.connect(on_left_early)
	if auto:
		day = float(Game.company.get("win_start", -1.0))
		if progress(_now()) < 0.0:   # 밤에 켬 (창 밖) = 이미 퇴근한 회사
			office.set_off_duty(true)
			done.end = true
		elif progress(_now()) >= ASSEMBLY_MAX_P:
			done.assembly = true
	for a in Game.dev_args():
		if a.begins_with("--rhythm="):
			get_tree().create_timer(3.0).timeout.connect(play.bind(a.get_slice("=", 1)))
		elif a == "--stage-up":
			get_tree().create_timer(3.0).timeout.connect(func() -> void:
				stage_target = office.stage + 1
				stage_up())


func _now() -> float:
	return Time.get_unix_time_from_system()


func progress(now: float) -> float:
	if _fixed_p > -2.0:
		return _fixed_p
	return Company.progress(Game.company, now)


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		tick(_now())


## 1초마다: 오늘 일정 하나 · 아니면 미룬 단계 상승
func tick(now: float) -> void:
	if busy or now < _wait_until:
		return
	if auto and _fixed_p <= -2.0 and float(Game.company.get("win_start", -1.0)) != day:   # 새 하루 (신호를 놓친 경우)
		on_day_started()
		return
	var what := due(progress(now), done) if auto else ""
	if what != "":
		done[what] = true
		play(what)
	elif stage_ready():
		stage_up()


## 지금 할 일정 (순수): p = 창 진행률 (-1 = 창 밖 · 일찍 퇴근), done = 오늘 한 것
static func due(p: float, done_today: Dictionary) -> String:
	if p < 0.0:
		return "" if done_today.has("end") else "end"
	if p < ASSEMBLY_MAX_P and not done_today.has("assembly"):
		return "assembly"
	if p >= LUNCH_P and p < LUNCH_MAX_P and not done_today.has("lunch"):
		return "lunch"
	return ""


## 단계 팝업 글: "창업 ② 첫 의뢰" + 생긴 것 (숫자 · 칭찬 없음)
static func popup_text(n: int) -> String:
	var st: Array = Company.stage_data().stages
	var s: Dictionary = st[n]
	var k2 := 0
	for i in n:
		if st[i].group == s.group:
			k2 += 1
	var t := "%s %s %s" % [s.group, NUM[mini(k2, NUM.size() - 1)], s.name]
	return t + ("\n" + str(s.say) if s.has("say") else "")


func _target() -> int:
	return stage_target if stage_target >= 0 else int(Game.company.get("shown_stage", 0))


## 단계 상승을 지금 할 수 있나: 올릴 단계가 있고 · 내 차례 없음 · 쉬는 직원이 있거나 아무도 일하지 않음
func stage_ready() -> bool:
	if not (auto or stage_target >= 0) or office.stage >= _target() or office.stage + 1 >= Company.stage_data().stages.size():
		return false
	return Director.scene("stage", _ctx()) != "wait" and (not office.resting().is_empty() or not office.any_working())


func _ctx() -> Dictionary:
	return {"turn": office.any_turn(), "quiet": bool(Game.settings.get("quiet", false))}


## 장면 하나 (일정 · 개발 인자)
func play(what: String) -> void:
	history.append(what)
	match what:
		"day":
			on_day_started()
		"early":
			on_left_early()
		"end":
			office.set_off_duty(true)
		"lunch":
			if Director.scene("lunch", _ctx()) == "play":
				office.lunch(office.resting())
		"assembly":
			if stage_ready():
				stage_up()   # 단계가 오른 날은 조회 = 단계 상승 모임
			elif Director.scene("assembly", _ctx()) == "play" and not office.resting().is_empty():
				_assembly()


func on_day_started() -> void:
	day = float(Game.company.get("win_start", -1.0))
	done = {}
	office.set_off_duty(false)   # 쉬던 직원도 버스로 출근
	_wait_until = _now() + ARRIVE_S * k


func on_left_early() -> void:
	done.end = true
	history.append("early")
	office.set_off_duty(true, true)   # 손 흔들고 통근버스 · 게시판 '오늘 업무 끝'


## 아침 조회: 모여서 판을 보고 → 꾸벅 → 흩어짐
func _assembly() -> void:
	busy = true
	var idxs: Array = office.resting()
	office.gather(idxs)
	await get_tree().create_timer(WALK_S * k).timeout
	office.gather_play(idxs, "bow")
	await get_tree().create_timer(BOW_S * k).timeout
	office.gather_end(idxs)
	busy = false


## 단계 상승 1단계: 모임 → 박수 + 팝업 → 가구 '뿅' (대단계 = 간판 교체) → 흩어짐. 모일 직원이 없으면 가구 · 팝업만
func stage_up() -> void:
	busy = true
	var n: int = office.stage + 1
	history.append("stage:%d" % n)
	var idxs: Array = office.resting() if Director.scene("stage", _ctx()) == "play" else []
	if idxs.is_empty():
		office.show_popup(popup_text(n))
		office.apply_stage(n, true)
		busy = false
		return
	office.gather(idxs)
	await get_tree().create_timer(WALK_S * k).timeout
	office.gather_play(idxs, "Clap")
	office.show_popup(popup_text(n))
	await get_tree().create_timer(0.6 * k).timeout
	office.apply_stage(n, true)
	await get_tree().create_timer((CLAP_S - 0.6) * k).timeout
	office.gather_end(idxs)
	busy = false
