extends Node
## 게시판 큰 창 (M5 5세션째, 사용자 결정 '넣기' — PLAN 3-1 · 6-1: 성장 막대 · 숫자는 HUD 에 없고 게시판에서만)
##   복도 입간판 게시판 근처를 누르면 패널 '게시판': 근무일 · 지금 단계 · 다음 단계까지 · 직원 수 · 휴직 직원. 2열 타일 6칸 (사용자)
##   비교 · 순위 · 칭찬 없음 (5-7 넣지 않는 것). 개발: `--open=board`

const Company := preload("res://scripts/world/company.gd")
const CompanyShow := preload("res://scripts/world/company_show.gd")
const Office := preload("res://scripts/world/office.gd")
const JUA := preload("res://assets/fonts/Jua-Regular.ttf")   ## 둥근 글씨 (값)
## 칸 바탕 = 옅은 파스텔 (노랑 · 빨강 없음): 하늘 · 민트 · 라벤더 · 라벤더 · 하늘 · 따뜻한 회색
const TILE_COLORS := ["e6f0fa", "e4f3ea", "eee9f8", "eee9f8", "e6f0fa", "f2ede6"]

var ui: CanvasLayer
var office: Node3D
var routine: Node   ## office_routine (없으면 = 데모 · 화면 밖, 직원 줄 비움)


func setup(u: CanvasLayer, o: Node3D, r: Node) -> void:
	ui = u
	office = o
	routine = r
	ui.register_panel("board", "게시판", panel)


## 게시판 판 가운데 (화면 클릭 판정용)
func board_point() -> Vector3:
	var nb := office.get_node_or_null("NoticeBoard") as Node3D
	if nb == null:
		return Vector3.INF
	return nb.global_position + Vector3.UP * 0.6 * office.layout.unit_m


## 화면 클릭 → 게시판 근처면 패널 (phone_ui.click 다음에 봄). 처리했으면 true
func click(screen: Vector2) -> bool:
	var cam := office.get_viewport().get_camera_3d()
	var p := board_point()
	if cam == null or p == Vector3.INF or cam.is_position_behind(p):
		return false
	if cam.unproject_position(p).distance_to(screen) > 30.0 * maxf(1.0, office.get_viewport().get_visible_rect().size.y / 740.0):
		return false
	ui.open_panel("board")
	return true


## 게시판 칸 6개 (순수 — 시험), 2열 타일 순서 (사용자 2026-10-16): [근무일 | 직원] [지금 | 다음] [남은 날 | 휴직]
##   co = Game.company · reg = 직원 기록 · names = {직원 id: 이름}. 단계 칸은 "창업 ②\n첫 의뢰" (2줄)
static func lines(co: Dictionary, reg: Dictionary, names: Dictionary) -> Array:
	var st: Array = Company.stage_data().stages
	var days := int(co.get("earned_days", 0))
	var n := clampi(int(co.get("shown_stage", 0)), 0, st.size() - 1)
	var on := 0
	var off: Array = []
	for s in reg.get("staff", []):
		if bool(s.leave):
			off.append(str(names.get(int(s.id), Office.name_of(int(s.id)))))
		else:
			on += 1
	var last := n + 1 >= st.size()
	return [["근무일", "%d일" % days], ["직원", "%d명" % on],
			["지금", _two(n)], ["다음", "마지막 단계" if last else _two(n + 1)],
			["남은 날", "-" if last else "%d일" % maxi(0, int(st[n + 1].days) - days)], ["휴직", "없음" if off.is_empty() else "\n".join(off)]]


## "창업 ② 첫 의뢰" → "창업 ②\n첫 의뢰"
static func _two(n: int) -> String:
	var t := CompanyShow.popup_text(n).get_slice("\n", 0)
	var parts := t.split(" ", false, 2)
	return "%s %s\n%s" % [parts[0], parts[1], parts[2]] if parts.size() == 3 else t


## 성장 막대 채움 (0~1): 지금 단계 문턱 → 다음 문턱 사이 어디쯤
static func fill(co: Dictionary) -> float:
	var st: Array = Company.stage_data().stages
	var n := clampi(int(co.get("shown_stage", 0)), 0, st.size() - 1)
	if n + 1 >= st.size():
		return 1.0
	var a := float(st[n].days)
	var b := float(st[n + 1].days)
	return clampf((float(co.get("earned_days", 0)) - a) / maxf(b - a, 1.0), 0.0, 1.0)


func panel(body: VBoxContainer) -> void:
	var reg: Dictionary = routine._reg if routine and not routine._reg.is_empty() else {"staff": []}
	var names := {}
	if routine:
		for id in routine.looks:
			names[int(id)] = str(routine.looks[id].get("name", ""))
	var co: Dictionary = Game.company.duplicate()
	if int(office.stage) >= 0:
		co.shown_stage = int(office.stage)   # 화면에 보이는 단계 (미룬 단계 상승 전이면 그 전 단계)
	var bar := ProgressBar.new()   # 몽글몽글 (사용자): 두껍고 둥근 막대
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = fill(co)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 16)
	for it in [["background", ui.TRACK], ["fill", ui.ACCENT]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = it[1]
		sb.set_corner_radius_all(8)
		bar.add_theme_stylebox_override(it[0], sb)
	body.add_child(bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var rows := lines(co, reg, names)
	var bold := FontVariation.new()
	bold.base_font = body.get_theme_font("font")
	bold.variation_embolden = 1.4
	for j in rows.size():
		var r: Array = rows[j]
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(145, 0)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()   # 둥근 파스텔 칸 + 부드러운 그림자 (테두리 없음)
		sb.bg_color = Color(TILE_COLORS[j % TILE_COLORS.size()])
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(0.29, 0.25, 0.21, 0.12)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 5
		sb.content_margin_bottom = 7
		tile.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		tile.add_child(v)
		var k := Label.new()
		k.text = r[0]
		k.add_theme_font_override("font", bold)   # 칸 이름 = 크고 굵게, 값 = 조금 작게 (사용자 2026-10-21)
		k.add_theme_font_size_override("font_size", 14)
		k.add_theme_color_override("font_color", ui.TEXT.lerp(ui.SUB, 0.35))
		v.add_child(k)
		var val := Label.new()
		val.text = r[1]
		val.add_theme_font_override("font", JUA)
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", ui.TEXT)
		v.add_child(val)
		grid.add_child(tile)
	var pad := Control.new()   # 맨 아래 칸 그림자까지 보이게 (스크롤 높이 = 최소 크기라 그림자가 잘림)
	pad.custom_minimum_size.y = 14
	body.add_child(pad)
