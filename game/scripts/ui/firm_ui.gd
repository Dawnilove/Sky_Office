extends Node
## 회사 옷 화면 (PLAN 5-7 · 6-2 · 6-4 · 8장, M5 3세션째) — 창업 화면 · 입사식 · 결재함 · 돌아오면 요약 · 설정 '회사' 탭
##   상태 = Game.firm (firm.gd 순수 함수로 바꿈). 간판 · 이름판은 Game.firm_changed 로 다시 그림
##   개발 인자: `--found` (창업 화면) · `--hire-card` (입사식 카드) · `--ledger` (결재함 견본 장 + 패널) · `--back` (돌아오면 요약 카드) · `--hashed` (데모 직원도 해시 직원)

const Firm := preload("res://scripts/game/firm.gd")
const StaffHash := preload("res://scripts/world/staff_hash.gd")
const HangulInput := preload("res://scripts/ui/hangul_input.gd")
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")
const AWAY_SHOW_S := 10.0   ## 돌아오면 요약 카드 10초

var ui: CanvasLayer
var office: Node3D
var routine: Node            ## office_routine (없으면 직원 기록 없음 — 데모 · 화면 밖)
var company: Node            ## company.gd (없으면 하루 마감 없음)
var found_card: PanelContainer
var hire_card: PanelContainer
var away_card: PanelContainer
var hire_queue: Array = []   ## 입사식 기다리는 직원 id
var hire_id := -1            ## 지금 카드의 직원
var away := false
var away_done := 0
var away_turn := 0
var away_text := ""          ## 띄울 요약 (내 차례 중이면 기다림)
var shown_away: Array = []   ## 띄운 요약 글 (시험 · 그림 확인)
var _acc := 0.0
var _editing := -1           ## 설정 '회사' 탭에서 명패를 바꾸는 직원 id (-1 = 없음)
var close_section: Callable   ## 설정 '회사' 탭 맨 아래 폐업 정리 (phone_ui.close_section, M5 4세션째)
var demo_looks := {}         ## `--hashed` 데모 직원 (routine 없을 때 설정 '회사' 탭 그림용)


func setup(u: CanvasLayer, o: Node3D, r: Node, c: Node) -> void:
	ui = u
	office = o
	routine = r
	company = c
	Game.firm_changed.connect(_on_firm_changed)
	_on_firm_changed()
	if routine:
		routine.counted.connect(on_counted)
	if company:
		company.day_started.connect(func() -> void: close_day(int(Game.company.earned_days) - 1, float(Game.company.win_start)))
		company.left_early.connect(func() -> void: close_day(int(Game.company.earned_days), -2.0))
	Game.away_started.connect(on_away_started)
	Game.away_ended.connect(on_away_ended)
	var dev := Game.dev_args()
	if "--hashed" in dev:
		_demo_hashed()
	if "--ledger" in dev:
		_demo_ledger()
		ui.open_panel.call_deferred("tray")
	if "--hire-card" in dev:
		get_tree().create_timer(0.5).timeout.connect(func() -> void: show_hire(0, "서연"))
	if "--back" in dev:
		get_tree().create_timer(0.5).timeout.connect(func() -> void: show_away(Firm.away_text(2, 1)))
	if "--found" in dev or (not Game.firm.founded and not Game.is_test_run() and not "--demo" in dev):
		show_found.call_deferred()


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	if Game.firm.founded and routine and not routine._reg.is_empty() and found_card == null:   # 입사식: 명패가 없는 책상 직원 (창업 화면 다음)
		for id in Firm.need_ceremony(Game.firm, routine._reg):
			if id != hire_id and not (id in hire_queue):
				hire_queue.append(id)
		if hire_card == null and not hire_queue.is_empty():
			_next_hire()
	if away_text != "" and not away and not _calling():   # 내 차례 중엔 미룸 (5-3)
		show_away(away_text)
		away_text = ""


func _calling() -> bool:
	return routine != null and OfficeRoutine.calling(routine.shown) > 0


func _on_firm_changed() -> void:
	office.set_sign_text(Firm.sign_name(Game.firm))
	if routine and routine.watch:   # 명패가 바뀜 → 이름판 바로 (시험 일과는 감지기 없음)
		routine.refresh()


## 직원 id → 보일 이름 (해시 · 명패)
func names() -> Dictionary:
	var out := {}
	if routine:
		for id in routine.looks:
			out[id] = routine.looks[id].name
	return out


# ------------------------------------------------------------------ 결재함 · 돌아오면 요약 셈
func on_counted(kind: String, staff_id: int) -> void:
	Game.set_firm(Firm.count(Game.firm, kind, staff_id, float(Game.company.get("win_start", -1.0)), names()), false)
	if away:
		match kind:
			"done":
				away_done += 1
			"turn":
				away_turn += 1


## 하루 마감 → 결재함 한 장 (기록 없는 날은 안 꽂음)
func close_day(days: int, next_day: float) -> void:
	Game.set_firm(Firm.close_day(Game.firm, days, names(), next_day))


func on_away_started() -> void:
	away = true
	away_done = 0
	away_turn = 0


func on_away_ended(_minutes: int) -> void:
	away = false
	away_text = Firm.away_text(away_done, away_turn)   # 0건이면 "" → 안 띄움


# ------------------------------------------------------------------ 카드 공통
func _float_card(title: String) -> Array:
	var card: PanelContainer = ui._card()
	card.add_to_group("ui_bounds")
	ui.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	if title != "":
		var t := Label.new()
		t.text = title
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", ui.TEXT)
		v.add_child(t)
	return [card, v]


## 창업 화면 · 입사식 = 큰 카드 (사용자 "창업 창을 좀 크게"): 폭 · 글자 · 입력칸 · 버튼 키움
const FOUND_W := 420.0
const FOUND_TITLE := 24
const FOUND_TEXT := 16
const FOUND_INPUT := 20


## 카드를 섬 가운데 (y = 0~1 비율) 에 놓음
func _place(card: Control, y: float) -> void:
	card.reset_size()
	var a: Rect2 = ui.main_area if ui.main_area.size != Vector2.ZERO else Rect2(Vector2.ZERO, ui._vp())
	card.position = Vector2(round(a.position.x + a.size.x * 0.55 - card.size.x / 2), round(a.position.y + a.size.y * y - card.size.y / 2))
	ui.layout_changed.emit()


func _close(card: Control) -> void:
	if card and is_instance_valid(card):
		card.remove_from_group("ui_bounds")
		card.queue_free()
	ui.layout_changed.emit.call_deferred()


func _buttons(v: VBoxContainer, items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for it in items:
		var b: Button = ui.button(it[0], it[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)


func _input_box(max_len: int, hint: String, text := "") -> HangulInput:
	var inp := HangulInput.new()
	inp.max_length = max_len
	inp.placeholder = hint
	inp.set_text(text)
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return inp


# ------------------------------------------------------------------ 창업 화면 (6-2 · 8장 첫 실행)
func show_found() -> void:
	if found_card:
		return
	var cv := _float_card("창업을 축하해요!")
	found_card = cv[0]
	var v: VBoxContainer = cv[1]
	_big_card(found_card, v)
	v.add_child(_big_note("하늘에 새 회사가 떴어요.\n간판에 걸 회사 이름을 지어 주세요.", FOUND_TEXT))
	var inp := _big_input(Firm.NAME_MAX, Firm.DEFAULT_NAME, str(Game.firm.name))
	v.add_child(inp)
	var done := func(nm: String) -> void:
		var f: Dictionary = Game.firm.duplicate(true)
		f.name = Firm.clean_name(nm, Firm.NAME_MAX)
		f.founded = true
		Game.set_firm(f)
		_close(found_card)
		found_card = null
		Game.toast.emit("%s 창업!" % Firm.sign_name(f))
	inp.text_submitted.connect(func(t: String) -> void: done.call(t))
	_big_buttons(v, [["창업하기", func() -> void: done.call(inp.get_text())], ["건너뛰기", func() -> void: done.call("")]])
	v.add_child(_big_note("건너뛰면 '%s'. 나중에 설정에서도 바꿀 수 있어요." % Firm.DEFAULT_NAME, 14))
	_place(found_card, 0.45)
	inp.grab_input_focus.call_deferred()


## 큰 카드 (창업 화면 · 입사식, 사용자 "창업 창을 좀 크게"): 폭 · 여백 · 제목 키움
func _big_card(card: PanelContainer, v: VBoxContainer) -> void:
	card.custom_minimum_size.x = FOUND_W
	var sb := (card.get_theme_stylebox("panel") as StyleBoxFlat)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 24)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	v.add_theme_constant_override("separation", 12)
	(v.get_child(0) as Label).add_theme_font_size_override("font_size", FOUND_TITLE)


## 안내 글: 문장마다 직접 줄바꿈 (사용자) — 자동 줄바꿈은 끔 (줄바꿈 자리만큼 아래 빈칸이 생기지 않게)
func _big_note(text: String, size: int) -> Label:
	var l: Label = ui._note(text)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _big_input(max_len: int, hint: String, text := "") -> HangulInput:
	var inp := _input_box(max_len, hint, text)
	inp.font_size = FOUND_INPUT
	inp.get_child(0).custom_minimum_size.y = 48
	inp.get_child(1).custom_minimum_size = Vector2(48, 48)
	return inp


func _big_buttons(v: VBoxContainer, items: Array) -> void:
	_buttons(v, items)
	for b in v.get_child(v.get_child_count() - 1).get_children():
		(b as Button).custom_minimum_size.y = 44
		(b as Button).add_theme_font_size_override("font_size", 17)


# ------------------------------------------------------------------ 입사식 (5-7 C29 · 8장): 직원 이름 정하기, 비우면 자동 (팀 이름 없음, M5 5세션째 사용자)
func _next_hire() -> void:
	while not hire_queue.is_empty():
		var id: int = hire_queue.pop_front()
		if Game.firm.plates.has(str(id)) or not routine.looks.has(id):
			continue
		show_hire(id, str(routine.looks[id].name))
		return


func show_hire(id: int, auto_name: String) -> void:
	if hire_card:
		_close(hire_card)
	hire_id = id
	var cv := _float_card("새 직원 입사")
	hire_card = cv[0]
	var v: VBoxContainer = cv[1]
	_big_card(hire_card, v)
	v.add_child(_big_note("%s 님이 짐 상자를 들고 첫 출근해요.\n이름을 정해 주세요." % auto_name, FOUND_TEXT))
	var inp := _big_input(Firm.PLATE_MAX, auto_name)
	v.add_child(inp)
	var done := func(nm: String) -> void:
		Game.set_firm(Firm.set_plate(Game.firm, id, nm, ""))
		_close(hire_card)
		hire_card = null
		hire_id = -1
	inp.text_submitted.connect(func(t: String) -> void: done.call(t))
	var items := [["정하기", func() -> void: done.call(inp.get_text())], ["자동 (%s)" % auto_name, func() -> void: done.call("")]]
	if hire_queue.size() > 0:
		items.append(["모두 자동", func() -> void:
			for q in hire_queue:
				Game.firm = Firm.set_plate(Game.firm, int(q), "", "")
			hire_queue.clear()
			done.call("")])
	_big_buttons(v, items)
	v.add_child(_big_note("명패 = 이름 · 작업 폴더. 나중에 설정에서도 바꿀 수 있어요.", 14))
	_place(hire_card, 0.74)


# ------------------------------------------------------------------ 돌아오면 요약 (6-4): 카드 1장, 10초 뒤 사라짐
func show_away(text: String) -> void:
	if text == "":
		return
	shown_away.append(text)
	if away_card:
		_close(away_card)
	var cv := _float_card("")
	away_card = cv[0]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", ui.TEXT)
	(cv[1] as VBoxContainer).add_child(l)
	_place(away_card, 0.2)
	var card := away_card
	var tw := card.create_tween()
	tw.tween_interval(AWAY_SHOW_S - 0.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_close(card)
		if away_card == card:
			away_card = null)


# ------------------------------------------------------------------ 결재함 패널 (C21): 한 장 = 출근부 · 출근한 직원 · 완료 · 결재 (숫자 + 이름만)
func tray_panel(body: VBoxContainer) -> void:
	var t: Dictionary = Game.firm.today
	var sheets: Array = []
	if not (t.staff as Array).is_empty() or int(t.done) > 0 or int(t.turn) > 0:
		var who: Array = []
		var nm := names()
		for id in t.staff:
			who.append(str(nm.get(int(id), "직원")))
		sheets.append({"title": "오늘 (%d일째, 쓰는 중)" % maxi(1, int(Game.company.earned_days)), "staff": who, "done": t.done, "turn": t.turn})
	var led: Array = Game.firm.ledger.duplicate()
	led.reverse()
	for s in led:
		sheets.append({"title": "출근부 %d일째 · %s" % [int(s.day), _date(float(s.t))], "staff": s.staff, "done": s.done, "turn": s.turn})
	if sheets.is_empty():
		body.add_child(ui._note("아직 서류가 없어요. 게임 하루가 끝나면 퇴근 보고 · 업무 일지 · 출근부가 한 장으로 꽂혀요."))
		return
	for s in sheets:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ui.CARD
		sb.border_color = ui.LINE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var h := Label.new()
		h.text = s.title
		h.add_theme_font_size_override("font_size", 14)
		h.add_theme_color_override("font_color", ui.TEXT)
		v.add_child(h)
		v.add_child(ui._note("출근: %s" % (" · ".join(s.staff) if not (s.staff as Array).is_empty() else "없음")))
		v.add_child(ui._note("완료 %d · 결재 %d" % [int(s.done), int(s.turn)]))
		body.add_child(card)
	body.add_child(ui._note("최근 %d장만 남고 오래된 장은 저절로 정리돼요." % Firm.LEDGER_MAX))


func _date(t: float) -> String:
	if t <= 0.0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(int(t) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%d월 %d일" % [d.month, d.day]


# ------------------------------------------------------------------ 설정 > 회사 탭: 회사 이름 · 명패 바꾸기 (C17)
func firm_tab(body: VBoxContainer) -> void:
	ui.group(body, "회사 이름")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var inp := _input_box(Firm.NAME_MAX, Firm.DEFAULT_NAME, str(Game.firm.name))
	row.add_child(inp)
	var save_name := func() -> void:
		var f: Dictionary = Game.firm.duplicate(true)
		f.name = Firm.clean_name(inp.get_text(), Firm.NAME_MAX)
		f.founded = true
		Game.set_firm(f)
		Game.toast.emit("간판: %s" % Firm.sign_name(f))
	inp.text_submitted.connect(func(_t: String) -> void: save_name.call())
	row.add_child(ui.button("바꾸기", save_name))
	body.add_child(row)
	body.add_child(ui._note("비우면 '%s'. 간판에 %d글자까지." % [Firm.DEFAULT_NAME, Firm.NAME_MAX]))
	ui.group(body, "명패 (직원 이름)")
	var lks: Dictionary = routine.looks if routine else demo_looks
	if lks.is_empty():
		body.add_child(ui._note("아직 직원이 없어요. Claude Code 로 일을 시작하면 입사해요."))
	var ids := lks.keys()
	ids.sort()
	for id in ids:
		var lk: Dictionary = lks[id]
		if _editing == int(id):
			var pl: Dictionary = Game.firm.plates.get(str(id), {})
			var n_in := _input_box(Firm.PLATE_MAX, StaffHash.NAMES[int(lk.look.name)], str(pl.get("name", "")))
			ui.section(body, "직원 이름")
			body.add_child(n_in)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 6)
			for it in [["저장", func() -> void:
						Game.set_firm(Firm.set_plate(Game.firm, int(id), n_in.get_text(), ""))
						_editing = -1
						ui.refresh_panel()],
					["자동으로", func() -> void:
						Game.set_firm(Firm.set_plate(Game.firm, int(id), "", ""))
						_editing = -1
						ui.refresh_panel()],
					["취소", func() -> void:
						_editing = -1
						ui.refresh_panel()]]:
				var b: Button = ui.button(it[0], it[1])
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(b)
			body.add_child(h)
			continue
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.text = str(lk.name)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", ui.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(ui.button("바꾸기", func() -> void:
			_editing = int(id)
			ui.refresh_panel()))
		body.add_child(r)
	body.add_child(ui._note("비우면 자동 이름. 명패 = '이름 · 작업 폴더' ('화면' 탭에서 폴더 끄면 이름만)."))
	if close_section.is_valid():
		close_section.call(body)


# ------------------------------------------------------------------ 개발 인자 (그림)
## `--hashed`: 데모 직원 (책상 자리) 도 해시 직원 겉모습 · 이름 · 팀 (가짜 프로젝트 "demo0" …)
func _demo_hashed() -> void:
	var reg := {"staff": []}
	for i in office.desk_count:
		reg.staff.append({"id": i, "agent": "claude", "proj": "demo%d" % i, "desk": i, "leave": false})
	var lks := StaffHash.staff_looks(reg, str(Game.firm.salt), Game.firm.plates)
	demo_looks = lks
	for i in office.desk_count:
		office.set_look(i, lks[i].look)
		office.set_staff_name(i, str(lks[i].name))
		office.set_staff_team(i, str(lks[i].team))


## `--ledger`: 견본 장 3장 + 오늘 (저장 안 함 — 개발 실행)
func _demo_ledger() -> void:
	var f := Firm.empty()
	f.salt = Game.firm.salt
	f.name = Game.firm.name
	f.founded = true
	var now := Time.get_unix_time_from_system()
	f.ledger = [{"day": 10, "t": now - 3 * 86400.0, "staff": ["서연", "민준"], "done": 6, "turn": 2},
			{"day": 11, "t": now - 2 * 86400.0, "staff": ["서연"], "done": 3, "turn": 1},
			{"day": 12, "t": now - 86400.0, "staff": ["서연", "민준", "하은"], "done": 9, "turn": 4}]
	Game.set_firm(f, false)
