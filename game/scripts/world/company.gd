extends Node
## 회사 (PLAN 6-1 · 6-3 · 9-2): 근무일 · 게임 하루 (5시간 창 추정 + 훅 보정)
## 게임 하루 = Claude 5시간 한도 창 1개. 1.0 = 추정만: 직전 창이 끝난 뒤 첫 활동 (UserPromptSubmit, 관찰 모드는 첫 .jsonl 수정) + 5시간
## 훅 보정: StopFailure error "rate_limit" = 일찍 퇴근 · Notification quota_auto_resume_fired = 그 시각부터 새 하루
## 근무일 = 시작한 창 수 (누적, 관찰 모드 활동도 1일). shown_stage = 화면에 보이는 단계 — 게임 하루마다 1단계씩만 따라 올라감
## 상태는 Game.company (저장 파일) 에 둠. 아래 static 함수는 순수 함수 → 시나리오가 시각을 넣어 바로 시험
## 단계 문턱 = data/stages.json · 연출 (단계 상승 · 아침 조회 · 점심 · 퇴근 버스) = company_show.gd (M5 2세션째)

signal day_started   ## 새 게임 하루 (출근 버스 · 아침 조회 · 단계 상승)
signal left_early    ## 한도에 닿아 일찍 퇴근 (손 흔들기 · '오늘 업무 끝')

const WINDOW_S := 18000.0     ## 5시간
const RETRY_S := 600.0        ## 일찍 퇴근 뒤 10분 안에 또 rate_limit = 같은 하루 (다시 시도했다 막힘)
const DAY_START_H := 8.0      ## 창 0% = 08시
const DAY_LEN_H := 12.0       ## 창 100% = 20시
const NIGHT_H := 22.0         ## 창 밖 = 밤
const DUSK_S := 1800.0        ## 창이 끝난 뒤 30분 동안 밤으로 넘어감

const STAGES := "res://data/stages.json"

## 단계 문턱 (근무일) = data/stages.json 의 days (M5 2세션째). 시험은 바꿔 넣었다 되돌림
static var thresholds: Array = stage_days()


## data/stages.json → {"stages": [...], "looks": {...}}. 못 읽으면 첫 단계만
static func stage_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(STAGES))
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("stages")) != TYPE_ARRAY or (d.stages as Array).is_empty():
		return {"stages": [{"group": "창업", "name": "첫 출근", "days": 0, "unlock": []}], "looks": {}}
	return d


static func stage_days() -> Array:
	return stage_data().stages.map(func(s) -> int: return int(s.days))


## 단계 번호 → 사무실 크기 (지름). stages.json 의 diameter 중 그 단계까지 가장 큰 값, 없으면 10 (1.1 증축 — 켤 때 적용)
static func diameter_for(stage: int) -> int:
	var d := 10
	var st: Array = stage_data().stages
	for i in mini(stage + 1, st.size()):
		d = maxi(d, int(st[i].get("diameter", 10)))
	return d


## 단계 번호 → 그때까지 생긴 것 (unlock 누적)
static func unlocked(stage: int) -> Array:
	var out: Array = []
	var st: Array = stage_data().stages
	for i in mini(stage + 1, st.size()):
		out.append_array(st[i].get("unlock", []))
	return out


static func empty() -> Dictionary:
	return {"earned_days": 0, "shown_stage": 0, "win_start": -1.0, "early_at": -1.0, "provisional": false, "prev_start": -1.0, "last_t": -1.0}


## 저장에서 불러온 값 → 모르는 키 버리고 빠진 키 채움
static func normalize(v: Variant) -> Dictionary:
	var out := empty()
	if typeof(v) == TYPE_DICTIONARY:
		for k in out:
			if v.has(k):
				out[k] = v[k]
	out.earned_days = int(out.earned_days)
	out.shown_stage = int(out.shown_stage)
	return out


## 지금 창이 끝나는 시각 (일찍 퇴근이면 그 시각). 창이 없으면 -1
static func window_end(st: Dictionary) -> float:
	if float(st.win_start) < 0.0:
		return -1.0
	return float(st.early_at) if float(st.early_at) >= 0.0 else float(st.win_start) + WINDOW_S


## 이벤트 하나 반영. kind = "prompt" (UserPromptSubmit) · "jsonl" (관찰 모드) · "rate_limit" · "resume"
## 돌려줌: {"state": 새 상태, "day": 새 하루 시작?, "early": 일찍 퇴근?}
static func on_event(state: Dictionary, kind: String, t: float) -> Dictionary:
	var st := state.duplicate(true)
	var out := {"state": st, "day": false, "early": false}
	if t < float(st.last_t):
		return out   # 늦게 도착한 옛 신호 (순서 뒤바뀜) — 무시
	st.last_t = t
	var start := float(st.win_start)
	var open := start >= 0.0 and t < start + WINDOW_S   # 5시간 안 (일찍 퇴근 여부와 별개)
	var early := open and float(st.early_at) >= 0.0
	match kind:
		"prompt", "jsonl":
			if not open:
				_new_day(st, t, false)
				out.day = true
			elif early and kind == "prompt":   # 재개 알림이 안 오는 경우: 다음 메시지 = 새 하루 (막히면 되돌림)
				_new_day(st, t, true)
				out.day = true
		"rate_limit":
			if bool(st.provisional) and t - start < RETRY_S:   # 다시 시도했는데 또 막힘 → 방금 센 하루 취소
				st.earned_days = maxi(0, int(st.earned_days) - 1)
				st.win_start = float(st.prev_start)
				st.early_at = t
				st.provisional = false
			elif open and not early:
				st.early_at = t
				out.early = true
		"resume":
			if open and not early and t - start < RETRY_S:
				st.win_start = t   # 방금 시작한 하루 = 같은 하루, 경계만 바로잡음
				st.provisional = false
			else:
				_new_day(st, t, false)
				out.day = true
	if not bool(st.provisional):
		st.prev_start = -1.0
	return out


static func _new_day(st: Dictionary, t: float, provisional: bool) -> void:
	if provisional:
		st.prev_start = st.win_start
	st.win_start = t
	st.early_at = -1.0
	st.provisional = provisional
	st.earned_days = int(st.earned_days) + 1
	if int(st.shown_stage) < stage_for(int(st.earned_days)):   # 업데이트로 문턱이 생겨도 하루 1단계씩
		st.shown_stage = int(st.shown_stage) + 1


## 근무일 → 도달한 단계 번호 (0부터)
static func stage_for(days: int) -> int:
	var s := 0
	for i in thresholds.size():
		if days >= int(thresholds[i]):
			s = i
	return s


## 창 진행률 0~1. 창 밖 (시작 전 · 5시간 지남 · 일찍 퇴근) = -1
static func progress(st: Dictionary, now: float) -> float:
	var start := float(st.win_start)
	if start < 0.0 or now < start or now >= window_end(st):
		return -1.0
	return (now - start) / WINDOW_S


## 게임 시각 (시): 창 0% = 08시 → 100% = 20시. 창이 끝나면 30분 동안 22시 (밤) 로, 창이 없으면 밤
static func hour_at(st: Dictionary, now: float) -> float:
	var p := progress(st, now)
	if p >= 0.0:
		return DAY_START_H + DAY_LEN_H * p
	var end := window_end(st)
	if end < 0.0 or now < float(st.win_start):
		return NIGHT_H
	var end_h := DAY_START_H + DAY_LEN_H * clampf((end - float(st.win_start)) / WINDOW_S, 0.0, 1.0)
	return lerpf(end_h, NIGHT_H, clampf((now - end) / DUSK_S, 0.0, 1.0))


## 창 진행률 → 게임 시각 (개발용 `--window=0.5`)
static func hour_of(p: float) -> float:
	return DAY_START_H + DAY_LEN_H * clampf(p, 0.0, 1.0)


# ------------------------------------------------------------------ 노드: 감지기 신호 → Game.company
## agent_watch.activity 에 연결. 새 하루 · 일찍 퇴근이면 바로 저장
func feed(kind: String, t: float) -> void:
	var r := on_event(Game.company, kind, t)
	Game.company = r.state
	if r.day:
		day_started.emit()
	if r.early:
		left_early.emit()
	if r.day or r.early:
		Game.save_game()
