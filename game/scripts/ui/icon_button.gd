extends Control
## 벡터 아이콘 버튼 (마우스를 올리면 둥근 배경 강조). interactive=false 면 그림만 표시

signal pressed
signal hovered(on: bool)

const Icons := preload("res://scripts/ui/icons.gd")

var icon := ""
var tip_text := ""
var icon_radius := 16.0
var interactive := true
var selected := false:
	set(v):
		selected = v
		queue_redraw()

var badge := false:   ## 오른쪽 위 빨간 점 (예: 새 버전이 있음) — 아이콘 색 셰이더를 받지 않게 따로 그림
	set(v):
		badge = v
		_badge_dot()

var _hover := false
var _bg := StyleBoxFlat.new()
var _dot: Control


func _init(p_icon := "", p_tip := "", p_size := 48.0, p_interactive := true) -> void:
	icon = p_icon
	tip_text = p_tip
	interactive = p_interactive
	custom_minimum_size = Vector2(p_size, p_size)
	icon_radius = p_size * 0.34
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	_bg.set_corner_radius_all(int(p_size * 0.3))


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		hovered.emit(true)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		hovered.emit(false)
		queue_redraw())


func _draw() -> void:
	if interactive and (_hover or selected):
		_bg.bg_color = Color("e6dccb") if selected else Color("ece4d5")
		_bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	Icons.draw(self, icon, size / 2.0, icon_radius)


func _badge_dot() -> void:
	if _dot == null:
		if not badge:
			return
		_dot = Control.new()
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot.size = Vector2(12, 12)
		_dot.draw.connect(func() -> void:
			_dot.draw_circle(Vector2(6, 6), 6.0, Color.WHITE)
			_dot.draw_circle(Vector2(6, 6), 4.5, Color("e5484d")))
		add_child(_dot)
	_dot.position = Vector2(custom_minimum_size.x - 15, 4)
	_dot.visible = badge


func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
