extends Node
## 시간·낮밤: 게임 시각 = Claude 5시간 창 진행률 (PLAN 6-3, M5) — 0% = 08시 → 100% = 20시, 창 밖 = 밤 (company.gd)
## 개발용: `--hour=21` 시각 고정 · `--window=0.5` 창 진행률 고정 (`--window=off` = 창 밖). `--demo` · 화면 밖 시험은 PC 시각 (감지기 없음)
## 날씨 (맑음·흐림·비·눈·실제) 코드는 1.1 창밖 연출용으로 남김 — 1.0 사무실은 맑음 고정 (개발용 `--weather=rain` 만)

const RasterIcons := preload("res://scripts/util/raster_icons.gd")
const Company := preload("res://scripts/world/company.gd")

signal weather_changed   ## 비·눈 켜짐/꺼짐 → 창 표시 영역 다시 계산

## 시각(시)별 조명: [시, 해 높이각, 해 방위각, 해 색, 해 세기, 주변광 색, 주변광 세기, 보조광 색, 등불(0~1)]
const KEYS := [
	[0.0, -55.0, 160.0, "8fa6ff", 0.4, "3e4e7c", 0.55, "4f62a0", 1.0],
	[5.0, -40.0, 120.0, "9aa8e6", 0.42, "4f5a86", 0.55, "5f6fa8", 1.0],
	[6.2, -10.0, 85.0, "ffad78", 0.65, "8c8aa8", 0.5, "a99ac8", 0.5],
	[8.0, -30.0, 55.0, "ffe2c0", 1.15, "e4e2e0", 0.75, "d0d8ec", 0.0],
	[12.5, -62.0, 15.0, "fff4e6", 1.35, "f2eee4", 0.85, "dfe4f0", 0.0],
	[16.5, -32.0, -30.0, "ffd9a8", 1.3, "ece4d8", 0.8, "dcdcec", 0.0],
	[18.4, -9.0, -55.0, "ff9050", 0.85, "9a86a4", 0.5, "8a86c0", 0.55],
	[19.6, -30.0, 150.0, "a8b0f0", 0.45, "525c8c", 0.55, "5a68a6", 1.0],
	[24.0, -55.0, 160.0, "8fa6ff", 0.4, "3e4e7c", 0.55, "4f62a0", 1.0],
]
const SLEEP_FROM := 21.0
const WAKE_AT := 6.0
const WEATHERS := [["맑음", "clear"], ["흐림", "cloudy"], ["비", "rain"], ["눈", "snow"], ["자동", "auto"], ["실제 날씨", "real"]]

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var island: Node3D
var hour := 8.0
var time_label: Label            ## 시계 창(HUD 시계를 누르면)이 열려 있으면 갱신
var board: Node                  ## 깃대 · 간판 사이 전자시계 (office.set_time_text, M5)
var force_sleep := false         ## 자리 비움 중이면 낮이어도 동물이 낮잠
var service: Node                ## 실제 날씨 (weather_service.gd)

var _weather := "clear"          ## 실제 적용 중인 날씨 (자동이면 바뀜)
var _mode := "clear"             ## 날씨 방식 (1.0 = 맑음 고정, 개발용 --weather 만 바꿈)
var _auto_next := 0.0
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _lamp_lights: Array = []     ## [OmniLight3D, 기본 세기]
var _tints := [Color.WHITE, Color.WHITE,
		Color.WHITE]   ## 섬 테마 조명 색조 [해, 주변광, 보조광]
var _fire_flicker: Node


func setup() -> void:
	for l in island.find_children("*", "OmniLight3D", true, false):
		_lamp_lights.append([l, l.light_energy])
	island.item_placed.connect(func(node: Node3D, _asset: String) -> void:   # 나중에 놓은 가로등·모닥불도 밤낮에 맞춰
		for l in node.find_children("*", "OmniLight3D", true, false):
			_lamp_lights.append([l, l.light_energy]))
	for n in island.find_children("*", "", true, false):
		if n.get_script() and n.get("light") is OmniLight3D:
			_fire_flicker = n
	_rain = _precip(false)
	_snow = _precip(true)
	island.add_child(_rain)
	island.add_child(_snow)
	Game.settings_changed.connect(_apply_weather_setting)
	_apply_weather_setting()
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	hour = game_hour(Game.company, Time.get_unix_time_from_system(), Game.dev_args())
	_apply_lighting()
	_update_sleep()
	if _mode == "auto":
		_auto_next -= delta
		if _auto_next <= 0.0:
			_auto_next = randf_range(240.0, 480.0)   # 4~8분마다 날씨 변화
			_set_weather(["clear", "clear", "cloudy", "rain", "snow"].pick_random())
	if board and is_instance_valid(board):
		board.set_time_text(hud_text())   # 두 점은 늘 켬 (깜빡이면 작은 화면에서 "1400" 으로 읽힘)
	if time_label and is_instance_valid(time_label):
		time_label.text = "%02d:%02d · %s" % [int(hour), int(fmod(hour, 1.0) * 60), phase_name()]


## 게임 시각 (시). 개발 인자가 있으면 그것을 따름
static func game_hour(company: Dictionary, now: float, args: PackedStringArray) -> float:
	for a in args:
		if a.begins_with("--hour="):   # 시각 고정 (`--hour=21`)
			return float(a.get_slice("=", 1))
		if a.begins_with("--window="):   # 창 진행률 고정 (`--window=0.5` = 14시, `off` = 창 밖 밤)
			var v := a.get_slice("=", 1)
			return Company.NIGHT_H if v == "off" else Company.hour_of(float(v))
	if "--demo" in args or "--offscreen" in args:   # 감지기가 없는 실행 = 예전처럼 PC 시각
		var t := Time.get_datetime_dict_from_system()
		return t.hour + t.minute / 60.0 + t.second / 3600.0
	return Company.hour_at(company, now)


func phase_name() -> String:
	if hour < 5.0 or hour >= 20.0:
		return "밤"
	if hour < 7.5:
		return "새벽"
	if hour < 17.0:
		return "낮"
	return "저녁"


func _apply_lighting() -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := smoothstep(0.0, 1.0, (hour - a[0]) / max(0.001, b[0] - a[0]))
	var w_dim: float = {"clear": 1.0, "cloudy": 0.72, "rain": 0.55, "snow": 0.8}[_weather]
	sun.rotation_degrees = Vector3(lerpf(a[1], b[1], t), lerp_angle_deg(a[2], b[2], t), 0)
	sun.light_color = Color(a[3]).lerp(Color(b[3]), t) * _tints[0]   # 섬 테마 색조 (예: 태엽 공방마을 = 호박색)
	sun.light_energy = lerpf(a[4], b[4], t) * w_dim
	env.ambient_light_color = Color(a[5]).lerp(Color(b[5]), t) * _tints[1]
	env.ambient_light_energy = lerpf(a[6], b[6], t) * lerpf(1.0, 1.15, 1.0 - w_dim)
	fill.light_color = Color(a[7]).lerp(Color(b[7]), t) * _tints[2]
	var lamp: float = lerpf(a[8], b[8], t)
	if _weather in ["rain", "cloudy"]:
		lamp = max(lamp, 0.35)
	_lamp_lights = _lamp_lights.filter(func(e) -> bool: return is_instance_valid(e[0]))   # 창고에 넣어 사라진 불빛 빼기
	for e in _lamp_lights:
		e[0].light_energy = e[1] * (0.25 + 0.95 * lamp) * float(e[0].get_meta("dim", 1.0))   # dim: 농부가 잠들면 집 창문 불 끔 (farmer_routine)
	if is_instance_valid(_fire_flicker):
		_fire_flicker.base = 2.6 * (0.8 + 0.6 * lamp)


static func lerp_angle_deg(a: float, b: float, t: float) -> float:
	return rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), t))


func is_sleep_time() -> bool:
	return hour >= SLEEP_FROM or hour < WAKE_AT


var sleeping := false   ## 밤 · 자리 비움이면 true


func _update_sleep() -> void:
	var night := is_sleep_time() or force_sleep
	sleeping = night   # 직원 퇴근 · 쉬는 모습은 M3 ~ M5 에서 이 값을 씀


# ------------------------------------------------------------------ 날씨
func _apply_weather_setting() -> void:
	var w := "clear"   # 1.0 사무실 = 맑음 고정. Game.settings.weather 는 1.1 창밖 연출 때 씀
	for a in Game.dev_args():   # 개발용: `--weather=rain`
		if a.begins_with("--weather="):
			w = a.get_slice("=", 1)
	_mode = w
	if w == "auto":
		if _auto_next <= 0.0:
			_auto_next = 0.01
	elif w == "real":
		if service:
			service.refresh()
	else:
		_set_weather(w)


func _set_weather(w: String) -> void:
	_weather = w
	_rain.emitting = w == "rain"
	_snow.emitting = w == "snow"
	weather_changed.emit.call_deferred()


func weather() -> String:
	return _weather


func weather_name() -> String:
	for o in WEATHERS:
		if o[1] == _weather:
			return o[0]
	return _weather


## 비(가늘고 긴 물줄기) / 눈(천천히 흔들리며 내리는 작은 조각)
func _precip(snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Snow" if snow else "Rain"
	p.amount = 160 if snow else 220
	p.lifetime = 4.0 if snow else 1.0
	p.emitting = false
	p.position = Vector3(0, 6.0 if snow else 6.5, 0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(4.6, 0.1, 4.6)
	m.direction = Vector3.DOWN
	m.spread = 3.0
	m.initial_velocity_min = 1.0 if snow else 6.5
	m.initial_velocity_max = 1.4 if snow else 7.5
	m.gravity = Vector3(0, -0.3, 0) if snow else Vector3(0.4, -2.0, 0)
	if snow:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 1.2
		m.turbulence_noise_scale = 3.0
	m.color = Color(1, 1, 1, 0.9) if snow else Color(0.75, 0.85, 1.0, 0.55)
	p.process_material = m
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04) if snow else Vector3(0.012, 0.32, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-5, -7, -5), Vector3(10, 7.5, 10))
	return p


# ------------------------------------------------------------------ 패널
## 위쪽 HUD 시계 글자: "가을 · 08:03 · 맑음" (좁으면 "08:03")
func hud_text(_short := false) -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)]


## HUD 시계를 누르면 뜨는 창: 지금 시각·날씨 (설정은 설정 > 시간·날씨)
func clock_panel(ui: CanvasLayer, body: VBoxContainer) -> void:
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 18)
	body.add_child(time_label)
	_update(0.0)
