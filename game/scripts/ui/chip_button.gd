extends Control
## 둥근 칩 버튼: [아이콘 + 글자 (+ 숫자 배지) (+ 오른쪽 작은 아이콘)]
## style: "soft" 베이지 / "primary" 초록 바탕·흰 글자 / "ghost" 평소엔 배경 없음

signal pressed

const Icons := preload("res://scripts/ui/icons.gd")
## [평소, 마우스 올림, 누름, 글자색] — 섬 테마가 바꿀 수 있음 (btn · btn_hover · accent · text)
var STYLES := _styles()


static func _styles() -> Dictionary:
	var txt := Color("4a3f35")
	var btn := Color("ebe3d4")
	var hov := Color("e1d6c2")
	var acc := Color("7fa35a")
	return {
		"soft": [btn, hov, hov.darkened(0.06), txt],
		"primary": [acc, acc.darkened(0.06), acc.darkened(0.13), Color.WHITE],
		"ghost": [Color(0, 0, 0, 0), btn.lightened(0.02), hov, txt],
	}
const H := 34.0
const PAD := 12.0
const ICON_R := 9.0

var icon := ""
var text := ""
var style := "soft"
var badge := -1             ## 숫자 배지 (-1 = 없음)
var trailing := ""          ## 오른쪽 작은 아이콘 (예: "chevron_down")
var font: Font              ## 글자 모양 (없으면 테마 기본)
var font_size := 14

var _hover := false
var _down := false


func _init(p_icon := "", p_text := "", p_style := "soft") -> void:
	icon = p_icon
	text = p_text
	style = p_style
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false
		queue_redraw())


func _font() -> Font:
	return font if font else get_theme_default_font()


func _text_w() -> float:
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if text != "" else 0.0


func _get_minimum_size() -> Vector2:
	var w := PAD * 2 + _text_w()
	if icon != "":
		w += ICON_R * 2 + (6.0 if text != "" else 0.0)
	if badge >= 0:
		w += 26.0
	if trailing != "":
		w += 16.0
	return Vector2(w, H)


func _draw() -> void:
	var col: Array = STYLES.get(style, STYLES.soft)
	var bg: Color = col[2] if _down else (col[1] if _hover else col[0])
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(H / 2))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var fg: Color = col[3]
	var tint := fg if style == "primary" else Color(0, 0, 0, 0)   # 초록 칩의 선 아이콘은 흰색
	var x := PAD
	var cy := size.y / 2
	if icon != "":
		Icons.draw(self, icon, Vector2(x + ICON_R, cy), ICON_R, tint)
		x += ICON_R * 2 + (6.0 if text != "" else 0.0)
	if text != "":
		var f := _font()
		draw_string(f, Vector2(x, cy + (f.get_ascent(font_size) - f.get_descent(font_size)) / 2), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
		x += _text_w()
	if badge >= 0:   # 주황 동그라미 + 흰 숫자
		var bc := Vector2(x + 14, cy)
		draw_circle(bc, 10, Color("e0892e"))
		var f2 := _font()
		var s := str(badge)
		var sw := f2.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f2, Vector2(bc.x - sw / 2, cy + (f2.get_ascent(12) - f2.get_descent(12)) / 2), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		x += 26.0
	if trailing != "":
		Icons.draw(self, trailing, Vector2(x + 8, cy), 5.0, tint)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
	elif _down:
		_down = false
		pressed.emit()
	queue_redraw()
	accept_event()
