extends CanvasLayer
## 화면 UI: 상단 HUD (손잡이 · 시계) + 왼쪽 세로 메뉴 + 메뉴별 패널 + 말풍선 도움말 + 알림
## 패널 내용은 각 시스템이 register_panel(아이콘, 제목, 내용 만드는 함수)로 등록

signal layout_changed            ## UI 영역이 바뀜 → 창 클릭 영역 다시 계산
signal panel_closed(id: String)
signal panel_opened(id: String)

const IconButton := preload("res://scripts/ui/icon_button.gd")
const HangulInput := preload("res://scripts/ui/hangul_input.gd")
const BAR_PANELS: Array = []   ## 얇은 바 모양으로 여는 패널 (지금은 없음)

const MENU := [
	["tray", "결재함"], ["gear", "설정"], ["power", "종료"],
]
var BG := Color("f4efe6")      ## 창·카드 바탕 (섬 테마가 바꿀 수 있음)
var TEXT := Color("4a3f35")
var SUB := Color("8a7d70")
var BTN := Color("ebe3d4")           ## 버튼 바탕
var BTN_HOVER := Color("e1d6c2")
var ACCENT := Color("7fa35a")     ## 누른 버튼·막대 채움
var ACCENT_DARK := Color("5f8f3e")
var TRACK := Color("e3dacb")       ## 막대 바탕
var CARD := Color("fbf8f2")         ## 창 안의 작은 카드 바탕
var LINE := Color("e6dccb")         ## 카드 테두리·구분선
var DISABLED := Color("efeae1")
var DISABLED_TEXT := Color("b5aca0")

var window_ctl: Node             ## desktop_window (손잡이 드래그·창 모드)
var hud: PanelContainer
var chips: PanelContainer      ## 직원 칩 바 (PLAN v2.3 3-3): 이름 + 상태 점, 노랑이 맨 앞. 미니 모드에선 UI 와 함께 숨김
var menu: PanelContainer
var panel: PanelContainer        ## 현재 열린 패널
var panel_id := ""
var _panel_body: VBoxContainer
var _menu_buttons := {}
var _labels := {}
var _tip: PanelContainer
var _tip_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _builders := {}              ## 아이콘 → [제목, Callable(content: VBoxContainer)]
var clock_label: Label           ## HUD 시계 ("가을 · 08:03 · 맑음" / 집중 중이면 남은 시간) — 누르면 시계 창
var clock_text: Callable         ## main.gd: func(short) -> [글자, 집중 중?]
var sound_panel: Callable        ## 설정 > 소리 탭 (sound.panel)
var firm_panel: Callable         ## 설정 > 회사 탭 (firm_ui.firm_tab, M5 3세션째)
var main_area := Rect2()        ## 본섬이 보이는 영역 (UI 좌표) — 확장 섬으로 창이 넓어져도 HUD는 본섬 위에
var ui_scale := 1.0              ## 섬 크기가 작을 때 UI도 조금 줄임 (글자가 너무 작아지지 않게 섬보다 덜)
var _panel_scroll: ScrollContainer


func _ready() -> void:
	layer = 10
	_build_theme()
	_build_hud()
	_build_menu()
	_build_tip()
	_build_toast()
	register_panel("gear", "설정", _settings_panel)
	register_panel("power", "종료", _quit_panel)
	Game.changed.connect(_refresh)
	Game.toast.connect(show_toast)
	Updater.changed.connect(_on_update_changed)
	Updater.progressed.connect(func() -> void:
		if is_instance_valid(_upd_label):
			_upd_label.text = _update_text())
	Game.settings_changed.connect(_apply_visibility)
	_refresh()
	_apply_visibility()
	_place.call_deferred()


# ------------------------------------------------------------------ 공개 함수
func set_ui_scale(s: float) -> void:
	ui_scale = s
	scale = Vector2(s, s)
	_place.call_deferred()
	_place_panel.call_deferred()


## UI 좌표 기준 화면 크기 (UI 배율 반영)
func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size / ui_scale


func register_panel(id: String, title: String, builder: Callable) -> void:
	_builders[id] = [title, builder]


func open_panel(id: String) -> void:
	if panel_id == id:
		close_panel()
		return
	close_panel()
	panel_id = id
	if _menu_buttons.has(id):
		_menu_buttons[id].selected = true
	panel = _card()
	panel.add_to_group("ui_bounds")
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if id in BAR_PANELS:   # 얇은 바 모양: 제목·닫기 없이 내용만, HUD 바로 아래 (_place_panel)
		var psb := panel.get_theme_stylebox("panel") as StyleBoxFlat
		psb.content_margin_top = 6
		psb.content_margin_bottom = 6
		psb.content_margin_left = 12
		psb.content_margin_right = 8
		var bar_body := VBoxContainer.new()
		bar_body.add_theme_constant_override("separation", 6)
		v.add_child(bar_body)
		_panel_scroll = null
		_panel_body = bar_body
		_builders[id][1].call(bar_body)
		panel_opened.emit(id)
		_place_panel.call_deferred()
		return
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = _builders.get(id, ["준비 중"])[0]
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := IconButton.new("close", "", 24.0)
	x.pressed.connect(close_panel)
	head.add_child(x)
	var scroll := ScrollContainer.new()   # 긴 패널(설정 기능 탭 등)은 창 높이를 넘지 않게 스크롤
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_panel_scroll = scroll
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_panel_body = body
	if _builders.has(id):
		_builders[id][1].call(body)
	else:
		body.add_child(_note("곧 추가될 기능이에요."))
	panel_opened.emit(id)
	_place_panel.call_deferred()


func close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
	if panel_id != "":
		if _menu_buttons.has(panel_id):
			_menu_buttons[panel_id].selected = false
		var old := panel_id
		panel_id = ""
		panel_closed.emit(old)
	layout_changed.emit.call_deferred()


## 열린 패널 내용을 다시 만듦 (값이 바뀌었을 때)
func refresh_panel() -> void:
	if panel_id == "" or _panel_body == null or not _builders.has(panel_id):
		return
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()
	_builders[panel_id][1].call(_panel_body)
	_place_panel.call_deferred()


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.reset_size()
	var below: float = hud.position.y + hud.size.y   # 꾸미기 바가 열려 있으면 그 아래에
	if panel and panel_id in BAR_PANELS:
		below = panel.position.y + panel.size.y
	_toast.position = Vector2(hud.position.x + hud.size.x / 2 - _toast.size.x / 2, below + 10)
	layout_changed.emit()
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_toast.visible = false
		layout_changed.emit())


func toggle_ui() -> void:
	Game.set_setting("ui_visible", not Game.settings.ui_visible)


# ------------------------------------------------------------------ 위젯 도우미 (다른 패널에서도 사용)
func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = _theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.16)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	return p


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", SUB)
	l.add_theme_font_size_override("font_size", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 240
	return l


## 묶음 제목: 진한 글씨 + 위 여백 (설정·상점에서 구역 나누기)
func group(body: VBoxContainer, text: String) -> void:
	if body.get_child_count() > 1:
		var gap := Control.new()
		gap.custom_minimum_size.y = 4
		body.add_child(gap)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", TEXT)
	body.add_child(l)
	var line := ColorRect.new()
	line.color = Color(SUB, 0.25)
	line.custom_minimum_size.y = 1
	body.add_child(line)


func section(body: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", SUB)
	body.add_child(l)


## 여러 개 중 하나 고르는 버튼 묶음. options: [[표시 글자, 값], ...]
func segment(options: Array, current, on_select: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for o in options:
		var b := Button.new()
		b.text = o[0]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (o[1] == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val = o[1]
		b.pressed.connect(func() -> void: on_select.call(val))
		h.add_child(b)
	return h


## 섬 크기 슬라이드바 (기본 크기 = 100%, 50~180%): 끄는 동안은 숫자만, 손을 떼면 적용
## (창 크기가 바뀌며 슬라이드바가 손 밑에서 움직이지 않게). 모니터보다 크면 화면에 맞춰 줄임
const SIZE_BASE := 0.8   ## 100%에 해당하는 섬 배율 (처음 크기)


func _size_slider() -> VBoxContainer:
	var v := VBoxContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var s := HSlider.new()
	s.min_value = 50
	s.max_value = 180
	s.step = 5
	s.value = float(Game.settings.get("size", SIZE_BASE)) / SIZE_BASE * 100.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var pct := Label.new()
	pct.custom_minimum_size.x = 50
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	var fit := _note("")
	v.add_child(fit)
	var show := func(val: float) -> void:
		pct.text = "%d%%" % int(round(val))
		var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var max_k := minf((scr.size.x - 20.0) / 1080.0, (scr.size.y + 40.0) / 740.0)   # main.gd 의 창 크기 계산과 같은 기준 (BASE_SIZE, 확장 섬 제외)
		fit.text = "이 화면에선 %d%%까지 보여요 (더 크게 하면 화면에 맞춰요)" % int(max_k / SIZE_BASE * 100.0) if val / 100.0 * SIZE_BASE > max_k + 0.001 else ""
		fit.visible = fit.text != ""
	show.call(s.value)
	var apply := func() -> void:
		var k := snappedf(s.value / 100.0 * SIZE_BASE, 0.001)
		if not is_equal_approx(float(Game.settings.get("size", SIZE_BASE)), k):
			Game.settings["size_set"] = true   # 직접 고른 적 있음 → 다음 실행에도 유지
			Game.set_setting("size", k)
	s.value_changed.connect(func(val: float) -> void:
		show.call(val)
		if not s.has_meta("dragging"):   # 클릭·키보드로 바꾼 경우 바로 적용
			apply.call())
	s.drag_started.connect(func() -> void: s.set_meta("dragging", true))
	s.drag_ended.connect(func(_changed: bool) -> void:
		s.remove_meta("dragging")
		apply.call())
	return v


## 퍼센트 슬라이드바 한 줄: [이름 ───●── 70%] — 손을 떼거나 클릭하면 on_change(값)
func _percent_slider(label: String, lo: int, hi: int, value: float, on_change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", SUB)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 5
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var pct := Label.new()
	pct.custom_minimum_size.x = 50
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % int(round(value))
	h.add_child(pct)
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v))
		if not s.has_meta("dragging"):
			on_change.call(v))
	s.drag_started.connect(func() -> void: s.set_meta("dragging", true))
	s.drag_ended.connect(func(_c: bool) -> void:
		s.remove_meta("dragging")
		on_change.call(s.value))
	return h


## 실제 날씨 도시 입력 한 줄 [입력칸 가/A 저장] — 설정 > 시간·날씨
func city_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var inp := HangulInput.new()
	inp.max_length = 30
	inp.placeholder = "예: 서울, Busan"
	inp.set_text(Game.settings.city)
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(inp)
	var save_city := func() -> void:
		var s := inp.get_text().strip_edges()
		Game.set_setting("city", s)
		Game.toast.emit("도시 저장: %s" % s)
	inp.text_submitted.connect(func(_t: String) -> void: save_city.call())
	row.add_child(button("저장", save_city))
	return row


func button(text: String, on_press: Callable, danger := false) -> Button:
	var b := Button.new()
	b.text = text
	if danger:
		var sb := (_theme.get_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = Color("e0484f")
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color("c93a41")
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(on_press)
	return b


# ------------------------------------------------------------------ 구성
func _build_theme() -> void:
	var th := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "Arial"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	th.default_font = font
	th.default_font_size = 15
	bold_font = font.duplicate() as SystemFont
	(bold_font as SystemFont).font_weight = 700
	th.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		match state:
			"normal": sb.bg_color = BTN
			"hover": sb.bg_color = BTN_HOVER
			"pressed", "hover_pressed": sb.bg_color = ACCENT
			"focus": sb.draw_center = false
			"disabled": sb.bg_color = DISABLED
		th.set_stylebox(state, "Button", sb)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", DISABLED_TEXT)
	# 슬라이드바: 둥근 홈 + 채워진 부분 초록 + 흰 동그라미 손잡이
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_icon("grabber", "HSlider", _knob(ACCENT))
	th.set_icon("grabber_highlight", "HSlider", _knob(ACCENT_DARK))
	_theme = th   # CanvasLayer는 테마를 물려주지 못하므로 카드마다 직접 지정 (_card 참고)


## 슬라이드바 손잡이 그림: 흰 원 + 색 테두리 (가장자리 부드럽게)
static func _knob(edge: Color) -> Texture2D:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			var col := Color.WHITE if d < c - 3.0 else edge
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


var _theme: Theme
var bold_font: Font              ## 굵은 글자 (제목 등)


func _build_hud() -> void:
	hud = _card()
	hud.add_to_group("ui_bounds")
	(hud.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(22)
	(hud.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 4
	(hud.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 4
	add_child(hud)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	hud.add_child(h)
	var handle := IconButton.new("handle", "끌어서 옮기기", 34.0)
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.pressed.connect(func() -> void:
		if window_ctl:
			window_ctl.begin_drag())
	h.add_child(handle)
	if Game.is_test_run() and not "--no-badge" in Game.dev_args():   # 저장하지 않는 테스트 실행이면 눈에 띄게 표시 (평소 실행과 헷갈리지 않게) · `--no-badge` = README 사진용
		var tl := Label.new()
		tl.text = " 테스트 · 저장 안 함 "
		tl.add_theme_font_size_override("font_size", 12)
		tl.add_theme_color_override("font_color", Color("e0892e"))
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
	var chip := HBoxContainer.new()   # 시계: 늘 보임, 누르면 시계 창
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = "시간 · 날씨"
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			open_panel("clock"))
	var ci := IconButton.new("clock", "", 30.0, false)
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(ci)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 14)
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(clock_label)
	h.add_child(chip)
	var tick := Timer.new()   # 1초마다 시계 글자 갱신
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_update_clock)
	add_child(tick)
	_update_clock.call_deferred()


func _build_menu() -> void:
	menu = _card()
	menu.add_to_group("ui_bounds")
	var sb := menu.get_theme_stylebox("panel") as StyleBoxFlat
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	add_child(menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	menu.add_child(v)
	for m in MENU:
		var b := IconButton.new(m[0], m[1], 50.0)
		var id: String = m[0]
		b.pressed.connect(func() -> void: open_panel(id))
		b.hovered.connect(func(on: bool) -> void: _show_tip(b, on))
		v.add_child(b)
		_menu_buttons[id] = b


func _build_tip() -> void:
	_tip = _card()
	var sb := _tip.get_theme_stylebox("panel") as StyleBoxFlat
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.add_to_group("ui_bounds")
	add_child(_tip)
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip.add_child(_tip_label)


func _build_toast() -> void:
	_toast = _card()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast.add_to_group("ui_bounds")
	add_child(_toast)
	_toast_label = Label.new()
	_toast.add_child(_toast_label)


func _show_tip(b: Control, on: bool) -> void:
	_tip.visible = on and panel_id == ""
	if _tip.visible:
		_tip_label.text = b.tip_text
		_tip.reset_size()
		_tip.position = Vector2(menu.position.x + menu.size.x + 8, b.global_position.y + b.size.y / 2 - _tip.size.y / 2)
	layout_changed.emit()


## 칩 바 내용 바꾸기 (office.gd chips_changed): [{name, color, glyph, turn}]
func set_staff_chips(items: Array) -> void:
	if chips == null:
		chips = _card()
		chips.add_to_group("ui_bounds")
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := chips.get_theme_stylebox("panel") as StyleBoxFlat
		sb.set_corner_radius_all(16)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		add_child(chips)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		chips.add_child(row)
	var row: HBoxContainer = chips.get_child(0)
	for c in row.get_children():
		c.queue_free()
	for it in items:
		var dot := Label.new()
		dot.text = "●" if str(it.glyph) == "" else str(it.glyph)
		dot.add_theme_color_override("font_color", Color(it.color))
		dot.add_theme_font_size_override("font_size", 15 if it.turn else 12)
		row.add_child(dot)
		var name := Label.new()
		name.text = it.name
		name.add_theme_font_size_override("font_size", 13)
		row.add_child(name)
	chips.visible = not items.is_empty()
	_place.call_deferred()


## HUD는 섬 위쪽 가운데, 메뉴는 왼쪽, 칩 바는 HUD 아래
func _place() -> void:
	var vp := _vp()
	hud.reset_size()
	var cx := vp.x * 0.55 if main_area.size == Vector2.ZERO else main_area.position.x + main_area.size.x * 0.55
	hud.position = Vector2(round(cx - hud.size.x / 2), 14)
	if chips:
		chips.reset_size()
		chips.position = Vector2(round(cx - chips.size.x / 2), hud.position.y + hud.size.y + 8)
	menu.reset_size()
	menu.position = Vector2(16, 150)
	layout_changed.emit()


func _place_panel() -> void:
	if panel == null:
		return
	var top := 10.0   # 창은 HUD 아래에서 시작 (긴 설정 창이 HUD 를 덮지 않게)
	if hud and hud.visible:
		top = hud.position.y + hud.size.y + 8.0
	if _panel_scroll and _panel_body:
		var need := _panel_body.get_combined_minimum_size()
		var max_h := maxf(200.0, _vp().y - top - 90.0)   # 제목·여백 빼고 HUD 아래에 들어가는 높이
		_panel_scroll.custom_minimum_size = Vector2(need.x + (12.0 if need.y > max_h else 0.0), min(need.y, max_h))
	panel.reset_size()
	var vp := _vp()
	if panel_id in BAR_PANELS:   # 얇은 바: HUD 바로 아래 가운데 (섬을 가리지 않게)
		panel.position = Vector2(round(hud.position.x + hud.size.x / 2 - panel.size.x / 2), hud.position.y + hud.size.y + 8)
	elif _menu_buttons.has(panel_id):
		var btn: Control = _menu_buttons[panel_id]
		var y: float = clamp(btn.global_position.y - 10, top, maxf(top, vp.y - panel.size.y - 10))
		panel.position = Vector2(menu.position.x + menu.size.x + 12, y)
	else:   # HUD에서 연 패널 → HUD 아래
		panel.position = Vector2(clamp(hud.position.x + hud.size.x / 2 - panel.size.x / 2, 10, vp.x - panel.size.x - 10),
				hud.position.y + hud.size.y + 10)
	layout_changed.emit()


func _refresh() -> void:
	if hud:
		_place.call_deferred()


func _apply_visibility() -> void:
	visible = Game.settings.ui_visible and not Game.runtime.get("mini", false)   # 미니 섬일 땐 설정이 바뀌어도 UI를 켜지 않음
	if not visible:
		close_panel()
	layout_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# H 키 또는 섬 우클릭 → UI 숨기기/보이기
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_run_action("photo")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		toggle_ui()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		toggle_ui()


# ------------------------------------------------------------------ 기본 패널
var actions := {}            ## 다른 시스템이 등록하는 동작 (예: "photo" → 사진 찍기)
var _settings_tab := _dev_tab()
## 기능 켜기/끄기 목록: [설정 키, 이름, 설명]
const FEATURE_TOGGLES := [
	["idle_detect", "자리 비움 감지", "컴퓨터를 안 쓰면 회사도 쉬어요 (저전력)"],
	["sway", "회사 흔들림", "창을 옮길 때 회사가 살짝 흔들려요"],
]


## HUD 시계 글자: 계절·시각·날씨 (창이 좁으면 시각만)
func _update_clock() -> void:
	if clock_label == null or not clock_text.is_valid():
		return
	var r: Array = clock_text.call(get_viewport().get_visible_rect().size.x < 760.0)
	if clock_label.text != r[0]:
		clock_label.text = r[0]
		_place.call_deferred()
	clock_label.add_theme_color_override("font_color", ACCENT_DARK if r[1] else TEXT)


## 켜고 끄기 줄 (keys 에 있는 것만): 이름 + 설명 + 켬/끔, 자리 비움은 켰을 때 기준도
func _feature_rows(body: VBoxContainer, keys: Array) -> void:
	for f in FEATURE_TOGGLES:
		var key: String = f[0]
		if not key in keys:
			continue
		var r := HBoxContainer.new()
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		var name_l := Label.new()
		name_l.text = f[1]
		v.add_child(name_l)
		var d := _note(f[2])
		d.custom_minimum_size.x = 200
		v.add_child(d)
		r.add_child(v)
		var seg := segment([["켬", true], ["끔", false]], bool(Game.settings.get(key, true)),
				func(val) -> void:
					Game.set_setting(key, val)
					refresh_panel())
		seg.custom_minimum_size.x = 96
		r.add_child(seg)
		body.add_child(r)
		if key == "idle_detect" and Game.settings.idle_detect:   # 자리 비움 기준은 감지를 켰을 때만
			var ir := HBoxContainer.new()
			var il := _note("   안 쓴 지 얼마 뒤에 쉬기?")
			il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ir.add_child(il)
			ir.add_child(segment([["3분", 3], ["5분", 5], ["10분", 10]], int(Game.settings.idle_minutes),
					func(val) -> void: Game.set_setting("idle_minutes", val)))
			body.add_child(ir)


## 개발용: `--settings-tab=time` 처럼 설정 탭을 골라서 열기
func _dev_tab() -> String:
	for a in Game.dev_args():
		if a.begins_with("--settings-tab="):
			return a.get_slice("=", 1)
	return "screen"


func _settings_panel(body: VBoxContainer) -> void:
	body.add_child(segment([["회사", "firm"], ["화면", "screen"], ["소리", "sound"], ["정보", "info"]], _settings_tab,
			func(v) -> void:
				_settings_tab = v
				refresh_panel()))
	match _settings_tab:
		"firm":
			if firm_panel.is_valid():
				firm_panel.call(body)
		"sound":
			if sound_panel.is_valid():
				sound_panel.call(body)
		"screen":
			group(body, "창")
			section(body, "창 모드")
			body.add_child(segment([["일반", 0], ["항상 위", 1], ["바탕화면 고정", 2]], int(Game.settings.window_mode),
					func(v) -> void: Game.set_setting("window_mode", v)))
			section(body, "회사 크기")
			body.add_child(_size_slider())
			section(body, "Windows 시작 시 자동 실행")
			var layer: Node = window_ctl._layer if window_ctl else null
			if layer and layer.call("CanAutoStart"):
				body.add_child(segment([["켜기", true], ["끄기", false]], bool(layer.call("IsAutoStart")), func(v) -> void:
					layer.call("SetAutoStart", v)
					Game.toast.emit("컴퓨터를 켜면 회사가 자동으로 떠요" if v else "자동 실행을 껐어요")))
			else:
				body.add_child(_note("exe(%s)로 실행할 때만 설정할 수 있어요." % Identity.EXE))
			group(body, "보이는 것")
			_feature_rows(body, ["sway"])
			section(body, "회사 생활")
			body.add_child(segment([["보통", false], ["조용히", true]], bool(Game.settings.get("quiet", false)),
					func(v) -> void: Game.set_setting("quiet", v)))
			body.add_child(_note("조용히 = 커피 · 소파 · 모임을 줄여요. 부르는 직원은 그대로."))
			section(body, "명패에 폴더 이름")
			body.add_child(segment([["보이기", true], ["숨기기", false]], bool(Game.settings.get("show_project", true)),
					func(v) -> void: Game.set_setting("show_project", v)))
			body.add_child(_note("부를 때 뜨는 명패에 폴더 이름이 보여요. 화면 공유 땐 끄기 (직무만). 파일에는 저장하지 않아요."))
			section(body, "명패 아래 모델")
			body.add_child(segment([["보이기", true], ["숨기기", false]], bool(Game.settings.get("show_model", true)),
					func(v) -> void: Game.set_setting("show_model", v)))
			body.add_child(_note("명패 아래에 모델 이름 (Opus 4.7). 훅이 켜진 세션만, 관찰 모드는 안 보여요."))
			group(body, "비켜 줄 때")
			section(body, "다른 프로그램이 전체 화면일 때 (게임·영상)")
			body.add_child(segment([["회사 숨기고 쉬기", true], ["계속 보이기", false]], Game.settings.pause_fullscreen,
					func(v) -> void: Game.set_setting("pause_fullscreen", v)))
			section(body, "다른 창에 가려졌을 때")
			body.add_child(segment([["작은 회사로", true], ["그대로", false]], bool(Game.settings.get("mini_mode", true)),
					func(v) -> void:
						Game.set_setting("mini_mode", v)
						refresh_panel()))
			if Game.settings.get("mini_mode", true):
				body.add_child(_percent_slider("투명도", 30, 100, float(Game.settings.get("mini_opacity", 0.7)) * 100.0,
						func(v: float) -> void: Game.set_setting("mini_opacity", v / 100.0)))
				body.add_child(_note("회사가 절반 넘게 가려지면 오른쪽 아래에 작은 회사가 떠요 (구경만, 클릭은 뒤 창으로). 트레이 아이콘을 누르면 바로 돌아와요."))
			_feature_rows(body, ["idle_detect"])
			group(body, "성능")
			section(body, "화면 갱신 (낮을수록 가벼움)")
			body.add_child(segment([["15", 15], ["30", 30], ["60", 60]], int(Game.settings.fps),
					func(v) -> void: Game.set_setting("fps", v)))
			section(body, "저전력 모드 (그림자·효과 줄이고 15프레임)")
			body.add_child(segment([["배터리일 때", "auto"], ["항상", "on"], ["끄기", "off"]], Game.settings.low_power,
					func(v) -> void: Game.set_setting("low_power", v)))
		"info":
			var title := Label.new()
			title.text = ProjectSettings.get_setting("application/config/name")
			title.add_theme_font_size_override("font_size", 18)
			body.add_child(title)
			body.add_child(_note("버전 %s" % ProjectSettings.get_setting("application/config/version", "1.0.0")))
			body.add_child(_note("AI 에이전트가 일하는 모습을 보여 주는 바탕화면 하늘 회사. 게임은 지켜보기만 하고, 결정은 늘 터미널에서 해요."))
			body.add_child(_note("가구 일부 — 자료: kArchive · 출처: 쓰레드 dogfooter (자세히는 README)"))
			_update_section(body)
			group(body, "단축키 · 도구")
			for k in [["H", "UI 숨기기 / 보이기 (회사 오른쪽 클릭도 같아요)"], ["P", "사진 찍기 — 사진 폴더에 투명 배경 PNG"],
					["트레이 왼쪽 클릭", "회사 숨기기 / 보이기 (작은 회사면 바로 원래대로)"], ["트레이 오른쪽 클릭", "설정 열기 (숨긴 UI도 다시 보여요)"],
					["위쪽 시계", "지금 시각 (PC 시각)"]]:
				var kr := HBoxContainer.new()   # 왼쪽 열 폭 고정 (가장 긴 "트레이 오른쪽 클릭" 기준) → 설명이 같은 자리에서 시작
				kr.add_theme_constant_override("separation", 10)
				var kl := Label.new()
				kl.text = k[0]
				kl.custom_minimum_size.x = 122
				kl.add_theme_font_size_override("font_size", 13)
				kl.add_theme_color_override("font_color", ACCENT_DARK)
				kl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
				kr.add_child(kl)
				var kn := _note(k[1])
				kn.custom_minimum_size.x = 150
				kn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				kr.add_child(kn)
				body.add_child(kr)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 6)
			body.add_child(h)
			for b in [button("UI 숨기기", toggle_ui), button("사진 찍기", func() -> void: _run_action("photo"))]:
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(b)
			group(body, "저장")
			body.add_child(_note("자동 저장(30초마다) · 하루 1번 자동 백업 — 그날 처음 저장할 때 직전 모습을 따로 보관해요."))
			var bk: Dictionary = Game.day_backup_info()
			if bk.ok:
				var br := HBoxContainer.new()
				br.add_theme_constant_override("separation", 6)
				var bl: Label = _note("백업: %s" % bk.when)
				bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				br.add_child(bl)
				var rb := button("되돌리기", func() -> void: pass)
				rb.pressed.connect(func() -> void:
					if rb.text == "되돌리기":
						rb.text = "한 번 더 누르면 되돌림"
					else:
						Game.restore_backup())
				br.add_child(rb)
				body.add_child(br)
			else:
				body.add_child(_note("아직 백업이 없어요. 내일 처음 저장할 때부터 만들어져요."))
			group(body, "처음부터")
			var h2 := HBoxContainer.new()
			h2.add_theme_constant_override("separation", 6)
			body.add_child(h2)
			var reset := button("처음부터 다시", func() -> void: pass)
			reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reset.pressed.connect(func() -> void:
				if reset.text == "처음부터 다시":
					reset.text = "한 번 더 누르면 초기화"
				else:
					Game.reset_game())
			h2.add_child(reset)


## 설정 → 정보 → 업데이트: 상태 한 줄 + 상태에 맞는 버튼 + 자동 확인 켜기/끄기
var _upd_label: Label


func _update_section(body: VBoxContainer) -> void:
	group(body, "업데이트")
	_upd_label = _note(_update_text())
	body.add_child(_upd_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var btns: Array = []
	match Updater.state:
		"available":
			btns.append(button("받기", Updater.download))
			btns.append(button("바뀐 점 보기", Updater.open_page))
		"ready":
			btns.append(button("다시 시작해서 설치", Updater.install))
		"error":
			btns.append(button("다시 확인", func() -> void: Updater.check(true)))
			btns.append(button("받으러 가기", Updater.open_page))
		"checking", "downloading":
			pass
		_:
			btns.append(button("새 버전 확인", func() -> void: Updater.check(true)))
	for b in btns:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	if not btns.is_empty():
		body.add_child(h)
	section(body, "새 버전 자동으로 확인")
	body.add_child(segment([["켜기", true], ["끄기", false]], Updater.auto_on(), func(v) -> void:
		Game.set_setting("update_check", v)))
	body.add_child(_note("켠 지 1분 뒤와 하루에 한 번 GitHub 릴리스 정보만 읽어요 (보내는 건 접속 정보뿐). 받은 파일은 제작자 서명이 맞을 때만 설치하고, 진행 상황은 그대로 남아요."))


func _update_text() -> String:
	var cur := Identity.version()
	match Updater.state:
		"checking":
			return "새 버전을 확인하는 중…"
		"latest":
			return "최신 버전이에요 (%s)%s" % [cur, " · %s 확인" % Updater.checked_at if Updater.checked_at != "" else ""]
		"available":
			return "✨ 새 버전 %s 이 있어요 (지금 %s · %d MB)" % [Updater.game.version, cur, int(Updater.game.size / 1048576)]
		"downloading":
			return "받는 중… %d%%" % int(Updater.progress * 100.0)
		"ready":
			return "받기 끝 · 서명 확인 완료 — 다시 시작하면 %s 버전으로 바뀌어요 (진행 상황은 그대로)" % Updater.game.get("version", "")
		"error":
			return Updater.message
	if not Updater.enabled():
		return "지금 버전 %s (개발 실행에서는 확인하지 않아요)" % cur
	return "지금 버전 %s · %s" % [cur, "켠 지 1분 뒤에 새 버전을 확인해요" if Updater.auto_on() else "자동 확인이 꺼져 있어요"]


func _on_update_changed() -> void:
	if _menu_buttons.has("gear"):
		_menu_buttons["gear"].badge = Updater.state in ["available", "ready"]
	if panel_id == "gear" and _settings_tab == "info":
		refresh_panel()



func _run_action(action_name: String) -> void:
	if actions.has(action_name):
		actions[action_name].call()


func _quit_panel(body: VBoxContainer) -> void:
	body.add_child(_note("진행 상황을 저장하고 종료할까요?"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	var ok := button("저장하고 종료", func() -> void: _run_action("quit"), true)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ok)
	var no := button("취소", close_panel)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
