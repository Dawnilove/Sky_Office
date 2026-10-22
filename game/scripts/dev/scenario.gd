extends Node
## 개발용 자동 점검 (`-- --offscreen --fresh --scenario`): 결과를 [SCENARIO] 줄로 출력
## 하늘 오피스 M1: 오버랜드와 신원이 겹치지 않는지 (9-1 신원 분리 8곳) + 저장 · 업데이트 · 틀이 도는지
## M2: 구역 배치 (지름 10 · 14 데이터 비교 + 지금 지름의 실제 배치 · 길찾기 · 가림) — `--diameter=14` 로 한 번 더 돌림

var main: Node3D

## 오버랜드: 하늘 농장의 값 — 하나라도 같으면 두 게임이 서로를 방해함
const OVERLAND := {
	"name": "오버랜드: 하늘 농장", "user_dir": "Overland", "mutex": "Local\\OverlandSkyFarm.Single", "run_name": "Overland",
	"repo": "Dawnilove/Overland-Sky-Farm", "zip": "Overland-%s-windows-x64.zip", "exe": "Overland.exe",
	"company": "Overland", "photo": "오버랜드", "assembly": "DeskTopFarm",
}
const FIXTURES := "res://scripts/dev/fixtures/"
const Layout := preload("res://scripts/world/layout.gd")
const AgentState := preload("res://scripts/world/agent_state.gd")
const StaffRegistry := preload("res://scripts/world/staff_registry.gd")
const AgentWatch := preload("res://scripts/world/agent_watch.gd")
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")
const StaffHash := preload("res://scripts/world/staff_hash.gd")
const Firm := preload("res://scripts/game/firm.gd")
const FirmUI := preload("res://scripts/ui/firm_ui.gd")
const Office := preload("res://scripts/world/office.gd")
const RasterIcons := preload("res://scripts/util/raster_icons.gd")
const Company := preload("res://scripts/world/company.gd")
const DayNight := preload("res://scripts/world/day_night.gd")
const CompanyShow := preload("res://scripts/world/company_show.gd")
const Phone := preload("res://scripts/world/phone.gd")
const Director := preload("res://scripts/world/director.gd")
const FastDay := preload("res://scripts/dev/fast_day.gd")
const BoardUI := preload("res://scripts/ui/board_ui.gd")


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var tally := [0, 0]   # [성공, 실패] (람다 안에서 바꾸려고 배열 사용)
	var check := func(name: String, cond: bool, info := "") -> void:
		tally[0 if cond else 1] += 1
		print("[SCENARIO] %s %s %s" % ["✔" if cond else "✘", name, info])

	# 1) 정체성 파일 ↔ 프로젝트 설정
	check.call("이름 = Identity.NAME", ProjectSettings.get_setting("application/config/name") == Identity.NAME)
	check.call("저장 폴더 = Identity.USER_DIR", ProjectSettings.get_setting("application/config/custom_user_dir_name") == Identity.USER_DIR
			and OS.get_user_data_dir().get_file() == Identity.USER_DIR, OS.get_user_data_dir())
	check.call("어셈블리 이름", ProjectSettings.get_setting("dotnet/project/assembly_name") == "DeskTopIsLand")

	# 2) 신원 분리 8곳: 오버랜드 값과 하나도 같지 않음
	var layer: Node = main.window_ctl._layer
	var cs: PackedStringArray = layer.call("IdentityInUse")
	check.call("① 저장 폴더 분리", Identity.USER_DIR != OVERLAND.user_dir and OS.get_user_data_dir().get_file() != OVERLAND.user_dir)
	check.call("② 업데이트 주소 분리", not Updater.API.contains(OVERLAND.repo) and Updater.API.contains(Identity.REPO), Updater.API)
	check.call("③ 업데이트 파일명 분리", Identity.ZIP_FORMAT % "1.0.0" != OVERLAND.zip % "1.0.0", Identity.ZIP_FORMAT % "1.0.0")
	check.call("⑤ 중복 실행 뮤텍스 분리 (C# 이 읽은 값)", cs[0] == Identity.MUTEX and cs[0] != OVERLAND.mutex, cs[0])
	check.call("⑥ 자동 실행 이름 분리 (C# 이 읽은 값)", cs[1] == Identity.RUN_NAME and cs[1] != OVERLAND.run_name, cs[1])
	check.call("⑧ 알림 앱 ID (C# 이 읽은 값)", cs[2] == Identity.APP_ID and cs[2].contains("SkyOffice"), cs[2])
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check.call("⑦ 내보내기 설정 분리", presets.contains('export_path="../release/NEW/SkyOffice/%s"' % Identity.EXE)
			and presets.contains('company_name="%s"' % Identity.COMPANY) and presets.contains('product_name="%s"' % Identity.NAME)
			and not presets.contains(OVERLAND.name) and not presets.contains('"%s"' % OVERLAND.exe)
			and not presets.contains("DLC") and presets.count("[preset.") == 4)
	check.call("사진 폴더 분리", Identity.PHOTO_DIR != OVERLAND.photo, Identity.PHOTO_DIR)

	# 3) ④ 업데이터: 버전 · 서명 키가 Identity 에 붙어 있음 (DLC 를 지워도 동작)
	var up_list := [
		{"tag_name": "v9.9.8", "assets": [{"name": OVERLAND.zip % "9.9.8", "browser_download_url": "o1"},
				{"name": OVERLAND.zip % "9.9.8" + ".sig", "browser_download_url": "o2"}]},   # 오버랜드 파일은 무시
		{"tag_name": "V1.0.0", "assets": [{"name": Identity.ZIP_FORMAT % "1.0.0", "browser_download_url": "z0"}]},   # 서명 없음
		{"tag_name": "v1.2.0", "assets": [{"name": Identity.ZIP_FORMAT % "1.2.0", "browser_download_url": "z1"},
				{"name": Identity.ZIP_FORMAT % "1.2.0" + ".sig", "browser_download_url": "s1"}]},
		{"tag_name": "v1.3.0", "draft": true, "assets": [{"name": Identity.ZIP_FORMAT % "1.3.0", "browser_download_url": "z2"},
				{"name": Identity.ZIP_FORMAT % "1.3.0" + ".sig", "browser_download_url": "s2"}]},
		{"tag_name": "cozy-ranch-v1.3.0", "assets": []},
	]
	var up_r: Dictionary = Updater.pick(up_list, Identity.version())
	check.call("④ 업데이트: 오피스 파일만 고름", str(up_r.get("version", "")) == "1.2.0" and str(up_r.get("sig", "")) == "s1", str(up_r.get("version", "")))
	check.call("④ 업데이트: 최신이면 알림 없음", Updater.pick(up_list, "1.2.0").is_empty())
	var bin := ProjectSettings.globalize_path(FIXTURES + "update_test.bin")
	check.call("④ 업데이트: 오피스 키로 서명한 파일은 통과", Updater.verify_file(bin, FileAccess.get_file_as_bytes(FIXTURES + "update_test.office.sig")))
	check.call("④ 업데이트: 오버랜드 키로 서명한 파일은 거부", not Updater.verify_file(bin, FileAccess.get_file_as_bytes(FIXTURES + "update_test.overland.sig")))
	check.call("④ 업데이트: 틀린 서명 거부", not Updater.verify_file(bin, PackedByteArray([1, 2, 3])) and not Updater.verify_file(bin, PackedByteArray()))
	check.call("업데이트: 개발 실행에선 인터넷 확인 안 함", not Updater.enabled())

	# 4) 저장: 암호화 · 왕복
	var tp := "user://scenario_save.dat"
	Game.stats["scenario"] = 777
	var wrote: bool = Game.write_save(tp)
	var raw := FileAccess.get_file_as_bytes(tp).get_string_from_ascii()
	Game.stats.erase("scenario")
	var back = Game.read_save(tp)
	check.call("저장 암호화 · 왕복", wrote and back != null and int(back.stats.scenario) == 777 and int(back.version) == Game.SAVE_VERSION
			and not raw.contains("scenario"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tp))
	var farm_keys := ["coins", "crops", "animal_data", "ext_data", "mail"]
	check.call("저장에 농장 값 없음", farm_keys.all(func(k): return not Game._snapshot().has(k))
			and not Game.settings.has("robot") and not Game.settings.has("theme"))
	check.call("개발 옵션은 개발 실행에서만", OS.is_debug_build() and Game.dev_args().size() > 0)

	# 5) 틀: 농장 · DLC 가 빠지고 섬 · 창 · 메뉴만
	check.call("Plugins 자동 로드 없음", get_node_or_null("/root/Plugins") == null)
	check.call("밭 · 동물 노드 없음", main.island.find_children("Farm*", "", true, false).is_empty() and main.island.get_node_or_null("Animals") == null)
	check.call("메뉴 = 결재함 · 설정 · 종료 (M5 3세션째 결재함)", main.ui._menu_buttons.keys() == ["tray", "gear", "power"], str(main.ui._menu_buttons.keys()))
	check.call("섬 길찾기", main.island.find_path(Vector2(0.5, 1.5), Vector2(-2.0, 1.0)).size() >= 2)
	main.ui.open_panel("gear")
	for tab in ["screen", "sound", "info"]:
		main.ui._settings_tab = tab
		main.ui.refresh_panel()
	await get_tree().process_frame
	check.call("설정 탭 3개 열림 (시간·날씨 탭 뺌)", main.ui.panel_id == "gear")
	main.ui.close_panel()

	await _m2(check)
	_m3(check)
	_m3_staff(check)
	_m3_watch(check)
	await _m3_routine(check)
	_m4(check)
	await _m4_life(check)
	_m4_tools(check)
	_m5_company(check)
	_m5_save(check)
	await _m5_show(check)
	await _m5_firm(check)
	await _m5_phone(check)
	await _m5_budget(check)

	print("[SCENARIO] 결과: 성공 %d / 실패 %d" % [tally[0], tally[1]])
	main.quit_game()


# ------------------------------------------------------------------ M4 4세션째: 소리 기본값 · 쉬는 행동 · 버릇 · ⑩ ⑪ · 인사
func _m4_life(check: Callable) -> void:
	check.call("M4 소리 기본값: 음악 · 환경음 끔 · 알림 음량 따로 (v2.8)", Game.settings.bgm == false and Game.settings.ambience == false
			and Game.settings.has("alert_volume"))
	var office: Node3D = main.office
	office.set_process(false)   # 무작위 쉬는 행동이 시험을 흔들지 않게
	var cfg: Dictionary = office.idle_cfg
	var run := func(i: int) -> void:   # 걷기 tween 을 끝까지 돌림 (도착 콜백이 새 tween 을 만들면 그것도)
		for k in 8:
			var tw: Tween = office.staff[i].tween
			if tw == null or not tw.is_valid():
				break
			tw.custom_step(5.0)
	check.call("M4 쉬는 행동 고르기: 비중 × 성격 (부지런 = 버릇 ×2) · 성격 = id % 4", Office.pick_act("부지런", cfg, 0.0) == "coffee"
			and Office.pick_act("부지런", cfg, 0.999) == "quirk" and Office.pick_act("느긋", cfg, 0.999, ["quirk"]) == "pier"
			and Office.personality_of(2, cfg) == "수다" and Office.personality_of(5, cfg) == "느긋")
	for j in office.desk_count:
		office.set_state(j, "off")
	office.set_state(0, "rest")
	office.rest_act(0, "coffee")
	run.call(0)
	var s0: Dictionary = office.staff[0]
	var coffee: bool = s0.held == "cup" and (s0.anim as AnimationPlayer).current_animation == "Drink" and office.at_pantry(0)
	office.set_state(0, "work", true)   # ⑪ 커피 중 일이 옴 → 컵 들고 걸어감 → 책상에 내려놓음
	var carry: bool = s0.held == "cup" and s0.tween != null
	run.call(0)
	check.call("M4 커피 (탕비) → ⑪ 컵 들고 복귀 → 책상 위 컵", coffee and carry and s0.held == "" and s0.get("desk_cup") != null
			and (s0.anim as AnimationPlayer).current_animation == "Sit", "%s %s %s" % [coffee, carry, s0.held])
	office.set_state(0, "rest")
	office.rest_act(0, "sofa")
	run.call(0)
	await get_tree().create_timer(0.6).timeout
	var sofa: bool = (s0.anim as AnimationPlayer).current_animation == "SitRest" and s0.get("desk_cup") == null
	office.set_state(2, "rest")   # 수다 상대 = 쉬며 서 있는 동료 (소파에 앉은 직원 0 은 안 끼움)
	office.set_state(1, "rest")
	office.rest_act(1, "chat")
	run.call(1)
	var s1: Dictionary = office.staff[1]
	var partner := -1
	for j in office.staff.size():
		if j != 1 and office.staff[j].get("act", "") == "chat":
			partner = j
	check.call("M4 소파 (기대 앉기) · 수다 (쉬는 동료와 2명, 손짓)", sofa and partner == 2 and (s1.anim as AnimationPlayer).current_animation == "Talk",
			"sofa=%s partner=%d" % [sofa, partner])
	office.set_state(0, "work")
	office.set_state(1, "work")
	office.set_state(2, "work")
	office.play_quirk(2 if office.staff.size() > 2 else 0)
	var qk: String = office.staff[2 if office.staff.size() > 2 else 0].get("last_quirk", "")
	office.set_state(1, "done0", true)
	run.call(1)
	var stretch: bool = (s1.anim as AnimationPlayer).current_animation == "Stretch"
	office.set_state(1, "done", true)   # ⑩ 기지개 → 서류 들고 결재함 → 커피
	var tidy_papers := false
	for k in 8:
		var tw: Tween = s1.tween
		if tw == null or not tw.is_valid():
			break
		tw.custom_step(1.5)
		tidy_papers = tidy_papers or s1.held == "papers"
	var qi := 2 if office.staff.size() > 2 else 0
	check.call("M4 ⑩ 끝: 자리 기지개 → 서류 들고 결재함 → 탕비 커피 · 버릇 = 그 직원 성격 (해시 직원, M5)", stretch and tidy_papers and s1.held == "cup"
			and office.at_pantry(1) and qk == str(office.idle_cfg.quirks[office.person_of(office.staff[qi])]), "%s %s %s %s" % [stretch, tidy_papers, s1.held, qk])
	office.set_state(1, "turn15", true)
	run.call(1)
	check.call("M4 인사: 창구 도착 때 손 번쩍 1번 (사장 쪽) · 컵 대신 서류 (⑨)", (s1.anim as AnimationPlayer).current_animation == "RaiseHand" and s1.held == "papers")
	office.set_state(1, "off", true)
	var bag: bool = s1.get("bag") != null
	run.call(1)
	check.call("M4 퇴근 가방: 정류장으로 갈 때 백팩 → 사라지면 치움", bag and s1.get("bag") == null)
	for j in office.desk_count:
		office.set_state(j, "off")
	office.set_process(true)


# ------------------------------------------------------------------ M4 5세션째: ② 도구별 책상 동작 · 아이콘 7장 · ⑨ 엄지척 · 멈춤 손
func _m4_tools(check: Callable) -> void:
	var office: Node3D = main.office
	office.set_process(false)
	check.call("M4 도구 종류: Edit = 고치기 · Grep = 읽기 · PowerShell = 실행 · 모르는 도구 = 그 밖 · 없음 = ''",
			Office.tool_kind("Edit") == "edit" and Office.tool_kind("Grep") == "read" and Office.tool_kind("PowerShell") == "run"
			and Office.tool_kind("Foo") == "other" and Office.tool_kind("") == "")
	var icons_ok := true
	for k in RasterIcons.TOOL_KINDS:
		var im := (RasterIcons.tool_texture(k, "A", 64) as ImageTexture).get_image()
		var navy := 0
		for y in range(8, 56, 2):
			for x in range(8, 56, 2):
				var c := im.get_pixel(x, y)
				if c.a > 0.9 and c.b > c.r + 0.1 and c.r < 0.4:
					navy += 1
		icons_ok = icons_ok and im.get_pixel(32, 4).a > 0.5 and navy >= 20 and im.get_pixel(1, 1).a < 0.1
	check.call("M4 아이콘 7장: 흰 원 + 남색 그림 (A) · 모서리 투명", icons_ok and RasterIcons.TOOL_KINDS.size() == 7)
	for j in office.desk_count:
		office.set_state(j, "off")
	var s0: Dictionary = office.staff[0]
	var an: AnimationPlayer = s0.anim
	office.set_state(0, "work")
	office.set_tool(0, "Read")
	var read_ok: bool = an.current_animation == "SitFlip" and s0.held == "papers" and (s0.tool_icon as Sprite3D).visible
	office.set_tool(0, "Edit")   # 1.5초 안 → 그대로
	var min_ok: bool = s0.tool_kind == "read"
	s0.tool_since = -1.0e9
	office.set_tool(0, "Edit")
	var edit_ok: bool = an.current_animation == "SitTypeFast" and s0.held == "" and s0.desk_papers != null and (s0.desk_papers as Node3D).get_child_count() == 1
	s0.tool_since = -1.0e9
	office.set_tool(0, "Bash")
	var scr: MeshInstance3D = office.desk_parts[0].screen
	var run_ok: bool = an.current_animation == "SitWatch" and scr.material_override == office._terminal_mat() and s0.desk_papers != null
	office.set_state(0, "done0")
	var clean: bool = s0.desk_papers == null and s0.tool_kind == "" and not (s0.tool_icon as Sprite3D).visible
	check.call("M4 ② 도구별: 읽기 = 서류 넘기기 (손에 서류) · 1.5초 유지 · 고치기 = 빠른 타자 + 종이 더미 · 실행 = 지켜보기 + 검은 화면 · 끝나면 치움",
			read_ok and min_ok and edit_ok and run_ok and clean, "%s %s %s %s %s" % [read_ok, min_ok, edit_ok, run_ok, clean])
	office.set_state(0, "work")
	office.set_stop(0, true)
	var stop_on: bool = an.current_animation == "SitStop"
	office.set_stop(0, false)
	var st := AgentState.replay([_ev(0, "UserPromptSubmit"), _ev(5, "PostToolUseFailure", "s1", {"tool": "Bash", "is_interrupt": true})])
	var v6 := AgentState.view(st.sessions.s1, 6)
	var v20 := AgentState.view(st.sessions.s1, 20)
	check.call("M4 멈춤 손: Esc (is_interrupt) → 손 들고 멈춤 4초 (땀방울 아님) → 다시 타자",
			stop_on and an.current_animation == "Sit" and v6.stop and not v6.fail and not v20.stop, "%s %s %s" % [stop_on, v6, v20.stop])
	var s1: Dictionary = office.staff[1]
	office.set_state(1, "work")
	office.set_state(1, "turn15", true)
	for k in 8:
		var tw: Tween = s1.tween
		if tw == null or not tw.is_valid():
			break
		tw.custom_step(5.0)
	var papers: bool = s1.held == "papers"
	office.set_state(1, "work", true)
	var thumbs: bool = (s1.anim as AnimationPlayer).current_animation == "ThumbsUp" and (s1.thumb as Node3D).visible and s1.held == ""
	for k in 8:
		var tw: Tween = s1.tween
		if tw == null or not tw.is_valid():
			break
		tw.custom_step(5.0)
	check.call("M4 ⑨ 내 차례 15초: 서류 들고 창구 → 사장이 답하면 엄지척 (엄지 보임) → 자리로",
			papers and thumbs and office.staff[1].node.position.distance_to(office.layout.m3(office.staff[1].desk.seat)) < 0.05, "%s %s" % [papers, thumbs])
	for j in office.desk_count:
		office.set_state(j, "off")
	office.set_process(true)


# ------------------------------------------------------------------ M4 꾸밈
func _m4(check: Callable) -> void:
	# 1) 트레이 점: 창구에서 부르는 (turn15) 직원 수
	var sh := {"a": {"look": "turn15"}, "b": {"look": "turn"}, "c": {"look": "turn15"}, "d": {"look": "work"}}
	check.call("M4 트레이: 부르는 수 = turn15 만 (2) · 없으면 0", OfficeRoutine.calling(sh) == 2 and OfficeRoutine.calling({}) == 0)
	# 2) 트레이 아이콘: 하늘 바탕 + 남색 건물, 차례면 오른쪽 아래 노랑 점 · 모서리는 투명
	var a := RasterIcons.get_texture("office", 32).get_image()
	var b := RasterIcons.get_texture("office_turn", 32).get_image()
	var dot := Vector2i(25, 25)
	check.call("M4 트레이 아이콘: 점 자리 노랑 (차례) / 노랑 아님 (평소) · 모서리 투명 · 가운데 남색 벽",
			_is_yellow(b.get_pixelv(dot)) and not _is_yellow(a.get_pixelv(dot)) and a.get_pixel(0, 0).a < 0.1
			and a.get_pixel(16, 20).b > a.get_pixel(16, 20).r, "%s %s" % [a.get_pixelv(dot), b.get_pixelv(dot)])
	# 3) 미니 모드: 부르는 동안 선명 (1.0), 아니면 설정 투명도
	var MiniMode := preload("res://scripts/window/mini_mode.gd")
	check.call("M4 미니: 부르면 투명도 1.0 · 아니면 설정값 (0.7)",
			MiniMode.want_opacity(0.7, sh) == 1.0 and MiniMode.want_opacity(0.7, {"b": {"look": "turn"}}) == 0.7)
	# 4) 인턴 조끼: 책상 직원은 조끼 없음 · 인턴 (손님) 은 조끼 + 흰 셔츠
	var office: Node3D = main.office
	var g: int = office.add_guest()
	var v0: Node3D = office.staff[0].vest
	var vg: Node3D = office.staff[g].vest
	check.call("M4 인턴 조끼: 직원 0 조끼 없음 · 인턴 조끼 보임", v0 != null and vg != null and not v0.visible and vg.visible)
	# 작업실 · 분위기 모델 (2세션째): 회색 상자 대신 모델 + 책상마다 개인 소품 3~5개
	var names_ok := ["Rack", "Bookshelf", "Whiteboard", "Telescope", "CallBoard", "BaseRock", "Rug"].all(func(n): return office.find_child(n, false, false) != null)
	var per_ok := true
	for dk in office.layout.desks().size():
		var shown := 0
		for k in 6:
			var it: Node3D = office.find_child("Desk_%d" % dk, false, false).find_child("Item%d" % k, true, false)
			shown += int(it != null and it.visible)
		per_ok = per_ok and shown >= 3 and shown <= 5
	check.call("M4 작업실 모델: 랙 · 책장 · 화이트보드 · 망원경 · 보드 틀 · 바위 · 러그 + 책상마다 개인 소품 3~5개", names_ok and per_ok)
	# 5) 실패: 머리 긁기 (앉으면 SitScratch) + 땀방울 3개 (최소 7px) → 끝나면 원래대로
	office.set_state(0, "work")
	office.set_fail(0, true)
	var an: AnimationPlayer = office.staff[0].anim
	var sw: Node3D = office.staff[0].sweat
	var spx: float = float((sw.get_child(1) as Sprite3D).pixel_size) * 32.0 / office.layout.unit_m * office.px_per_cell
	var on_ok: bool = sw.visible and sw.get_child_count() == 3 and an.current_animation == "SitScratch" and spx >= 7.0 * 0.8 - 0.01
	office.set_fail(0, false)
	check.call("M4 실패: 앉아서 머리 긁기 + 땀방울 3개 (작은 것 %.1fpx) → 끝나면 숨김 · 타자로" % spx, on_ok and not sw.visible and an.current_animation == "Sit")
	for arg in Game.dev_args():   # 개발용: `--icon-out=<폴더>` 트레이 아이콘 두 장 저장 (시안 비교)
		if arg.begins_with("--icon-out="):
			var dir := arg.get_slice("=", 1)
			for nm in ["office", "office_turn"]:
				for px in [16, 32]:
					RasterIcons.get_texture(nm, px).get_image().save_png(dir.path_join("%s_%d.png" % [nm, px]))


# ------------------------------------------------------------------ M2 구역 배치
func _m2(check: Callable) -> void:
	var l10 := Layout.new(10)
	var l14 := Layout.new(14)
	# 1) 신호: 호출 보드 · 깃대 = 고정 좌표, 창구 = 오른벽에서 같은 거리 (v2.6) · 1.0 책상 4개는 증축해도 같은 자리
	for n in ["board", "flagpole"]:
		check.call("신호 고정: " + n, l10.signal_pos(n) == l14.signal_pos(n), str(l10.signal_pos(n)))
	var off10 := Vector2(l10.building_rect().end.x, 0) - l10.signal_pos("counter")
	var off14 := Vector2(l14.building_rect().end.x, 0) - l14.signal_pos("counter")
	check.call("신호 고정: counter (오른벽 기준 같은 거리 · 같은 깊이)", off10.is_equal_approx(off14), str(off10))
	var d10 := l10.desks()
	var d14 := l14.desks()
	check.call("책상 수 4 → 12", d10.size() == 4 and d14.size() == 12)
	check.call("1.0 책상 4개 자리 그대로 (지름 14)", range(4).all(func(i): return d10[i].pos == d14[i].pos), str(d10.map(func(d): return d.pos)))
	check.call("책상 마주보기 (뒷줄 = 카메라 쪽 · 앞줄 = 뒤쪽)", d10.all(func(d): return d.rot == (180.0 if d.row == 0 else 0.0)))
	for l: Layout in [l10, l14]:
		var tag := "지름 %d" % l.diameter
		# 2) 건물 하나 안에 작업실 · 창구 · 휴게, 부두는 밖. 구역 긴 변 3칸 (150px) · 짧은 변 2칸 (100px) 이상 · 서로 안 겹침
		#    (v2.6 가로 4:3 · 앞뒤 2단: 앞줄 깊이가 크기 10 에서 2.15칸이라 '3×3칸' 대신 이 기준)
		var bld := l.building_rect()
		var small := []
		var over := []
		var names: Array = l.zone_names()
		for i in names.size():
			var r: Rect2 = l.zone_rect(names[i])
			if names[i] != "pier" and (maxf(r.size.x, r.size.y) < 3.0 or minf(r.size.x, r.size.y) < 2.0):   # 부두는 작은 발판 (v2.4)
				small.append("%s %.1f×%.1f" % [names[i], r.size.x, r.size.y])
			for j in range(i + 1, names.size()):
				if r.intersects(l.zone_rect(names[j])):
					over.append("%s-%s" % [names[i], names[j]])
		check.call(tag + ": 실내 구역 3개 모두 긴 변 3칸 · 짧은 변 2칸 이상", small.is_empty(), str(small))
		var dx := float(l.data.zones.divider_x)
		check.call(tag + ": 앞줄 = 휴게 | 창구 (경계 x %.1f 고정, 휴게가 더 넓음)" % dx, l.zone_rect("rest").end.x < dx and l.zone_rect("counter").position.x > dx
				and l.zone_rect("rest").size.x > l.zone_rect("counter").size.x and is_equal_approx(l.zone_rect("counter").end.x, bld.end.x)
				and is_equal_approx(l.zone_rect("rest").position.x, bld.position.x), "%.2f : %.2f" % [l.zone_rect("rest").size.x, l.zone_rect("counter").size.x])
		check.call(tag + ": 구역끼리 안 겹침", over.is_empty(), str(over))
		check.call(tag + ": 작업실 · 창구 · 휴게는 건물 안, 부두는 밖", ["workroom", "counter", "rest"].all(func(n): return bld.grow(0.01).encloses(l.zone_rect(n)))
				and not bld.intersects(l.zone_rect("pier")))
		var pier := l.zone_rect("pier")
		var door: Array = l.data.building.doors_left[0]
		check.call(tag + ": 부두는 왼벽 문에 붙음", is_equal_approx(pier.end.x, bld.position.x) and pier.position.y <= float(door[0]) and pier.end.y >= float(door[1]))
		var fp := l.signal_pos("flagpole")
		check.call(tag + ": 깃대는 뒷벽 위 (뒷벽 전체가 높음 = back_h, 시계 기준 간판과 좌우 짝)", absf(fp.y - bld.position.y) < 0.15 and absf(fp.x) < bld.size.x / 2.0 - 0.5
				and float(l.data.building.back_h) >= float(l.data.building.wall_high))
		check.call(tag + ": 호출 보드는 건물 뒷벽", bld.has_point(l.signal_pos("board")) and absf(l.signal_pos("board").y - bld.position.y) < 0.3)
		check.call(tag + ": 창구 · 줄은 창구 구역 안", l.zone_rect("counter").has_point(l.signal_pos("counter"))
				and l.slots("queue").all(func(q): return l.zone_rect("counter").has_point(q.pos)))
		check.call(tag + ": 책상 · 앉는 자리는 작업실 안", l.desks().all(func(d): return l.room_rect().has_point(d.pos) and l.room_rect().has_point(d.seat)))
		var off := []
		for n in ["queue", "wait_chairs", "rest_spots", "meeting_seats"]:
			for q in l.slots(n):
				if not bld.has_point(q.pos):
					off.append("%s %s" % [n, q.pos])
		for n in ["dock", "kiosk", "stop_sign"]:
			if not pier.has_point(l.slot(n)):
				off.append(n)
		check.call(tag + ": 직원이 서는 자리 모두 사무실 · 부두 안", off.is_empty(), str(off))

	# 3) 지금 지름의 실제 배치: 길찾기 · 가림
	var office: Node3D = main.office
	var lay: Layout = main.layout
	var tag2 := "[실제 %d]" % lay.diameter
	for i in office.staff.size():
		office.set_state(i, "work")
	await get_tree().process_frame
	var targets := {"창구 줄": lay.slot("queue", 3), "휴게": lay.slot("rest_spots", 0), "대기 의자": lay.slot("wait_chairs", 0),
			"승강장": lay.slot("dock"), "결재함 앞": lay.slot("inbox") + Vector2(0, -0.45), "회의 탁자": lay.slot("meeting_seats", 2)}
	var fails := []
	for d in lay.desks():
		for t in targets:
			if office.path(d.seat, targets[t]).is_empty():
				fails.append("책상%d→%s" % [d.id, t])
	check.call(tag2 + " 길찾기: 모든 책상 ↔ 창구 · 휴게 · 대기 의자 · 승강장 · 결재함", fails.is_empty(), str(fails))
	var stuck := []
	for t in targets:
		if not main.island.is_reachable(lay.m(targets[t])):
			stuck.append(t)
	for d in lay.desks():
		if not main.island.is_reachable(lay.m(d.seat)):
			stuck.append("자리%d" % d.id)
	check.call(tag2 + " 갇힌 자리 없음", stuck.is_empty(), str(stuck))
	# 가림 (화면 투영): 뒷줄 얼굴 ↔ 모니터 · 앞줄 직원, 앞줄 직원 ↔ 자기 모니터 화면, 모든 직원 · 모니터 ↔ 보드칸, 이름표끼리
	var cam: Camera3D = main.camera
	var hits := []
	var desks := lay.desks()
	var head := func(id: int) -> Rect2: return _screen_rect(cam, [office.staff[id].head])
	var body := func(id: int) -> Rect2: return _screen_rect(cam, [office.staff[id].body, office.staff[id].head])
	var screen := func(id: int) -> Rect2: return _screen_rect(cam, [office.desk_parts[id].screen])
	for a in desks:
		if a.row == 0:
			for b in desks:
				if head.call(a.id).intersects(screen.call(b.id)):
					hits.append("뒷줄 얼굴%d←모니터%d" % [a.id, b.id])
				if b.row == 1 and head.call(a.id).intersects(body.call(b.id)):
					hits.append("뒷줄 얼굴%d←앞줄%d" % [a.id, b.id])
		else:
			if screen.call(a.id).intersects(body.call(a.id)):
				hits.append("앞줄%d→자기 모니터" % a.id)
	for c in office.board_cells.size():
		var cr := _screen_rect(cam, [office.board_cells[c]])
		for d in desks:
			if cr.intersects(body.call(d.id)) or cr.intersects(screen.call(d.id)):
				hits.append("보드칸%d←책상%d" % [c, d.id])
	check.call(tag2 + " 가림 없음 (뒷줄 얼굴 · 앞줄 모니터 · 보드칸)", hits.is_empty(), str(hits.slice(0, 8)))
	check.call(tag2 + " 평소엔 이름판 숨김", desks.all(func(d): return not office.staff[d.id].tagbox.visible))
	for d in desks:   # 마우스를 다 올렸다고 치고 겹침 확인 — 부를 때 명패 = 폴더만 (M5 5세션째), 폴더 10자로
		office.set_staff_project(d.id, "SkyOffice2")   # 부를 때 명패 = 폴더만 (저절로 여럿 뜨는 경우)
	var tags := []
	for d in desks:
		tags.append(_sprite_rect(cam, office.staff[d.id].tag_bg))
	var tag_hits := []
	for i in tags.size():
		for j in range(i + 1, tags.size()):
			if tags[i].intersects(tags[j]):
				tag_hits.append("%d-%d" % [i, j])
	check.call(tag2 + " 이름판끼리 안 겹침 (모두 보일 때)", tag_hits.is_empty(), str(tag_hits))
	var board_hits := []   # 뒷줄 이름판 ↔ 호출 보드 (v2.6 회의 3 위험)
	for c in office.board_cells.size():
		var cr := _screen_rect(cam, [office.board_cells[c]])
		for d in desks:
			if tags[d.id].intersects(cr):
				board_hits.append("보드칸%d←이름판%d" % [c, d.id])
	check.call(tag2 + " 이름판 ↔ 호출 보드 안 겹침", board_hits.is_empty(), str(board_hits.slice(0, 6)))
	for d in desks:
		office.set_staff_project(d.id, "")
	for d in desks:
		office.set_hover(d.id, false)
	check.call(tag2 + " 일하는 중엔 머리 위 큰 아이콘 없음 (노랑 · 회색만, v2.5)", desks.all(func(d): return not office.staff[d.id].icon.visible)
			and desks.all(func(d): return office.staff[d.id].dot.visible and office.staff[d.id].dot.text == "●"))
	check.call("직급 명패: 근속 근무일 → 사원 · 대리 · 부장", office.rank_title(0) == "사원" and office.rank_title(15) == "대리" and office.rank_title(999) == "부장")
	office.set_days(0, 40)
	var team0: String = office.staff[0].team
	office.set_staff_team(0, "")
	var t0: String = (office.staff[0].tag as Label3D).text
	office.set_staff_team(0, "구름팀")
	var t1: String = (office.staff[0].tag as Label3D).text
	office.set_hover(0, true)
	var t1h: String = (office.staff[0].tag as Label3D).text
	office.set_hover(0, false)
	office.set_staff_project(0, "OverLand")
	var t2: String = (office.staff[0].tag as Label3D).text
	office.set_hover(0, true)
	var t3: String = (office.staff[0].tag as Label3D).text
	office.set_staff_project(0, "Physical-AI-Learnig-Machine")
	var t4: String = (office.staff[0].tag as Label3D).text
	office.set_hover(0, false)
	office.set_staff_project(0, "")
	office.set_staff_team(0, team0)
	var nm: String = office.staff[0].name
	check.call(tag2 + " 명패 (M5 5세션째 사용자 결정): 직급 · 팀 이름 안 붙임 · 부를 때 = 폴더만 · 마우스 올림 = 2줄 '직원 이름 / 폴더' (폴더 모름 = 이름만) · 10자 넘으면 '…'",
			t0 == nm and t1 == nm and t1h == nm and t2 == "OverLand" and t3 == nm + "\nOverLand" and t4 == nm + "\nPhysical-…" and bool(Game.settings.show_project),
			"%s / %s / %s / %s / %s / %s" % [t0, t1, t1h, t2, t3, t4])
	office.set_days(0, 0)
	check.call(tag2 + " 칩 바 없음 (M3 4세션째 결정) · 노랑 순서표는 그대로", main.ui.chips == null and office.chips().size() == desks.size())
	# 아이콘 크기: 창 100% · 1칸 = 50px 기준 16px 이상
	var icon_px := 0.38 * 50.0
	check.call(tag2 + " 머리 위 아이콘 16px 이상 (1칸 50px 기준)", icon_px >= 16.0, "%.0fpx" % icon_px)
	# 노랑 예약: 아무도 안 부를 때 화면에 노랑 재질 없음 (금지색 3-3)
	var yellow := []
	for mi in main.island.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		for col in _colors(mi):
			if _is_yellow(col):
				yellow.append("%s %s" % [mi.name, col.to_html(false)])
	check.call(tag2 + " 노랑 예약: 평소 화면에 노랑 없음", yellow.is_empty(), str(yellow.slice(0, 6)))
	var warm := []   # 분위기 조각 (v2.5): 노랑 · 금색 · 주황도 안 씀
	for mi in main.island.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree():
			for col in _colors(mi):
				if col.h > 0.05 and col.h < 0.19 and col.s > 0.5 and col.v > 0.6:
					warm.append("%s %s" % [mi.name, col.to_html(false)])
	check.call(tag2 + " 분위기: 노랑 · 금색 · 주황 없음", warm.is_empty(), str(warm.slice(0, 6)))
	var st: Dictionary = office.staff[0]
	check.call(tag2 + " 분위기 조각 모델: 책상 세트 · 탕비 · 직원 (앉기 동작)", office.desk_parts[0].screen is MeshInstance3D
			and office.get_node("Pantry").find_child("Pantry", true, false) is MeshInstance3D and (st.anim as AnimationPlayer).current_animation == "Sit")
	office.set_state(0, "turn")
	var at_desk: bool = office.staff[0].tagbox.visible and office.staff[0].dot.text == "!"
	office.set_state(0, "turn15")
	await get_tree().process_frame
	check.call(tag2 + " 내 차례 직원은 자리에서 이름판이 보임 · 창구 줄에선 '!' 만 (M5 3세션째 사용자)", at_desk and not office.staff[0].tagbox.visible
			and office.staff[0].icon.visible)
	check.call(tag2 + " 내 차례 15초: 줄 서기 + 깃발 노랑 + 칩 맨 앞", office.staff[0].node.position.distance_to(lay.m3(lay.slot("queue", 0))) < 0.01
			and _is_yellow((office.flag.material_override as StandardMaterial3D).albedo_color) and office.chips()[0].turn)
	for i in office.staff.size():
		office.set_state(i, "off")


# ------------------------------------------------------------------ M3 상태 판단 (agent_state.gd reduce · decide)
## 가짜 이벤트 1줄
func _ev(t: float, event: String, sess := "s1", extra := {}) -> Dictionary:
	var e := {"t": t, "event": event, "sess": sess, "proj": "p1"}
	e.merge(extra, true)
	return e


## 표시 상태 → "turn1" 같은 짧은 글자 (시험 비교용)
func _tag(v: Dictionary) -> String:
	return "%s%d" % [v.state, v.stage]


## 이벤트 목록 재생 후 now 시각의 표시 상태 (세션 하나)
func _see(lines: Array, now: float, sess := "s1") -> Dictionary:
	var st := AgentState.replay(lines.filter(func(e): return float(e.t) <= now))
	return AgentState.view(st.sessions[sess], now) if st.sessions.has(sess) else {}


func _m3(check: Callable) -> void:
	var tm := AgentState.timings()
	check.call("M3 timings.json: 15초 · 3분 · 30분 · 30초 · 12분 · 1시간", [tm.turn_walk_s, tm.turn_remind_s, tm.turn_limit_s, tm.done_rest_s, tm.quiet_s, tm.leave_s]
			== [15.0, 180.0, 1800.0, 30.0, 720.0, 3600.0])

	# 1) 내 차례 단계: 0초 자리 "!" → 15초 창구 → 3분 다시 알림 → 30분 상한 "?" · 처음 시각 유지
	var turn := [_ev(0, "SessionStart"), _ev(1, "UserPromptSubmit"), _ev(5, "PostToolUse", "s1", {"tool": "Read"}),
			_ev(100, "Notification", "s1", {"ntype": "permission_prompt"}), _ev(400, "Notification", "s1", {"ntype": "permission_prompt"})]
	var stages := [100.0, 114.9, 115.0, 279.9, 280.0, 1899.9].map(func(n): return _tag(_see(turn, n)))
	check.call("M3 내 차례 단계 0 → 15초 → 3분", stages == ["turn0", "turn0", "turn1", "turn1", "turn2", "turn2"], str(stages))
	var lim := _see(turn, 1900)
	check.call("M3 내 차례 30분 상한 → 회색 ? · 시각은 첫 알림 (14:02부터)", lim.state == "unknown" and _see(turn, 500).since == 100.0, lim.state)

	# 2) 해제 (5-2): 확실한 신호 · 2초 뒤 도구 신호만 · .jsonl 변화 (거절 · Esc)
	var rel := [_ev(0, "UserPromptSubmit"), _ev(10, "Notification", "s1", {"ntype": "permission_prompt"})]
	check.call("M3 해제: 2초 안의 도구 신호 (병렬 도구 늦은 신호) 는 해제 아님",
			_see(rel + [_ev(11.5, "PostToolUse", "s1", {"tool": "Bash"})], 12).state == "turn")
	var by_tool := AgentState.replay(rel + [_ev(12, "PostToolUse", "s1", {"tool": "Bash"})])
	check.call("M3 해제: 2초 뒤 도구 신호 → 작업 중", AgentState.view(by_tool.sessions.s1, 13).state == "work" and by_tool.sessions.s1.released == "tool")
	# v2.8 ①: 서브에이전트 (aid) 도구 신호는 본 에이전트의 '내 차례' 를 안 지움 · 알림 낸 서브에이전트 자신의 도구 신호는 해제
	var sub_tool := _see(rel + [_ev(12.1, "PostToolUse", "s1", {"tool": "Read", "aid": "a1"})], 13)
	var own_ev := [_ev(0, "UserPromptSubmit"), _ev(10, "Notification", "s1", {"ntype": "permission_prompt", "aid": "a1"}),
			_ev(12.5, "PostToolUse", "s1", {"tool": "Read", "aid": "a2"}), _ev(13, "PostToolUse", "s1", {"tool": "Bash", "aid": "a1"})]
	var own := AgentState.replay(own_ev)
	check.call("M4 해제: 서브에이전트 도구 신호 → 그대로 내 차례 · 같은 aid 만 해제",
			sub_tool.state == "turn" and _see(own_ev, 12.8).state == "turn" and own.sessions.s1.released == "tool" and own.sessions.s1.turn_at < 0.0,
			sub_tool.get("state", ""))
	var sig_ok := ["UserPromptSubmit", "Stop", "SessionEnd"].all(func(ev): return AgentState.replay(rel + [_ev(11, ev)]).sessions.s1.turn_at < 0.0)
	check.call("M3 해제: 프롬프트 · Stop · SessionEnd (즉시)", sig_ok)
	var by_jsonl := AgentState.replay(rel + [_ev(14, "jsonl", "s1", {"mtime": 14.0})])
	var old_jsonl := AgentState.replay(rel + [_ev(14, "jsonl", "s1", {"mtime": 9.0})])
	check.call("M3 해제: 알림 뒤 .jsonl 변화 = 처리됨 (추정), 알림 전 수정 시각은 무시",
			by_jsonl.sessions.s1.released == "jsonl" and AgentState.view(by_jsonl.sessions.s1, 15).state == "work" and old_jsonl.sessions.s1.turn_at == 10.0)

	# 3) 끝 → 30초 뒤 휴게 · ✓ 30분 · 1분 넘은 일만 '똑' · 입력 기다림
	var done := [_ev(0, "UserPromptSubmit"), _ev(70, "Stop")]
	var dv := [_see(done, 70), _see(done, 99.9), _see(done, 100), _see(done, 70 + 1799), _see(done, 70 + 1800)]
	check.call("M3 끝 → 30초 뒤 휴게 · ✓ 는 30분 뒤 사라짐", dv.map(func(v): return v.state) == ["done", "done", "rest", "rest", "rest"]
			and dv.map(func(v): return v.check) == [true, true, true, true, false])
	check.call("M3 끝: 1분 넘은 일만 long ('똑')", _see(done, 71).long and not _see([_ev(0, "UserPromptSubmit"), _ev(30, "Stop")], 31).long)
	check.call("M3 입력 기다림 (idle_prompt) → 쉼", _see(done + [_ev(130, "Notification", "s1", {"ntype": "idle_prompt"})], 131).state == "rest")

	# 4) 무소식 12분 · 백그라운드 작업 · 서브에이전트 · 내 차례 대기 중은 세지 않음 · 1시간 퇴근
	var quiet := [_ev(0, "UserPromptSubmit"), _ev(5, "PostToolUse", "s1", {"tool": "Edit"})]
	check.call("M3 무소식: 마지막 신호 뒤 12분 → ?", _see(quiet, 5 + 719).state == "work" and _see(quiet, 5 + 720).state == "unknown")
	var bg := [_ev(0, "UserPromptSubmit"), _ev(5, "Stop", "s1", {"bg_running": 1})]
	check.call("M3 Stop + 백그라운드 실행 중 = 끝이 아니라 작업 중 (12분 넘어도)", _see(bg, 6).state == "work" and _see(bg, 3000).state == "work")
	check.call("M3 서브에이전트 실행 중엔 무소식 아님", _see([_ev(0, "UserPromptSubmit"), _ev(5, "SubagentStart", "s1", {"agent_type": "Explore"})], 2000).state == "work")
	var wait := quiet + [_ev(600, "Notification", "s1", {"ntype": "permission_prompt"}), _ev(1000, "jsonl", "s1", {"mtime": 1000.0})]
	check.call("M3 내 차례 대기 시간은 무소식에 안 셈 (풀린 때부터 12분)", _see(wait, 1100).state == "work" and _see(wait, 1000 + 720).state == "unknown")
	check.call("M3 신호 없음 1시간 → 퇴근 (59분엔 아직) · SessionEnd → 퇴근", _see(quiet, 5 + 3600).state == "off" and _see(quiet, 5 + 3540).state != "off"
			and _see(quiet + [_ev(9, "SessionEnd")], 10).state == "off" and _see(bg, 5 + 3600).state == "off")
	check.call("M3 퇴근 뒤 같은 세션 다시 시작 → 쉼", _see(quiet + [_ev(9, "SessionEnd"), _ev(20, "SessionStart")], 21).state == "rest")
	var shut := quiet + [_ev(9, "jsonl", "s1", {"mtime": 9.0, "closed": true})]
	var reopen := AgentState.replay(shut + [_ev(30, "jsonl", "s1", {"mtime": 30.0})])
	check.call("M4 앱 꺼짐 (SessionEnd 없음, .jsonl 마지막 줄 cost-state) → 바로 퇴근 · 다시 열면 쉼 · 다시 훅 오면 일함",
			_see(shut, 10).state == "off" and AgentState.view(reopen.sessions.s1, 31).state == "rest"
			and _see(shut + [_ev(30, "jsonl", "s1", {"mtime": 30.0}), _ev(31, "UserPromptSubmit")], 32).state == "work"
			and _see(quiet + [_ev(9, "jsonl", "s1", {"mtime": 9.0})], 10).state == "work")

	# 5) 실패 · 도구 · 서브에이전트 기록 · 관찰 모드
	var fail := [_ev(0, "UserPromptSubmit"), _ev(5, "PostToolUseFailure", "s1", {"tool": "Bash", "is_interrupt": false})]
	check.call("M3 실패: 3초 동안 땀방울 · 도구 이름", _see(fail, 6).fail and _see(fail, 6).tool == "Bash" and not _see(fail, 8.1).fail
			and not _see([_ev(0, "UserPromptSubmit"), _ev(5, "PostToolUseFailure", "s1", {"tool": "Bash", "is_interrupt": true})], 6).fail)
	var sub := AgentState.replay([_ev(0, "SubagentStart", "s1", {"agent_type": "Explore"}), _ev(1, "SubagentStart", "s1", {"agent_type": "Explore"}),
			_ev(2, "SubagentStop", "s1", {"agent_type": "Explore"}), _ev(3, "SubagentStop", "s1", {"agent_type": "Explore"})])
	check.call("M3 서브에이전트: agent_type 기록만 (중복 없이) · 봉투 2개", sub.sessions.s1.agent_types == ["Explore"] and sub.sessions.s1.envelopes.size() == 2
			and int(sub.sessions.s1.subagents) == 0)
	var watch := [_ev(0, "jsonl", "w1", {"mtime": 0.0}), _ev(50, "jsonl", "w1", {"mtime": 50.0})]
	var wv := [_see(watch, 60, "w1"), _see(watch, 50 + 90, "w1")]
	check.call("M3 관찰 모드 (훅 없음): 활동 중 (추정) / 쉼 두 가지만", wv[0].state == "watch" and wv[0].guess and wv[1].state == "rest")

	# 6) 여러 세션 · 우선순위 · 순수 함수 · 스냅샷
	var multi := AgentState.replay([_ev(0, "UserPromptSubmit", "a"), _ev(0, "UserPromptSubmit", "b"), _ev(0, "UserPromptSubmit", "c"),
			_ev(5, "Notification", "b", {"ntype": "permission_prompt"}), _ev(6, "Stop", "c")])
	var dm := AgentState.decide(multi, 10)
	check.call("M3 세션 3개 동시: 일함 · 내 차례 · 끝 따로", dm.size() == 3 and dm.a.state == "work" and dm.b.state == "turn" and dm.c.state == "done")
	check.call("M3 우선순위: 내 차례 > ? > 일함 > 끝 > 쉼", AgentState.more_urgent("work", "turn") == "turn" and AgentState.more_urgent("done", "work") == "work"
			and AgentState.more_urgent("rest", "done") == "done" and AgentState.more_urgent("unknown", "work") == "unknown")
	var before := JSON.stringify(multi)
	AgentState.reduce(multi, _ev(7, "SessionEnd", "a"))
	AgentState.decide(multi, 99)
	check.call("M3 reduce · decide 는 들어온 상태를 바꾸지 않음", JSON.stringify(multi) == before)
	check.call("M3 모르는 이벤트 · 세션 없는 줄은 무시", JSON.stringify(AgentState.reduce(multi, {"t": 8, "event": "Weird", "sess": "a"})) == before
			and JSON.stringify(AgentState.reduce(multi, {"t": 8, "event": "Stop", "sess": ""})) == before)
	check.call("M3 오래 꺼진 세션 정리 (하루)", AgentState.prune(multi, 86400 + 10).sessions.is_empty() and AgentState.prune(multi, 100).sessions.size() == 3)

	# 7) 녹화 재생 (M0 실제 신호, 개인정보 뺀 fixture)
	var lines := []
	for raw in FileAccess.get_file_as_string(FIXTURES + "replay_m0.jsonl").split("\n", false):
		lines.append(JSON.parse_string(raw))
	var full := AgentState.replay(lines)
	var end_t := float(lines[-1].t)
	check.call("M3 재생: 녹화 %d줄 → 세션 11개, 모두 훅 신호 있음" % lines.size(), full.sessions.size() == 11
			and full.sessions.values().all(func(s): return s.hooked))
	var half := int(lines.size() / 2.0)
	var resumed := AgentState.replay(lines.slice(half), JSON.parse_string(JSON.stringify(AgentState.replay(lines.slice(0, half)), "", true, true)))
	check.call("M3 재생: 중간에 스냅샷 저장 → 다시 켜서 이어도 결과 같음", JSON.stringify(AgentState.decide(resumed, end_t)) == JSON.stringify(AgentState.decide(full, end_t)))
	var a56 := "a56f20ac29539f47"
	var n1: Dictionary = lines.filter(func(e): return e.sess == a56 and e.event == "Notification")[0]
	var r_turn := [_see(lines, n1.t + 1, a56), _see(lines, n1.t + 16, a56), _see(lines, n1.t + 21, a56)]
	check.call("M3 재생: 허락 창 → 내 차례 0초 → 15초 창구 → 승인한 명령이 끝나 해제", r_turn.map(_tag)
			== ["turn0", "turn1", "work0"], str(r_turn.map(func(v): return v.state)))
	var e16 := "5e16cdf7c15ea16d"
	var nx := lines.filter(func(e): return e.sess == e16 and e.event == "Notification")
	var st_rej := AgentState.replay(lines.filter(func(e): return float(e.t) <= float(nx[2].t) + 5))
	check.call("M3 재생: 거절 (훅 신호 없음) → .jsonl 변화로 해제 (추정)", st_rej.sessions[e16].released == "jsonl" and st_rej.sessions[e16].turn_at < 0.0)
	var ends := [a56, e16, "5c0370adcd8ac724"].all(func(sid): return AgentState.view(full.sessions[sid], end_t).state == "off")
	check.call("M3 재생: /exit 한 세션 3개는 퇴근", ends)
	var desk: Dictionary = full.sessions["f8ca9a9064e0001a"]
	check.call("M3 재생: 데스크톱 세션 Stop + 백그라운드 1개 → 작업 중", int(desk.bg) > 0 and AgentState.view(desk, float(desk.last) + 1).state == "work")
	check.call("M3 재생: 서브에이전트 역할 이름 기록 (general-purpose)", full.sessions.values().any(func(s): return "general-purpose" in s.agent_types))


# ------------------------------------------------------------------ M3 2세션째: 직원 배정 (staff_registry) · 감지기 (agent_watch)
func _m3_staff(check: Callable) -> void:
	var day := 86400.0
	var now := 100.0 * day
	var r := StaffRegistry.empty()
	for p in ["p1", "p2", "p3"]:
		r = StaffRegistry.touch(r, "claude", p, now, now)
	r = StaffRegistry.touch(r, "codex", "p1", now, now)
	r = StaffRegistry.touch(r, "claude", "p1", now + 5, now + 5)
	r = StaffRegistry.sync(r, 4, now + 5)
	check.call("M3 직원: 같은 조합 = 같은 직원 · 새 조합 = 빈 책상 순서 · 에이전트가 다르면 다른 직원", r.staff.size() == 4
			and r.staff.map(func(s): return int(s.desk)) == [0, 1, 2, 3] and int(r.staff[3].id) == 3 and r.staff[3].agent == "codex"
			and float(r.staff[0].last) == now + 5)
	var first := StaffRegistry.touch(StaffRegistry.empty(), "claude", "old", now - 15 * day, now)
	first = StaffRegistry.touch(first, "claude", "new", now - 13 * day, now)
	check.call("M3 직원 첫 실행: 최근 2주 조합만 입사", first.staff.size() == 1 and first.staff[0].proj == "new")
	# 휴직 2주 → 복직 (같은 직원 · 비어 있으면 같은 책상)
	var lv := StaffRegistry.sync(r, 4, now + 5 + 14 * day)
	var back := StaffRegistry.sync(StaffRegistry.touch(lv, "claude", "p2", now + 20 * day, now + 20 * day), 4, now + 20 * day)
	var p2: Dictionary = back.staff[StaffRegistry.find(back, "claude", "p2")]
	check.call("M3 직원 휴직: 2주 안 쓰면 휴직 · 책상 비움 (13일은 그대로)", lv.staff.all(func(s): return s.leave and int(s.desk) == -1)
			and StaffRegistry.sync(r, 4, now + 13 * day).staff.all(func(s): return not s.leave))
	check.call("M3 직원 복직: 같은 직원 id · 같은 책상", not p2.leave and int(p2.id) == 1 and int(p2.desk) == 1 and back.staff.size() == 4)
	# 파견: 책상보다 조합이 많을 때만 → 휴직 · 증축으로 책상이 나면 정식 배정
	var d5 := StaffRegistry.sync(StaffRegistry.touch(r, "claude", "p5", now + 6, now + 6), 4, now + 6)
	var p5: Dictionary = d5.staff[4]
	check.call("M3 파견: 최근 2주 조합 5 > 책상 4 → 다섯째는 파견 (책상 없음)", p5.dispatch and int(p5.desk) == -1
			and d5.staff.slice(0, 4).all(func(s): return not s.dispatch))
	var grown := StaffRegistry.sync(d5, 6, now + 7)
	var freed := StaffRegistry.sync(StaffRegistry.touch(d5, "claude", "p5", now + 10 * day, now + 10 * day), 4, now + 15 * day)
	check.call("M3 파견 → 정식: 증축 (책상 6) · 다른 직원 휴직으로 책상이 나면", not grown.staff[4].dispatch and int(grown.staff[4].desk) == 4
			and not freed.staff[4].dispatch and int(freed.staff[4].desk) == 0)
	# 세션 → 직원 (같은 조합 두 창 = 두 번째 세션은 임시 파견)
	var st := AgentState.replay([_ev(0, "SessionStart", "a"), _ev(5, "SessionStart", "b"), _ev(6, "SessionStart", "c", {"proj": "p2"}),
			_ev(7, "SessionStart", "z", {"proj": "모름"}), _ev(8, "SessionStart", "x"), _ev(9, "SessionEnd", "x")])
	var asg := StaffRegistry.assign(r, st, 10)
	check.call("M3 같은 조합 두 창: 먼저 연 세션 = 그 직원, 두 번째 = 임시 파견 · 퇴근 세션 · 미입사 조합 빠짐", asg.size() == 3
			and asg.a == {"staff": 0, "temp": false} and asg.b == {"staff": 0, "temp": true} and asg.c == {"staff": 1, "temp": false}, str(asg))
	# 저장 = 버전 번호 + 책상 슬롯 id · 직원 id, 연쇄 이전, 순수 함수
	var v0 := {"staff": [{"id": 2, "agent": "claude", "proj": "p", "desk": 3, "hired": 1.0, "last": 1.0, "leave": false}]}
	var m := StaffRegistry.migrate(JSON.parse_string(JSON.stringify(v0)))
	var rt := StaffRegistry.migrate(JSON.parse_string(JSON.stringify(d5, "", true, true)))
	check.call("M3 직원 저장: v0 견본 → v1 이전 · 깨진 저장 = 빈 기록 · 저장 → 읽기 같음", int(m.v) == 1 and int(m.next) == 3 and int(m.staff[0].home) == 3
			and StaffRegistry.migrate("깨짐").staff.is_empty() and JSON.stringify(StaffRegistry.sync(rt, 4, now + 6)) == JSON.stringify(StaffRegistry.sync(d5, 4, now + 6)))
	var before := JSON.stringify(r)
	StaffRegistry.touch(r, "claude", "p9", now, now)
	StaffRegistry.sync(r, 1, now + 30 * day)
	StaffRegistry.assign(r, st, 10)
	check.call("M3 staff_registry 는 들어온 기록을 바꾸지 않음", JSON.stringify(r) == before)


## bell.exe 가 쓰는 inbox 파일 1개 흉내 (<UTC 100ns>-<pid>.json, 내용은 bell 줄 모양)
func _bell(inbox: String, e: Dictionary, pid: int) -> String:
	var ticks := int(round(float(e.t) * 1e7)) + AgentWatch.TICKS_UNIX
	var line := {"v": 1, "t_start": ticks, "folder": "가림", "_shape": {}}
	for k in e:
		if k != "t":
			line[k] = e[k]
	var name := "%019d-%d.json" % [ticks, pid]
	var f := FileAccess.open(inbox.path_join(name), FileAccess.WRITE)
	f.store_string(JSON.stringify(line))
	f.close()
	return name


func _rm_tree(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_rm_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


## 세션별 짧은 표시 (부동소수 오차 없이 비교)
func _tags(st: Dictionary, now: float) -> Dictionary:
	var out := {}
	for sid in st.sessions:
		var s: Dictionary = st.sessions[sid]
		out[sid] = "%s/%s/%d/%s" % [_tag(AgentState.view(s, now)), s.phase, int(s.turn_count), s.released]
	return out


func _m3_watch(check: Callable) -> void:
	var tmp := OS.get_environment("TEMP").path_join("skyoffice_scenario_%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(tmp):
		_rm_tree(tmp)
	var base := tmp.path_join(".skyoffice")
	var w := AgentWatch.new()
	w.setup(base, "", 4)
	check.call("M3 감지기: 해시 = bell.exe 와 같음 (SHA-256 앞 8바이트)", AgentWatch.hash16("abc") == "ba7816bf8f01cfea")

	# 1) 녹화 재생: fixture 의 훅 신호를 bell 파일로 inbox 에 넣고 → 1번 확인 = agent_state.replay 와 같음
	var lines := []
	for raw in FileAccess.get_file_as_string(FIXTURES + "replay_m0.jsonl").split("\n", false):
		var e: Dictionary = JSON.parse_string(raw)
		if e.event != "jsonl":
			lines.append(e)
	var half := int(lines.size() / 2.0)
	var end_t := float(lines[-1].t)
	for i in half:
		_bell(w.inbox_dir(), lines[i], 10000 + i)
	w.tick(float(lines[half - 1].t) + 1)
	var left := DirAccess.get_files_at(w.inbox_dir()).size()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(w.state_path()))
	check.call("M3 감지기: inbox %d개 → 적용 · 스냅샷 저장 (state.json) · 파일 삭제" % half, left == 0 and typeof(saved) == TYPE_DICTIONARY
			and saved.agent.sessions.size() == AgentState.replay(lines.slice(0, half)).sessions.size() and str(saved.agent.last_file).ends_with("-%d.json" % (10000 + half - 1)))
	# 2) 다시 켜기 (새 감지기 = 스냅샷에서 시작) → 나머지 재생 = 한 번에 재생한 것과 같음
	w.free()
	w = AgentWatch.new()
	w.setup(base, "", 4)
	for i in range(half, lines.size()):
		_bell(w.inbox_dir(), lines[i], 10000 + i)
	w.tick(end_t + 1)
	var full := AgentState.replay(lines)
	check.call("M3 감지기: 다시 켜도 빠짐 없음 (스냅샷 → 이어서 = 한 번에 재생)", _tags(w.snap.agent, end_t + 1) == _tags(full, end_t + 1),
			"%d 세션" % full.sessions.size())
	var projs := {}
	for e in lines:
		projs[e.proj] = true
	var staff: Array = w.snap.staff.staff
	check.call("M3 감지기 → 직원: 프로젝트 %d개 = 직원 %d명, 책상 4개 넘는 조합은 파견" % [projs.size(), staff.size()], staff.size() == projs.size()
			and staff.filter(func(s): return int(s.desk) >= 0).size() == mini(4, projs.size())
			and staff.filter(func(s): return s.dispatch).size() == maxi(0, projs.size() - 4))
	# 3) 저장 뒤 삭제 전에 꺼짐 → 같은 파일이 남아 있어도 다시 적용하지 않음 (중복 없음)
	var t0 := end_t + 100
	var n1 := _bell(w.inbox_dir(), _ev(t0, "Notification", "dup", {"ntype": "permission_prompt"}), 1)
	var n2 := _bell(w.inbox_dir(), _ev(t0 + 1, "SubagentStart", "dup", {"agent_type": "Explore"}), 2)
	w.tick(t0 + 2)
	var once := _tags(w.snap.agent, t0 + 2)
	_bell(w.inbox_dir(), _ev(t0, "Notification", "dup", {"ntype": "permission_prompt"}), 1)
	_bell(w.inbox_dir(), _ev(t0 + 1, "SubagentStart", "dup", {"agent_type": "Explore"}), 2)
	w.free()
	w = AgentWatch.new()
	w.setup(base, "", 4)
	w.tick(t0 + 2)
	check.call("M3 감지기: 저장 뒤 못 지운 파일은 다시 적용 안 함 (중복 없음)", _tags(w.snap.agent, t0 + 2) == once and w.snap.batch == [n1, n2]
			and int(w.snap.agent.sessions.dup.subagents) == 1 and DirAccess.get_files_at(w.inbox_dir()).is_empty())
	# 4) 늦게 도착한 파일 (이름이 마지막보다 앞) 도 버리지 않음
	_bell(w.inbox_dir(), _ev(t0 + 0.5, "SubagentStart", "dup", {"agent_type": "Plan"}), 3)
	w.tick(t0 + 3)
	check.call("M3 감지기: 늦게 쓰인 앞 이름 파일도 적용", int(w.snap.agent.sessions.dup.subagents) == 2 and str(w.snap.agent.last_file) == n2)
	# 5) 상한 정리: 24시간 지난 파일은 적용하지 않고 지움 · 200개 넘으면 오래된 것부터
	_bell(w.inbox_dir(), _ev(t0 - 86401, "UserPromptSubmit", "old"), 4)
	for i in 205:
		_bell(w.inbox_dir(), _ev(t0 + 10 + i * 0.01, "PostToolUse", "many", {"tool": "Read"}), 100 + i)
	FileAccess.open(w.inbox_dir().path_join(".9999-1.tmp"), FileAccess.WRITE).close()
	w.tick(t0 + 20)
	var many: Dictionary = w.snap.agent.sessions.many
	check.call("M3 감지기 상한: 24시간 지난 파일 버림 · 200개만 처리 · 쓰는 중 임시 파일은 둠", not w.snap.agent.sessions.has("old")
			and w.snap.batch.size() == 200 and is_equal_approx(float(many.start), t0 + 10 + 5 * 0.01)
			and Array(DirAccess.get_files_at(w.inbox_dir())) == [".9999-1.tmp"])
	check.call("M3 감지기: 바뀐 게 없으면 다시 저장 안 함", not w.tick(t0 + 21))
	check.call("M3 감지기: 무결성 경고 (paused) 면 inbox 처리 멈춤", _paused_keeps(w, t0 + 22))
	w.free()

	# 6) 관찰 모드: .jsonl 수정 시각만, 폴더 · 파일 이름은 해시
	var projects := tmp.path_join("projects")
	DirAccess.make_dir_recursive_absolute(projects.path_join("C--Users-me-proj"))
	var jf := FileAccess.open(projects.path_join("C--Users-me-proj").path_join("abc.jsonl"), FileAccess.WRITE)
	jf.store_string("{}\n")
	jf.close()
	var now := Time.get_unix_time_from_system()
	var o := AgentWatch.new()
	o.setup(tmp.path_join("watch"), projects, 4)
	var ch1 := o.tick(now)
	var sid := AgentWatch.hash16("abc")
	var os_: Dictionary = o.snap.agent.sessions.get(sid, {})
	var text := FileAccess.get_file_as_string(o.state_path())
	check.call("M3 관찰 모드: .jsonl 수정 → 활동 중 (추정) · 직원 입사 · 경로는 해시만 저장", ch1 and not os_.is_empty()
			and os_.proj == AgentWatch.hash16("C--Users-me-proj") and AgentState.view(os_, now).state == "watch"
			and o.snap.staff.staff.size() == 1 and not ("Users-me" in text) and not ("abc" in text))
	check.call("M3 관찰 모드: 수정 시각이 그대로면 새 이벤트 없음", not o.tick(now + 1))
	o.free()
	var cf := projects.path_join("C--Users-me-proj").path_join("abc.jsonl")
	jf = FileAccess.open(cf, FileAccess.WRITE)
	jf.store_string("{\"type\":\"user\",\"x\":\"" + "가".repeat(4000) + "\"}\n{\"type\":\"cost-state\",\"sessionId\":\"abc\"}\n")
	jf.close()
	var c1 := AgentWatch.closed_tail(cf)
	jf = FileAccess.open(cf, FileAccess.READ_WRITE)
	jf.seek_end()
	jf.store_string("{\"type\":\"user\"}\n")
	jf.close()
	check.call("M4 꺼짐 확인: .jsonl 마지막 줄 종류만 (cost-state = 꺼짐, 뒤에 새 줄 = 다시 엶 · 없는 파일 = 아님)", c1
			and not AgentWatch.closed_tail(cf) and not AgentWatch.closed_tail(cf + ".none"))
	var o2 := AgentWatch.new()
	o2.setup(tmp.path_join("watch2"), projects, 4)
	o2.tick(now + 15 * 86400.0)
	check.call("M3 관찰 모드 첫 실행: 2주 넘은 .jsonl 은 입사 · 세션 없음", o2.snap.staff.staff.is_empty() and o2.snap.agent.sessions.is_empty()
			and o2.snap.seen.size() == 1)
	o2.free()

	# 7) 4세션째 실화면: Claude 임시 폴더는 직원 아님 · worktree = 원래 프로젝트 · 한꺼번에 바뀐 파일 무시
	var app := "C--Users-me-Desktop-app"
	check.call("M3 직원 폴더: 임시 폴더 빼기 · worktree → 원래 프로젝트", AgentWatch.canon_folder("C--Users-me-AppData-Local-Temp") == ""
			and AgentWatch.canon_folder("C--Users-me-AppData-Roaming-Claude-scratch-workspaces-e3-scratch-2026-10-08-924ab1") == ""
			and AgentWatch.canon_folder(app + "--claude-worktrees-musing-satoshi-9d82e0") == app and AgentWatch.canon_folder(app) == app)
	var fr := []
	for i in 5:
		fr.append({"t": 1000.0 + i * 10, "proj": "p%d" % i})
	var spread := fr.map(func(x): return {"t": float(x.t) * 100, "proj": x.proj})
	check.call("M3 한꺼번에: 1분 안 프로젝트 5곳 = 무시 · 4곳 · 흩어진 5곳 = 적용", AgentWatch.is_bulk(fr, fr[0])
			and not AgentWatch.is_bulk(fr.slice(0, 4), fr[0]) and not AgentWatch.is_bulk(spread, spread[2]))
	var p2 := tmp.path_join("projects2")
	_jsonl(p2.path_join(app), "a1")
	_jsonl(p2.path_join(app + "--claude-worktrees-x-1"), "w1")
	_jsonl(p2.path_join("C--Users-me-AppData-Local-Temp"), "t1")
	var o3 := AgentWatch.new()
	o3.setup(tmp.path_join("watch3"), p2, 4)
	o3.tick(now)
	var wt: Dictionary = o3.snap.agent.sessions.get(AgentWatch.hash16("w1"), {})
	check.call("M3 관찰 모드: worktree 세션 = 원래 프로젝트 직원 1명 · 임시 폴더 세션 없음", o3.snap.staff.staff.size() == 1
			and o3.snap.agent.sessions.size() == 2 and str(wt.get("proj", "")) == AgentWatch.hash16(app))
	# 훅 신호도 같은 규칙 (bell 해시 = 폴더 이름 해시)
	_bell(o3.inbox_dir(), _ev(now, "UserPromptSubmit", "tmp1", {"proj": AgentWatch.hash16("C--Users-me-AppData-Local-Temp")}), 1)
	_bell(o3.inbox_dir(), _ev(now, "UserPromptSubmit", "wt1", {"proj": AgentWatch.hash16(app + "--claude-worktrees-x-1")}), 2)
	o3.tick(now + 1)
	check.call("M3 훅 신호: 임시 폴더 무시 · worktree → 원래 프로젝트", not o3.snap.agent.sessions.has("tmp1")
			and str(o3.snap.agent.sessions.get("wt1", {}).get("proj", "")) == AgentWatch.hash16(app) and o3.snap.staff.staff.size() == 1)
	o3.free()
	var p3 := tmp.path_join("projects3")
	for i in 6:
		_jsonl(p3.path_join("C--Users-me-old%d" % i), "old%d" % i)
	var o4 := AgentWatch.new()
	o4.setup(tmp.path_join("watch4"), p3, 4)
	o4.tick(now)
	check.call("M3 관찰 모드: 프로젝트 6곳 파일이 한꺼번에 바뀜 → 입사 · 세션 없음 (기억만)", o4.snap.staff.staff.is_empty()
			and o4.snap.agent.sessions.is_empty() and o4.snap.seen.size() == 6)
	o4.free()
	var deep := tmp.path_join("내 프로젝트").path_join("my-app_v2")
	DirAccess.make_dir_recursive_absolute(deep)
	var enc_deep := AgentWatch.encode_path(deep.replace("/", "\\"))
	check.call("M3 이름판 프로젝트 이름: projects 폴더 이름 → 디스크에서 실제 이름 ('-' · '_' · 한글 섞여도) · 없는 폴더는 ''",
			AgentWatch.real_name(enc_deep) == "my-app_v2" and AgentWatch.real_name(AgentWatch.encode_path(tmp.path_join("내 프로젝트").replace("/", "\\"))) == "내 프로젝트"
			and AgentWatch.real_name(enc_deep + "-nope") == "" and AgentWatch.real_name("xyz") == "", enc_deep)
	_rm_tree(tmp)


func _jsonl(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join(name + ".jsonl"), FileAccess.WRITE)
	f.store_string("{}\n")
	f.close()


func _paused_keeps(w: Node, now: float) -> bool:
	var n := _bell(w.inbox_dir(), _ev(now, "UserPromptSubmit", "paused"), 7)
	w.paused = true
	w.tick(now)
	var kept: bool = FileAccess.file_exists(w.inbox_dir().path_join(n)) and not w.snap.agent.sessions.has("paused")
	w.paused = false
	w.tick(now)
	return kept and w.snap.agent.sessions.has("paused")


func _screen_rect(cam: Camera3D, nodes: Array) -> Rect2:
	var r := Rect2()
	var first := true
	for n in nodes:
		var mi := n as VisualInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		for k in 8:
			var p := cam.unproject_position(box.get_endpoint(k))
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r.grow(-1.0)   # 테두리 1px 맞닿음은 가림이 아님


func _colors(mi: MeshInstance3D) -> Array:
	var out := []
	if mi.material_override is StandardMaterial3D:
		out.append((mi.material_override as StandardMaterial3D).albedo_color)
		return out
	if mi.mesh == null:
		return out
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if m is StandardMaterial3D:
			out.append((m as StandardMaterial3D).albedo_color)
	return out


func _is_yellow(c: Color) -> bool:
	return c.h > 0.11 and c.h < 0.19 and c.s > 0.5 and c.v > 0.6


## 이름표 (빌보드 Label3D) 의 화면 사각형: 글자 폭 · 높이로 계산 (AABB 는 빌보드라 실제보다 큼)
func _label_rect(cam: Camera3D, l: Label3D) -> Rect2:
	var sz := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size) * l.pixel_size
	var c := l.global_position
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var a := cam.unproject_position(c - right * sz.x / 2 - up * sz.y / 2)
	var b := cam.unproject_position(c + right * sz.x / 2 + up * sz.y / 2)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## 빌보드 Sprite3D (이름판) 의 화면 사각형
func _sprite_rect(cam: Camera3D, sp: Sprite3D) -> Rect2:
	var size := Vector2(sp.texture.get_width() * sp.scale.x, sp.texture.get_height() * sp.scale.y) * sp.pixel_size
	var c := sp.global_position
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var a := cam.unproject_position(c - right * size.x / 2 - up * size.y / 2)
	var b := cam.unproject_position(c + right * size.x / 2 + up * size.y / 2)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(-1.0)


# ------------------------------------------------------------------ M3 3세션째: 직원 일과 (office_routine.gd) · 마우스 올림 · 관리인 · 아이콘 · 깃발
func _m3_routine(check: Callable) -> void:
	var R := OfficeRoutine
	# 1) 순수: decide 이름 → office LOOK 연결표
	var lk := func(state: String, stage := 0, check_ := false, guest := false) -> String:
		return R.look_of({"state": state, "stage": stage, "check": check_}, guest)
	var table := [lk.call("turn"), lk.call("turn", 1), lk.call("turn", 2), lk.call("work"), lk.call("watch"), lk.call("unknown"),
			lk.call("done"), lk.call("rest", 0, true), lk.call("rest"), lk.call("off"), lk.call("work", 0, false, true), lk.call("turn", 1, false, true)]
	check.call("M3 일과 연결표: turn · turn15 ×2 · work · watch · unknown · done0 · done (✓) · rest · off · 손님 wait · 손님 창구",
			table == ["turn", "turn15", "turn15", "work", "watch", "unknown", "done0", "done", "rest", "off", "wait", "turn15"], str(table))
	var idle := {"state": "rest", "stage": 0, "check": false, "since": 0.0}
	var ws := {"a": {"look": "wait", "v": {"state": "rest"}}, "b": {"look": "wait", "v": {"state": "work"}},
			"c": {"look": "wait", "v": {"state": "work"}}, "d": {"look": "turn15", "v": {"state": "turn"}}}
	var over: int = R.cap_interns(ws, {})
	var ws2 := {"a": {"look": "wait", "v": {"state": "rest"}}, "b": {"look": "wait", "v": {"state": "work"}}}
	var over2: int = R.cap_interns(ws2, {"a": {"look": "wait"}})
	check.call("M3 인턴 (순수): 쉼 1분 안 = 대기 · 1분 뒤 = 숨김 · 일함은 그대로 · 쉬는 인턴은 새로 안 나타남 (있던 인턴만 유지) · 최대 2명 · 내 차례는 상한 밖",
			R.look_of(idle, true, 59.0) == "wait" and R.look_of(idle, true, 61.0) == "hide" and R.look_of({"state": "work", "since": 0.0}, true, 999.0) == "wait"
			and R.look_of(idle, false, 999.0) == "rest" and over == 0 and ws.a.look == "hide" and ws.b.look == "wait" and ws.c.look == "wait" and ws.d.look == "turn15"
			and over2 == 0 and ws2.a.look == "wait")
	var wb := {"t:a": {"guest": true, "look": "wait", "v": {"state": "work"}}, "t:b": {"guest": true, "look": "wait", "v": {"state": "rest"}},
			"t:c": {"guest": true, "look": "wait", "v": {"state": "work"}}, "s:0": {"guest": false, "look": "work", "v": {"state": "work"}}}
	var plan1: Dictionary = R.borrow_plan(wb, [2, 3], {})
	var plan2: Dictionary = R.borrow_plan(wb, [3], {"t:c": 3, "t:b": 2})
	check.call("M3 책상 빌리기 (순수): 일하는 인턴만 새로 빌림 · 주인 직원은 안 빌림 · 빌린 책상은 비어 있으면 그대로 · 주인이 오면 (빈 책상에서 빠지면) 내놓음",
			plan1 == {"t:a": 2, "t:c": 3} and plan2 == {"t:c": 3}, "%s / %s" % [plan1, plan2])
	var reg0 := StaffRegistry.sync(StaffRegistry.touch(StaffRegistry.empty(), "claude", "p1", 1000.0, 1000.0), 4, 1000.0)
	var ag := AgentState.replay([_ev(1000, "SessionStart", "a"), _ev(1001, "SessionStart", "b"), _ev(1002, "UserPromptSubmit", "b")])
	var vw: Dictionary = R.views(ag, reg0, 1003.0)
	var ag2 := AgentState.replay([_ev(1000, "SessionStart", "a"), _ev(1001, "SessionStart", "b"), _ev(1002, "Notification", "b", {"ntype": "permission_prompt"})])
	var vr: Dictionary = R.views(ag2, reg0, 1020.0)
	check.call("M4 팀원 = 메인 세션 (먼저 연 a, 쉬어도 고정) · 인턴 = b · 인턴 내 차례 → 팀원이 대신 창구 (인턴은 대기)", str(vw.get("s:0", {}).get("sess", "")) == "a"
			and vw.has("t:b") and vr["s:0"].state == "turn" and vr["s:0"].get("relay", "") == "b" and int(vr["s:0"].stage) == 1
			and R.look_of(vr["s:0"]) == "turn15" and R.look_of(vr["t:b"], true, 1020.0) == "wait", str(vw.keys()))
	var sp := [_ev(1000, "SessionStart", "a"), _ev(1001, "UserPromptSubmit", "a"), _ev(1002, "SubagentStart", "a", {"agent_type": "Explore", "aid": "x1"}),
			_ev(1003, "SubagentStart", "a", {"agent_type": "", "aid": "x2"}), _ev(1004, "PostToolUse", "a", {"tool": "Read", "aid": "x1"})]
	var vsp: Dictionary = R.views(AgentState.replay(sp), reg0, 1010.0)
	var vsp_end: Dictionary = R.views(AgentState.replay(sp + [_ev(1011, "SubagentStop", "a", {"agent_type": "Explore", "aid": "x1"})]), reg0, 1012.0)
	var tsp: Dictionary = R.targets(AgentState.replay(sp), reg0, 1010.0)
	check.call("M6-1 전문가 직원: 역할 이름 있는 서브에이전트 = 손님 'x:aid' (이름 = 역할 · 도구 따라감 · 팀원은 부모) · 빈 이름은 안 보임 · 끝나면 사라짐 · 끝 신호 놓치면 무소식 뒤 사라짐",
			vsp.has("x:x1") and not vsp.has("x:x2") and vsp["x:x1"].spec == "Explore" and vsp["x:x1"].tool == "Read" and int(vsp["x:x1"].staff) == 0
			and vsp.has("s:0") and tsp["x:x1"].name == "Explore" and tsp["x:x1"].guest and R.look_of(vsp["x:x1"], true, 1010.0) == "wait"
			and not vsp_end.has("x:x1") and not R.views(AgentState.replay(sp), reg0, 1004.0 + 1.0e5).has("x:x1"), str(vsp.keys()))
	var wsp: Dictionary = R.targets(AgentState.replay(sp), reg0, 1010.0)
	R.spec_looks(wsp, reg0, "salt1")
	var wsp2: Dictionary = R.targets(AgentState.replay(sp), reg0, 1010.0)
	R.spec_looks(wsp2, reg0, "salt1")
	var wsp3: Dictionary = R.targets(AgentState.replay(sp), reg0, 1010.0)
	R.spec_looks(wsp3, reg0, "salt2")
	var rg := reg0
	for d in [10, 10, 11, 12, 13, 14, 15]:   # 같은 날은 1일 · 서로 다른 날 6일 → 직급
		rg = StaffRegistry.touch_role(rg, "p1", "Explore", d)
	var wsp4: Dictionary = R.targets(AgentState.replay(sp), rg, 1010.0)
	R.spec_looks(wsp4, rg, "salt1")
	check.call("M6-4 전문가 고정 얼굴 (같은 솔트 = 같은 이름 · 모습, 다른 솔트 = 다름) · 명패 역할 줄 (PM · 전문가) · 역할 근속 5일 → 직급 · 옛 저장 호환",
			wsp["x:x1"].hash == wsp2["x:x1"].hash and wsp["x:x1"].name == wsp2["x:x1"].name and str(wsp["x:x1"].role) == "전문가"
			and wsp["s:0"].role == "PM" and not wsp["x:x1"].hash.is_empty() and StaffRegistry.role_days(rg, "p1", "Explore") == 6
			and str(wsp4["x:x1"].role) == "전문가 주임" and wsp3["x:x1"].hash != wsp["x:x1"].hash
			and StaffRegistry.migrate({"v": 1, "next": 0, "staff": []}).roles == {} and R.role_label("Explore") == "탐색" and R.role_label("mine") == "mine", str(wsp4["x:x1"].get("role")) + " " + str(StaffRegistry.role_days(rg, "p1", "Explore")))
	check.call("M3 일과: 모든 표시 이름이 office LOOK 에 있음", table.all(func(t): return Office.LOOK.has(t)))
	# 3초 유지 · 내 차례 즉시 · 끼어들기는 바로 (순수)
	var sh := {"k": {"look": "work", "at": 10.0, "stage": 0}}
	var held: Dictionary = R.step(sh, {"k": {"look": "done0"}}, 12.0)
	var moved: Dictionary = R.step(sh, {"k": {"look": "done0"}}, 13.0)
	var turned: Dictionary = R.step(sh, {"k": {"look": "turn"}}, 10.5)
	var rested: Dictionary = R.step({"k": {"look": "rest", "at": 10.0, "stage": 0}}, {"k": {"look": "work"}}, 10.5)
	check.call("M3 일과 3초 유지: 2초 뒤 그대로 · 3초 뒤 바뀜 · 내 차례는 0.5초에도 즉시 · 쉬다가 일이 오면 즉시",
			held.k.look == "work" and moved.k.look == "done0" and turned.k.look == "turn" and rested.k.look == "work")
	check.call("M3 끼어들기 3가지: 커피 = 컵 · 소파 = 벌떡 · 퇴근 중 = 앗 (일하는 중엔 없음)", R.interrupt("done", "work", true, false) == "cup"
			and R.interrupt("rest", "turn", false, false) == "jump" and R.interrupt("off", "work", false, true) == "oops"
			and R.interrupt("off", "work", false, false) == "" and R.interrupt("work", "turn", false, false) == "" and R.interrupt("rest", "done", true, false) == "")
	check.call("M3 '딩': 창구 도착 · 3분 다시 알림만, 30초 안엔 안 울림", R.ding_due({}, {"k": {"look": "turn15", "stage": 1}}, -1e18, 100.0)
			and not R.ding_due({}, {"k": {"look": "turn15", "stage": 1}}, 80.0, 100.0)
			and R.ding_due({"k": {"look": "turn15", "stage": 1}}, {"k": {"look": "turn15", "stage": 2}}, 0.0, 100.0)
			and not R.ding_due({"k": {"look": "turn15", "stage": 1}}, {"k": {"look": "turn15", "stage": 1}}, 0.0, 100.0)
			and not R.ding_due({}, {"k": {"look": "turn", "stage": 0}}, -1e18, 100.0))
	var texts: Array = R.TOOL_TEXT.values() + ["work", "watch", "unknown", "done0", "rest", "wait"].map(func(l): return R.bubble_text(l, {}))
	var tb: String = R.bubble_text("turn15", {"since": 0.0}, 14 * 60 + 2)
	check.call("M3 말풍선: 정해진 문구 12자 이하 · 내 차례 = '터미널에서 확인하세요' + '14:02부터'", texts.all(func(t): return t.length() <= 12 and t != "")
			and tb == "터미널에서 확인하세요\n14:02부터" and Array(tb.split("\n")).all(func(t): return t.length() <= 12), tb.replace("\n", " / "))

	# 2) 가짜 스냅샷 → 실제 office (화면 밖)
	var office: Node3D = main.office
	var rt: Node = OfficeRoutine.new()
	rt.name = "RoutineTest"
	rt.setup(office, null, null, main.camera)
	add_child(rt)
	var day := 86400.0
	var T := 100.0 * day
	var reg := StaffRegistry.empty()
	for pj in ["p1", "p2"]:
		reg = StaffRegistry.touch(reg, "claude", pj, T, T)
	reg = StaffRegistry.sync(reg, office.desk_count, T)
	var lines: Array = [_ev(T, "SessionStart", "a"), _ev(T + 1, "UserPromptSubmit", "a")]
	var at := func(now: float) -> void:
		rt.apply(AgentState.replay(lines.filter(func(e): return float(e.t) <= now)), reg, now)
	at.call(T + 2)
	check.call("M3 일과: 가짜 스냅샷 → 책상 0 직원 '일함' · 이름 = 해시 직원 이름 (M5) · 다른 책상은 퇴근", office.staff[0].state == "work"
			and office.staff[0].name == str(StaffHash.staff_looks(reg, str(Game.firm.salt), Game.firm.plates)[0].name) and office.staff[1].state == "off" and office.staff[0].node.visible)
	check.call("M4 출근 버스: 퇴근해 있던 직원이 일을 받으면 비행선 버스가 정류장으로 옴 (보임)", office.bus_state in ["coming", "docked"]
			and office.bus.visible, office.bus_state)
	lines.append(_ev(T + 3, "Stop", "a"))
	at.call(T + 3.5)
	var hold1: String = office.staff[0].state
	at.call(T + 5.1)
	check.call("M3 일과 3초 유지: 끝이 와도 1.5초 뒤엔 그대로 '일함' → 3초 뒤 자리에서 ✓ (done0)", hold1 == "work" and office.staff[0].state == "done0", hold1)
	lines.append(_ev(T + 6, "Notification", "a", {"ntype": "permission_prompt"}))
	at.call(T + 6.0)
	check.call("M3 일과 내 차례 즉시: 바뀐 지 1초여도 바로 '!' (자리)", office.staff[0].state == "turn" and office.staff[0].icon.visible)
	at.call(T + 21)
	check.call("M3 일과 15초: 창구 줄로 + 깃발 노랑 (그늘 없음 · 크게) + '딩' 1번", office.staff[0].state == "turn15" and rt.dings == 1
			and _is_yellow((office.flag.material_override as StandardMaterial3D).albedo_color)
			and (office.flag.material_override as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and office.flag.scale.x > 1.2)
	var want_px: float = Office.icon_cells(true, office.px_per_cell, office.big_k) * main.layout.unit_m / 64.0
	check.call("M3 큰 '!' 크기 = icon_cells (크기 단계 %.1f 반영)" % office.big_k, is_equal_approx((office.staff[0].plate as Sprite3D).pixel_size, want_px)
			and is_equal_approx(office.big_k, main.diameter_k))
	lines.append_array([_ev(T + 20, "SessionStart", "b", {"proj": "p2"}), _ev(T + 25, "Notification", "b", {"ntype": "permission_prompt"})])
	at.call(T + 40)
	check.call("M3 '딩' 30초 제한: 둘째가 19초 뒤 창구에 서도 안 울림 · 줄 두 번째 자리", office.staff[1].state == "turn15" and rt.dings == 1
			and int(office.staff[1].spot.k) == 1)
	at.call(T + 186)
	check.call("M3 '딩' 3분 다시 알림 (한 번)", rt.dings == 2)
	lines.append_array([_ev(T + 190, "UserPromptSubmit", "a"), _ev(T + 192, "SubagentStop", "a")])
	at.call(T + 192)
	var paused: bool = rt.env_flying == 0 and rt.env_queue.size() == 1
	lines.append(_ev(T + 200, "UserPromptSubmit", "b"))
	at.call(T + 200)
	check.call("M3 봉투: 누가 내 차례면 멈춤 → 풀리면 책상으로 날아감", paused and rt.env_flying == 1 and rt.env_queue.is_empty()
			and office.find_children("Envelope", "", false, false).size() == 1)
	check.call("M4 일 받기: 일을 주면 (UserPromptSubmit) 사장 책상 → 직원 책상 종이비행기 (내 차례여도 날림)", rt.planes == 2
			and office.find_children("PaperPlane", "", false, false).size() >= 1, "planes=%d" % rt.planes)
	var thrown: bool = office.boss_present() and (office.boss.anim as AnimationPlayer).current_animation == "SitThrow"
	office.set_boss_away(true)
	var gone: bool = not office.boss_present()
	office.set_boss_away(false)
	check.call("M4 사장 (플레이어): 의자에 앉아 있다가 일을 주면 직접 던짐 (SitThrow) · 자리 비우면 사라짐 · 돌아오면 앉음", thrown and gone
			and office.boss_present(), (office.boss.anim as AnimationPlayer).current_animation)
	office.dress(0, 1)
	var vis: Array = office.staff[0].outfits.map(func(o): return (o as Node3D).visible)
	var seen := {}
	for n in 30:   # 무작위 30번이면 3벌 다 나옴
		office.dress(0)
		seen[office.staff[0].outfit] = true
	check.call("M4 직원 복장: 한 번에 한 벌만 (후드) · 출근마다 무작위 (30번에 3벌 모두)", vis == [false, true, false] and seen.size() == 3, str(vis))
	# 끼어들기: 끝 → 30초 뒤 휴게 코너 → 일이 옴 (1초 만이어도 바로)
	lines.append(_ev(T + 300, "Stop", "a"))
	at.call(T + 300)
	at.call(T + 331)
	var rest_look: String = office.staff[0].state
	var pantry: bool = office.at_pantry(0)
	lines.append(_ev(T + 332, "UserPromptSubmit", "a"))
	at.call(T + 332)
	check.call("M3 끼어들기: 휴게 코너 (✓) → 1초 뒤 일이 와도 바로 자리로 · 컵/벌떡 (자리 따라)", rest_look == "done" and office.staff[0].state == "work"
			and rt.said.back() == ["s:0", "cup" if pantry else "jump"], "%s %s" % [rest_look, str(rt.said.back())])
	lines.append(_ev(T + 400, "SessionEnd", "a"))
	at.call(T + 400)
	var leaving: bool = office.is_leaving(0)
	lines.append_array([_ev(T + 401, "SessionStart", "a2"), _ev(T + 401.5, "UserPromptSubmit", "a2"), _ev(T + 401.6, "PostToolUse", "a2", {"tool": "Edit"})])
	at.call(T + 402)
	check.call("M3 끼어들기: 퇴근 걸음 중 일이 옴 → '앗!' 돌아서 자리로", leaving and office.staff[0].state == "work" and rt.said.back() == ["s:0", "oops"]
			and office.staff[0].bubble.visible and office.staff[0].bubble.text == "앗!")
	# 같은 조합 두 번째 창 = 인턴 (회색 옷) → 주인이 퇴근한 빈 책상을 빌려 앉음 (5세션째) → 내 차례면 창구로
	lines.append_array([_ev(T + 403, "SessionStart", "c"), _ev(T + 404, "UserPromptSubmit", "c")])
	at.call(T + 405)
	var gi: int = rt.slot.get("t:c", -1)
	check.call("M3 인턴: 두 번째 창 = 인턴 (책상 없음 · 이름 '인턴') → 빈 책상 빌려 앉아 일함 · 주인은 그대로 · 이름판 색 줄 = 주인과 같은 프로젝트 색",
			gi >= office.desk_count and office.staff[gi].state == "work" and office.staff[gi].name == "인턴" and office.staff[gi].desk.is_empty()
			and office.staff[gi].spot.where == "borrow" and int(office.staff[gi].borrow_j) >= 2 and office.staff[0].state == "work"
			and str(office.staff[gi].color) != "" and office.staff[gi].color == office.staff[0].color and office.staff[1].color != office.staff[0].color
			and office.staff[gi].stripe.visible, "guest %d · 책상 %d" % [gi, int(office.staff[gi].borrow_j) if gi >= 0 else -1])
	lines.append(_ev(T + 406, "Notification", "c", {"ntype": "permission_prompt"}))
	at.call(T + 422)
	var ai: int = rt.slot.get("t:c", -1)
	check.call("M4 인턴 보고는 팀원을 거쳐서만: 인턴 c 내 차례 → 팀원 (직원 0, 메인 a2) 이 창구 줄 · c 는 빌린 책상에서 대기 · a2 는 인턴 아님", office.staff[0].state == "turn15"
			and office.staff[0].spot.where == "queue" and ai >= office.desk_count and office.staff[ai].state == "wait" and office.staff[ai].spot.where == "borrow"
			and not rt.slot.has("t:a2"), "c 인턴 %d" % ai)
	await get_tree().create_timer(3.0).timeout
	check.call("M3 이동 3초 안: 3초 뒤 직원은 창구 줄 · 인턴은 빌린 책상에 도착 (걷기 끝)", office.staff[0].tween == null and ai >= 0 and office.staff[ai].tween == null
			and is_equal_approx(Office.walk_speed(12.0, 0.6, 2.8) * (2.8 - 0.15), 12.0) and Office.walk_speed(0.5, 0.6, 2.8) == 0.6,
			"직원 %s / 인턴 %s" % [office.staff[0].tween, office.staff[ai].tween if ai >= 0 else null])
	# 인턴: 쉬면 1분 뒤 정류장으로 걸어 나감 · 쉬는 인턴은 새로 안 나타남 · 빈 책상 다 차면 대기 의자 최대 2명 + '+N'
	lines.append(_ev(T + 430, "UserPromptSubmit", "c"))
	at.call(T + 431)
	var ci: int = rt.slot.get("t:c", -1)
	var c_in: String = office.staff[ci].state if ci >= 0 else "?"
	var env_before: int = rt.env_queue.size() + rt.env_flying
	lines.append(_ev(T + 440, "Stop", "c"))
	at.call(T + 445)
	check.call("M4 인턴 일 끝 = 보고 서류 → 팀원 책상 (직원 0) 으로 봉투 1장", rt.env_queue.size() + rt.env_flying == env_before + 1
			and (rt.env_queue.is_empty() or rt.env_queue.back() == 0), "%d → %d" % [env_before, rt.env_queue.size() + rt.env_flying])
	var kept: String = office.staff[ci].state if ci >= 0 else "?"
	var kept_at: String = office.staff[ci].spot.get("where", "") if ci >= 0 else "?"
	at.call(T + 501)
	check.call("M3 인턴: 둘 다 일하면 먼저 연 a2 가 책상 · c 는 인턴 (빌린 책상) → 끝난 뒤 1분 안은 그 자리 · 1분 뒤 정류장으로 걸어 나감",
			office.staff[0].state == "work" and c_in == "work" and kept == "wait" and kept_at == "borrow" and office.staff[ci].state == "hide"
			and office.is_leaving(ci), "%s %s %s" % [c_in, kept, kept_at])
	var n_int: int = office.desk_count - 2 + 3   # 빈 책상 (책상 수 - 주인 2명) + 의자 2 + 넘침 1
	for k in n_int:
		lines.append_array([_ev(T + 502, "SessionStart", "i%d" % k), _ev(T + 503, "UserPromptSubmit", "i%d" % k)])
	at.call(T + 505)
	var on_desk := range(office.desk_count, office.staff.size()).filter(func(j): return office.staff[j].state == "work" and office.staff[j].spot.get("where", "") == "borrow")
	var waiting := range(office.desk_count, office.staff.size()).filter(func(j): return office.staff[j].state == "wait")
	check.call("M3 인턴 %d명: 빈 책상 %d개 다 빌림 → 대기 의자 2명 + '+1'" % [n_int, office.desk_count - 2], on_desk.size() == office.desk_count - 2
			and waiting.size() == 2 and office.more_label.visible and office.more_label.text == "+1", "책상 %d · 의자 %d · %s" % [on_desk.size(), waiting.size(), office.more_label.text])
	# 주인 출근 → 빌린 인턴이 비켜 줌 (책상 2 에 새 직원 p3)
	var reg3 := StaffRegistry.sync(StaffRegistry.touch(reg, "claude", "p3", T + 506, T + 506), office.desk_count, T + 506)
	lines.append_array([_ev(T + 506, "SessionStart", "z", {"proj": "p3"}), _ev(T + 507, "UserPromptSubmit", "z", {"proj": "p3"})])
	rt.apply(AgentState.replay(lines.filter(func(e): return float(e.t) <= T + 508)), reg3, T + 508)
	var on2 := range(office.desk_count, office.staff.size()).filter(func(j): return int(office.staff[j].borrow_j) == 2)
	check.call("M3 주인 출근 → 그 책상 빌린 인턴이 비켜 줌 (책상 2 = 새 직원 · 빌린 인턴 없음)", office.staff[2].state == "work" and on2.is_empty(), str(on2))
	for k in n_int:
		lines.append(_ev(T + 509, "SessionEnd", "i%d" % k))
	rt.apply(AgentState.replay(lines.filter(func(e): return float(e.t) <= T + 515)), reg3, T + 515)
	check.call("M3 인턴: 다 끝나면 '+N' 숨김", not office.more_label.visible)
	# 마우스 올림: 머리 위치로 광선 → 그 직원 · 이름판 + 말풍선 (도구 문구)
	var head: Vector3 = office.staff[0].head.global_position
	var picked: int = rt.pick_at(main.camera.unproject_position(head))
	rt.set_hover(picked)
	office.staff[0].say_text = ""
	office._show_bubble(0)
	check.call("M3 마우스 올림 (ray_pick): 직원 머리 → 그 직원 · 이름판 + 말풍선 '고치는 중' · 빈 곳은 없음", picked == 0 and office.staff[0].tagbox.visible
			and office.staff[0].bubble.visible and office.staff[0].bubble.text == "고치는 중" and rt.pick_at(Vector2(2, 2)) == -1, "picked %d" % picked)
	rt.set_hover(-1)
	check.call("M3 마우스 내리면 이름판 · 말풍선 숨김 (일하는 중)", not office.staff[0].tagbox.visible and not office.staff[0].bubble.visible)
	# 큰 아이콘 최소 크기 · 관리인
	check.call("M3 아이콘: 크기 14 큰 '!' = 400px 그림에서 크기 10 이상 · 창 60% 에서도 작은 아이콘 16px", Office.icon_cells(true, 50, 1.4) / 1.4 >= Office.icon_cells(true, 50, 1.0)
			and Office.icon_cells(false, 30, 1.0) * 30 >= 16.0 and Office.icon_cells(true, 30, 1.0) > Office.icon_cells(false, 30, 1.0))
	var kk: MeshInstance3D = office.kiosk
	check.call("M3 정류장 (4세션째): 관리인 대신 안내 단말기 · 표지판 · 유리 쉼터 · 승강장 1.75×1.0칸 (M4 실화면 사용자 \"옆으로 조금 길게\")", kk != null and office.get_node_or_null("Caretaker") == null
			and Vector2(kk.position.x, kk.position.z).distance_to(main.layout.m(main.layout.slot("kiosk"))) < 0.01
			and office.get_node_or_null("StopSign") == null and office.find_children("StopPole", "", false, false).size() == 1
			and office.find_children("StopRoof", "", false, false).size() == 1 and main.layout.zone_rect("pier").size.is_equal_approx(Vector2(1.75, 1.0)))
	rt.queue_free()
	for i in office.staff.size():
		office.set_state(i, "off")
	for e in office.find_children("Envelope", "", false, false):
		e.queue_free()


# ------------------------------------------------------------------ M5 1세션째: 근무일 · 게임 하루 (company.gd) · 저장 버전 (시험 ③)
## 이벤트 여러 개를 차례로 → 마지막 상태
func _co(st: Dictionary, evs: Array) -> Dictionary:
	for e in evs:
		st = Company.on_event(st, e[0], e[1]).state
	return st


func _m5_company(check: Callable) -> void:
	var T := 1_800_000_000.0
	var H := 3600.0
	var e0 := Company.empty()
	check.call("M5 하루: 창 없음 = 밤 (22시) · 근무일 0", is_equal_approx(Company.hour_at(e0, T), 22.0) and e0.earned_days == 0)
	var a := Company.on_event(e0, "prompt", T)
	var s1: Dictionary = a.state
	check.call("M5 하루: 첫 메시지 = 새 하루 (근무일 1) · 08시 → 2.5시간 = 14시 → 5시간 = 20시 → 30분 뒤 22시 (밤)", a.day and s1.earned_days == 1
			and is_equal_approx(Company.hour_at(s1, T), 8.0) and is_equal_approx(Company.hour_at(s1, T + 2.5 * H), 14.0)
			and is_equal_approx(Company.hour_at(s1, T + 5 * H), 20.0) and is_equal_approx(Company.hour_at(s1, T + 5.5 * H), 22.0)
			and Company.progress(s1, T + 5 * H) < 0.0)
	var s2 := _co(s1, [["jsonl", T + H], ["prompt", T + 4 * H], ["jsonl", T + 5 * H + 60]])
	check.call("M5 하루: 창 안 활동 = 같은 하루 · 5시간 지난 첫 활동 (관찰 모드 .jsonl 도) = 다음 하루 (근무일 2)", s2.earned_days == 2
			and is_equal_approx(float(s2.win_start), T + 5 * H + 60))
	var r := Company.on_event(s1, "rate_limit", T + 2 * H)
	var s3: Dictionary = r.state
	check.call("M5 훅 보정: rate_limit = 일찍 퇴근 (창 밖 · 12시 48분에서 30분 동안 밤으로) · 근무일 그대로", r.early and s3.earned_days == 1
			and Company.progress(s3, T + 2 * H + 1) < 0.0 and is_equal_approx(Company.hour_at(s3, T + 2 * H), 12.8)
			and is_equal_approx(Company.hour_at(s3, T + 2.5 * H), 22.0))
	var s4 := _co(s3, [["jsonl", T + 2 * H + 2]])
	var s5 := _co(s4, [["prompt", T + 3 * H]])
	var s6 := _co(s5, [["rate_limit", T + 3 * H + 30]])
	check.call("M5 훅 보정: 일찍 퇴근 뒤 .jsonl 만 = 아님 · 다음 메시지 = 새 하루 · 10분 안에 또 막힘 = 그 하루 취소", s4.earned_days == 1
			and s5.earned_days == 2 and Company.progress(s5, T + 3 * H) == 0.0 and s6.earned_days == 1 and Company.progress(s6, T + 3 * H + 60) < 0.0)
	var s7 := Company.on_event(s6, "resume", T + 4 * H)
	check.call("M5 훅 보정: quota_auto_resume_fired = 그 시각부터 새 하루 (08시) · 그 뒤 5시간", s7.day and s7.state.earned_days == 2
			and is_equal_approx(Company.hour_at(s7.state, T + 4 * H), 8.0) and Company.progress(s7.state, T + 8.9 * H) > 0.9)
	var s8 := _co(s1, [["resume", T + 120]])
	check.call("M5 훅 보정: 하루 시작 10분 안 재개 알림 = 같은 하루, 경계만 바로잡음", s8.earned_days == 1 and is_equal_approx(float(s8.win_start), T + 120))
	var s9 := _co(s1, [["jsonl", T + 6 * H], ["prompt", T + 5.5 * H]])
	check.call("M5 하루: 늦게 온 옛 신호 (시각이 거꾸로) 무시", s9.earned_days == 2 and is_equal_approx(float(s9.win_start), T + 6 * H))
	var keep_th := Company.thresholds
	Company.thresholds = [0, 2, 6]
	var st := Company.empty()
	st.earned_days = 9   # 업데이트로 문턱이 생긴 경우: 이미 두 단계 위
	var u1 := _co(st, [["prompt", T]])
	var u2 := _co(u1, [["prompt", T + 6 * H]])
	var u3 := _co(u2, [["prompt", T + 12 * H]])
	check.call("M5 단계: earned_days · shown_stage 분리 — 업데이트 뒤 게임 하루 1단계씩 따라 올라감", Company.stage_for(9) == 2 and Company.stage_for(1) == 0
			and [u1.shown_stage, u2.shown_stage, u3.shown_stage] == [1, 2, 2] and u3.earned_days == 12)
	Company.thresholds = keep_th
	var n := Company.normalize({"earned_days": 3.0, "zzz": 1})
	check.call("M5 저장 값 정리: 모르는 키 버림 · 빠진 키 채움 · 근무일 정수", n.earned_days == 3 and typeof(n.earned_days) == TYPE_INT
			and not n.has("zzz") and n.has("win_start") and Company.normalize(null) == Company.empty())

	# 감지기 → 근무일 신호
	var kinds := [AgentWatch.company_kind({"event": "UserPromptSubmit"}), AgentWatch.company_kind({"event": "jsonl", "closed": false}),
			AgentWatch.company_kind({"event": "jsonl", "closed": true}), AgentWatch.company_kind({"event": "StopFailure", "error_kind": "rate_limit"}),
			AgentWatch.company_kind({"event": "StopFailure", "error_kind": "overloaded"}), AgentWatch.company_kind({"event": "Notification", "ntype": "quota_auto_resume_fired"}),
			AgentWatch.company_kind({"event": "Notification", "ntype": "idle_prompt"}), AgentWatch.company_kind({"event": "PostToolUse"})]
	check.call("M5 감지기 → 근무일 신호: 메시지 · .jsonl (꺼짐 줄 빼고) · rate_limit 만 · 재개 알림만", kinds == ["prompt", "jsonl", "", "rate_limit", "", "resume", "", ""], str(kinds))
	var tmp := OS.get_environment("TEMP").path_join("skyoffice_m5_%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(tmp):
		_rm_tree(tmp)
	var w := AgentWatch.new()
	w.setup(tmp.path_join(".skyoffice"), "", 4)
	var got := []
	w.activity.connect(func(k: String, t: float) -> void: got.append([k, int(t)]))
	var now := floorf(Time.get_unix_time_from_system())
	_bell(w.inbox_dir(), _ev(now - 30, "UserPromptSubmit", "c1"), 1)
	_bell(w.inbox_dir(), _ev(now - 20, "StopFailure", "c1", {"error_kind": "rate_limit"}), 2)
	_bell(w.inbox_dir(), _ev(now - 10, "Notification", "c1", {"ntype": "quota_auto_resume_fired"}), 3)
	w.tick(now)
	check.call("M5 감지기: bell 파일 (error_kind · ntype) → activity 신호 3개, 시각 그대로", got == [["prompt", int(now - 30)], ["rate_limit", int(now - 20)], ["resume", int(now - 10)]], str(got))
	w.free()
	_rm_tree(tmp)

	# 하늘 = 창 진행률 (개발 인자)
	var c := _co(Company.empty(), [["prompt", T]])
	var hrs := [DayNight.game_hour(c, T + H, PackedStringArray()), DayNight.game_hour(c, T, PackedStringArray(["--window=0.5"])),
			DayNight.game_hour(c, T, PackedStringArray(["--window=off"])), DayNight.game_hour(c, T, PackedStringArray(["--hour=21"]))]
	check.call("M5 하늘: hour = 창 진행률 (1시간 = 10시 24분) · --window=0.5 = 14시 · --window=off = 밤 · --hour 유지", is_equal_approx(hrs[0], 10.4)
			and is_equal_approx(hrs[1], 14.0) and is_equal_approx(hrs[2], 22.0) and is_equal_approx(hrs[3], 21.0), str(hrs))
	var bi: Array = main.office.board_index()   # 보드 칸 자리 = 책상 자리 (뒷줄 = 윗줄, x 순서 같음)
	var desks: Array = main.office.layout.desks()
	var same_place := bi.size() == desks.size()
	for i in desks.size():
		for j in desks.size():
			var dx: float = desks[i].pos.x - desks[j].pos.x
			var cx: int = bi[i] % 6 - bi[j] % 6
			if signf(dx) != signf(cx) or (int(desks[i].row) == 0) != (bi[i] < 6):
				same_place = false
	check.call("M5 호출 보드: 칸 자리 = 책상 자리 (뒷줄 책상 = 윗줄 · 왼쪽 → 오른쪽 같음)", same_place, str(bi))
	var tb: Node3D = main.office.get_node_or_null("TimeBoard")
	var fpx: float = (main.office.find_child("FlagPole", false, false) as Node3D).global_position.x
	var sgx: float = (main.office.find_child("Sign", false, false) as Node3D).global_position.x
	var now_text: String = main.office.time_text
	var same: bool = now_text == main.day_night.hud_text()
	main.office.set_time_text("18:88")   # 1 = 2칸 · 8 = 7칸 → 2 + 7 + 7 + 7 = 23
	var lit18: int = main.office.clock_lit()
	main.office.set_time_text("10:47")   # 2 + 6 + 4 + 3 = 15
	var lit10: int = main.office.clock_lit()
	main.office.set_time_text(now_text)
	check.call("M5 전자시계: 정가운데 · 간판 (왼쪽) 과 깃대 (오른쪽) 사이 · HUD 시계와 같은 시각 · LED 7칸 숫자 (18:88 = 23칸, 10:47 = 15칸)", tb != null
			and is_zero_approx(tb.position.x) and sgx < tb.global_position.x and tb.global_position.x < fpx and same and lit18 == 23 and lit10 == 15, "%s %d %d" % [now_text, lit18, lit10])


## 시험 ③: 1.0 저장 (견본) → 암호화 저장 · 읽기 → 가짜 v2 형식 이전 (연쇄 v3 까지)
func _m5_save(check: Callable) -> void:
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "saves/save_v1.json"))
	sample.erase("_note")
	var tp := "user://scenario_v1.dat"
	var f := FileAccess.open_encrypted_with_pass(tp, FileAccess.WRITE, Game.SAVE_KEY)
	f.store_string(JSON.stringify(sample))
	f.close()
	var v1 = Game.read_save(tp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tp))
	var to_v2 := func(d: Dictionary) -> Dictionary:   # 가짜 v2: 통계 → 기록 · 근무일 이름 바꿈
		d["records"] = d.get("stats", {})
		d.erase("stats")
		d.company["days"] = d.company.get("earned_days", 0)
		d.company.erase("earned_days")
		return d
	var to_v3 := func(d: Dictionary) -> Dictionary:   # 가짜 v3: fps → frame_rate
		d.settings["frame_rate"] = d.settings.get("fps", 30)
		d.settings.erase("fps")
		return d
	var m2: Dictionary = Game.migrate(v1, {1: to_v2}, 2)
	check.call("M5 시험 ③: 1.0 저장 (버전 1 견본) → 가짜 v2 형식 이전 성공 (값 그대로 · 원본 안 바뀜)", typeof(v1) == TYPE_DICTIONARY and int(m2.version) == 2
			and int(m2.records.scenario_turns) == 12 and int(m2.company.days) == 7 and not m2.has("stats") and int(m2.settings.window_mode) == 2
			and v1.has("stats") and int(v1.version) == 1)
	var m3: Dictionary = Game.migrate(v1, {1: to_v2, 2: to_v3}, 3)
	var gap: Dictionary = Game.migrate(v1, {2: to_v3}, 3)
	check.call("M5 저장 연쇄 이전: 1 → 2 → 3 한 단계씩 · 이전 함수가 빠지면 거기서 멈춤", int(m3.version) == 3 and int(m3.settings.frame_rate) == 30
			and int(m3.company.days) == 7 and not m3.settings.has("fps") and int(gap.version) == 1)
	var keep := Game._snapshot()
	Game._apply_data(v1)
	var applied := [Game.company.earned_days, Game.company.shown_stage, Game.settings.show_project]
	var newer: Dictionary = sample.duplicate(true)
	newer.version = 99
	Game._apply_data(newer)
	var newer_ok: bool = Game.company.earned_days == 7
	Game._apply_data(keep)
	check.call("M5 저장: 지금 형식 (이전 없음) 불러오기 = 근무일 · 단계 · 설정 그대로 · 더 새 버전도 아는 키는 읽음",
			applied == [7, 2, true] and newer_ok and Game.migrations().has(1) and Game.SAVE_VERSION == 2 and Game._snapshot().has("company"), str(applied))


# ------------------------------------------------------------------ M5 2세션째: 6단계 (stages.json) · 단계 상승 · 하루 리듬 · 짐 상자
func _m5_show(check: Callable) -> void:
	var sd: Dictionary = Company.stage_data()
	var groups: Array = sd.stages.map(func(s): return s.group)
	check.call("M5 단계 데이터: stages.json 6단계 (창업 3 · 스타트업 3) · 문턱 = v2.8 ×2 · company.gd 가 여기서 읽음",
			Company.stage_days() == [0, 2, 6, 10, 14, 20] and Company.thresholds == Company.stage_days()
			and groups == ["창업", "창업", "창업", "스타트업", "스타트업", "스타트업"] and Company.stage_for(9) == 2 and Company.stage_for(20) == 5,
			str(Company.thresholds))
	var all := ["bookshelf", "whiteboard", "desk_real", "chair_new", "sign_new", "server_rack", "telescope", "personal_shelf"]
	check.call("M5 단계 가구: 첫 출근 = 새로 생긴 것 없음 · 첫 사용자 = 8가지 모두 · 재질 교체 2가지 (박스 책상 · 낡은 의자)",
			Company.unlocked(0).is_empty() and all.all(func(k): return k in Company.unlocked(5)) and Company.unlocked(2) == ["bookshelf", "whiteboard"]
			and sd.looks.keys() == ["desk_real", "chair_new"])
	check.call("M5 단계 팝업 글: '창업 ② 첫 의뢰' + 생긴 것 · 스타트업은 ①부터", CompanyShow.popup_text(1) == "창업 ② 첫 의뢰\n책장이 들어왔어요"
			and CompanyShow.popup_text(3).begins_with("스타트업 ① 첫 투자"), CompanyShow.popup_text(1).replace("\n", " / "))
	check.call("M5 하루 일정 (순수): 0% 아침 조회 · 33% 점심 · 창 밖 퇴근 · 하루 한 번씩 · 늦게 켜면 조회 건너뜀",
			CompanyShow.due(0.0, {}) == "assembly" and CompanyShow.due(0.05, {"assembly": true}) == "" and CompanyShow.due(0.2, {}) == ""
			and CompanyShow.due(0.34, {"assembly": true}) == "lunch" and CompanyShow.due(0.6, {}) == "" and CompanyShow.due(-1.0, {}) == "end"
			and CompanyShow.due(-1.0, {"end": true}) == "")

	var office: Node3D = main.office
	office.set_process(false)   # 무작위 쉬는 행동이 시험을 흔들지 않게
	var run := func(i: int) -> void:   # 걷기 tween 을 끝까지
		for k in 8:
			var tw: Tween = office.staff[i].tween
			if tw == null or not tw.is_valid():
				break
			tw.custom_step(5.0)
	var vis := func(n: String) -> bool: return (office.get_node(n) as Node3D).visible
	var sign: Node3D = office.get_node("Sign")
	var box_mat := func() -> bool:   # 0번 책상 상판이 골판지 색인지
		for e in office._look_mats:
			if e.key == "desk_real" and office.get_node("Desk_0").is_ancestor_of(e.mi):
				return (e.mi as MeshInstance3D).get_surface_override_material(int(e.surface)) != null
		return false
	var start_stage: int = office.stage
	office.apply_stage(0)
	var s0 := [vis.call("Bookshelf"), vis.call("Whiteboard"), vis.call("Telescope"), vis.call("Rack"), vis.call("ServerShelf"),
			(sign.find_child("SignHand", true, false) as Node3D).visible, (sign.find_child("SignNew", true, false) as Node3D).visible,
			(office.get_node("Desk_0").find_child("PersonalShelf", true, false) as Node3D).visible, box_mat.call()]
	office.apply_stage(3)
	var s3 := [(sign.find_child("SignNew", true, false) as Node3D).visible, box_mat.call(), vis.call("Whiteboard"), vis.call("ServerShelf")]
	check.call("M5 단계 가구 적용: 0 = 손글씨 간판 · 서버 선반 · 박스 책상 (책장 · 화이트보드 · 망원경 · 랙 · 개인 칸 없음) → 3 = 남색 간판 · 진짜 책상",
			s0 == [false, false, false, false, true, true, false, false, true] and s3 == [true, false, true, true], "%s %s 재질 %d" % [s0, s3, office._look_mats.size()])
	office.apply_stage(1)
	var at1: String = office.gather_spot().at
	var pts1: Array = office.gather_points(4)
	office.apply_stage(2)
	var at2: String = office.gather_spot().at
	var pts2: Array = office.gather_points(4)
	var b: Rect2 = main.layout.building_rect()
	var from: Vector2 = main.layout.slot("rest_spots")
	var reach := (pts1 + pts2).all(func(p: Vector2) -> bool: return b.has_point(p) and not main.island.find_path(main.layout.m(from), main.layout.m(p)).is_empty())
	check.call("M5 모임 자리: 화이트보드 전 (근무일 0~5) = 게시판 앞 · 뒤 = 화이트보드 앞 · 4명 자리 모두 건물 안 · 걸어갈 수 있음",
			at1 == "notice_board" and at2 == "whiteboard" and reach, "%s %s %s" % [at1, at2, pts1])

	# 단계 상승 연출: 쉬는 직원 2명 모임 → 박수 + 팝업 → 화이트보드 '뿅' · 일하는 직원은 그대로
	for j in office.desk_count:
		office.set_state(j, "off")
	office.apply_stage(1)
	var sh: Node = CompanyShow.new()
	sh.name = "CompanyShowTest"
	add_child(sh)
	sh.setup(office, null)
	sh.set_process(false)
	sh.k = 0.1
	office.set_state(0, "rest")
	office.set_state(1, "done")
	office.set_state(2, "work")
	office.set_state(3, "turn")
	sh.stage_target = 2
	var defer: bool = not sh.stage_ready()   # 내 차례가 있으면 미룸
	office.set_state(3, "off")
	var ready: bool = sh.stage_ready()
	sh.stage_up()
	run.call(0)
	run.call(1)
	var met: int = office.gathered()
	await get_tree().create_timer(0.35).timeout
	var clap: bool = (office.staff[0].anim as AnimationPlayer).current_animation == "Clap" and (office.staff[1].anim as AnimationPlayer).current_animation == "Clap"
	var pop: bool = office.popup.visible and office.popup.text.begins_with("창업 ③") and not _is_yellow(office.popup.outline_modulate) and not _is_yellow(office.popup.modulate)
	var worker: bool = office.staff[2].state == "work" and str(office.staff[2].get("act", "")) != "gather"
	await get_tree().create_timer(0.4).timeout
	check.call("M5 단계 상승: 내 차례면 미룸 · 쉬는 직원만 게시판 앞 모임 → 박수 + 팝업 (노랑 없음) → 화이트보드 생김 → 흩어짐",
			defer and ready and met == 2 and clap and pop and worker and office.stage == 2 and vis.call("Whiteboard") and not sh.busy
			and office.gathered() == 0 and sh.history == ["stage:2"], "%s %s %d %s %s %s %d" % [defer, ready, met, clap, pop, worker, office.stage])
	office.staff[0].act = ""
	sh.stage_target = 3
	office.set_state(0, "off")
	office.set_state(1, "off")
	var quiet: bool = sh.stage_ready()   # 일하는 직원만 있고 쉬는 직원 없음 → 미룸
	office.set_state(2, "off")
	sh.stage_up()   # 아무도 없음 → 가구 · 팝업만 (대단계: 간판 교체)
	check.call("M5 단계 상승: 모두 일하는 중이면 미룸 · 아무도 없으면 가구만 · 대단계 (스타트업 ①) = 남색 간판으로 교체",
			not quiet and office.stage == 3 and (sign.find_child("SignNew", true, false) as Node3D).visible
			and not (sign.find_child("SignHand", true, false) as Node3D).visible and not box_mat.call())

	# 아침 조회 · 점심 · 퇴근 (일찍 퇴근)
	office.set_state(0, "rest")
	office.set_state(1, "rest")
	office.set_state(2, "work")
	sh.play("assembly")
	run.call(0)
	run.call(1)
	var as_met: int = office.gathered()
	await get_tree().create_timer(0.55).timeout
	check.call("M5 아침 조회: 쉬는 직원만 화이트보드 앞에 모였다 → 꾸벅 → 흩어짐", as_met == 2 and office.gathered() == 0 and not sh.busy
			and office.staff[2].state == "work", str(as_met))
	sh.play("lunch")
	run.call(0)
	run.call(1)
	await get_tree().create_timer(0.3).timeout
	var seats: Array = main.layout.slots("meeting_seats")
	var at_seat := func(i: int) -> bool:
		var p: Vector3 = (office.staff[i].node as Node3D).position
		return seats.any(func(s): return main.layout.m3(s.pos).distance_to(p) < 0.05)
	check.call("M5 점심: 쉬는 직원이 회의 탁자 의자에 앉아 쉼", office.staff[0].act == "lunch" and at_seat.call(0) and at_seat.call(1)
			and (office.staff[0].anim as AnimationPlayer).current_animation == "SitRest")
	sh.play("early")
	var leaving: bool = office.staff[0].leaving and office.staff[1].leaving and office.staff[0].get("bag") != null
	run.call(0)
	run.call(1)
	check.call("M5 일찍 퇴근 (rate_limit): 쉬는 직원 가방 메고 통근버스 → 안 보임 · 일하는 직원은 남음 (야근) · 화이트보드 '오늘 업무 끝'",
			leaving and not (office.staff[0].node as Node3D).visible and not (office.staff[1].node as Node3D).visible
			and (office.staff[2].node as Node3D).visible and office.early_note() == office.board_note and office.board_note.text == "오늘 업무 끝"
			and not _is_yellow(office.board_note.modulate) and not (office.get_node("Whiteboard").find_child("Doodle", true, false) as Node3D).visible and office.bus_state in ["coming", "docked"])
	office.set_state(2, "rest", true)   # 퇴근한 뒤 쉬게 된 직원도 바로 퇴근
	run.call(2)
	var after: bool = not (office.staff[2].node as Node3D).visible
	sh.on_day_started()
	var back: bool = (office.staff[0].node as Node3D).visible and office.staff[0].tween != null and office.early_note() == null
	run.call(0)
	check.call("M5 새 하루: 퇴근 뒤 쉬게 된 직원도 퇴근 · 새 하루 = 버스에서 내려 출근 · '오늘 업무 끝' 치움 · 일정 다시",
			after and back and not office.off_duty and sh.done.is_empty() and float(sh._wait_until) > Time.get_unix_time_from_system())

	# 짐 상자: 입사 = 상자 들고 출근 → 책상에 풀기 · 송별 = 상자 들고 버스
	for j in office.desk_count:
		office.set_state(j, "off")
	var anims: AnimationPlayer = office.staff[0].anim
	var has_anims: bool = ["Clap", "HoldBox", "WalkBox"].all(func(a): return anims.has_animation(a))
	var rt: Node = OfficeRoutine.new()
	rt.name = "RoutineBoxTest"
	rt.office = office
	var reg := {"staff": [{"id": 10, "desk": 0, "leave": false}]}
	rt.staff_moves(reg)   # 켜고 첫 확인 = 기록만
	var first: bool = not office.staff[0].get("box_in", false)
	rt._started = true
	reg.staff.append({"id": 11, "desk": 1, "leave": false})
	rt.staff_moves(reg)
	var hired: bool = office.staff[1].get("box_in", false) and not office.staff[0].get("box_in", false)
	office.set_state(1, "work", true)
	var carry: bool = office.staff[1].held == "box" and office.staff[1].tween != null
	run.call(1)
	var on_desk: bool = office.get_node_or_null("DeskBox") != null and office.staff[1].held == ""
	await get_tree().create_timer(2.7).timeout
	check.call("M5 짐 상자 (입사): 새 직원 = 상자 들고 출근 (WalkBox) → 책상 위 상자 → 2.5초 뒤 풀면 개인 소품", has_anims and first and hired and carry
			and on_desk and office.get_node_or_null("DeskBox") == null and not office.staff[1].get("box_in", false), "%s %s %s %s %s" % [has_anims, first, hired, carry, on_desk])
	reg.staff[0].leave = true
	reg.staff[0].desk = -1
	rt.staff_moves(reg)   # 휴직 = 송별
	var appear: bool = (office.staff[0].node as Node3D).visible
	(office.staff[0].tween as Tween).custom_step(1.3)
	var fw: bool = office.staff[0].held == "box" and office.staff[0].leaving
	run.call(0)
	var items_gone: bool = not (office.get_node("Desk_0").find_child("Item0", true, false) as Node3D).visible \
			and not (office.get_node("Desk_0").find_child("Item1", true, false) as Node3D).visible
	check.call("M5 짐 상자 (송별): 휴직한 직원이 자리에 나타나 소품을 상자에 담고 → 들고 정류장 → 사라짐 · 책상은 빈 채로",
			appear and fw and not (office.staff[0].node as Node3D).visible and items_gone and office.staff[0].held == "", "%s %s %s" % [appear, fw, items_gone])
	rt.free()
	sh.queue_free()
	for j in office.desk_count:
		office.set_state(j, "off")
	office.apply_stage(start_stage)
	office.set_process(true)


# ------------------------------------------------------------------ M5 3세션째: 회사 옷 (창업 화면 · 해시 직원 · 명패 · 입사식 · 결재함 · 돌아오면 요약 · 저장 v2)
func _btn(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text):
			return b
	return null


func _m5_firm(check: Callable) -> void:
	var office: Node3D = main.office
	var keep_firm: Dictionary = Game.firm.duplicate(true)
	# 해시 직원 (순수)
	var reg := StaffRegistry.empty()
	for pj in ["p1", "p2", "p3", "p4", "p5", "p6"]:
		reg = StaffRegistry.touch(reg, "claude", pj, 1000.0, 1000.0)
	reg = StaffRegistry.sync(reg, 6, 1000.0)
	var a := StaffHash.staff_looks(reg, "salt-a", {})
	var a2 := StaffHash.staff_looks(reg, "salt-a", {})
	var b := StaffHash.staff_looks(reg, "salt-b", {})
	var names_a: Array = a.values().map(func(x): return x.name)
	var uniq := {}
	for n in names_a:
		uniq[n] = true
	for t in a.values():
		uniq["팀:" + str(t.team)] = true
	var differ := 0
	for id in a:
		if a[id].look != b[id].look:
			differ += 1
	check.call("M5 해시 직원: 같은 솔트 · 프로젝트 = 늘 같은 직원 · 솔트가 다르면 다른 얼굴 · 이름 · 자동 팀 안 겹침 · 자동 팀 '…팀'",
			a == a2 and differ >= 5 and uniq.size() == 12 and a.values().all(func(x): return str(x.team).ends_with("팀") and int(x.look.person) in [0, 1, 2, 3]),
			"%d명 다름 · %s" % [differ, str(names_a)])
	var pl := {"0": {"name": "봄이", "team": "기획팀"}, "1": {"name": "", "team": ""}}
	var c := StaffHash.staff_looks(reg, "salt-a", pl)
	check.call("M5 명패: 바꾼 이름 · 팀이 이김 · 빈 칸 = 자동 · 자동 이름은 바꾼 이름을 피함",
			c[0].name == "봄이" and c[0].team == "기획팀" and c[1].name == a[1].name and c[1].team == a[1].team
			and not ("봄이" in c.values().slice(1).map(func(x): return x.name)))
	var dig := StaffHash.digest("s", "claude", "p1").hex_encode()
	check.call("M5 해시 직원: 해시 입력 = 솔트 · 에이전트 · 프로젝트 해시만 (결과에 프로젝트 글자 없음)", dig.length() == 64 and dig.find("p1") < 0)
	# firm (순수): 이름 · 결재함 · 입사식 · 돌아오면 요약
	var f := Firm.empty()
	check.call("M5 회사 이름: 비우면 기본 '하늘 오피스' · 8글자까지 · 줄바꿈 · 앞뒤 공백 정리",
			Firm.sign_name(f) == "하늘 오피스" and Firm.clean_name("  가나다라마바사아자차 ", 8) == "가나다라마바사아" and Firm.clean_name("a\nb", 8) == "a b")
	var D1 := 5000.0
	var D2 := 30000.0
	f = Firm.count(f, "staff", 0, D1)
	f = Firm.count(f, "done", 0, D1)
	f = Firm.count(f, "done", 1, D1)
	f = Firm.count(f, "turn", 1, D1)
	var closed := Firm.close_day(f, 4, {0: "서연", 1: "민준"}, D2)
	var twice := Firm.close_day(closed, 5, {}, D2)
	var empty_day := Firm.close_day(Firm.close_day(closed, 5, {}, D2 + 1.0), 6, {}, D2 + 2.0)
	var sheet: Dictionary = closed.ledger[0] if not closed.ledger.is_empty() else {}
	check.call("M5 결재함: 하루 마감 = 한 장 (출근부 n일째 · 출근 이름 · 완료 · 결재, 숫자 + 이름만) · 같은 하루 두 번 마감 안 함 · 빈 하루는 안 꽂음",
			closed.ledger.size() == 1 and int(sheet.day) == 4 and sheet.staff == ["서연", "민준"] and int(sheet.done) == 2 and int(sheet.turn) == 1
			and float(closed.today.day) == D2 and twice.ledger.size() == 1 and empty_day.ledger.size() == 1 and sheet.keys().size() == 5, str(sheet))
	var many := Firm.empty()
	for k in 10:
		many = Firm.count(many, "done", 0, 100.0 * (k + 1), {0: "서연"})
	check.call("M5 결재함 자동 정리: 최근 7장만 · 하루 마감을 놓치면 다음 셈이 마감 (번호 = 이전 장 + 1)",
			many.ledger.size() == Firm.LEDGER_MAX and int(many.ledger[-1].day) == 9 and many.ledger[-1].staff == ["서연"], str(many.ledger.map(func(x): return x.day)))
	var need := Firm.need_ceremony(Firm.empty(), reg)
	var after := Firm.need_ceremony(Firm.set_plate(Firm.empty(), 0, "", ""), reg)
	check.call("M5 입사식: 명패 없는 책상 직원만 (입사 순) · 자동으로 넘겨도 다시 안 물음", need == [0, 1, 2, 3, 4, 5] and after == [1, 2, 3, 4, 5])
	check.call("M5 돌아오면 요약 글: '비운 동안: 완료 2 · 기다림 1' · 없는 건 빼고 · 0건 = 안 띄움",
			Firm.away_text(2, 1) == "비운 동안: 완료 2 · 기다림 1" and Firm.away_text(3, 0) == "비운 동안: 완료 3" and Firm.away_text(0, 0) == "")
	# 저장 v2 (이전 함수 · 견본)
	var v1: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "saves/save_v1.json"))
	v1.erase("_note")
	var m := Game.migrate(v1)
	check.call("M5 저장 v2: 1.0 저장 → 실제 이전 함수 (1 → 2) = firm 칸 · 솔트 새로 1번 (32자) · 창업 화면 아직 · 다른 값 그대로",
			int(m.version) == 2 and str(m.firm.salt).length() == 32 and not bool(m.firm.founded) and str(m.firm.name) == ""
			and int(m.company.earned_days) == 7 and Game.migrate(v1).firm.salt != m.firm.salt and not v1.has("firm"))
	var v2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "saves/save_v2.json"))
	v2.erase("_note")
	var keep := Game._snapshot()
	Game._apply_data(v2)
	var got := [Game.firm.name, Game.firm.founded, Game.firm.salt, Game.firm.plates.get("0", {}).get("team", ""), Game.firm.today.done, Game.firm.ledger.size(), Game.company.earned_days]
	Game._apply_data(keep)
	check.call("M5 저장 v2 견본 (save_v2.json) 불러오기: 회사 이름 · 솔트 · 명패 · 오늘 · 결재함 그대로 · 폴더 이름 칸 없음",
			got == ["구름상사", true, "0123456789abcdef0123456789abcdef", "기획팀", 3, 1, 8] and not JSON.stringify(v2.firm).contains("proj"), str(got))
	# 화면: 간판 · 해시 겉모습
	office.set_sign_text("구름상사")
	var short_ok: bool = office.sign_text.text == "구름상사" and is_equal_approx(office.sign_text.pixel_size, 0.16 / 64.0)
	office.set_sign_text("하늘구름바람상사")
	var long_ok: bool = office.sign_text.pixel_size < 0.16 / 64.0 * 0.8
	office.set_sign_text(Firm.sign_name(Game.firm))
	check.call("M5 간판 글자 = 회사 이름 (6-2) · 7글자 넘으면 판 안에 들어가게 줄임", short_ok and long_ok)
	var s3: Dictionary = office.staff[3]
	office.set_look(3, {"shirt": 4, "hair": 1, "acc": 2, "person": 3})
	var acc_vis: Array = Office.ACCESSORIES.filter(func(n): return n != "" and (s3.model.find_child(n, true, false) as Node3D).visible)
	var chair_col: Color = ((office.desk_parts[3].chair_back as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	check.call("M5 해시 겉모습: 셔츠 색 · 장신구 · 의자 등받이 · 성격 (버릇) 이 해시 번호대로",
			s3.shirt == Office.SHIRTS[4] and acc_vis == [Office.ACCESSORIES[2]] and chair_col.is_equal_approx(Color(Office.SHIRTS[4]))
			and office.person_of(s3) == str(office.idle_cfg.personalities[3]), "%s %s" % [s3.get("shirt", ""), str(acc_vis)])
	# 일과 → 셈 (결재함 · 돌아오면 요약)
	var rt: Node = OfficeRoutine.new()
	rt.setup(office, null, null, main.camera)
	add_child(rt)
	var got_kinds: Array = []
	rt.counted.connect(func(kind: String, id: int) -> void: got_kinds.append([kind, id]))
	var T := 300.0 * 86400.0
	var reg2 := StaffRegistry.sync(StaffRegistry.touch(StaffRegistry.empty(), "claude", "p1", T, T), office.desk_count, T)
	var lines: Array = [_ev(T, "SessionStart", "a"), _ev(T + 1, "UserPromptSubmit", "a")]
	rt.apply(AgentState.replay(lines), reg2, T + 2)
	lines.append(_ev(T + 10, "Notification", "a", {"ntype": "permission_prompt"}))
	rt.apply(AgentState.replay(lines), reg2, T + 11)
	lines.append(_ev(T + 20, "UserPromptSubmit", "a"))
	rt.apply(AgentState.replay(lines), reg2, T + 21)
	lines.append(_ev(T + 30, "Stop", "a"))
	rt.apply(AgentState.replay(lines), reg2, T + 31)
	var lk0: Dictionary = rt.looks.get(0, {})
	check.call("M5 일과 셈: 출근 · 내 차례 · 일 끝을 한 번씩 알림 (직원 id) · 명패 = 해시 이름 · 팀",
			got_kinds == [["staff", 0], ["turn", 0], ["done", 0]] and office.staff[0].name == str(lk0.get("name", "?"))
			and office.staff[0].team == str(lk0.get("team", "?")), str(got_kinds))
	# 화면: 창업 화면 · 입사식 · 돌아오면 요약 (firm_ui)
	Game.firm = Firm.empty()
	Game.firm.salt = keep_firm.salt
	var fu: Node = FirmUI.new()
	add_child(fu)
	fu.setup(main.ui, office, rt, null)
	fu.show_found()
	var card_ok: bool = fu.found_card != null and fu.found_card.is_in_group("ui_bounds") and _btn(fu.found_card, "건너뛰기") != null
	_btn(fu.found_card, "건너뛰기").pressed.emit()
	check.call("M5 창업 화면: 첫 실행 카드 (이름 입력 · 창업하기 · 건너뛰기) · 건너뛰면 기본 이름 간판 · 창업 표시",
			card_ok and fu.found_card == null and bool(Game.firm.founded) and office.sign_text.text == "하늘 오피스")
	fu._process(1.0)
	var hire_ok: bool = fu.hire_card != null and fu.hire_id == 0 and _btn(fu.hire_card, "자동") != null
	if hire_ok:
		_btn(fu.hire_card, "자동").pressed.emit()
	check.call("M5 입사식: 창업 뒤 명패 없는 직원 카드 (팀 이름 쓰기 · 자동) · 자동 = 빈 팀 칸 (해시 팀 이름) · 다시 안 뜸",
			hire_ok and fu.hire_card == null and Game.firm.plates.has("0") and str(Game.firm.plates["0"].team) == "" and Firm.need_ceremony(Game.firm, reg2).is_empty())
	fu.on_away_started()
	fu.on_counted("done", 0)
	fu.on_counted("done", 0)
	fu.on_counted("turn", 0)
	fu.on_away_ended(12)
	fu._process(1.0)
	var away_ok: bool = fu.shown_away == ["비운 동안: 완료 2 · 기다림 1"] and fu.away_card != null
	fu.on_away_started()
	fu.on_away_ended(3)
	fu._process(1.0)
	check.call("M5 돌아오면 요약: 비운 동안 셈 → 카드 1장 · 아무 일 없으면 안 띄움 · 결재함 오늘 칸에도 셈",
			away_ok and fu.shown_away.size() == 1 and int(Game.firm.today.done) == 2 and int(Game.firm.today.turn) == 1, str(fu.shown_away))
	var body := VBoxContainer.new()
	fu.tray_panel(body)
	var tray_txt := ""
	for l in body.find_children("*", "Label", true, false):
		tray_txt += (l as Label).text + " / "
	body.free()
	check.call("M5 결재함 패널: 오늘 장 (쓰는 중) = 출근 이름 · 완료 · 결재 (숫자 + 이름만)", tray_txt.contains("쓰는 중") and tray_txt.contains("완료 2 · 결재 1")
			and tray_txt.contains(str(lk0.get("name", "?"))), tray_txt)
	for i in 3:
		office.set_state(i, "turn15", true)
	await get_tree().process_frame
	var shown_tags: Array = range(3).filter(func(i): return (office.staff[i].tagbox as Node3D).visible)
	var bangs: Array = range(3).filter(func(i): return (office.staff[i].icon as Node3D).visible)
	office.set_hover(2, true)
	var hover_ok: bool = (office.staff[2].tagbox as Node3D).visible
	office.set_hover(2, false)
	check.call("M5 창구 줄 명패 (사용자 '창구에선 명패 빼자'): 줄에 선 직원은 '!' 만 · 명패 없음 · 마우스 올리면 보임",
			shown_tags.is_empty() and bangs.size() == 3 and hover_ok and not (office.staff[2].tagbox as Node3D).visible, "%s %s" % [shown_tags, bangs])
	fu._close(fu.away_card)
	fu.queue_free()
	rt.queue_free()
	for i in office.staff.size():
		office.set_state(i, "off")
	Game.firm = keep_firm
	office.set_sign_text(Firm.sign_name(Game.firm))
	await get_tree().process_frame


# ------------------------------------------------------------------ M5 4세션째: 플러그인 · 무결성 · 전화 · 연결 상태 · 폐업 정리
func _m5_phone(check: Callable) -> void:
	# 묶음 (게임 안 원본)
	var hj = JSON.parse_string(FileAccess.get_file_as_string(Phone.BUNDLE + "hooks.json"))
	var ev: Dictionary = hj.hooks if typeof(hj) == TYPE_DICTIONARY else {}
	var hooks_ok := ev.size() == 11 and not ev.has("PreToolUse") and not ev.has("PermissionRequest")
	for k in ev:
		var h: Dictionary = ev[k][0].hooks[0]
		hooks_ok = hooks_ok and h.command == "${CLAUDE_PLUGIN_ROOT}/bell.exe" and (h.args as Array).is_empty() and bool(h.async) == (k != "SessionEnd")
	var pj = JSON.parse_string(FileAccess.get_file_as_string(Phone.BUNDLE + "plugin.json"))
	check.call("M5 플러그인 묶음: 파일 4개 · 훅 11개 (PreToolUse · PermissionRequest 없음 · --record 없음 · SessionEnd 만 동기) · 버전 = PLUGIN_VER",
			hooks_ok and Phone.expected().values().all(func(x): return str(x).length() == 64) and str(pj.version) == Phone.PLUGIN_VER, str(ev.keys()))
	# 판단 (순수)
	var R := "C:/u/.skyoffice/plugin/0.1.0"
	var ok4 := {"a": "ok", "b": "ok"}
	var mine := {"market": "C:\\u\\.skyoffice\\plugin\\0.1.0\\", "enabled": true, "known": true}
	var now := 100000.0
	var none := Phone.judge({"a": "missing", "b": "missing"}, {"market": "", "enabled": false, "known": false}, R, {})
	var on := Phone.judge(ok4, mine, R, {"now": now, "hook_t": now - 30, "jsonl_t": now - 10})
	var diff := Phone.judge({"a": "diff", "b": "ok"}, mine, R, {"now": now})
	var miss := Phone.judge({"a": "missing", "b": "ok"}, mine, R, {"now": now})
	var other := Phone.judge(ok4, {"market": "C:/u/.skyoffice/plugin", "enabled": true, "known": true}, R, {"now": now})
	var off := Phone.judge(ok4, {"market": R, "enabled": false, "known": true}, R, {"now": now})
	var quiet := Phone.judge(ok4, mine, R, {"now": now, "hook_t": now - 2000, "jsonl_t": now - 60})
	var fresh := Phone.judge(ok4, mine, R, {"now": now, "hook_t": 0.0, "jsonl_t": now - 60, "since": now - 90})
	check.call("M5 전화 판단: 미개통 · 개통 (경로 대소문자 · 끝 \\ 무시) · 파일 다름/없음 · 다른 판 = 불통 + inbox 멈춤 · 꺼짐 · 신호 끊김 = 불통 (멈춤 아님) · 개통 2분 안은 기다림",
			none.state == "none" and on.state == "on" and diff.state == "broken" and diff.paused and miss.paused and other.state == "broken" and other.paused
			and off.state == "broken" and not off.paused and quiet.state == "broken" and not quiet.paused and fresh.state == "on",
			"%s %s %s %s" % [none.state, on.state, quiet.state, fresh.state])
	# 설치 폴더 · 무결성 (임시 폴더 — 사용자 .skyoffice · .claude 안 건드림)
	var tmp := OS.get_environment("TEMP").path_join("skyoffice_phone_%d" % OS.get_process_id())
	_rm_tree(tmp)
	var ch := tmp.path_join(".claude")
	DirAccess.make_dir_recursive_absolute(ch.path_join("plugins"))
	var w := AgentWatch.new()
	w.setup(tmp.path_join(".skyoffice"), "", 4)
	var ph := Phone.new()
	add_child(ph)
	var calls: Array = []
	ph.run_cmd = func(_exe: String, args: Array) -> Array:   # 가짜 Claude Code: 명령 기록 + 설정 파일 흉내
		calls.append(" ".join(args.slice(1, 3)))
		if args.slice(1, 3) == ["marketplace", "add"]:
			_write_json(ch.path_join("plugins/known_marketplaces.json"), {"skyoffice": {"installLocation": str(args[3])}})
		if args[1] == "install":
			_write_json(ch.path_join("settings.json"), {"enabledPlugins": {Phone.PLUGIN_ID: true}})
		if args[1] == "uninstall":
			_write_json(ch.path_join("settings.json"), {"enabledPlugins": {}})
		if args.slice(1, 3) == ["marketplace", "remove"]:
			_write_json(ch.path_join("plugins/known_marketplaces.json"), {})
		return [0, ""]
	ph.setup(tmp.path_join(".skyoffice"), ch, w)
	var st0: String = ph.status.state
	DirAccess.make_dir_recursive_absolute(tmp.path_join(".skyoffice/plugin/bell"))   # 예전 M0 시험판 자리
	_write_json(ch.path_join("plugins/known_marketplaces.json"), {"skyoffice": {"installLocation": tmp.path_join(".skyoffice/plugin")}})
	_write_json(ch.path_join("settings.json"), {"enabledPlugins": {Phone.PLUGIN_ID: true}})
	ph.refresh(true)
	var st_old: Dictionary = ph.status.duplicate()
	var paused_old: bool = w.paused
	ph.install()
	var r: Array = await ph.job_done
	check.call("M5 전화 개통: 원본 복사 → 예전 판 빼고 (uninstall · marketplace remove) → marketplace add · install (공식 명령만) · 예전 M0 폴더 지움 · 해시 같음 → 개통",
			st0 == "none" and st_old.state == "broken" and paused_old and bool(r[1]) and ph.status.state == "on" and not w.paused
			and calls == ["uninstall skyoffice-bell@skyoffice", "marketplace remove", "marketplace add", "install skyoffice-bell@skyoffice"]
			and not DirAccess.dir_exists_absolute(tmp.path_join(".skyoffice/plugin/bell")) and ph.status.files.values().all(func(x): return x == "ok"),
			"%s %s" % [calls, ph.status.state])
	var hp := ph.root().path_join("bell/hooks/hooks.json")
	var f := FileAccess.open(hp, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string(" ")
	f.close()
	ph.refresh()
	var tampered: Dictionary = ph.status.duplicate()
	var tamper_paused: bool = w.paused
	var st_test: Dictionary = ph.self_test()
	check.call("M5 무결성: 설치 폴더 파일이 1바이트라도 바뀌면 불통 + inbox 멈춤 · 바뀐 bell 은 연결 점검에서도 실행 안 함",
			tampered.state == "broken" and tamper_paused and tampered.files["bell/hooks/hooks.json"] == "diff" and not bool(st_test.ok), str(tampered.files))
	ph.copy_bundle()
	ph.refresh()
	var tw := Time.get_unix_time_from_system()
	for i in 12:
		var nm := "%019d-%d.json" % [int(tw * 1e7) + AgentWatch.TICKS_UNIX + i, 7]
		_write_json(w.inbox_dir().path_join(nm), {"v": 1, "t_start": int(tw * 1e7) + AgentWatch.TICKS_UNIX, "event": "Stop" if i == 11 else "PostToolUse", "sess": "s", "proj": "p"})
	w.paused = true
	w.tick(tw + 1)
	var held := DirAccess.get_files_at(w.inbox_dir()).size()
	w.paused = false
	w.tick(tw + 1)
	var rec: Array = ph.recent()
	check.call("M5 연결 상태: 멈춘 동안 inbox 그대로 · 풀리면 처리 → 마지막 신호 · 최근 신호 10개 (이벤트 이름 · 시각만, 최신 먼저) · 개통 다시 됨",
			ph.status.state == "on" and held == 12 and rec.size() == 10 and str(rec[0][0]) == "Stop" and (rec[0] as Array).size() == 2
			and absf(float(ph.signal_times().hook_t) - tw) < 1.0, "%d %s" % [held, str(rec.slice(0, 2))])
	# 연결 점검 = 진짜 bell (NativeAOT) 을 시험 신호로 1번 → 사용자 inbox 에 SelfTest 파일 1개가 생김 → 바로 지움
	var real_inbox := Phone.home().path_join(".skyoffice/inbox")
	DirAccess.make_dir_recursive_absolute(real_inbox)
	var t1: Dictionary = ph.self_test(real_inbox)
	if t1.has("file"):
		DirAccess.remove_absolute(real_inbox.path_join(str(t1.file)))
	check.call("M5 연결 점검: 해시가 맞을 때만 bell 실행 → 신호 파일 (SelfTest) 받음 · 100ms 안", bool(t1.ok) and int(t1.ms) < 100, str(t1))
	check.call("M5 명령 복사 글: claude plugin marketplace add <폴더> · install · uninstall",
			Phone.command_text(ph.install_steps({"known": false, "enabled": false})).contains("claude plugin marketplace add ")
			and Phone.command_text(ph.uninstall_steps()) == "claude plugin uninstall skyoffice-bell@skyoffice\nclaude plugin marketplace remove skyoffice")
	# 폐업 정리 (시험 실행 = 게임 저장 폴더 · 자동 실행 · 끄기는 건너뜀)
	var keep_salt: String = Game.firm.salt
	DirAccess.make_dir_recursive_absolute(ch.path_join("plugins/cache/skyoffice/skyoffice-bell/0.1.0"))   # uninstall 뒤에도 남는 캐시 (실제 시험)
	DirAccess.make_dir_recursive_absolute(ch.path_join("plugins/cache/other"))
	calls.clear()
	ph.close_business()
	var r2: Array = await ph.job_done
	var left: Array = ph.close_files(false)
	var side := Phone.claude_side(ch)
	check.call("M5 폐업 정리: 플러그인 제거 · 마켓 제거 (공식 명령) → .skyoffice 폴더 · 우리 플러그인 캐시만 지움 · 솔트 지움 · Claude 쪽 흔적 없음",
			bool(r2[1]) and calls == ["uninstall skyoffice-bell@skyoffice", "marketplace remove"] and left.is_empty()
			and not DirAccess.dir_exists_absolute(tmp.path_join(".skyoffice")) and Game.firm.salt == "" and not side.known and not side.enabled
			and not DirAccess.dir_exists_absolute(ch.path_join("plugins/cache/skyoffice")) and DirAccess.dir_exists_absolute(ch.path_join("plugins/cache/other")), str(calls))
	Game.firm.salt = keep_salt
	ph.queue_free()
	w.free()
	_rm_tree(tmp)
	# 전화기 모습 · 누르기
	var office: Node3D = main.office
	office.set_phone("on")
	var lit: bool = ((office.boss.plight as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled
	var rest: Transform3D = (office.boss.handset as Node3D).transform
	office.set_phone("broken")
	var down: bool = (office.boss.handset as Node3D).transform != rest and (office.boss.phone_x as Node3D).visible
	office.set_phone("none")
	var back: bool = (office.boss.handset as Node3D).transform == rest and not (office.boss.phone_x as Node3D).visible \
			and not ((office.boss.plight as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled
	check.call("M5 전화기 모습: 개통 = 불빛 · 불통 = 수화기 내려감 + X · 미개통 = 회색 (불빛 없음, 수화기 제자리)", lit and down and back)
	var cam := office.get_viewport().get_camera_3d()
	var pu: Node = main.phone_ui
	var hit: bool = pu.click(cam.unproject_position(office.phone_point()))
	var opened: bool = main.ui.panel_id == "phone"
	main.ui.close_panel()
	var miss_click: bool = pu.click(cam.unproject_position(office.phone_point()) + Vector2(200, 0))
	check.call("M5 전화기 누르기 → 연결 상태 패널 · 다른 곳은 그대로", hit and opened and not miss_click and main.ui.panel_id == "")



# ------------------------------------------------------------------ M5 5세션째: 잔잔 예산 (감독 · 조용히 · 하루 빨리 보기 · 게시판 큰 창 · 환경음)
func _m5_budget(check: Callable) -> void:
	var cfg: Dictionary = main.office.idle_cfg
	var ok := {"turn": false, "quiet": false, "big_now": 0, "last_big": -1.0e18, "now": 1000.0}
	var with := func(k: String, v) -> Dictionary:
		var d := ok.duplicate()
		d[k] = v
		return d
	check.call("M5 감독: 내 차례 · 조용히 = 큰 움직임 대신 서 있음 · 작은 행동은 그대로", Director.rest_act("coffee", ok, cfg) == "coffee"
			and Director.rest_act("sofa", with.call("turn", true), cfg) == "stand" and Director.rest_act("pier", with.call("quiet", true), cfg) == "stand"
			and Director.rest_act("stand", with.call("turn", true), cfg) == "stand")
	check.call("M5 감독: 동시 3명까지 (수다 = 2명 몫) · 같은 직원 10분 1번", Director.rest_act("coffee", with.call("big_now", 3), cfg) == "stand"
			and Director.rest_act("chat", with.call("big_now", 2), cfg) == "stand" and Director.rest_act("coffee", with.call("big_now", 2), cfg) == "coffee"
			and Director.rest_act("quirk", with.call("last_big", 500.0), cfg) == "stand" and Director.rest_act("quirk", with.call("last_big", 300.0), cfg) == "quirk"
			and int(cfg.big_gap_s) == 600)
	check.call("M5 감독 장면: 내 차례 = 조회 · 점심 건너뜀 · 단계 미룸 / 조용히 = 조회 · 점심 없음 · 단계는 가구 · 팝업만 / 출퇴근 늘",
			Director.scene("assembly", {"turn": true}) == "skip" and Director.scene("lunch", {"quiet": true}) == "skip"
			and Director.scene("stage", {"turn": true, "quiet": true}) == "wait" and Director.scene("stage", {"quiet": true}) == "lite"
			and Director.scene("lunch", {}) == "play" and Director.scene("end", {"turn": true, "quiet": true}) == "play"
			and not Director.work_quirk({"turn": true}) and not Director.work_quirk({"quiet": true}) and Director.work_quirk({}))
	# 실제 office: 내 차례 · 조용히 · 10분 → 스스로 고르는 쉬는 행동이 큰 움직임이 아님
	var office: Node3D = main.office
	office.set_process(false)
	for j in office.desk_count:
		office.set_state(j, "off")
	office.set_state(0, "turn15")
	office.set_state(1, "rest")
	var s1: Dictionary = office.staff[1]
	var picks := []
	for n in 20:
		s1.act_until = 0.0
		s1.tween = null
		office.life_tick(office._now())
		picks.append(str(s1.act))
	var in_turn: bool = picks.all(func(a): return not (a in Director.BIG_ACTS))
	office.set_state(0, "off")
	Game.settings.quiet = true
	picks.clear()
	for n in 20:
		s1.act_until = 0.0
		s1.tween = null
		office.life_tick(office._now())
		picks.append(str(s1.act))
	var in_quiet: bool = picks.all(func(a): return not (a in Director.BIG_ACTS))
	Game.settings.quiet = false
	s1.big_at = office._now() - 60.0
	picks.clear()
	for n in 20:
		s1.act_until = 0.0
		s1.tween = null
		office.life_tick(office._now())
		picks.append(str(s1.act))
	var in_gap: bool = picks.all(func(a): return not (a in Director.BIG_ACTS))
	s1.big_at = -1.0e18
	office.rest_act(1, "coffee")
	var stamped: bool = float(s1.get("big_at", -1.0e18)) > 0.0
	check.call("M5 감독 (실제 office): 창구에 누가 있으면 · 조용히 · 10분 안 = 큰 움직임 안 고름 · 큰 움직임 시작 시각 기록", in_turn and in_quiet and in_gap and stamped,
			"%s %s %s %s" % [in_turn, in_quiet, in_gap, stamped])
	for j in office.desk_count:
		office.set_state(j, "off")
	office.set_process(true)
	# 조용히 모드 스위치 (설정 > 화면)
	main.ui.open_panel("gear")
	main.ui._settings_tab = "screen"
	main.ui.refresh_panel()
	await get_tree().process_frame
	var qb := _btn(main.ui, "조용히")
	check.call("M5 조용히 모드: 기본 끔 · 설정 '화면' 에 스위치 1개", Game.settings.has("quiet") and qb != null)
	main.ui.close_panel()
	# 하루 빨리 보기: 녹화 재생 → 장면 로그 · 상한 · 같은 결과 (난수 고정)
	var sc := FastDay.load_json(FastDay.SCENES)
	var lines := FastDay.read_lines(FastDay.DEFAULT)
	var r1: Dictionary = FastDay.run(lines, sc, cfg)
	var r2: Dictionary = FastDay.run(lines, sc, cfg)
	var calls: bool = r1.log.any(func(x): return str(x[2]) == str(sc.scenes.turn15))
	check.call("M5 하루 빨리 보기: 녹화 재생 → 장면 로그 (창구 부르기 포함) · 상한 통과 · 두 번 돌려도 같음", r1.fails.is_empty() and calls
			and JSON.stringify(r1.summary) == JSON.stringify(r2.summary) and int(r1.summary.big_in_turn) == 0 and int(r1.summary.big_gap_bad) == 0
			and int(r1.summary.big_peak) <= int(sc.limits.big_max), JSON.stringify(r1.summary))
	var rq: Dictionary = FastDay.run(lines, sc, cfg, {"quiet": true})
	var strict := sc.duplicate(true)
	strict.limits.big_max = 0
	var rs: Dictionary = FastDay.run(lines, strict, cfg)
	check.call("M5 하루 빨리 보기: 조용히 = 큰 움직임 · 버릇 0 (부르기는 그대로) · 상한을 넘으면 실패로 잡음", int(rq.summary.counts.get("big", 0)) == 0
			and int(rq.summary.counts.get("quirk", 0)) == 0 and int(rq.summary.counts.get("turn15", 0)) == int(r1.summary.counts.get("turn15", 0))
			and not rs.fails.is_empty() and FastDay.run([], sc, cfg).fails.size() == 1)
	check.call("M5 하루 빨리 보기: 끝 보고 기준 시간 후보별 긴 보고 수 (60 ≥ 180 ≥ 300)", (r1.summary.long_by_base as Dictionary).size() == 3
			and int(r1.summary.long_by_base["60"]) >= int(r1.summary.long_by_base["180"]) and int(r1.summary.long_by_base["180"]) >= int(r1.summary.long_by_base["300"]))
	# 게시판 큰 창
	var reg := {"staff": [{"id": 0, "leave": false}, {"id": 1, "leave": true}, {"id": 2, "leave": false}]}
	var bl: Array = BoardUI.lines({"earned_days": 3, "shown_stage": 1}, reg, {1: "하늘"})
	var top: Array = BoardUI.lines({"earned_days": 30, "shown_stage": Company.stage_data().stages.size() - 1}, {"staff": []}, {})
	check.call("M5 게시판 2열 타일 6칸: 근무일 | 직원 · 지금 | 다음 (단계 2줄) · 남은 날 | 휴직 이름", bl.size() == 6 and bl[0] == ["근무일", "3일"]
			and bl[1] == ["직원", "2명"] and bl[2][1] == "창업 ②\n첫 의뢰" and bl[3][1] == "창업 ③\n첫 결과물" and bl[4] == ["남은 날", "3일"] and bl[5] == ["휴직", "하늘"]
			and top[3][1] == "마지막 단계" and top[4][1] == "-" and top[5][1] == "없음", str(bl))
	main.ui.open_panel("board")
	await get_tree().process_frame
	check.call("M5 게시판 창: 2열 칸 6개", main.ui.find_children("*", "GridContainer", true, false).any(func(g): return (g as GridContainer).columns == 2 and g.get_child_count() == 6))
	main.ui.close_panel()
	check.call("M5 게시판 성장 막대: 지금 문턱 → 다음 문턱 사이 (2 → 6 에서 3일 = 0.25) · 마지막 = 가득", is_equal_approx(BoardUI.fill({"earned_days": 3, "shown_stage": 1}), 0.25)
			and BoardUI.fill({"earned_days": 99, "shown_stage": Company.stage_data().stages.size() - 1}) == 1.0)
	var cam := office.get_viewport().get_camera_3d()
	var bp: Vector2 = cam.unproject_position(main.board_ui.board_point())
	var bhit: bool = main.window_ctl.click_handler.call(bp)
	var bopen: bool = main.ui.panel_id == "board"
	await get_tree().process_frame
	main.ui.close_panel()
	var phone_still: bool = main.window_ctl.click_handler.call(cam.unproject_position(office.phone_point())) and main.ui.panel_id == "phone"
	main.ui.close_panel()
	check.call("M5 게시판 누르기 → 큰 창 '게시판' · 전화기 누르기는 그대로 연결 상태", bhit and bopen and phone_still, "%s %s %s" % [bhit, bopen, phone_still])
	# 환경음 = 합성한 사무실 소리 (오버랜드 농장 소리 아님)
	var amb := load("res://assets/sounds/ambience.wav") as AudioStreamWAV
	var nig := load("res://assets/sounds/night.wav") as AudioStreamWAV
	check.call("M5 환경음: 합성 파일 (40초 · 30초, 반복) · 만드는 도구 있음", amb != null and nig != null and is_equal_approx(amb.get_length(), 40.0)
			and amb.loop_mode != AudioStreamWAV.LOOP_DISABLED and FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join("../tools/build_ambience.py")))


func _write_json(path: String, d: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
