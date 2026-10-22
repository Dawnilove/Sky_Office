extends HBoxContainer
## 한글 입력칸 (입력칸 + [가/A] 전환 버튼)
## Godot 입력칸(LineEdit)은 Windows에서 한글을 조합할 때 앞 글자가 사라지는 엔진 버그가 있어서(4.7.2),
## Windows 입력기(IME)를 끄고 키보드 자판(두벌식)을 게임이 직접 한글로 조합함.
##   한글/영문 전환: [가/A] 버튼 · 한/영 키 · Shift+Space   ·   Enter = 확인   ·   Backspace = 자모 하나씩 지우기

signal text_submitted(text: String)

const CHO := "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
const JUNG := "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
const JONG := ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ",
		"ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
## 두벌식 자판: 영문 키 → 자모 (Shift = 쌍자음·ㅒ·ㅖ, 나머지 대문자는 소문자와 같음)
const KEYMAP := {
	"q": "ㅂ", "w": "ㅈ", "e": "ㄷ", "r": "ㄱ", "t": "ㅅ", "y": "ㅛ", "u": "ㅕ", "i": "ㅑ", "o": "ㅐ", "p": "ㅔ",
	"a": "ㅁ", "s": "ㄴ", "d": "ㅇ", "f": "ㄹ", "g": "ㅎ", "h": "ㅗ", "j": "ㅓ", "k": "ㅏ", "l": "ㅣ",
	"z": "ㅋ", "x": "ㅌ", "c": "ㅊ", "v": "ㅍ", "b": "ㅠ", "n": "ㅜ", "m": "ㅡ",
	"Q": "ㅃ", "W": "ㅉ", "E": "ㄸ", "R": "ㄲ", "T": "ㅆ", "O": "ㅒ", "P": "ㅖ",
}
const VOWEL_PAIRS := {"ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"}
const FINAL_PAIRS := {"ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
		"ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"}
const NO_FINAL := ["ㄸ", "ㅃ", "ㅉ"]   ## 받침이 될 수 없는 자음

var TEXT := Color("4a3f35")
var SUB := Color("8a7d70")

var max_length := 0              ## 최대 글자 수 (0 = 제한 없음)
var placeholder := ""
var korean := true               ## true = 한글, false = 영문
var font_size := 0               ## 글자 크기 (0 = 테마 기본) — 창업 화면 큰 입력칸 (M5)

var _done := ""                  ## 확정된 글자
var _keys: Array[String] = []    ## 조합 중인 글자를 만든 자모 순서 (지울 때 하나씩 되돌리기용)
var _cho := ""
var _jung := ""
var _jong := ""
var _field: Control
var _mode: Button
var _blink := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_field = Control.new()
	_field.custom_minimum_size = Vector2(150, 34)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.focus_mode = Control.FOCUS_ALL
	_field.clip_contents = true
	_field.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_input)
	_field.focus_entered.connect(func() -> void:
		DisplayServer.window_set_ime_active(false)   # 입력기 끔 → 키가 영문 그대로 들어오고 게임이 조합
		_blink = 0.0
		_field.queue_redraw())
	_field.focus_exited.connect(func() -> void:
		_commit()
		_field.queue_redraw())
	add_child(_field)
	_mode = Button.new()
	_mode.focus_mode = Control.FOCUS_NONE
	_mode.custom_minimum_size.x = 34
	_mode.tooltip_text = "한글/영문 전환 (한/영 키 또는 Shift+Space)"
	_mode.pressed.connect(func() -> void:
		_toggle()
		_field.grab_focus())
	add_child(_mode)
	_update_mode()


func get_text() -> String:
	return _done + _composing()


func set_text(t: String) -> void:
	_done = t
	_clear_syllable()
	_field.queue_redraw()


func grab_input_focus() -> void:
	_field.grab_focus()


func _process(delta: float) -> void:
	if _field.has_focus():
		_blink += delta
		_field.queue_redraw()   # 커서 깜빡임


# ------------------------------------------------------------------ 입력
func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_field.grab_focus()
		_field.accept_event()
		return
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	if _is_toggle_key(k):
		_toggle()
	elif k.keycode == KEY_BACKSPACE:
		_backspace()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_commit()
		text_submitted.emit(get_text())
	elif k.keycode == KEY_ESCAPE:
		_field.release_focus()
	elif k.unicode >= 32 and not (k.ctrl_pressed or k.alt_pressed or k.meta_pressed):
		type_char(char(k.unicode))
	else:
		return
	_blink = 0.0
	_field.queue_redraw()
	_field.accept_event()


## 한/영 전환 키: 한/영 키(Godot에 이름이 없는 키로 들어옴) · 오른쪽 Alt · Shift+Space
func _is_toggle_key(k: InputEventKey) -> bool:
	if k.echo:
		return false
	if k.keycode == KEY_SPACE and k.shift_pressed:
		return true
	if k.keycode == KEY_ALT and k.location == KEY_LOCATION_RIGHT:
		return true
	return k.keycode == KEY_NONE and k.unicode == 0


func _toggle() -> void:
	_commit()
	korean = not korean
	_update_mode()


func _update_mode() -> void:
	_mode.text = "가" if korean else "A"


## 글자 하나 입력 (키보드 입력과 테스트에서 사용)
func type_char(c: String) -> void:
	var snap := [_done, _keys.duplicate(), _cho, _jung, _jong]
	var key := c if KEYMAP.has(c) else c.to_lower()
	if korean and KEYMAP.has(key):
		_feed(KEYMAP[key])
	else:
		_commit()
		_done += c
	if max_length > 0 and get_text().length() > max_length:   # 글자 수를 넘으면 되돌림
		_done = snap[0]
		_keys = snap[1]
		_cho = snap[2]
		_jung = snap[3]
		_jong = snap[4]


func _backspace() -> void:
	if not _keys.is_empty():   # 조합 중: 마지막 자모만 빼고 다시 조합
		var ks := _keys.duplicate()
		ks.pop_back()
		_clear_syllable()
		for j in ks:
			_feed(j)
	elif _done != "":
		_done = _done.left(-1)


# ------------------------------------------------------------------ 한글 조합 (두벌식)
func _is_vowel(j: String) -> bool:
	return JUNG.contains(j)


func _composing() -> String:
	if _cho != "" and _jung != "":
		return char(0xAC00 + (CHO.find(_cho) * 21 + JUNG.find(_jung)) * 28 + JONG.find(_jong))
	return _cho + _jung   # 자음 하나 또는 모음 하나만 있을 때


func _clear_syllable() -> void:
	_cho = ""
	_jung = ""
	_jong = ""
	_keys.clear()


func _commit() -> void:
	_done += _composing()
	_clear_syllable()


func _feed(j: String) -> void:
	if _is_vowel(j):
		if _jung == "":
			_jung = j                                   # ㄱ + ㅏ → 가
		elif _jong == "" and VOWEL_PAIRS.has(_jung + j):
			_jung = VOWEL_PAIRS[_jung + j]               # 고 + ㅏ → 과
		elif _jong != "" and _cho != "":
			# 받침이 다음 글자의 첫소리로 넘어감: 각 + ㅏ → 가가, 닭 + ㅏ → 달가
			var keep := ""
			var move := _jong
			for pair in FINAL_PAIRS:
				if FINAL_PAIRS[pair] == _jong:
					keep = (pair as String)[0]
					move = (pair as String)[1]
			_jong = keep
			_commit()
			_cho = move
			_jung = j
			_keys.assign([move, j])
			return
		else:
			_commit()
			_jung = j
	else:
		if _cho == "" and _jung == "":
			_cho = j
		elif _jung == "" or _cho == "":                 # 자음만/모음만 있는데 자음 → 앞 글자 확정
			_commit()
			_cho = j
		elif _jong == "":
			if j in NO_FINAL:
				_commit()
				_cho = j
			else:
				_jong = j                               # 가 + ㄱ → 각
		elif FINAL_PAIRS.has(_jong + j):
			_jong = FINAL_PAIRS[_jong + j]               # 달 + ㄱ → 닭
		else:
			_commit()
			_cho = j
	_keys.append(j)


# ------------------------------------------------------------------ 그리기
func _draw_field() -> void:
	var focused := _field.has_focus()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffcf6")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color("7fa35a") if focused else Color("ddd2c0")
	_field.draw_style_box(sb, Rect2(Vector2.ZERO, _field.size))
	var font := get_theme_default_font()
	var fs := font_size if font_size > 0 else get_theme_default_font_size()
	var y := (_field.size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	var comp := _composing()
	var w_done := font.get_string_size(_done, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w_comp := font.get_string_size(comp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := 10.0 - maxf(0.0, w_done + w_comp + 22.0 - _field.size.x)   # 길면 왼쪽으로 밀어 커서가 보이게
	if _done == "" and comp == "" and not focused:
		_field.draw_string(font, Vector2(10, y), placeholder, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SUB)
		return
	_field.draw_string(font, Vector2(x, y), _done, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)
	x += w_done
	if comp != "":   # 조합 중인 글자: 밑줄
		_field.draw_string(font, Vector2(x, y), comp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)
		_field.draw_line(Vector2(x, y + 3), Vector2(x + w_comp, y + 3), TEXT, 1.5)
		x += w_comp
	if focused and fmod(_blink, 1.0) < 0.6:
		_field.draw_line(Vector2(x + 1, 8), Vector2(x + 1, _field.size.y - 8), TEXT, 1.5)
