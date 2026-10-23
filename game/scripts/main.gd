extends Node3D
## 메인: 조명·카메라·환경 설정 → 섬 생성 → 바탕화면 창 동작 연결
## 하늘 오피스 M1: 오버랜드에서 농장 · 상점 · 레벨 · DLC 를 걷어 낸 틀 (회사 · 직원은 M2 부터 이 위에)
##
## 실행 인자 `-- --autotest` : 9초 후 미리보기 이미지 저장 후 종료 (개발 검증용)
## 실행 인자 `-- --record`   : 8초 동안 프레임을 user://rec/ 에 저장 후 종료 (동작 확인 영상용)
## 실행 인자 `-- --offscreen`: 화면에 안 보이는 내부 화면(SubViewport)에 그림 (사용자 작업 방해 없는 테스트용)
## 실행 인자 `-- --scenario` : 자동 점검 (scripts/dev/scenario.gd)
## 실행 인자 `-- --islets=0,1`: 확장 섬 붙이기 (증축 전 미리 보기)
## 실행 인자 `-- --diameter=14`: 크기 단계 (10~14 = 1.0~1.4 사무실 크기, 창 · 카메라도 같은 비율로)
## 실행 인자 `-- --shot=<경로.png>`: 4초 뒤 화면을 하늘색 배경에 합성해 저장하고 종료 (가독성 시험 그림, `--shot-ui` = UI 포함)

const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const DesktopWindow := preload("res://scripts/window/desktop_window.gd")
const UIRoot := preload("res://scripts/ui/ui_root.gd")
const DayNight := preload("res://scripts/world/day_night.gd")
const Sound := preload("res://scripts/world/sound.gd")
const Tray := preload("res://scripts/window/tray.gd")
const IslandMotion := preload("res://scripts/world/island_motion.gd")
const Presence := preload("res://scripts/game/presence.gd")
const WeatherService := preload("res://scripts/world/weather_service.gd")
const MiniMode := preload("res://scripts/window/mini_mode.gd")
const AgentWatch := preload("res://scripts/world/agent_watch.gd")
const Company := preload("res://scripts/world/company.gd")
const CompanyShow := preload("res://scripts/world/company_show.gd")
const Layout := preload("res://scripts/world/layout.gd")
const Office := preload("res://scripts/world/office.gd")
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")
const FirmUI := preload("res://scripts/ui/firm_ui.gd")
const Phone := preload("res://scripts/world/phone.gd")
const PhoneUI := preload("res://scripts/ui/phone_ui.gd")
const BoardUI := preload("res://scripts/ui/board_ui.gd")
const StaffCard := preload("res://scripts/ui/staff_card.gd")
const CommandRunner := preload("res://scripts/world/command_runner.gd")
const CommandUI := preload("res://scripts/ui/command_ui.gd")
## 높이: 섬은 창 위쪽 645 까지만 그려져서 아래 빈 하늘을 잘라 1000 → 740 (M5: 회사 크기가 1080p 에서 134% 에 걸리던 것 → 180%)
const BASE_SIZE := Vector2i(1080, 740)
const CAM_V_SHIFT := 130.0   ## 잘라 낸 높이의 절반 (px) → 카메라를 그만큼 올려 섬이 창 위에서 예전 자리에
## 확장 섬이 붙을 때 창을 넓히는 양 (왼쪽 섬 → 왼쪽, 오른쪽 섬 → 오른쪽)
const ISLET_EXTRA := [Vector2i(300, 0), Vector2i(0, 400)]
const PX_PER_M := 82.1     ## 크기 1.0에서 섬 중심 깊이의 1m = 화면 약 82px
## 카메라 (PLAN 3-1, M2 3세션째 각도 훑기 → 사용자 결정): 앞-오른쪽 15° · 55° 내려다봄 · 세로 시야 24°. 거리는 1m = PX_PER_M 이 되게 (창 높이 1000 기준)
const CAM_FOV := 24.0
const CAM_PITCH := 55.0
const CAM_YAW := 0.0   ## 정면 (M3 4세션째 사용자 결정, 15° 에서 바꿈)
const CAM_H_OFFSET := -0.75   ## 섬을 창 오른쪽으로 → 왼쪽에 메뉴 자리
const CAM_TARGET := Vector3(0, -0.55, 0)

var camera: Camera3D
var island: Node3D
var office: Node3D
var layout: Layout
var diameter_k := 1.0   ## 섬 지름 / 10 — 창 · 카메라 거리도 이 배율 (1칸 = 같은 px 유지)
var window_ctl: Node
var ui: CanvasLayer
var day_night: Node
var sound: Node
var _env: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _world: Node             ## 장면을 담는 곳: 평소엔 자기 자신, --offscreen 이면 SubViewport


func _ready() -> void:
	Game.prof("main._ready 시작")
	var guard: Node = load("res://scripts/window/WindowLayer.cs").new()
	guard.call("ApplyAppId")   # 알림 · 작업 표시줄 앱 ID (identity.gd) — 창 관련 일보다 먼저
	var dup: bool = not "--offscreen" in Game.dev_args() and guard.call("AnotherInstanceRunning")
	guard.free()
	if dup:
		Game.no_save = true   # 이미 켜진 게임이 있음 → 그 창을 앞으로 보이고 이쪽은 바로 끔
		get_tree().quit()
		return
	get_viewport().transparent_bg = true
	_world = self
	var offscreen := "--offscreen" in Game.dev_args()
	if not offscreen:
		# 화면 밖 테스트용 설정(override.cfg: 1x1·포커스 없음)이 남아 있을 때 켜져도 키보드 입력이 되게
		get_window().unfocusable = false
	else:
		var svp := SubViewport.new()
		svp.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
				ProjectSettings.get_setting("display/window/size/viewport_height"))
		svp.transparent_bg = true
		svp.own_world_3d = true
		svp.msaa_3d = Viewport.MSAA_2X
		svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(svp)
		_world = svp
	_setup_environment()
	_setup_lights()

	var diameter := 10
	var stage_arg := -1   # 개발 `--stage=N`: 그 단계의 크기로 (증축 그림 · 확인용)
	for a in Game.dev_args():
		if a.begins_with("--stage="):
			stage_arg = int(a.get_slice("=", 1))
	if stage_arg >= 0:
		diameter = Company.diameter_for(stage_arg)
	elif not ("--offscreen" in Game.dev_args() or "--demo" in Game.dev_args()):
		diameter = Company.diameter_for(int(Game.company.get("shown_stage", 0)))   # 1.1 증축: 저장된 단계의 크기로 켬 (다음에 켤 때 적용)
	var front_extra := 0.0   # 라운지 띠 (1.2 단계 64): 지름과 같은 방식 — 켤 때 저장된 단계로
	if stage_arg >= 0:
		front_extra = Company.front_extra_for(stage_arg)
	elif not ("--offscreen" in Game.dev_args() or "--demo" in Game.dev_args()):
		front_extra = Company.front_extra_for(int(Game.company.get("shown_stage", 0)))
	for a in Game.dev_args():
		if a.begins_with("--diameter="):
			diameter = int(a.get_slice("=", 1))
		if a.begins_with("--front-extra="):
			front_extra = float(a.get_slice("=", 1))
	layout = Layout.new(diameter, Layout.PATH, front_extra)
	diameter_k = layout.diameter / 10.0
	island = IslandBuilder.new()
	island.name = "Island"
	island.scale_k = diameter_k
	_world.add_child(island)
	island.build("res://data/island_layout.json")
	office = Office.new()
	office.name = "Office"
	island.add_child(office)
	office.build(island, layout)
	island.finish()
	Game.away_started.connect(office.set_boss_away.bind(true))   # 사장의 흔적 (v2.8 C15): 자리 비우면 의자 빠짐 · 쪽지
	Game.away_ended.connect(func(_m: int) -> void: office.set_boss_away(false))
	if "--away" in Game.dev_args():   # 개발용 (그림): 사장 자리 비움 모습
		office.set_boss_away(true)
	for a in Game.dev_args():
		if a.begins_with("--islets="):
			for i in a.get_slice("=", 1).split(","):
				island.add_islet(int(i))
	Game.prof("섬 만들기")

	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.h_offset = CAM_H_OFFSET * diameter_k
	var dist := BASE_SIZE.y / (2.0 * PX_PER_M * tan(deg_to_rad(CAM_FOV / 2.0)))
	var yaw := CAM_YAW
	var pitch := CAM_PITCH
	for a in Game.dev_args():   # 비교용 (M3 4세션째): 정면 0° 와 15° · 내려다봄 50° 와 55° 견주기
		if a.begins_with("--cam-yaw="):
			yaw = float(a.get_slice("=", 1))
		if a.begins_with("--cam-pitch="):
			pitch = float(a.get_slice("=", 1))
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	camera.position = CAM_TARGET + dir * dist * diameter_k
	_world.add_child(camera)
	camera.look_at(CAM_TARGET)

	window_ctl = DesktopWindow.new()
	window_ctl.camera = camera
	window_ctl.target = island
	add_child(window_ctl)

	ui = UIRoot.new()
	ui.window_ctl = window_ctl
	_world.add_child(ui)
	ui.layout_changed.connect(window_ctl.update_passthrough)
	# 칩 바 (3-3) 는 뺌 (M3 4세션째 사용자 결정) — 이름은 마우스 올림 이름판으로

	day_night = DayNight.new()
	day_night.name = "DayNight"
	day_night.sun = _sun
	day_night.fill = _fill
	day_night.env = _env
	day_night.island = island
	day_night.board = office
	add_child(day_night)
	day_night.weather_changed.connect(window_ctl.rebuild_static_shape)
	day_night.setup()
	ui.register_panel("clock", "시간", func(body: VBoxContainer) -> void: day_night.clock_panel(ui, body))   # HUD 시계를 누르면
	ui.clock_text = func(short: bool) -> Array: return [day_night.hud_text(short), false]
	sound = Sound.new()
	sound.name = "Sound"
	sound.day_night = day_night
	add_child(sound)
	ui.sound_panel = func(body: VBoxContainer) -> void: sound.panel(ui, body)   # 설정 > 소리
	Game.prof("낮밤 · 소리")

	# 실제 날씨 (설정 > 시간·날씨에서 '실제 날씨'를 고를 때만 동작)
	var wx := WeatherService.new()
	wx.name = "WeatherService"
	day_night.add_child(wx)
	day_night.service = wx
	wx.weather_found.connect(func(kind: String, _label: String) -> void:
		day_night._set_weather(kind)
		ui.refresh_panel())
	day_night._apply_weather_setting()   # 서비스 연결 후 다시 적용 (실제 날씨면 바로 받아오기)

	# 섬 둥실·흔들림
	var motion := IslandMotion.new()
	motion.name = "IslandMotion"
	motion.island = island
	add_child(motion)

	# 자리 비움 감지 + 저전력
	var presence := Presence.new()
	presence.name = "Presence"
	presence.window_layer = window_ctl._layer
	presence.day_night = day_night
	presence.sun = _sun
	presence.env = _env
	add_child(presence)

	ui.actions["photo"] = take_photo
	ui.actions["quit"] = quit_game
	get_tree().auto_accept_quit = false   # 창 닫기도 quit_game()을 거치게

	_update_layout()

	for a in Game.dev_args():   # 개발용: `--timescale=10` · `--size=0.6`
		if a.begins_with("--timescale="):
			Engine.time_scale = float(a.get_slice("=", 1))
		if a.begins_with("--size="):
			Game.settings.size = float(a.get_slice("=", 1))
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()
	window_ctl.restore_position(Game.settings.window_pos)
	if not offscreen:
		window_ctl._layer.call("RefreshAutoStart")   # exe를 옮겼으면 자동 실행 경로 고침
	_layout_ready = true
	Game.prof("창 크기 · 설정")
	if not offscreen:   # 테스트 실행 땐 트레이 아이콘을 만들지 않음
		var tray := Tray.new()
		tray.name = "Tray"
		tray.ui = ui
		tray.window_layer = window_ctl._layer
		mini = MiniMode.new()   # 다른 창에 가려지면 작은 섬으로
		mini.name = "MiniMode"
		mini.main = self
		mini.window_ctl = window_ctl
		mini.ui = ui
		mini.layer = window_ctl._layer
		add_child(mini)
		tray.mini = mini
		add_child(tray)
		if not "--demo" in Game.dev_args():   # 개발용 `--demo`: 실제 신호를 안 봄 → --states · --act 로 정한 모습 그대로 (실화면 확인, M4 4세션째)
			watch = AgentWatch.new()   # inbox · 관찰 모드 → %USERPROFILE%\.skyoffice\state.json
			watch.name = "AgentWatch"
			watch.setup(AgentWatch.home().path_join(".skyoffice"), AgentWatch.home().path_join(".claude/projects"), layout.desks().size(), AgentWatch.load_tools(AgentWatch.home()))
			add_child(watch)
			company = Company.new()   # 근무일 · 게임 하루 (5시간 창 추정 + 훅 보정, M5)
			company.name = "Company"
			add_child(company)
			watch.activity.connect(company.feed)
			routine = OfficeRoutine.new()   # 스냅샷 → 직원 표시 · '딩' · 봉투 · 마우스 올림 (M3 3세션째)
			routine.name = "OfficeRoutine"
			routine.setup(office, sound, watch, camera)
			add_child(routine)
			tray.routine = routine
	company_show = CompanyShow.new()   # 단계 상승 · 하루 리듬 연출 (M5) — 감지기가 없으면 (`--demo` · 화면 밖) 개발 인자 장면만
	company_show.name = "CompanyShow"
	add_child(company_show)
	company_show.setup(office, company)
	firm_ui = FirmUI.new()
	firm_ui.name = "FirmUI"
	add_child(firm_ui)
	firm_ui.setup(ui, office, routine, company)
	ui.register_panel("tray", "결재함", firm_ui.tray_panel)
	ui.firm_panel = firm_ui.firm_tab
	phone = Phone.new()   # 사장 책상 전화기 = 플러그인 개통 · 무결성 · 연결 상태 · 폐업 정리 (M5 4세션째) — 감지기 없으면 (`--demo` · 화면 밖) 상태만 (`--phone=`)
	phone.name = "Phone"
	phone.window_layer = window_ctl._layer
	add_child(phone)
	if watch:
		phone.setup(AgentWatch.home().path_join(".skyoffice"), Phone.default_claude_home(), watch)
	phone_ui = PhoneUI.new()
	phone_ui.name = "PhoneUI"
	add_child(phone_ui)
	phone_ui.setup(ui, phone, firm_ui, office)
	board_ui = BoardUI.new()   # 게시판 큰 창 (M5 5세션째)
	board_ui.name = "BoardUI"
	add_child(board_ui)
	board_ui.setup(ui, office, routine)
	staff_card = StaffCard.new()   # 직원 카드 + [프로젝트 완료] (1.3)
	staff_card.name = "StaffCard"
	add_child(staff_card)
	staff_card.setup(firm_ui, office, routine, watch, company_show)
	window_ctl.click_handler = func(p: Vector2) -> bool: return phone_ui.click(p) or board_ui.click(p) or staff_card.click(p)
	command_runner = CommandRunner.new()   # 게임 안 한 줄 명령 (로드맵 ⑤) — 설정에서 켜기 전엔 아무것도 안 보임
	command_runner.name = "CommandRunner"
	add_child(command_runner)
	command_runner.setup(watch)
	command_ui = CommandUI.new()
	command_ui.name = "CommandUI"
	add_child(command_ui)
	command_ui.setup(ui, command_runner, firm_ui)
	ui.register_panel("phone", "전화 · 연결 상태", func(body: VBoxContainer) -> void:
		phone_ui.panel(body)
		command_ui.entry(body))
	firm_ui.close_section = func(body: VBoxContainer) -> void:
		command_ui.settings_section(body)
		phone_ui.close_section(body)
	for a in Game.dev_args():
		if a.begins_with("--phone="):   # 개발용: 전화기 모습 (none · on · broken) — 그림
			var ps := a.get_slice("=", 1)
			phone.status = {"state": ps, "reason": {"none": "개통 전이에요.", "on": "정상이에요.", "broken": "전화기 파일이 바뀌었어요. 신호를 멈췄어요."}.get(ps, ""),
					"files": {} if ps == "none" else {"bell/bell.exe": "diff" if ps == "broken" else "ok", "bell/hooks/hooks.json": "ok", "bell/.claude-plugin/plugin.json": "ok", ".claude-plugin/marketplace.json": "ok"}, "paused": ps == "broken"}
			phone.changed.emit()
	if "--close-card" in Game.dev_args():   # 개발용: 폐업 정리 확인 카드 (그림)
		phone_ui.show_close.call_deferred()
	for a in Game.dev_args():
		if a.begins_with("--open="):   # 개발용: 패널 열어둔 상태로 시작
			ui.open_panel.call_deferred(a.get_slice("=", 1))
		if a.begins_with("--quit-after="):   # 개발용: 종료 버튼과 같은 동작 (저장하고 종료)
			get_tree().create_timer(float(a.get_slice("=", 1))).timeout.connect(func() -> void:
				print("[QUIT] 종료 버튼 흉내")
				ui._run_action("quit"))
	if "--no-ui" in Game.dev_args():   # 개발용: UI 없이 섬만 (앱 아이콘·README 그림)
		ui.visible = false
	if "--profile" in Game.dev_args():   # 개발용: 첫 프레임들의 시간
		_profile_frames.call_deferred()
	if "--scenario" in Game.dev_args():
		var sc: Node = load("res://scripts/dev/scenario.gd").new()
		sc.main = self
		add_child(sc)
	if "--command-check" in Game.dev_args() or "--command-real" in Game.dev_args():   # 개발용: 게임 안 한 줄 명령 점검 (가짜 claude, 토큰 0 — scripts/dev/command_check.gd)
		var cc: Node = load("res://scripts/dev/command_check.gd").new()
		cc.main = self
		add_child(cc)
	for a in Game.dev_args():   # 개발용: 하루 빨리 보기 (`--fast-day[=녹화.jsonl]`, scripts/dev/fast_day.gd, M5 5세션째)
		if a == "--fast-day" or a.begins_with("--fast-day="):
			var fd: Node = load("res://scripts/dev/fast_day.gd").new()
			fd.main = self
			add_child(fd)
	for a in Game.dev_args():   # 개발용: 카메라 각도 훑기 (`--cam-sweep=<폴더>`, scripts/dev/cam_sweep.gd)
		if a.begins_with("--cam-sweep="):
			var sw: Node = load("res://scripts/dev/cam_sweep.gd").new()
			sw.main = self
			add_child(sw)
	for a in Game.dev_args():
		if a.begins_with("--shot="):   # `--shot-at=7.5` = 그 초에 찍음 (연출 중간 그림, M5)
			var at := 4.0
			for b in Game.dev_args():
				if b.begins_with("--shot-at="):
					at = float(b.get_slice("=", 1))
			get_tree().create_timer(at).timeout.connect(_shot.bind(a.get_slice("=", 1)))
	if "--record" in Game.dev_args():
		_record()
	if "--autotest" in Game.dev_args():
		var dur := 9.0   # `-- --autotest --duration=60` 처럼 시간 지정 가능
		for a in Game.dev_args():
			if a.begins_with("--duration="):
				dur = float(a.get_slice("=", 1))
		get_tree().create_timer(dur).timeout.connect(_autotest)
		if "--perf" in Game.dev_args():   # 개발용: 그리는 양 · 메모리
			get_tree().create_timer(dur - 0.5).timeout.connect(func() -> void:
				print("[PERF] fps %d · 물체 %d · 삼각형 %d · 그리기 %d · 처리 %.2fms · 메모리 %.0fMB" % [
					Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]))


var _extra := Vector2i.ZERO   ## 지금 넓힌 양 (왼쪽, 오른쪽) — 크기 1.0 기준 px
var _layout_ready := false    ## 시작 시 창 위치 복원이 끝났는지 (그 전엔 창을 옮기지 않음)
var _layout_k := 0.0          ## 지금 적용된 크기 배율
var mini_k := 0.0             ## 미니 모드일 때의 섬 배율 (0 = 평소)
var mini: Node                ## 미니 모드 (mini_mode.gd)
var watch: Node               ## 감지기 (agent_watch.gd, M3) — 화면 밖 실행엔 없음
var company: Node             ## 근무일 (company.gd, M5) — 감지기와 같이 생김
var company_show: Node        ## 단계 상승 · 하루 리듬 연출 (company_show.gd, M5) — 감지기 없으면 개발 인자 장면만 (시험은 따로 만듦)
var routine: Node             ## 직원 일과 (office_routine.gd, M3) — 화면 밖 실행엔 없음 (시험이 따로 만듦)
var firm_ui: Node             ## 창업 화면 · 입사식 · 결재함 · 돌아오면 요약 (firm_ui.gd, M5 3세션째)
var phone: Node               ## 전화 = 플러그인 · 무결성 · 연결 상태 (phone.gd, M5 4세션째)
var phone_ui: Node            ## 연결 상태 패널 · 개통 안내 · 폐업 정리 카드 (phone_ui.gd)
var staff_card: Node          ## 직원 카드 (staff_card.gd)
var board_ui: Node            ## 게시판 큰 창 (board_ui.gd)
var command_runner: Node      ## 게임 안 한 줄 명령 (로드맵 ⑤, 선택 기능 · 기본 꺼짐)
var command_ui: Node


## 창 크기 = 기본 + 확장 섬 여백 (섬 크기 설정 반영, 모니터보다 넓으면 줄임)
## 왼쪽이 넓어지면 창을 그만큼 왼쪽으로 옮겨 본섬이 화면에서 제자리에 있게 함
func _update_layout() -> void:
	var extra := Vector2i.ZERO
	for i in island.islets_added:
		extra += ISLET_EXTRA[i]
	var need := Vector2(BASE_SIZE.x * diameter_k + extra.x + extra.y, BASE_SIZE.y * diameter_k)
	var k := float(Game.settings.get("size", 1.0)) if mini_k <= 0.0 else mini_k
	if not _world is SubViewport:
		var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		k = minf(k, minf((scr.size.x - 20.0) / need.x, (scr.size.y + 40.0) / need.y))   # 아래 투명 여백은 조금 넘쳐도 됨
	if extra == _extra and is_equal_approx(k, _layout_k):
		return
	var grow_left := int(round(extra.x * k - _extra.x * _layout_k)) if _layout_ready else 0
	_extra = extra
	_layout_k = k
	office.set_icon_scale(50.0 * k, diameter_k)   # 머리 위 아이콘: 창이 작아도 16px · 큰 '!' 는 크기 단계만큼 (M3)
	camera.h_offset = CAM_H_OFFSET * diameter_k - float(extra.x - extra.y) / 2.0 / PX_PER_M
	camera.v_offset = CAM_V_SHIFT * diameter_k / PX_PER_M
	var sz := Vector2i(need * k)
	if _world is SubViewport:
		(_world as SubViewport).size = sz
	else:
		var pos := DisplayServer.window_get_position()
		get_window().size = sz
		if grow_left != 0:
			pos.x -= grow_left
		if _layout_ready and mini_k <= 0.0:   # 넓어지거나 커진 창이 화면 밖으로 나가지 않게 (미니 모드는 따로 위치 지정)
			var scr2 := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			pos.x = clampi(pos.x, scr2.position.x, maxi(scr2.position.x, scr2.end.x - sz.x))
			pos.y = clampi(pos.y, scr2.position.y - 40, maxi(scr2.position.y, scr2.end.y - sz.y + 40))
			DisplayServer.window_set_position(pos)
			Game.settings.window_pos = [pos.x, pos.y]
	var s := 0.7 if k <= 0.5 else (0.8 if k <= 0.65 else (0.9 if k <= 0.85 else 1.0))
	ui.main_area = Rect2(Vector2(extra.x * k, 0) / s, Vector2(BASE_SIZE) * diameter_k * k / s)
	ui.set_ui_scale(s)
	window_ctl.rebuild_static_shape.call_deferred()


## 사진 찍기: UI를 잠깐 숨기고 섬만 투명 배경 PNG로 '사진' 폴더에 저장
func take_photo() -> void:
	var was: bool = ui.visible
	ui.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := _capture()
	ui.visible = was
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join(Identity.PHOTO_DIR)
	if "--offscreen" in Game.dev_args():
		dir = ProjectSettings.globalize_path("user://photos")   # 테스트 실행은 사용자 사진 폴더를 건드리지 않음
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("%s_%s.png" % [Identity.PHOTO_DIR, Time.get_datetime_string_from_system().replace(":", "-")])
	if img.save_png(path) == OK:
		Game.toast.emit("사진을 저장했어요: 사진 폴더 > " + Identity.PHOTO_DIR)
		Game.stat("photo")
	else:
		Game.toast.emit("사진을 저장하지 못했어요")


## 안전한 종료: 소리 멈춤 → 저장 → 두 프레임 기다린 뒤 종료
func quit_game() -> void:
	sound.shutdown()
	Game.save_game()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:   # Alt+F4 등으로 창을 닫을 때
		quit_game()


func _capture() -> Image:
	if _world is SubViewport:
		return (_world as SubViewport).get_texture().get_image()
	return get_viewport().get_texture().get_image()


func _apply_settings() -> void:
	Engine.max_fps = Game.effective_fps()
	_update_layout()   # 섬 크기 설정이 바뀌었으면 창 크기 다시 계산
	if window_ctl.mode != int(Game.settings.window_mode):
		window_ctl.set_mode(int(Game.settings.window_mode))


func _record() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://rec"))
	await get_tree().create_timer(1.0).timeout
	for i in 120:   # 15fps × 8초
		await get_tree().create_timer(1.0 / 15.0).timeout
		var img := _capture()
		var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color("8a8f99"))
		img.convert(Image.FORMAT_RGBA8)
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		bg.save_png(ProjectSettings.globalize_path("user://rec/f%03d.png" % i))
	quit_game()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR   # 투명 배경 유지
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c0dc")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.0
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)


func _setup_lights() -> void:
	# 주광: 노을빛 해 (부드러운 그림자)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 1.35
	sun.light_angular_distance = 2.5   # 해가 퍼져 보이는 정도 — 클수록 그림자 가장자리가 흐림 (M6-3)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.7   # 낮 그림자는 연하게 (밝은 사무실 비교, M6-3)
	sun.directional_shadow_max_distance = 40.0
	_sun = sun
	_world.add_child(sun)
	# 보조광: 반대편 하늘빛 (그림자 없음, 어두운 면이 뭉개지지 않게)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_color = Color("9fb4e6")
	fill.light_energy = 0.35
	_fill = fill
	_world.add_child(fill)


func _autotest() -> void:
	var img := _capture()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(ProjectSettings.globalize_path("user://preview_alpha.png"))
	# 회색 배경에 합성한 미리보기 (확인용)
	var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color("8a8f99"))
	bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	# 클릭 영역 테두리 표시
	var hull: PackedVector2Array = window_ctl.get_hull()
	for i in hull.size():
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		for s in 60:
			var p := a.lerp(b, s / 60.0)
			if Rect2(Vector2.ZERO, Vector2(bg.get_size()) - Vector2.ONE).has_point(p):
				bg.set_pixelv(Vector2i(p), Color.RED)
	bg.save_png(ProjectSettings.globalize_path("user://preview.png"))
	print("[AUTOTEST] 미리보기 저장: %s" % ProjectSettings.globalize_path("user://preview.png"))
	print("[AUTOTEST] 노드 수: %d / FPS: %d" % [island.get_child_count(), Engine.get_frames_per_second()])
	print("[AUTOTEST] 클릭 영역: 꼭짓점 %d개, 면적 %.0fpx² (창 면적의 %.0f%%)" % [hull.size(), window_ctl._area(hull),
			100.0 * window_ctl._area(hull) / (bg.get_width() * bg.get_height())])
	quit_game()


## 가독성 시험 그림: 회색 배경 합성 (UI 숨김) → 지정 경로에 PNG, 그리고 종료
func _shot(path: String) -> void:
	ui.visible = "--shot-ui" in Game.dev_args()   # `--shot-ui` = 칩 바 · HUD 도 같이
	await get_tree().process_frame
	await get_tree().process_frame
	var img := _capture()
	img.convert(Image.FORMAT_RGBA8)
	var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color("9db8d6"))   # 하늘 배경 (일함 하늘색 아이콘이 묻히는지도 같이 봄)
	bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	bg.save_png(path)
	print("[SHOT] %s" % path)
	quit_game()


func _profile_frames() -> void:
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	for i in 90:
		await get_tree().process_frame
		worst = maxf(worst, get_process_delta_time())
		if i == 0:
			Game.prof("첫 프레임")
	Game.prof("90프레임 (가장 긴 프레임 %d ms, 평균 %d ms)" % [int(worst * 1000), (Time.get_ticks_msec() - t0) / 90])
