extends Node3D
## 하늘 오피스 M2: zones.json 배치대로 회색 상자 사무실 + 상태 표현 자리
## PLAN v2.4: 하늘에 뜬 사무실 하나 (얇은 바위 받침 + 크리스탈) + 왼쪽 벽에 붙은 승강장 부두. 섬 · 테두리 길 없음
## 상태 판단 (reduce · decide) 은 M3 agent_state.gd — 여기는 '상태를 받으면 어디에 어떻게 보이나' 만
## 개발 인자: `--states=work,turn,turn15,done,unknown,meet,wait,off` · `--days=40,15,5,0` (근속 근무일 → 직급, 책상 순서대로) · `--roof` (떠오르는 지붕 시험)
##   · `--fail=0,2` (실패 연출) · `--guests=2` (대기 의자 인턴) · `--more=3` ('+N', M4)

const Layout := preload("res://scripts/world/layout.gd")
const RasterIcons := preload("res://scripts/util/raster_icons.gd")

## 상태 → 표시 (PLAN 5-1 · 5-6: 노랑 = 내 차례 전용 · 초록 = 끝 · 하늘색 = 일함 · 빨강 안 씀)

## glyph = 이름판 상태 점 (색 + 모양), head = 머리 위 큰 아이콘 (v2.5: 노랑 · 회색만)
const LOOK := {
	"work":    {"where": "seat",  "pose": "sit",   "glyph": "●", "color": "4aa8e0", "head": false, "big": false, "lamp": true},
	"turn":    {"where": "seat",  "pose": "stand", "glyph": "!", "color": "ffd21f", "head": true,  "big": false, "lamp": true},
	"turn15":  {"where": "queue", "pose": "stand", "glyph": "!", "color": "ffd21f", "head": true,  "big": true,  "lamp": true},
	"watch":   {"where": "seat",  "pose": "sit",   "glyph": "●", "color": "93c6e6", "head": false, "big": false, "lamp": true, "guess": true},   # 관찰 모드 '활동 중' (반투명 = 추정, 5-1)
	"done0":   {"where": "seat",  "pose": "stand", "glyph": "✓", "color": "3fb56a", "head": false, "big": false, "lamp": false},   # 끝 0~30초: 자리에서 기지개 (M3)
	"done":    {"where": "rest",  "pose": "stand", "glyph": "✓", "color": "3fb56a", "head": false, "big": false, "lamp": false},
	"rest":    {"where": "rest",  "pose": "stand", "glyph": "",  "color": "",       "head": false, "big": false, "lamp": false},   # 세션은 열렸는데 쉼 (✓ 사라진 뒤 · 입력 기다림)
	"unknown": {"where": "seat",  "pose": "sit",   "glyph": "?", "color": "9a9a9a", "head": true,  "big": false, "lamp": true},
	"meet":    {"where": "meet",  "pose": "sit",   "glyph": "",  "color": "",       "head": false, "big": false, "lamp": false},   # 회의 탁자 꾸밈 연출 (판단 없음, 5-4)
	"wait":    {"where": "chair", "pose": "sit",   "glyph": "",  "color": "",       "head": false, "big": false, "lamp": false},
	"off":     {"where": "",      "pose": "",      "glyph": "",  "color": "",       "head": false, "big": false, "lamp": false},
	"hide":    {"where": "",      "pose": "",      "glyph": "",  "color": "",       "head": false, "big": false, "lamp": false},   # 쉬는 인턴 · 넘친 인턴: 정류장으로 걸어 나가 사라짐 (퇴근과 같음, 사용자 '인턴은 걸어 나가게'). 안 보이던 인턴은 그대로 안 보임
}
## 직원 구분 색 (M4 사용자 "옷 색이 밤티" → C 톤온톤: 맑은 색 + 포인트 = 같은 색 진하게, 노랑 · 주황 없음)
const SHIRTS := ["7fa8d6", "7cc4b0", "a99ad6", "e89c86", "e58fa6", "94c47e", "86c3e0", "6fb5b8", "c49ad6", "8f9ee0", "d98a9a", "9cc9a0"]
const OUTFITS := ["OutfitShirt", "OutfitHoodie", "OutfitKnit"]   ## 출근마다 무작위 하나 (M4 사용자)
const ACCESSORIES := ["", "AccGlasses", "AccRibbon", "AccHeadphones"]   ## 직원마다 고정 하나 (알아보기 표시, M4 사용자 · 비니는 뺌)
## 회색 상자용 임시 이름 (M3: data/staff_names.json)
const RANKS := "res://data/ranks.json"   ## 직급 명패 (근속 근무일 기준, 장식만)
const NAMES := ["민준", "서연", "도윤", "하은", "지호", "수아", "예준", "지우", "시우", "서윤", "주원", "하린"]
## 회색 상자 색 (채도 낮게 — 진한 색은 상태에만, 3-3)
const C_WALL := "f4f0e8"
const C_WALL_LOW := "e9e3d7"
## 바닥 (v2.5): 작업실 회청색 카펫 · 휴게 나무 · 창구 차가운 타일 (v2.6) · 복도 밝은 나무
const C_FLOOR := {"building": "d8c3a0", "workroom": "dcc6a2", "counter": "dde1e4", "rest": "d3b98f", "pier": "b49c7c"}
const C_TILE_LINE := "a9b2b9"   ## 창구 타일 줄눈
const C_WALL_CAP := "a8916f"    ## 낮은 벽 위 덮개 (나무, M4)
const C_WALL_BASE := "8f877c"   ## 벽 걸레받이
const C_QUEUE := "5f6f86"       ## 창구 바닥 줄 선 · 차단봉 줄 (차분한 남색 — 노랑 · 빨강 아님)
const C_FURN := "e8e4dc"
## 분위기 조각 (M2, Blender: SkyOffice/tools/blender/) — 크기 단위 칸 (desk_set · pantry), 직원은 m
## 책상 · 모니터 · 의자 (M4 2세션째, KayKit Extra 스타일 참고 — tools/blender/build_desk_kit.py --export). 책상 기준 좌표 하나 (desk_set 과 같음)
## 이름 붙은 부품: Bulb (스탠드 갓, 책상에) · Screen (모니터 화면 — 2대 · 와이드도 한 물체) · ChairBack (등받이 = 직원 색)
const DESK_PARTS := [
	{"A": preload("res://assets/models/desk/desk_a.glb"), "B": preload("res://assets/models/desk/desk_b.glb")},
	{"A": preload("res://assets/models/desk/monitor_a.glb"), "B": preload("res://assets/models/desk/monitor_b.glb"), "C": preload("res://assets/models/desk/monitor_c.glb")},
	{"A": preload("res://assets/models/desk/chair_a.glb"), "B": preload("res://assets/models/desk/chair_b.glb"), "C": preload("res://assets/models/desk/chair_c.glb")},
]
## 자리 (책상 id) 마다 정해진 조합 = 책상 · 모니터 · 의자. 이웃끼리 겹치지 않게 고른 6가지를 돌려 씀 (사용자: '다 채택해서 개성 있게')
const DESK_COMBOS := ["AAA", "BBB", "ACC", "ABA", "BCB", "AAC"]
const PANTRY := preload("res://assets/models/pantry.glb")
const SERVICE := preload("res://assets/models/station/service_counter.glb")   ## 결재 창구: 높은 카운터 + 유리 틀 (손님 쪽 = +x), v2.6 · M4 남색 은행 창구 C
## 창구 · 승강장 나머지 (M4 3세션째, build_counter_kit.py --station-export) — 크기 단위 칸, 앞면 = +z
const PRINTER := preload("res://assets/models/station/printer.glb")   ## 흰 복합기 A (0.45 × 0.35)
const WAIT_CHAIR := preload("res://assets/models/station/wait_chair.glb")   ## 금속 공항 의자 C (방석 위 0.28)
const FLAGPOLE := preload("res://assets/models/station/flagpole.glb")   ## 남색 깃대 B (높이 1.5, 깃발은 코드)
const SIGN := preload("res://assets/models/station/sign.glb")   ## 뒷벽 위 간판: SignHand (창업 손글씨) · SignNew (스타트업 남색 A) — M5 단계가 바꿈, 개발 인자 `--sign-new`
const NOTICE := preload("res://assets/models/station/notice_board.glb")   ## 복도 입간판 게시판 D (이젤 + 흰 둥근 틀), Growth = 성장 막대 (M5)
## 작업실 · 분위기 (M4 2세션째, build_workroom.py) — 크기 단위 칸, 앞면 = +z
const RACK := preload("res://assets/models/server_rack.glb")   ## 서버 랙 (Leds = 불빛) — 스타트업 ② 부터. 그 전엔 서버 선반 (M5 단계 상승)
const SERVER_SHELF := preload("res://assets/models/server_shelf.glb")
const Company := preload("res://scripts/world/company.gd")
const Director := preload("res://scripts/world/director.gd")
const BOOKSHELF := preload("res://assets/models/bookshelf.glb")
const WHITEBOARD := preload("res://assets/models/whiteboard.glb")   ## Doodle = 기본 그림 (포스트잇 · 낙서가 생기면 숨김)
const TELESCOPE := preload("res://assets/models/telescope.glb")   ## Tube 원점 = 회전축
const CALL_BOARD := preload("res://assets/models/call_board.glb")   ## 호출 보드 틀 1.5 × 0.5 (칸은 코드가 그림, M4 3세션째 B 흰 틀 + 레일 · 종)
const PERSONAL := preload("res://assets/models/desk_personal.glb")   ## 책상 기준 좌표. Item0~5 중 책상마다 일부 + PersonalShelf
## 사장 자리 (M4 3세션째, build_counter_kit.py --export, 사용자 B 중역 책상) — 크기 단위 칸, 사장은 -z 를 봄
## 이름 붙은 부품: BossChair (자리 비우면 빠짐) · Bulb (내가 있으면 흰빛) · Note (자리 비움 쪽지) · Handset · PhoneLight (M5 연결 상태) · InboxPapers
const BOSS_DESK := preload("res://assets/models/boss/boss_desk.glb")
const BUS := preload("res://assets/models/station/bus.glb")   ## 하늘 통근버스 A (build_bus.py, 사용자 — 비행선 재사용 대신). Rotor0 · Rotor1 = 지붕 프로펠러
const JUA := preload("res://assets/fonts/Jua-Regular.ttf")   ## 주아 (Jua Project Authors, SIL OFL 1.1 — assets/fonts/OFL_Jua.txt)
const PAPER_PLANE := preload("res://assets/models/boss/paper_plane.glb")   ## 일 받기 연출 (v2.8 C4): 사장 책상 → 직원 책상
const BOSS_MODEL := preload("res://assets/models/boss/boss.glb")   ## 사장 = 플레이어 (build_boss.py A 남색 정장, 직원과 같은 뼈대). 사장만의 동작 SitThrow · SitRead, 보고서 = Report
const BOSS_CABINET := preload("res://assets/models/boss/boss_cabinet.glb")   ## 작은 진열장 (비행선 모형 · 지구본 · 액자), 앞면 = +z
const ROCK_BASE := preload("res://assets/models/rock_base.glb")   ## 윗면 1 × 1, 높이 3.3 (아래로)
## 휴게 층 · 화분 = 외부 팩 (M4 에셋 회의 A 안, 사용자 결정): KayKit (Kay Lousberg) · Tiny Treats (Isa Lousberg), CC0, 게임 색으로 다시 칠함
## 만들기: tools/assets/recolor_atlas.py → tools/blender/build_kits.py (원본 = tools/assets_src/). 크기 단위 칸, 앞면 = +z
const KIT_SOFA := preload("res://assets/models/kit/kit_sofa.glb")
const KIT_RUG := preload("res://assets/models/kit/kit_rug.glb")
const KIT_TABLE := preload("res://assets/models/kit/kit_table_round.glb")
const KIT_CHAIR := preload("res://assets/models/kit/kit_chair.glb")
const KIT_PLANTS := [preload("res://assets/models/kit/kit_plant_monstera.glb"), preload("res://assets/models/kit/kit_plant_pothos.glb")]
const STAFF_MODEL := preload("res://assets/models/staff.glb")   ## 2등신 직원 (재질 Shirt · Hair 를 직원마다 다시 칠함), 크기 단위 m
const STAFF_HEAD := 0.875    ## 직원 머리 중심 높이 (칸) — 서도 앉아도 같음 (앉으면 엉덩이가 의자 높이)
const DESK_TOP := 0.48       ## desk_set 상판 높이 (칸)
const HAIRS := ["3e322c", "2b2725", "5a4636", "6b5a4c", "3a3433", "4d3b31"]
const C_DARK := "6c6863"

signal chips_changed(items: Array)   ## 칩 바용 [{name, color, glyph, turn}] — 노랑이 맨 앞 (3-3)

var layout: Layout
var island: Node3D
var staff: Array = []          ## [{node, body, head, icon, plate, label, tag, name, state, desk}]
var board_cells: Array = []    ## 책상 id 순서의 램프칸 MeshInstance3D (덮개 칸은 빼고)
var desk_parts: Array = []     ## [{screen, bulb}]
var boss: Dictionary = {}      ## 사장 자리 부품 {chair, chair_pos, bulb, note, light} (v2.8 C15)
var flag: MeshInstance3D
var sign_text: Label3D         ## 간판 글자 = 회사 이름 (set_sign_text, M5 3세션째 창업 화면)
var time_text := ""        ## 깃대 · 간판 사이 전자시계에 보이는 글자 ("14:00", day_night 가 set_time_text 로 갱신, M5)
var _clock_segs: Array = []   ## 숫자 4개 × {칸 이름: [앞면]} (a b c d e f g)
var _clock_colon: Array = []
var _led_on: StandardMaterial3D
var roof: Node3D
var bus: Node3D                ## 출퇴근 버스 (하늘 통근버스): away → coming → docked → leaving (⑧ · ⑫)
var bus_state := "away"
var bus_hold := 0             ## 이 시각 (ms) 까지는 정류장에 머묾
var kiosk: MeshInstance3D      ## 정류장 안내 단말기 (관리인 대신, M3 4세션째)
var more_label: Label3D        ## 넘친 인턴 '+N' (M3 4세션째)
var desk_count := 0            ## staff 앞쪽 = 책상 직원 (책상 id 순서), 그 뒤 = 손님 (파견 · 임시 파견, add_guest)
## 머리 위 아이콘 크기 (M3): 창 100% · 1칸 = 50px 기준. main 이 창 배율 · 크기 단계를 넘겨줌
var px_per_cell := 50.0        ## 지금 창에서 1칸의 화면 px (창 배율 × 50)
var big_k := 1.0               ## 크기 단계 / 10 — 큰 '!' 는 이만큼 키움 (400px 그림에서 크기 10 과 같은 크기, M2 시험 ①)
const ICON_SMALL := 0.38       ## 칸 (0.38칸 ≈ 19px ≥ 16px)
const ICON_BIG := 0.62
const ICON_MIN_PX := 16.0      ## 머리 위 아이콘은 16px 아래로 안 작아짐 (3-3)
const ICON_BLUR := 1.05        ## 흐림 그림에서 테두리가 번지는 몫 (크기 14 실측 11px → 여유)
const C_GUEST := "8d8f91"      ## 파견 (인턴) = 회색 조끼 (4-1) — '+N' 글자색. 조끼 메시 'Vest' 는 staff.glb (M4)
const C_GUEST_SHIRT := "f1efea"   ## 인턴 = 흰 셔츠 + 회색 조끼 + 사원증 (M4 1세션째 사용자)
const SWEAT := [Vector2(0.3, 0.26), Vector2(0.42, 0.08), Vector2(-0.32, 0.22)]   ## 실패 땀방울 3개: 머리 가운데에서 (옆 칸, 위 칸)
const SWEAT_CELLS := 0.11      ## 땀방울 크기 (칸) — 창이 작아도 SWEAT_MIN_PX 아래로 안 작아짐
const SWEAT_MIN_PX := 7.0
const C_KEEPER := "4f6272"     ## 안내 단말기 (예전 관리인 제복 색, 차분한 남회색)
var _mats := {}


func build(isl: Node3D, lay: Layout) -> void:
	island = isl
	layout = lay
	_load_idle_cfg()
	island.walk_circle = false   # 둥근 섬 땅 없음 → 걷는 곳 = 사무실 바닥 + 부두
	_base()
	_floors()
	_walls()
	_workroom()
	_counter()
	_rest()
	_pier()
	_bus_build()
	_stage_setup()
	apply_stage(start_stage())
	if "--roof" in Game.dev_args():
		_roof()
	var states: Array = []
	for a in Game.dev_args():
		if a.begins_with("--states="):
			states = Array(a.get_slice("=", 1).split(","))
	var days: Array = []
	for a in Game.dev_args():
		if a.begins_with("--days="):
			days = Array(a.get_slice("=", 1).split(","))
	for d in layout.desks():
		_add_staff(d)
	desk_count = staff.size()
	for i in staff.size():
		set_days(i, int(days[i]) if i < days.size() else 0)
		set_state(i, states[i] if i < states.size() else "off")
	for a in Game.dev_args():   # 개발용 (M5 5세션째): `--folder=SkyOffice2` 데모 직원 명패 폴더 이름 (2줄 명패 그림)
		if a.begins_with("--folder="):
			for i in desk_count:
				set_staff_project(i, a.get_slice("=", 1))
	more_label = _label(48, 3)   # 넘친 인턴 수 '+N' (대기 의자 인턴 머리 위, 회색 글자 + 흰 테)
	more_label.name = "InternMore"
	more_label.modulate = Color(C_GUEST).darkened(0.25)
	more_label.outline_size = 12
	more_label.outline_modulate = Color.WHITE
	var wc: Array = layout.slots("wait_chairs")
	more_label.pixel_size *= 1.5   # M4 1세션째 사용자: 조금 키우고 위로 (화분 · 인턴 다리와 안 겹치게)
	more_label.position = layout.m3((wc[0].pos + wc[-1].pos) / 2.0, 1.6)   # 대기 의자 인턴들 머리 위
	more_label.visible = false
	add_child(more_label)
	for a in Game.dev_args():   # 개발용 (M4): `--fail=0,2` 그 책상 직원 실패 (머리 긁기 + 땀방울) · `--guests=2` 대기 의자 인턴
		if a.begins_with("--fail="):
			for k in a.get_slice("=", 1).split(","):
				set_fail(int(k), true)
		elif a.begins_with("--guests="):
			for k in int(a.get_slice("=", 1)):
				set_state(add_guest(), "wait")
		elif a.begins_with("--hire="):   # 짐 상자 그림 · 실화면 (M5): `--hire=0` 2초 뒤 그 책상 직원이 상자 들고 출근 (입사)
			var k := int(a.get_slice("=", 1))
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				set_state(k, "off")
				mark_hire(k)
				set_state(k, "work", true))
		elif a.begins_with("--farewell="):   # `--farewell=1` 2초 뒤 그 책상 직원 송별 (상자 들고 버스로)
			get_tree().create_timer(2.0).timeout.connect(farewell.bind(int(a.get_slice("=", 1))))
		elif a.begins_with("--more="):   # 대기 의자에 못 앉은 인턴 수 '+N'
			set_more(int(a.get_slice("=", 1)))
		elif a.begins_with("--say="):   # 말풍선 그림용 (M4 3세션째): `--say=0,2` 그 직원들이 끼어들기 문구 3개를 돌려 가며 말함
			var lines := ["컵 들고 갈게요", "벌떡!", "앗!"]
			var ks := a.get_slice("=", 1).split(",")
			for n in ks.size():
				say.call_deferred(int(ks[n]), lines[n % lines.size()], 600.0)
		elif a.begins_with("--plane="):   # 종이비행기 그림 · 실화면용 (M4): `--plane=0,2` 2.9초부터 4초마다 그 책상들로 (--shot 4초 = 날아가는 중)
			var ids := Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
			var tm := Timer.new()
			tm.wait_time = 4.0
			tm.timeout.connect(func() -> void:
				for k in ids:
					fly_plane(k))
			add_child(tm)
			get_tree().create_timer(2.9).timeout.connect(func() -> void:
				tm.start()
				tm.timeout.emit())
		elif a.begins_with("--act-s="):   # 실화면 빨리 보기: 쉬는 행동 바뀌는 간격 (초) `--act-s=8,15` (기본 30,180)
			idle_cfg.act_s = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
		elif a.begins_with("--act="):   # 쉬는 행동 그림 · 실화면용 (M4 4세션째): `--act=0:sofa,1:chat,2:pier,3:coffee` (+ --states=rest,...) · quirk · tidy (⑩)
			for kv in a.get_slice("=", 1).split(","):   # `k:행동@초` = 그 초 뒤에 (실화면 순서). 상태 = work · turn15 · off · tidy (⑩, done0 다음)
				var k: int = int(kv.get_slice(":", 0))
				var act: String = kv.get_slice(":", 1).get_slice("@", 0)
				var at: float = float(kv.get_slice("@", 1)) if "@" in kv else 0.0
				var go := func() -> void:
					if act == "tidy":
						set_state(k, "done", true)
					elif TOOL_KIND.has(act):   # ② 도구 (M4 5세션째): `0:Read@3,0:Edit@8,0:Bash@13`
						staff[k].tool_since = -1.0e9
						set_tool(k, act)
					elif act == "stop":   # 멈춤 손 4초
						set_stop(k, true)
						get_tree().create_timer(4.0).timeout.connect(set_stop.bind(k, false))
					elif act == "envelope":   # ⑦ 봉투
						fly_envelope(k)
					elif act in LOOK:
						set_state(k, act, true)
					else:
						rest_act(k, act)
				if at > 0.0:
					get_tree().create_timer(at).timeout.connect(go)
				else:
					go.call_deferred()


## 대기 의자에 못 앉은 인턴 수 (office_routine.cap_interns). 0 이면 숨김
func set_more(n: int) -> void:
	more_label.text = "+%d" % n
	more_label.visible = n > 0


## 근속 근무일 (M5 성장 때 직급 명패로 — 지금 이름판엔 직급 안 붙임, M3 4세션째 사용자 '사원은 별로')
func set_days(i: int, days: int) -> void:
	var s: Dictionary = staff[i]
	s.days = days
	_refresh_tag(s)


## 이름판 = 명패 (PLAN 5-7, M5 5세션째 사용자 결정 — 팀 이름 없음):
##   부를 때 (내 차례 · 무소식, 저절로 뜸) = 작업 폴더만 "OverLand" (여럿이 동시에 떠도 안 겹치게 한 줄)
##   마우스 올림 = 2줄 "서연\nOverLand" (위 = 직원 이름, 아래 = 폴더 — 한 명씩이라 안 겹침)
##   폴더 이름 설정 (기본 켬) 을 끄거나 폴더를 모르면 (인턴 · 데모) 직원 이름만
func tag_text(s: Dictionary) -> String:
	var label := str(s.get("project", ""))
	if label.length() > TAG_MAX_CHARS:
		label = label.left(TAG_MAX_CHARS - 1) + "…"
	if label == "":
		return str(s.name)
	return "%s\n%s" % [s.name, label] if bool(s.get("hover", false)) else label


func _refresh_tag(s: Dictionary) -> void:
	(s.tag as Label3D).text = tag_text(s)
	_layout_tag(s, LOOK.get(s.state, LOOK.off))


## 팀 이름 (명패, "" = 없음)
func set_staff_team(i: int, team: String) -> void:
	if str(staff[i].get("team", "")) == team:
		return
	staff[i].team = team
	_refresh_tag(staff[i])


## 해시 직원 겉모습 (staff_hash.look 번호: shirt · hair · acc · person) — 셔츠 · 머리 · 장신구 · 의자 등받이 · 성격. 같은 값이면 그대로
func set_look(i: int, lk: Dictionary) -> void:
	var s: Dictionary = staff[i]
	var key := "%d/%d/%d/%d" % [int(lk.shirt), int(lk.hair), int(lk.acc), int(lk.person)]
	if s.guest or str(s.get("look_key", "")) == key:
		return
	s.look_key = key
	s.person = int(lk.person)
	var shirt: String = SHIRTS[int(lk.shirt) % SHIRTS.size()]
	s.shirt = shirt
	_paint_staff(s.model, shirt, HAIRS[int(lk.hair) % HAIRS.size()])
	_wear_acc(s.model, ACCESSORIES[int(lk.acc) % ACCESSORIES.size()])
	if i < desk_parts.size() and desk_parts[i].get("chair_back"):
		(desk_parts[i].chair_back as MeshInstance3D).material_override = _mat(shirt)


func _wear_acc(model: Node3D, acc: String) -> void:
	for a in ACCESSORIES:
		if a != "":
			(model.find_child(a, true, false) as Node3D).visible = a == acc


## 간판 글자 = 회사 이름 (6-2, M5 3세션째). 판 폭 1.2칸에 6글자 — 더 길면 글자를 줄여 판 안에
func set_sign_text(t: String) -> void:
	if sign_text == null:
		return
	sign_text.text = t
	sign_text.pixel_size = 0.16 / 64.0 * minf(1.0, 6.0 / maxf(1.0, float(t.length())))


## 프로젝트 이름 ("" = 숨김)
func set_staff_project(i: int, label: String) -> void:
	if str(staff[i].get("project", "")) == label:
		return
	staff[i].project = label
	_refresh_tag(staff[i])


## 프로젝트 색 (이름판 왼쪽 줄, "" = 없음) — 같은 프로젝트 인턴도 같은 색 (M3 5세션째 사용자: 깃발 말고 이름판 줄만)
func set_staff_color(i: int, col: String) -> void:
	if str(staff[i].color) == col:
		return
	staff[i].color = col
	_refresh_tag(staff[i])


## 인턴 책상 빌려 앉기 (M3 5세션째): 주인이 퇴근한 책상 j 에 앉음 (-1 = 대기 의자). 바뀌면 걸어서 옮김 · 앞 책상 불은 주인 상태로 되돌림
func set_borrow(i: int, j: int, move := true) -> void:
	var s: Dictionary = staff[i]
	if int(s.borrow_j) == j:
		return
	var old := int(s.borrow_j)
	s.borrow_j = j
	s.borrow = staff[j].desk if j >= 0 else {}
	if old >= 0:
		_apply_look(old)
	if move and (s.node as Node3D).visible:
		set_state(i, str(s.state), true)


## 직원 이름 (staff_registry 의 직원 id 로 정함, office_routine)
func set_staff_name(i: int, n: String) -> void:
	if staff[i].name == n:
		return
	staff[i].name = n
	set_days(i, int(staff[i].days))


## 직원 id → 기본 이름 (이름 목록에서 자동, 4-2)
static func name_of(staff_id: int) -> String:
	return NAMES[staff_id % NAMES.size()]


## 손님 직원 (책상 없는 파견 · 같은 조합 두 번째 세션) 하나 더 → staff 번호. 회색 옷, 대기 의자에 앉음 (4-1)
func add_guest() -> int:
	_add_staff({"id": staff.size(), "guest": true})
	var i := staff.size() - 1
	set_state(i, "off")
	return i


static func rank_title(days: int) -> String:
	var title := ""
	for r in JSON.parse_string(FileAccess.get_file_as_string(RANKS)).ranks:
		if days >= int(r.days):
			title = r.title
	return title


# ------------------------------------------------------------------ 상태 표현 자리
##   move = false: 그 자리로 바로 (개발 인자 · 시험) / true: 걸어서 3초 안에 (office_routine, 5-3 이동 규칙)
##   delay: 걷기 전에 멈추는 시간 (끼어들기 '벌떡 · 기지개 1초', 결정 8) — 도착은 그래도 3초 안
func set_state(i: int, state: String, move := false, delay := 0.0) -> void:
	var s: Dictionary = staff[i]
	var look: Dictionary = LOOK.get(state, LOOK.off)
	var was_visible: bool = (s.node as Node3D).visible
	if move and state.begins_with("done") and not str(s.state).begins_with("done"):
		boss_read()   # 일이 끝나면 사장이 보고서를 읽음 (M4, 끝 보고 연출 전 임시)
	var prev: String = str(s.state)
	var thumbs: bool = move and prev == "turn15" and look.where == "seat" and was_visible   # ⑨ 사장이 답함: 창구에서 엄지척 → 자리로
	if thumbs:
		delay = maxf(delay, THUMB_S)
	if state != "work":
		_tool_reset(i)
	var tidy: bool = move and state == "done" and prev == "done0" and (s.node as Node3D).visible   # ⑩ 끝 30초: 기지개 → 결재함 → 커피
	if look.where != "rest" or tidy:
		_leave_act(i, "cup" if look.where == "seat" and str(s.get("act", "")) == "coffee" and move else "")   # ⑪ 커피 중 일이 오면 컵 들고 복귀
	if look.where != "seat":
		_desk_cup(i, false)
	if state == "work" and prev != "work":
		var span: Array = idle_cfg.get("work_quirk_s", [90, 240])
		s.quirk_at = _now() + float(preload("res://scripts/world/agent_state.gd").timings().get("long_work_s", 60)) + randf_range(0.0, float(span[0]))   # 긴 일 버릇 (5-3)
	elif state != "work":
		s.quirk_at = 0.0
	s.state = state
	var node: Node3D = s.node
	if s.tween != null:
		(s.tween as Tween).kill()
		s.tween = null
	if tidy:
		_tidy_to_coffee(i)
		_apply_look(i)
		_update_flag()
		chips_changed.emit(chips())
		return
	s.greet = move and look.where == "queue" and str(LOOK.get(prev, LOOK.off).where) != "queue"   # 창구 도착 손 들기 (v2.8 인사)
	if s.greet and str(s.get("held", "")) == "":
		hold(i, "papers")   # ⑨ 서류 들고 창구로
	if thumbs:
		_thumbs_up(i)
	var spot := _spot(i, str(look.where))
	if spot.is_empty():   # 퇴근 · 인턴 숨김: 걸어서 정류장으로 → 사라짐
		if move and was_visible:
			s.leaving = true
			_wear_bag(i, true)   # 가방 메고 (⑫)
			bus_call(4.5)   # 퇴근 (⑫): 버스가 와서 기다림
			s.tween = walk(i, layout.slot("dock"), 0.6, WALK_MAX_S, delay)
			if s.tween != null:
				(s.tween as Tween).tween_callback((s.anim as AnimationPlayer).play.bind("Wave", 0.15))   # 정류장에서 손 흔들기 (v2.8)
				(s.tween as Tween).tween_interval(1.0)
				(s.tween as Tween).tween_callback(_settle.bind(i))
			else:
				_settle(i)
		else:
			_settle(i)
	else:
		s.leaving = false
		node.visible = true
		var to := layout.m3(spot.pos)
		if move and node.position.distance_to(to) > 0.02:
			if not was_visible:   # 출근 (⑧): 버스에서 내려 정류장에서 걸어 들어옴
				node.position = layout.m3(layout.slot("dock"))
				dress(i)   # 출근마다 옷 바꿈
				bus_call(3.0)
				if bool(s.get("box_in", false)) and look.where == "seat":
					hold(i, "box")   # 입사 (M5): 짐 상자 들고 와서 책상에 풀어 놓음
			s.tween = walk(i, spot.pos, 0.6, WALK_MAX_S, delay)
		if s.tween != null:
			(s.tween as Tween).tween_property(node, "position", to, 0.12)
			(s.tween as Tween).tween_callback(_settle.bind(i))
			if not was_visible:
				(s.tween as Tween).tween_callback(bow.bind(i))   # 출근 꾸벅 (v2.8 인사 몸짓)
				if str(s.get("held", "")) == "box":
					(s.tween as Tween).tween_callback(_unpack.bind(i))
		else:
			_settle(i)
	_apply_look(i)
	_update_flag()
	chips_changed.emit(chips())


const WALK_MAX_S := 2.8   ## 이동은 3초 안 (5-3) — 마지막 자리 맞춤 0.12초 포함


## 도착 (또는 바로 놓기): 자리 · 방향 · 앉기/서기
func _settle(i: int) -> void:
	var s: Dictionary = staff[i]
	var look: Dictionary = LOOK.get(s.state, LOOK.off)
	var node: Node3D = s.node
	s.tween = null
	s.leaving = false
	var spot := _spot(i, str(look.where))
	node.visible = not spot.is_empty()
	if spot.is_empty():
		_wear_bag(i, false)
		hold(i, "")
		return
	node.position = layout.m3(spot.pos)
	node.rotation_degrees.y = float(spot.rot)
	if look.where == "seat" and str(s.get("held", "")) == "cup":   # ⑪ 들고 온 컵을 책상에 내려놓음
		hold(i, "")
		_desk_cup(i, true)
	elif str(s.get("held", "")) == "papers" and look.where != "queue":   # ⑨ 창구에서 들고 간 서류는 자리에 오면 내려놓음
		hold(i, "")
	_tool_props(i)
	var anim: AnimationPlayer = s.anim
	anim.play(_pose_anim(s), 0.2)
	if s.state == "done0" and not s.fail:   # 끝: 자리에서 기지개 1번 (⑩)
		anim.play("Stretch", 0.2)
		anim.queue("Idle")
	elif s.greet:   # 창구 도착: 사장 쪽으로 손 번쩍 1번
		s.greet = false
		anim.play("RaiseHand", 0.15)
		anim.queue("Idle")
	elif look.where == "rest" and str(s.get("act", "")) == "":
		s.act_until = 0.0   # 휴게 도착 → 다음 1초 안에 쉬는 행동 고름


## 서 있거나 앉은 기본 동작 — 실패 중이면 머리 긁기 (앉아서 / 서서)
func _pose_anim(s: Dictionary) -> String:
	var look: Dictionary = LOOK.get(s.state, LOOK.off)
	var sit: bool = look.pose == "sit"
	if sit and s.state == "work" and s.get("stop", false):
		return "SitStop"   # 멈춤 손 (Esc, C16)
	if s.fail:
		return "SitScratch" if sit else "Scratch"
	if sit:
		if look.where in ["meet", "chair"]:
			return "SitRest"   # 회의 탁자 · 대기 의자 = 기대 쉬기 (M4)
		return TOOL_ANIM.get(str(s.get("tool_kind", "")), "Sit") if s.state == "work" else "Sit"
	return "HoldBox" if str(s.get("held", "")) == "box" else ("HoldIdle" if str(s.get("held", "")) != "" else "Idle")


## 실패 (도구 실패 3초, 5-1 ⑤): 머리 긁기 + 땀방울 3개. 걷는 중이면 땀방울만 (도착하면 긁기)
func set_fail(i: int, on: bool) -> void:
	var s: Dictionary = staff[i]
	(s.sweat as Node3D).visible = on
	if on:
		_place_sweat(s)
	if on == bool(s.fail):
		return
	s.fail = on
	var tw: Tween = s.sweat.get_meta("bob") if s.sweat.has_meta("bob") else null
	if tw:
		tw.kill()
	if on:   # 땀방울이 살짝 흘러내렸다 돌아옴 (0.8초 반복)
		tw = create_tween().set_loops()
		tw.tween_property(s.sweat, "position:y", -0.06 * layout.unit_m, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(s.sweat, "position:y", 0.06 * layout.unit_m, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
		s.sweat.set_meta("bob", tw)
	if s.tween == null:
		(s.anim as AnimationPlayer).play(_pose_anim(s), 0.15)


func _place_sweat(s: Dictionary) -> void:
	var u := layout.unit_m
	var size := maxf(SWEAT_CELLS, SWEAT_MIN_PX / maxf(px_per_cell, 1.0))
	var sw: Node3D = s.sweat
	if not sw.has_meta("bob") or not (sw.get_meta("bob") as Tween).is_running():
		sw.position = Vector3(0, STAFF_HEAD * u, 0)
	for k in SWEAT.size():
		var dr := sw.get_child(k) as Sprite3D
		dr.pixel_size = size * u / 32.0 * (1.0 if k == 0 else 0.8)
		dr.position = Vector3(SWEAT[k].x * u, SWEAT[k].y * u, 0)


## 걷는 중인지 (퇴근 걸음 = '앗!' 끼어들기 판단, 결정 8)
func is_leaving(i: int) -> bool:
	return bool(staff[i].get("leaving", false)) and staff[i].tween != null


## where → 자리 {pos, rot}. 한 번 받은 자리 번호는 그 where 에 있는 동안 유지 (다른 직원이 바뀌어도 안 옮김)
func _spot(i: int, where: String) -> Dictionary:
	var s: Dictionary = staff[i]
	if s.desk.is_empty() and where in ["seat", "chair"] and not s.borrow.is_empty():
		s.spot = {"where": "borrow", "k": int(s.borrow_j)}   # 인턴이 빌린 책상
		return {"pos": s.borrow.seat, "rot": s.borrow.rot}
	if where == "seat" and s.desk.is_empty():
		where = "chair"   # 손님 (파견) 은 책상 대신 대기 의자 (4-1)
	if where == "" or (off_duty and where in ["rest", "meet"] and not s.desk.is_empty()):   # 하루 끝: 쉬는 직원은 퇴근 (M5 6-3)
		s.spot = {}
		return {}
	if where == "seat":
		s.spot = {"where": "seat", "k": 0}
		return {"pos": s.desk.seat, "rot": s.desk.rot}
	var names := {"queue": "queue", "rest": "rest_spots", "meet": "meeting_seats", "chair": "wait_chairs"}
	var list := layout.slots(names[where])
	var k := -1
	if s.get("spot", {}).get("where", "") == where:
		k = int(s.spot.k)
	else:
		var used := {}
		for j in staff.size():
			if j != i and staff[j].get("spot", {}).get("where", "") == where:
				used[int(staff[j].spot.k)] = true
		k = 0
		while used.has(k):
			k += 1
		s.spot = {"where": where, "k": k}
	if where == "queue":
		_queue_tags.call_deferred()   # 줄 자리가 정해진 뒤 맨 앞 명패
		return list[mini(k, list.size() - 1)]   # 줄이 넘치면 맨 뒤에 겹쳐 섬
	return list[k % list.size()]


## 그 직원이 지금 있는 휴게 자리가 탕비 쪽인지 (끼어들기: 커피 중 = 컵 들고, 소파 쪽 = 벌떡, 결정 8)
func at_pantry(i: int) -> bool:
	var sp: Dictionary = staff[i].get("spot", {})
	if sp.get("where", "") != "rest":
		return false
	var p: Vector2 = layout.slots("rest_spots")[int(sp.k) % layout.slots("rest_spots").size()].pos
	return p.distance_to(layout.slots("pantry")[0].pos) < p.distance_to(layout.slots("sofa")[0].pos)


# ------------------------------------------------------------------ 쉬는 행동 · 버릇 · 손에 든 소품 (M4 4세션째, PLAN 5-4 · 5-5 ⑩ ⑪ · 5-7 인사 · C19)
## 쉬는 직원 (rest · done) 은 30초~3분마다 행동 하나: 커피 (탕비) · 소파 · 수다 (2명) · 부두 · 버릇 (자기 자리). 비중 = data/idle_weights.json
## 크게 움직이는 직원은 big_max (3) 명까지 — 넘으면 그 자리에 서 있음. 일하는 직원도 오래 일하면 가끔 버릇 1번 (5-3 '긴 일')
## 스스로 고를 때 (life_tick) 는 연출 감독 (director.gd, M5 5세션째) 이 먼저 봄: 내 차례 · 조용히 모드 · 같은 직원 10분 1번
const PROPS := {"cup": preload("res://assets/models/props/cup.glb"), "papers": preload("res://assets/models/props/papers.glb"),
		"envelope": preload("res://assets/models/props/envelope.glb"), "bag": preload("res://assets/models/props/bag.glb"),
		"box": preload("res://assets/models/props/box.glb")}   ## 짐 상자 (입사 · 송별, M5) — 두 손으로 가슴 앞에
const LOOP_ANIMS := ["Idle", "Walk", "Sit", "Scratch", "SitScratch", "Drink", "HoldIdle", "WalkCarry", "Talk", "SitRest", "SitTypeFast", "SitFlip", "SitWatch", "SitStop", "Clap", "HoldBox", "WalkBox"]
## ② 도구별 책상 동작 (M4 5세션째): 도구 이름 → 종류 (아이콘 7장 = raster_icons.TOOL_KINDS) → 앉은 동작
const TOOL_KIND := {"Edit": "edit", "Write": "edit", "MultiEdit": "edit", "NotebookEdit": "edit",
	"Read": "read", "Grep": "read", "Glob": "read", "LS": "read",
	"Bash": "run", "PowerShell": "run", "BashOutput": "run", "Monitor": "run",
	"WebFetch": "web", "WebSearch": "web", "Task": "agent", "Agent": "agent", "TodoWrite": "plan"}
const TOOL_ANIM := {"edit": "SitTypeFast", "read": "SitFlip", "run": "SitWatch"}   ## 고치기 = 빠른 타자 + 종이 쌓임 · 읽기 = 서류 넘기기 · 실행 = 검은 화면 초록 글자 (5-1)
const TOOL_MIN_S := 1.5      ## '방금 쓴 도구' 는 최소 1.5초 (5-1) — 빨리 바뀌면 다음 확인 때 바꿈
const PAPER_STACK_MAX := 3   ## 고치기: 책상 위 종이 더미 (고칠 때마다 1장, 일이 끝나면 치움)
const THUMB_S := 1.2         ## ⑨ 창구에서 엄지척 시간 → 그 뒤 자리로
const BIG_ACTS := ["coffee", "sofa", "chat", "pier", "quirk"]
const DRINK_TURN := 60.0   ## 커피 마실 땐 탕비에서 카메라 쪽으로 반쯤 돌아섬 (컵이 보이게)
var idle_cfg := {}
var _life_acc := 0.0


func _load_idle_cfg() -> void:
	var f := FileAccess.open("res://data/idle_weights.json", FileAccess.READ)
	idle_cfg = JSON.parse_string(f.get_as_text()) if f else {}


static func personality_of(id: int, cfg: Dictionary) -> String:
	var ps: Array = cfg.get("personalities", ["부지런"])
	return str(ps[id % ps.size()])


## 직원 성격: 해시 직원 (set_look, M5 3세션째) 이면 해시 번호, 아니면 (데모 · 손님) 자리 번호 % 4
func person_of(s: Dictionary) -> String:
	var p := int(s.get("person", -1))
	return personality_of(p if p >= 0 else int(s.id), idle_cfg)


## 성격 보정을 곱한 비중으로 행동 하나 고르기 (r = 0~1 난수, 순수 함수 — 시험용)
static func pick_act(person: String, cfg: Dictionary, r: float, skip: Array = []) -> String:
	var acts: Dictionary = cfg.get("acts", {})
	var total := 0.0
	var ws := []
	for a in acts:
		var w := 0.0 if a in skip else float(acts[a].w) * float(acts[a].get(person, 1.0))
		ws.append([a, w])
		total += w
	var x := r * total
	for aw in ws:
		x -= float(aw[1])
		if x < 0.0:
			return str(aw[0])
	return "stand"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	for s in staff:   # 손에 든 소품은 손을 따라가되 늘 똑바로 (컵이 기울지 않게)
		if s.get("held_node") != null:
			var hn: Node3D = s.held_node
			hn.global_basis = Basis(Vector3.UP, (s.node as Node3D).rotation.y).scaled(Vector3.ONE * layout.unit_m)
	_life_acc += delta
	if _life_acc >= 1.0:
		_life_acc = 0.0
		life_tick(_now())


func life_tick(now: float) -> void:
	if idle_cfg.is_empty():
		return
	var ctx := {"turn": any_turn(), "quiet": bool(Game.settings.get("quiet", false)), "now": now}
	for i in staff.size():
		var s: Dictionary = staff[i]
		if not (s.node as Node3D).visible or s.tween != null:
			continue
		if s.state == "work" and float(s.get("quirk_at", 0.0)) > 0.0 and now >= float(s.quirk_at):
			var span: Array = idle_cfg.get("work_quirk_s", [90, 240])
			s.quirk_at = now + randf_range(float(span[0]), float(span[1]))
			if Director.work_quirk(ctx):
				play_quirk(i)
		elif s.state in ["rest", "done"] and not s.desk.is_empty() and now >= float(s.get("act_until", 0.0)):
			ctx.big_now = big_movers(i)
			ctx.last_big = float(s.get("big_at", -1.0e18))
			rest_act(i, Director.rest_act(pick_act(person_of(s), idle_cfg, randf()), ctx, idle_cfg), now)


## 지금 크게 움직이는 (커피 · 소파 · 수다 · 부두 · 버릇) 다른 직원 수
func big_movers(except := -1) -> int:
	var n := 0
	for j in staff.size():
		if j != except and str(staff[j].get("act", "")) in BIG_ACTS:
			n += 1
	return n


## 쉬는 행동 시작 (act = coffee · sofa · chat · pier · quirk · stand). 시험 · 개발 인자에서도 부름
func rest_act(i: int, act: String, now := -1.0) -> void:
	var s: Dictionary = staff[i]
	if now < 0.0:
		now = _now()
	var span: Array = idle_cfg.get("act_s", [30, 180])
	s.act_until = now + randf_range(float(span[0]), float(span[1]))
	if act in BIG_ACTS and big_movers(i) + (2 if act == "chat" else 1) > int(idle_cfg.get("big_max", 3)):
		act = "stand"   # 잔잔 예산: 크게 움직이는 직원 3명까지 (5-4)
	var partner := -1
	if act == "chat":
		for j in staff.size():
			if j != i and staff[j].state in ["rest", "done"] and str(staff[j].get("act", "")) in ["", "stand"] \
					and (staff[j].node as Node3D).visible and staff[j].tween == null and not staff[j].desk.is_empty():
				partner = j
				break
		if partner < 0:
			act = "coffee"
	_leave_act(i)
	s.act = act
	if act in BIG_ACTS:
		s.big_at = now   # 같은 직원 큰 연출 10분 1번 (감독)
		if partner >= 0:
			staff[partner].big_at = now
	var rs: Array = layout.slots("rest_spots")
	match act:
		"coffee":
			var k := _free_rest_spot(i, true)
			_act_go(i, rs[k].pos, float(rs[k].rot) + DRINK_TURN, func() -> void:
				hold(i, "cup")
				(s.anim as AnimationPlayer).play("Drink", 0.2))
		"sofa":
			var so: Dictionary = layout.slots("sofa")[0]
			var side := 0.3 if i % 2 == 0 else -0.3
			var face := Vector2(-sin(deg_to_rad(so.rot)), -cos(deg_to_rad(so.rot)))   # 소파가 보는 쪽
			var along := Vector2(face.y, -face.x) * side
			var seat: Vector2 = so.pos + along + face * 0.04
			var front: Vector2 = so.pos + along + face * 0.45
			s.act_exit = layout.m3(front)
			_act_go(i, front, float(so.rot), func() -> void:
				var tw := (s.node as Node3D).create_tween()
				tw.tween_property(s.node, "position", layout.m3(seat), 0.35)
				tw.tween_callback((s.anim as AnimationPlayer).play.bind("SitRest", 0.25)))
		"chat":
			var p0: Vector2 = rs[2 % rs.size()].pos
			var p1: Vector2 = rs[3 % rs.size()].pos
			var d := p1 - p0
			staff[partner].act = "chat"
			staff[partner].act_until = s.act_until
			_act_go(i, p0, rad_to_deg(atan2(-d.x, -d.y)), (s.anim as AnimationPlayer).play.bind("Talk", 0.2))
			_act_go(partner, p1, rad_to_deg(atan2(d.x, d.y)), (staff[partner].anim as AnimationPlayer).play.bind("Talk", 0.2))
		"pier":
			_act_go(i, layout.slot("dock") + Vector2(-0.2, -0.25 + 0.15 * (i % 3)), 90.0, (s.anim as AnimationPlayer).play.bind("LookUp", 0.3))
		"quirk":
			_act_go(i, s.desk.seat, float(s.desk.rot), func() -> void:
				(s.anim as AnimationPlayer).play("SitRest", 0.2)
				play_quirk(i))
		_:
			(s.anim as AnimationPlayer).play("Idle", 0.2)


## ⑩ 끝 30초: 자리에서 기지개 → 서류 (파일) 들고 결재함 → 내려놓고 탕비로 가서 커피
func _tidy_to_coffee(i: int) -> void:
	var s: Dictionary = staff[i]
	var node: Node3D = s.node
	var anim: AnimationPlayer = s.anim
	var k := _free_rest_spot(i, true)
	var to: Dictionary = layout.slots("rest_spots")[k]
	s.act = "coffee"
	var tw := node.create_tween()
	s.tween = tw
	tw.tween_callback(anim.play.bind("Stretch", 0.2))
	tw.tween_interval(1.1)
	tw.tween_callback(hold.bind(i, "papers"))
	var inbox := layout.slot("inbox")
	var pts: Array = island.find_path(Vector2(node.position.x, node.position.z), layout.m(inbox))
	if not pts.is_empty():
		var prev := Vector2(node.position.x, node.position.z)
		var speed := walk_speed(_path_len(prev, pts), 0.6, WALK_MAX_S)
		tw.tween_callback(anim.play.bind("WalkCarry", 0.2))
		for p in pts:
			var d: Vector2 = p - prev
			var dur := maxf(prev.distance_to(p) / speed, 0.01)
			if d.length() > 0.001:
				tw.tween_property(node, "rotation:y", atan2(-d.x, -d.y), minf(0.15, dur))
				tw.parallel().tween_property(node, "position", Vector3(p.x, 0, p.y), dur)
			prev = p
		tw.tween_callback(anim.play.bind("Idle", 0.2))
		tw.tween_interval(0.35)
	tw.tween_callback(hold.bind(i, ""))   # 결재함에 놓음
	tw.tween_callback(func() -> void:
		s.tween = null
		_act_go(i, to.pos, float(to.rot) + DRINK_TURN, func() -> void:
			hold(i, "cup")
			anim.play("Drink", 0.2)
			s.act_until = _now() + randf_range(30.0, 90.0)))


## 탕비 쪽 (또는 소파 쪽) 빈 휴게 자리 번호 → 그 직원 자리로 잡음 (at_pantry · 끼어들기 '컵 들고 갈게요' 판단과 같은 기준)
func _free_rest_spot(i: int, pantry: bool) -> int:
	var rs: Array = layout.slots("rest_spots")
	var pa: Vector2 = layout.slots("pantry")[0].pos
	var so: Vector2 = layout.slots("sofa")[0].pos
	var used := {}
	for j in staff.size():
		if j != i and staff[j].get("spot", {}).get("where", "") == "rest":
			used[int(staff[j].spot.k) % rs.size()] = true
	var best := -1
	for k in rs.size():
		var near_p: bool = (rs[k].pos as Vector2).distance_to(pa) < (rs[k].pos as Vector2).distance_to(so)
		if near_p == pantry and not used.has(k):
			best = k
			break
	if best < 0:
		best = int(staff[i].get("spot", {}).get("k", 0)) % rs.size()
	staff[i].spot = {"where": "rest", "k": best}
	return best


func _act_go(i: int, to: Vector2, rot: float, on_arrive: Callable) -> void:
	var s: Dictionary = staff[i]
	var arrive := func() -> void:
		s.tween = null
		(s.node as Node3D).rotation_degrees.y = rot
		on_arrive.call()
	if (s.node as Node3D).position.distance_to(layout.m3(to)) < 0.03:
		arrive.call()
		return
	s.tween = walk(i, to, 0.6, WALK_MAX_S)
	if s.tween == null:
		(s.node as Node3D).position = layout.m3(to)
		arrive.call()
	else:
		(s.tween as Tween).tween_property(s.node, "position", layout.m3(to), 0.12)
		(s.tween as Tween).tween_callback(arrive)


## 행동 끝: 소파에서 일어나 앞으로 나옴 · 손에 든 컵 내려놓음 (keep = 들고 감, ⑪)
func _leave_act(i: int, keep := "") -> void:
	var s: Dictionary = staff[i]
	if s.get("act_exit") != null:
		(s.node as Node3D).position = s.act_exit
		s.act_exit = null
	if s.get("swivel") != null:
		(s.swivel as Tween).kill()
		s.swivel = null
	s.act = ""
	if str(s.get("held", "")) != keep:
		hold(i, "")


## 성격별 버릇 1번 (앉은 자리): 부지런 = 모니터 닦기 · 느긋 = 의자 빙글 · 수다 = 두리번 · 조용 = 펜 돌리기 → 끝나면 원래 동작
func play_quirk(i: int) -> void:
	var s: Dictionary = staff[i]
	var q: String = idle_cfg.get("quirks", {}).get(person_of(s), "SitLook")
	var anim: AnimationPlayer = s.anim
	var back: String = anim.current_animation if anim.current_animation != "" else "Sit"
	if q == "swivel":
		var node: Node3D = s.node
		var y0 := node.rotation.y
		var tw := node.create_tween()
		tw.tween_property(node, "rotation:y", y0 + 0.6, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(node, "rotation:y", y0 - 0.45, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(node, "rotation:y", y0, 0.6).set_trans(Tween.TRANS_SINE)
		s.swivel = tw
		anim.play("SitRest", 0.2)
		tw.tween_callback(anim.play.bind(back, 0.3))
		s.last_quirk = q
		return
	anim.play(q, 0.2)
	anim.queue(back)
	s.last_quirk = q


## 오른손에 소품 들기 ("" = 내려놓음). fore_R 뼈 끝 (손) 에 붙임
func hold(i: int, kind: String) -> void:
	var s: Dictionary = staff[i]
	if s.get("held_node") != null:
		(s.held_node as Node3D).get_parent().queue_free()
		s.held_node = null
	s.held = kind
	if kind == "":
		return
	var sk := (s.node as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	var ba: Node3D
	if kind == "box":   # 짐 상자 = 두 손으로 가슴 앞 (뼈 대신 몸 기준, HoldBox · WalkBox)
		ba = Node3D.new()
		(s.node as Node3D).add_child(ba)
	else:
		ba = BoneAttachment3D.new()
		(ba as BoneAttachment3D).bone_name = "fore_R"
		sk.add_child(ba)
	var p := (PROPS[kind] as PackedScene).instantiate() as Node3D
	p.name = "Held_" + kind
	ba.add_child(p)
	if kind == "box":
		p.position = Vector3(0, BOX_Y, -BOX_Z)   # 직원 앞 = -z
	else:
		p.position = Vector3(0, 0.1, 0) + (Vector3(0, 0, 0.03) if kind == "papers" else Vector3(0, -0.04, 0))   # 손 끝 (뼈 길이 ≈ 0.09)
	s.held_node = p


## ② '방금 쓴 도구' (office_routine 이 확인 때마다 부름): 종류가 바뀌면 동작 · 아이콘 · 소품을 바꿈. 최소 TOOL_MIN_S 초 유지
static func tool_kind(tool: String) -> String:
	return "" if tool == "" else str(TOOL_KIND.get(tool, "other"))


func set_tool(i: int, tool: String) -> void:
	var s: Dictionary = staff[i]
	var k := tool_kind(tool) if s.state == "work" else ""
	if k == str(s.tool_kind) or (k != "" and _now() - float(s.tool_since) < TOOL_MIN_S):
		return
	s.tool_kind = k
	s.tool_since = _now()
	if k == "edit":
		s.edits = mini(int(s.edits) + 1, PAPER_STACK_MAX)
	_tool_props(i)
	if s.tween == null and (s.node as Node3D).visible and str(s.get("act", "")) == "":
		(s.anim as AnimationPlayer).play(_pose_anim(s), 0.2)
	_apply_look(i)


## 멈춤 손 (C16): Esc (PostToolUseFailure is_interrupt) 뒤 잠깐 손 들고 멈춤 — 앉아 일할 때만
func set_stop(i: int, on: bool) -> void:
	var s: Dictionary = staff[i]
	if on == bool(s.stop):
		return
	s.stop = on
	_tool_props(i)
	if s.tween == null and (s.node as Node3D).visible:
		(s.anim as AnimationPlayer).play(_pose_anim(s), 0.12)


## 일이 끝나면 (work 가 아니면) 도구 표시 · 종이 더미 치움
func _tool_reset(i: int) -> void:
	var s: Dictionary = staff[i]
	s.tool_kind = ""
	s.edits = 0
	s.stop = false
	if s.get("desk_papers") != null:
		(s.desk_papers as Node3D).queue_free()
		s.desk_papers = null
	if str(s.get("held", "")) == "papers" and LOOK.get(s.state, LOOK.off).where == "seat":
		hold(i, "")


## 자리에서 쓰는 도구 소품: 읽기 = 손에 서류 · 고치기 = 책상 위 종이 더미 (왼쪽 앞, 고칠 때마다 1장)
func _tool_props(i: int) -> void:
	var s: Dictionary = staff[i]
	var seated: bool = s.state == "work" and s.tween == null and (s.node as Node3D).visible and str(s.get("act", "")) == ""
	var read: bool = seated and str(s.tool_kind) == "read" and not s.fail and not s.stop
	if read and str(s.get("held", "")) == "":
		hold(i, "papers")
	elif not read and str(s.get("held", "")) == "papers" and s.state == "work":
		hold(i, "")
	var n := int(s.edits) if s.state == "work" and not s.desk.is_empty() and int(s.borrow_j) < 0 else 0
	var dpn: Node3D = s.get("desk_papers")
	if dpn != null and dpn.get_child_count() == n:
		return
	if dpn != null:
		dpn.queue_free()
		s.desk_papers = null
	if n <= 0:
		return
	dpn = Node3D.new()
	dpn.name = "DeskPapers"
	var r := deg_to_rad(float(s.desk.rot))
	var side := Vector2(cos(r), -sin(r)) * -0.34 + Vector2(-sin(r), -cos(r)) * 0.33   # 직원 왼쪽 앞 (컵은 오른쪽)
	dpn.position = layout.m3(s.desk.seat + side, DESK_TOP)
	dpn.rotation.y = r
	add_child(dpn)
	for k in n:
		var p := (PROPS.papers as PackedScene).instantiate() as Node3D
		p.scale = Vector3.ONE * layout.unit_m
		p.position.y = k * 0.03 * layout.unit_m
		p.rotation.y = [0.0, 0.18, -0.12][k % 3]   # 조금씩 비뚤게 쌓임
		dpn.add_child(p)
	s.desk_papers = dpn


## ⑨ 엄지척 (창구에서 사장이 답함): 서류는 손에 든 채, 엄지 메시를 잠깐 보임
func _thumbs_up(i: int) -> void:
	var s: Dictionary = staff[i]
	if str(s.get("held", "")) == "papers":
		hold(i, "")   # 서류는 창구에 냄
	var anim: AnimationPlayer = s.anim
	anim.play("ThumbsUp", 0.12)
	var th: Node3D = s.get("thumb")
	if th:
		th.visible = true
		get_tree().create_timer(THUMB_S).timeout.connect(func() -> void: th.visible = false)


## ② 실행 = 검은 화면 초록 글자 (화면 메시 UV 와 상관없이 세 방향 투영)
var _term: StandardMaterial3D
func _terminal_mat() -> StandardMaterial3D:
	if _term == null:
		_term = StandardMaterial3D.new()
		var tex := RasterIcons.get_texture("terminal", 64)
		_term.albedo_texture = tex
		_term.emission_enabled = true
		_term.emission_texture = tex
		_term.emission_energy_multiplier = 1.2
		_term.uv1_triplanar = true
		_term.uv1_world_triplanar = true
		_term.uv1_scale = Vector3.ONE * 2.2 / layout.unit_m
		_term.roughness = 0.5
	return _term


## 책상 위 컵 (⑪ 컵 들고 복귀 → 자리에 내려놓음). 자리를 떠나면 치움
func _desk_cup(i: int, on: bool) -> void:
	var s: Dictionary = staff[i]
	if s.get("desk_cup") != null:
		(s.desk_cup as Node3D).queue_free()
		s.desk_cup = null
	if not on or s.desk.is_empty():
		return
	var c := (PROPS.cup as PackedScene).instantiate() as Node3D
	c.name = "DeskCup"
	var r := deg_to_rad(float(s.desk.rot))
	var side := Vector2(cos(r), -sin(r)) * 0.32 + Vector2(-sin(r), -cos(r)) * 0.35   # 직원 오른쪽 앞
	c.position = layout.m3(s.desk.seat + side, DESK_TOP)
	c.scale = Vector3.ONE * layout.unit_m
	add_child(c)
	s.desk_cup = c


## 퇴근 가방 (⑫): 정류장으로 걸어갈 때 등에 멤
func _wear_bag(i: int, on: bool) -> void:
	var s: Dictionary = staff[i]
	if s.get("bag") != null:
		(s.bag as Node3D).queue_free()
		s.bag = null
	if not on or s.guest:
		return
	var b := (PROPS.bag as PackedScene).instantiate() as Node3D
	b.name = "Bag"
	b.position = Vector3(0, 0.3, 0.13)   # 직원 앞 = -z → 등 = +z
	b.rotation_degrees.y = 180.0
	b.scale = Vector3.ONE * layout.unit_m
	(s.node as Node3D).add_child(b)
	s.bag = b


func _walk_anim(i: int) -> String:
	var h := str(staff[i].get("held", ""))
	return "WalkBox" if h == "box" else ("WalkCarry" if h != "" else "Walk")


func _stand_anim(i: int) -> String:
	var h := str(staff[i].get("held", ""))
	return "HoldBox" if h == "box" else ("HoldIdle" if h != "" else "Idle")


## 창구 줄 명패 (M5 3세션째 사용자 "창구에선 그냥 명패 빼자"): 줄에 선 직원은 노랑 '!' 만 — 줄이 좁아 명패가 겹침. 마우스를 올리면 명패
func _queue_tags() -> void:
	for j in staff.size():
		var st: Dictionary = staff[j]
		if st.state == "turn15" and st.get("spot", {}).get("where", "") == "queue":
			(st.tagbox as Node3D).visible = bool(st.get("hover", false))


## 이름판 · 머리 위 아이콘 · 보드칸 · 스탠드 · 모니터 (자리와 상관없는 표시)
func _apply_look(i: int) -> void:
	var s: Dictionary = staff[i]
	var state: String = s.state
	var look: Dictionary = LOOK.get(state, LOOK.off)
	var head_y := STAFF_HEAD
	# 이름판 (어두운 판 + 상태 점 + "이름 직급") — 평소 숨김, 내 차례 · 무소식 · 마우스 올림 때만 (3-3) · 그 위에 큰 아이콘 (노랑 · 회색만)
	var lift := 0.0   # 옆 책상끼리 엇갈린 높이: 짝수 열 이름판을 올림 (정면 카메라라 옆자리 이름판이 같은 높이로 붙음, M3 4세션째) — 뒷줄은 호출 보드와 안 겹치게 덜
	if not s.desk.is_empty() and int(s.desk.col) % 2 == 0 and look.where == "seat":
		lift = TAG_LIFT_BACK if int(s.desk.row) == 0 else TAG_LIFT_FRONT
	var txt := tag_text(s)
	var up := 0.0       # 2줄 명패 (이름 · 폴더, M5 5세션째): 아이콘 · 말풍선 올림
	var tag_dy := 0.0   # 판 가운데 옮김 (+ = 위로 자람, - = 아래로)
	if txt.contains("\n"):
		if int(s.desk.get("row", 1)) == 0 and lift > 0.0:
			tag_dy = -TAG_TWO_UP / 2.0   # 뒷줄 올린 명패는 위로 자라면 호출 보드에 닿음 → 아래로 (아이콘 그대로)
		else:
			up = TAG_TWO_UP
			tag_dy = TAG_TWO_UP / 2.0
			lift *= TAG_TWO_LIFT
	(s.tagbox as Node3D).position.y = (head_y + 0.3 + tag_dy + lift) * layout.unit_m
	(s.tag as Label3D).text = txt
	_layout_tag(s, look)
	(s.tagbox as Node3D).visible = look.head or s.get("hover", false)
	_queue_tags()
	var bubble: Label3D = s.bubble
	bubble.position.y = (head_y + 0.62 + up + lift) * layout.unit_m
	var icon: Node3D = s.icon
	icon.visible = look.head
	var size := icon_cells(bool(look.big), px_per_cell, big_k)
	if icon.visible:
		icon.position.y = (head_y + 0.62 + up + (0.08 if look.big else 0.0) + lift + size / 2.0) * layout.unit_m   # 이름판 위 (안 겹치게, 큰 '!' 는 조금 더 위)
		var bare: bool = look.color == "ffd21f" or look.glyph == "?"   # 내 차례 '!' · 무소식 '?' = 배경 원 없이 동글한 글자 + 진한 테 (M3 4세션째 · M4 4세션째 사용자)
		(s.plate as Sprite3D).texture = (_quest_texture() if look.glyph == "?" else _bang_texture()) if bare else _disc_texture()
		(s.plate as Sprite3D).pixel_size = size * layout.unit_m / 64.0
		(s.plate as Sprite3D).modulate = Color(look.color)
		var lb: Label3D = s.label
		lb.text = "" if bare else look.glyph
		lb.pixel_size = size * layout.unit_m / 64.0
		lb.modulate = Color.WHITE
		bubble.position.y = icon.position.y + (size / 2.0 + 0.12) * layout.unit_m
	_show_bubble(i)
	var di := i
	if i >= board_cells.size():
		if int(s.borrow_j) < 0:
			return   # 인턴은 보드칸 · 책상이 없음
		di = int(s.borrow_j)   # 빌린 책상의 스탠드 · 모니터만 (보드칸은 주인 것)
	else:
		# 호출 보드 램프칸 (상태의 기준, 늘 주인 것)
		var cell: MeshInstance3D = board_cells[i]
		_set_glow(cell, Color(look.color) if look.color != "" else Color(C_DARK).darkened(0.3), look.color != "")
		if state == "off":
			for g in range(board_cells.size(), staff.size()):   # 퇴근한 내 책상을 인턴이 빌려 쓰는 중이면 스탠드 · 모니터는 인턴 것
				if int(staff[g].borrow_j) == i and staff[g].state != "off":
					_apply_look(g)
					return
	var dp: Dictionary = desk_parts[di]
	_set_glow(dp.bulb, Color("fff6e8") if look.lamp else Color("cfcac2"), look.lamp)
	(dp.light as Node3D).visible = look.lamp
	_set_glow(dp.screen, Color("cfe3ee") if state in ["work", "watch", "turn", "unknown"] else Color("3a3a3c"), state in ["work", "watch", "turn"])
	if state == "work" and str(s.get("tool_kind", "")) == "run":   # ② 실행 = 검은 화면 초록 글자
		(dp.screen as MeshInstance3D).material_override = _terminal_mat()


## 머리 위 아이콘 크기 (칸): 작은 '!' · '?' 는 창이 작아도 16px, 큰 '!' 는 크기 단계만큼 키움 (크기 14 = 400px 흐림 그림에서 16px)
static func icon_cells(big: bool, ppc: float, bk: float) -> float:
	var floor_cells := ICON_MIN_PX / maxf(ppc, 1.0)
	var small := maxf(ICON_SMALL, floor_cells)
	if not big:
		return small
	return maxf(ICON_BIG * maxf(bk, 1.0) * (ICON_BLUR if bk > 1.0 else 1.0), small * ICON_BIG / ICON_SMALL)


## 창 배율 · 크기 단계가 바뀌면 (main._update_layout) 아이콘 크기 다시
func set_icon_scale(ppc: float, bk: float) -> void:
	px_per_cell = ppc
	big_k = bk
	for i in staff.size():
		_apply_look(i)


## 봉투 (서브에이전트 끝, 5-1 v2.5): 뒤쪽 하늘에서 그 직원 책상으로 1.2초 곡선 → 사라짐 (소리 없음). 손님은 머리 위로
func fly_envelope(i: int, secs := 1.2) -> Tween:
	var s: Dictionary = staff[i]
	var u := layout.unit_m
	var to: Vector3 = (s.node as Node3D).position + Vector3(0, 0.6 * u, 0) if s.desk.is_empty() else layout.m3(s.desk.pos, DESK_TOP + 0.03)
	var from := to + Vector3(-1.4, 2.4, -1.2) * u
	var env := (PROPS.envelope as PackedScene).instantiate() as Node3D   # 흰 봉투 + 하늘색 봉인 (M4 4세션째 A)
	env.scale = Vector3.ONE * u * 1.4
	env.name = "Envelope"
	env.position = from
	add_child(env)
	var tw := env.create_tween()
	tw.tween_method(func(k: float) -> void:
		env.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.7 * u, 0)
		env.rotation.y = k * TAU * 0.5, 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(env.queue_free)
	return tw


## 종이비행기 (일 받기, v2.8 C4): 사장 책상 위에서 떠서 담당 직원 책상으로 활공 → 내려앉아 사라지고 직원이 꾸벅
func fly_plane(i: int, secs := 1.6) -> Tween:
	var s: Dictionary = staff[i]
	var u := layout.unit_m
	var to: Vector3 = (s.node as Node3D).position + Vector3(0, 0.6 * u, 0) if s.desk.is_empty() else layout.m3(s.desk.pos, DESK_TOP + 0.04)
	var from: Vector3 = boss.get("plane_from", to + Vector3(1.5, 1.0, 1.0) * u)
	var wait := 0.0
	if boss_present():   # 사장이 직접 던짐: 팔 올렸다 휙 (0.6초에 손에서 놓음) → 손 높이에서 출발
		(boss.report as Node3D).visible = false
		(boss.anim as AnimationPlayer).play("SitThrow", 0.15)
		from = (boss.fig as Node3D).global_position + Vector3(0, 0.62, 0)
		wait = 0.6
	var pl := PAPER_PLANE.instantiate() as Node3D
	pl.name = "PaperPlane"
	pl.scale = Vector3.ONE * u * 2.2   # 모델은 작음 (책상 위 소품 크기) → 날 때는 보이게 키움
	for mi in pl.find_children("*", "MeshInstance3D", true, false):   # 접은 종이 = 얇은 면 → 위에서도 보이게 양면
		var m := (mi as MeshInstance3D).get_active_material(0).duplicate() as BaseMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		(mi as MeshInstance3D).material_override = m
	pl.position = from
	pl.visible = wait <= 0.0
	add_child(pl)
	var tw := pl.create_tween()
	if wait > 0.0:
		tw.tween_interval(wait)
		tw.tween_callback(pl.show)
	var prev := [from]
	tw.tween_method(func(k: float) -> void:
		var tgt := to   # 직원이 아직 자리에 없으면 (걸어오는 중 · 휴게) 직원을 따라감 (M4 실화면: 빈 책상에 내려앉던 것)
		var nd := s.node as Node3D
		if s.desk.is_empty() or nd.position.distance_to(layout.m3(s.desk.seat)) > 0.3 * u:
			tgt = nd.position + Vector3(0, 0.6 * u, 0)
		var p := from.lerp(tgt, k) + Vector3(0, sin(k * PI) * 0.9 * u, 0)   # 위로 휘는 활공
		if p.distance_to(prev[0]) > 0.0001:
			pl.look_at(p + (p - prev[0]), Vector3.UP)   # 모델 코 = -z → 나는 쪽
		prev[0] = p
		pl.position = p, 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		pl.queue_free()
		bow(i))
	return tw


## ------------------------------------------------------------------ 출퇴근 버스 (하늘 통근버스 A, ⑧ · ⑫)
## 누가 출근 · 퇴근하면 뒤에서 날아와 승강장 왼쪽 하늘에 앞을 카메라 쪽으로 두고 섬 (옆으로 대면 창 밖으로 잘림) →
## 아무도 안 오가고 hold 가 지나면 그대로 앞으로 날아 떠남. 보이는 동안만 창 모양 (dynamic_bounds) 에 넣음. 개발 인자 `--bus` = 계속 정류장에


func _bus_build() -> void:
	bus = BUS.instantiate() as Node3D
	bus.name = "Bus"
	bus.scale = Vector3.ONE * layout.unit_m   # 모델 = 칸 단위 (길이 2.7, 직원 크기에 맞춤)
	bus.visible = false
	add_child(bus)
	var tm := Timer.new()
	tm.wait_time = 0.5
	tm.timeout.connect(_bus_tick)
	add_child(tm)
	tm.start()
	if "--bus" in Game.dev_args():
		bus_call(3600.0)
		bus.position = _bus_park()
		bus.rotation.y = BUS_YAW
		bus_state = "docked"


const BUS_YAW := -PI / 2   ## 모델 앞 (+x) → 카메라 쪽 (+z)


func _bus_park() -> Vector3:   # 승강장 왼쪽 끝 바로 옆 (폭 0.95), 가운데 = 정류장 (dock) 줄
	var p := layout.zone_rect("pier")
	return layout.m3(Vector2(p.position.x - 0.1 - 0.5, layout.slot("dock").y), -0.05)


func _bus_show(on: bool) -> void:
	bus.visible = on
	if on and not bus.is_in_group("dynamic_bounds"):
		bus.add_to_group("dynamic_bounds")
		var spin := bus.create_tween().set_loops()   # 지붕 프로펠러
		for k in 2:
			var r := bus.find_child("Rotor%d" % k, true, false) as Node3D
			if r:
				spin.parallel().tween_property(r, "rotation:y", r.rotation.y + TAU, 0.35).from(r.rotation.y)
		bus.set_meta("spin", spin)
	elif not on and bus.is_in_group("dynamic_bounds"):
		bus.remove_from_group("dynamic_bounds")
		(bus.get_meta("spin") as Tween).kill()


func bus_call(hold_s := 3.0) -> void:
	bus_hold = maxi(bus_hold, Time.get_ticks_msec() + int(hold_s * 1000.0))
	if bus == null or bus_state in ["coming", "docked"]:
		return
	bus_state = "coming"
	var park := _bus_park()
	if bus.has_meta("move"):
		(bus.get_meta("move") as Tween).kill()
	if not bus.visible:
		bus.position = park + Vector3(-1.5, 1.2, -6.0) * layout.unit_m   # 뒤 하늘에서
		bus.rotation.y = BUS_YAW
		_bus_show(true)
	var tw := bus.create_tween()
	bus.set_meta("move", tw)
	tw.tween_property(bus, "position", park, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: bus_state = "docked")


func _bus_tick() -> void:
	if bus_state != "docked" or Time.get_ticks_msec() < bus_hold or staff.any(func(s): return s.get("leaving", false)):
		return
	bus_state = "leaving"
	var park := _bus_park()
	var tw := bus.create_tween()
	bus.set_meta("move", tw)
	tw.tween_property(bus, "position", park + Vector3(0, 0.4, 0.2) * layout.unit_m, 0.5).set_trans(Tween.TRANS_SINE)   # 떠오르며
	tw.tween_property(bus, "position", park + Vector3(-1.5, 1.0, 6.0) * layout.unit_m, 1.4)   # 앞 (카메라 아래쪽) 으로.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if bus_state == "leaving":
			_bus_show(false)
			bus_state = "away")


## 복장 (M4 사용자): 셔츠 · 후드 · 니트 중 무작위 하나 (인턴 = 조끼만). k 를 주면 그 옷
func dress(i: int, k := -1) -> void:
	var s: Dictionary = staff[i]
	if not s.has("outfits"):
		return
	if k < 0:
		k = randi() % OUTFITS.size()
	for j in OUTFITS.size():
		var o := s.outfits[j] as Node3D
		if o:
			o.visible = not s.guest and j == k
	s.outfit = k


## 꾸벅 (일 받기 · 인사): 몸을 앞으로 숙였다 펴기 1번
func bow(i: int) -> void:
	var node := staff[i].node as Node3D
	if not node.visible:
		return
	var tw := node.create_tween()
	tw.tween_property(node, "rotation:x", -0.32, 0.18).set_ease(Tween.EASE_OUT)   # 직원 앞 = -z → 음수 = 앞으로 숙임
	tw.tween_property(node, "rotation:x", 0.0, 0.25).set_ease(Tween.EASE_IN_OUT)


## 마우스를 올린 직원의 이름판 · 말풍선 보이기 (M3: office_routine 이 ray_pick 으로 연결)
func set_hover(i: int, on: bool) -> void:
	if bool(staff[i].get("hover", false)) == on:
		return
	staff[i].hover = on
	_apply_look(i)


## 말풍선 문구 (정해진 짧은 문구 12자 이하, 3-3) — 마우스를 올렸을 때만 보임. say 는 끼어들기 같은 잠깐 문구 (마우스 없이도 보임)
func set_bubble(i: int, text: String) -> void:
	if staff[i].bubble_text == text:
		return
	staff[i].bubble_text = text
	_show_bubble(i)


func say(i: int, text: String, secs := 1.5) -> void:
	staff[i].say_text = text
	staff[i].say_until = Time.get_ticks_msec() + int(secs * 1000.0)
	_show_bubble(i)
	get_tree().create_timer(secs + 0.05).timeout.connect(_show_bubble.bind(i))


func _show_bubble(i: int) -> void:
	var s: Dictionary = staff[i]
	var b: Label3D = s.bubble
	var said := str(s.say_text) != "" and Time.get_ticks_msec() < int(s.say_until)
	b.text = str(s.say_text) if said else str(s.bubble_text)
	b.visible = s.state != "off" and b.text != "" and (said or bool(s.get("hover", false)))
	if b.visible:   # 판 폭 = 글자 폭 + 여백 (글자 픽셀 단위)
		var w := b.font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.font_size).x + 26.0
		var bg := b.get_node("BubbleBg") as Sprite3D
		bg.pixel_size = b.pixel_size * 48.0 / 36.0   # 판 높이 = 글자 48px 상당 (텍스처 36px)
		bg.scale = Vector3(w * b.pixel_size / (128.0 * bg.pixel_size), 1, 1)
		var tail := b.get_node("BubbleTail") as Sprite3D
		tail.pixel_size = b.pixel_size
		tail.offset.y = -24.0 - 4.0   # 판 아래 가장자리 바로 밑 (꼬리 높이 12px, 3px 겹침 = 판 테를 덮어 이어 보이게)


## 칩 바 내용: 출근한 직원만, 노랑 (내 차례) 이 맨 앞
func chips() -> Array:
	var out: Array = []
	for s in staff:
		if s.state == "off":
			continue
		var look: Dictionary = LOOK[s.state]
		out.append({"name": s.name, "color": look.color if look.color != "" else "b9b3aa", "glyph": look.glyph,
				"turn": s.state in ["turn", "turn15"]})
	out.sort_custom(func(a, b): return a.turn and not b.turn)
	return out


## 깃발: 창구에 한 명이라도 서 있으면 노랑 깃발이 꼭대기로 (평소엔 내려간 회색)
func _update_flag() -> void:
	if flag == null:
		return
	var up := staff.any(func(s): return s.state == "turn15")
	var h := float(layout.fixed("flagpole").height)
	var fy := float(layout.fixed("flagpole").get("base_y", 0.0))
	flag.position.y = (fy + (h - 0.25 if up else h * 0.35)) * layout.unit_m
	flag.scale = Vector3.ONE * (1.3 if up else 1.0)   # 올라가면 조금 크게 (M3: 흐림 그림에서 깃발 노랑이 흐리게 보이던 것)
	_set_glow(flag, Color("ffd21f") if up else Color("a9a49b"), up, up)   # 올라간 깃발은 그늘 없는 노랑 그대로


func _add_staff(d: Dictionary) -> void:
	var u := layout.unit_m
	var root := Node3D.new()
	root.name = "Staff_%d" % d.id
	add_child(root)
	var model := STAFF_MODEL.instantiate() as Node3D
	model.rotation_degrees.y = 180.0   # 모델 앞 = +z → 직원 앞 = -z (자리 rot 기준)
	root.add_child(model)
	var guest: bool = d.get("guest", false)
	var shirt: String = C_GUEST_SHIRT if guest else SHIRTS[d.id % SHIRTS.size()]
	_paint_staff(model, shirt, HAIRS[d.id % HAIRS.size()])
	var vest := model.find_child("Vest", true, false) as Node3D   # 인턴만 조끼 (M4)
	if vest:
		vest.visible = guest
	_wear_acc(model, "" if guest else ACCESSORIES[(d.id * 7 + 3) % ACCESSORIES.size()])
	var outfits: Array = OUTFITS.map(func(n): return model.find_child(n, true, false))
	var thumb := model.find_child("Thumb", true, false) as Node3D   # ⑨ 엄지척 때만 보임
	if thumb:
		thumb.visible = false
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in LOOP_ANIMS:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# 가림 시험 · 마우스 판정용 대리 상자 (안 보임): 몸 · 머리
	var body := _mesh(_box(Vector3(0.3, 0.55, 0.26) * u), shirt)
	body.position.y = 0.36 * u
	body.visible = false
	root.add_child(body)
	var head := _mesh(_sphere(0.15 * u), "e8c4a0")   # 머리 반지름 0.2칸 — 시험은 상자 (AABB) 꼭짓점으로 재므로 0.2/√2 ≈ 0.15 로 화면 크기를 맞춤
	head.position.y = STAFF_HEAD * u
	head.visible = false
	root.add_child(head)
	var tagbox := Node3D.new()   # 이름판 = 어두운 판 + 상태 점 + 이름 (Claw3D 식, v2.5)
	root.add_child(tagbox)
	var bg := Sprite3D.new()
	bg.texture = _plate_texture()
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.no_depth_test = true
	bg.render_priority = 8
	bg.shaded = false
	tagbox.add_child(bg)
	var tag := _label(40, 9)
	tag.text = "인턴" if guest else NAMES[d.id % NAMES.size()]
	tag.modulate = Color("3a3f4a")
	tagbox.add_child(tag)
	var dot := _label(40, 9)
	tagbox.add_child(dot)
	var stripe := Sprite3D.new()   # 프로젝트 색 줄 (이름판 왼쪽, M3 5세션째)
	stripe.texture = _stripe_texture()
	stripe.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stripe.no_depth_test = true
	stripe.render_priority = 9
	stripe.shaded = false
	stripe.visible = false
	tagbox.add_child(stripe)
	var tool_icon := Sprite3D.new()   # '방금 쓴 도구' 아이콘 (상태 점 옆, 아이콘 7장 A 흰 원 — M4 5세션째)
	tool_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tool_icon.no_depth_test = true
	tool_icon.render_priority = 9
	tool_icon.shaded = false
	tool_icon.visible = false
	tagbox.add_child(tool_icon)
	var icon := Node3D.new()
	root.add_child(icon)
	var plate := Sprite3D.new()
	plate.texture = _disc_texture()
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 10
	plate.shaded = false
	icon.add_child(plate)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 11
	label.font = _glyph_font()   # 회색 상자용 글자 아이콘 (M4 에서 아이콘 7장으로 교체)
	label.font_size = 44
	label.outline_size = 0
	label.position.z = 0.01
	icon.add_child(label)
	var sweat := Node3D.new()   # 실패 땀방울 3개 (5-1 ⑤, M4 1세션째 사용자 B) — 머리 긁기와 함께 3초
	sweat.visible = false
	root.add_child(sweat)
	for o in SWEAT:
		var dr := Sprite3D.new()
		dr.texture = _drop_texture()
		dr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dr.no_depth_test = true
		dr.render_priority = 7
		dr.shaded = false
		sweat.add_child(dr)
	var bubble := _label(32, 12)   # 말풍선: 정해진 짧은 문구 (마우스 올림 · 끼어들기, 3-3) — 흰 둥근 판 + 꼬리, 글자 0.8배 (M4 3세션째)
	bubble.modulate = Color("2b2622")
	bubble.pixel_size *= BUBBLE_K
	bubble.visible = false
	root.add_child(bubble)
	for k in 2:   # 판 · 꼬리 (말풍선 글자의 자식 → 같이 보이고 숨음)
		var sp := Sprite3D.new()
		sp.name = "BubbleBg" if k == 0 else "BubbleTail"
		sp.texture = _bubble_texture() if k == 0 else _tail_texture()
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.render_priority = 11
		sp.shaded = false
		bubble.add_child(sp)
	staff.append({"node": root, "model": model, "team": "", "person": -1, "body": body, "head": head, "anim": anim, "icon": icon, "plate": plate, "label": label, "tag": tag,
			"tagbox": tagbox, "tag_bg": bg, "dot": dot, "stripe": stripe, "color": "", "borrow": {}, "borrow_j": -1, "bubble": bubble, "bubble_text": "", "say_text": "", "say_until": 0,
			"tween": null, "leaving": false, "spot": {}, "hover": false, "sweat": sweat, "fail": false, "vest": vest, "outfits": outfits, "guest": guest,
			"name": tag.text, "days": 0, "state": "off", "desk": {} if guest else d, "id": int(d.id),
			"act": "", "act_until": 0.0, "act_exit": null, "held": "", "held_node": null, "greet": false, "quirk_at": 0.0,
			"thumb": thumb, "tool_icon": tool_icon, "tool_kind": "", "tool_since": -1.0e9, "edits": 0, "desk_papers": null, "stop": false})
	dress(staff.size() - 1)   # 첫 옷 (무작위)


## 직원 모델의 셔츠 · 머리 재질만 직원 색으로 (같은 메시를 함께 쓰므로 인스턴스별 덮어쓰기)
func _paint_staff(model: Node3D, shirt: String, hair: String) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(k) as BaseMaterial3D
			if src and src.resource_name in ["Shirt", "Hair", "Accent"]:
				var mat := src.duplicate() as BaseMaterial3D
				mat.albedo_color = {"Shirt": Color(shirt), "Hair": Color(hair), "Accent": Color(shirt).darkened(0.32)}[src.resource_name]   # 포인트 = 같은 색 진하게 (톤온톤)
				m.set_surface_override_material(k, mat)


const TAG_H := 0.23   ## 이름판 글자 높이 (칸) — 창 100% 에서 약 12px, 옆자리 이름판과 안 겹치게
const TAG_LIFT_BACK := 0.6    ## 짝수 열 이름판 올림 (칸) 뒷줄 · 앞줄 — 정면 0° 에서 옆자리와 안 겹치게 (15° 땐 0.3 · 0.42)
const TAG_LIFT_FRONT := 0.56
const TAG_TWO_UP := 0.3        ## 2줄 명패: 판이 위로 더 자라는 높이 (칸)
const TAG_TWO_LIFT := 1.5      ## 2줄 명패: 짝수 열 엇갈림 배율
const TAG_MAX_CHARS := 10      ## 프로젝트 이름이 길면 10자에서 '…'
const BUBBLE_K := 0.8          ## 말풍선 글자 = 이름판 글자의 0.8배 (약 10px, 사용자 0.8 · 0.9 · 1.0 비교 뒤 0.8)


func _label(size: int, prio: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = prio
	l.font = _glyph_font()
	l.font_size = size
	l.pixel_size = TAG_H * layout.unit_m / float(size)
	l.outline_size = 0
	return l


## 이름판 안 배치: [점][간격][이름 직급] 을 가운데 정렬, 판은 그 폭 + 여백 (글자 픽셀 단위로 계산)
func _layout_tag(s: Dictionary, look: Dictionary) -> void:
	var tag: Label3D = s.tag
	var dot: Label3D = s.dot
	var bg: Sprite3D = s.tag_bg
	dot.visible = look.glyph != ""
	dot.text = look.glyph
	dot.modulate = Color(look.color) if look.color != "" else Color.WHITE
	if look.get("guess", false):
		dot.modulate.a = 0.55   # 관찰 모드 = 추정 → 반투명 점 (5-1)
	var text_w := tag.font.get_multiline_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size).x
	var two := tag.text.contains("\n")   # 2줄 명패 (이름 · 폴더) = 판을 1.8배 높이로
	var dot_w := 34.0 if dot.visible else 0.0
	var ti: Sprite3D = s.tool_icon
	ti.visible = s.state == "work" and str(s.get("tool_kind", "")) != ""
	if ti.visible:
		ti.texture = RasterIcons.tool_texture(str(s.tool_kind), "A", 64)
		ti.pixel_size = tag.pixel_size * 34.0 / 64.0   # 상태 점과 같은 34px 칸
		dot_w += 40.0
	var gap := 8.0 if dot.visible else 0.0
	var stripe: Sprite3D = s.stripe
	stripe.visible = str(s.color) != ""
	var st_w := 14.0 if stripe.visible else 0.0   # 색 줄 8px + 간격 6px
	var total := st_w + dot_w + gap + text_w
	var left := -total / 2.0
	if stripe.visible:
		stripe.modulate = Color(str(s.color))
		stripe.pixel_size = tag.pixel_size
		stripe.offset.x = left + 4.0
	dot.offset.x = left + st_w + (dot_w - (40.0 if ti.visible else 0.0)) / 2.0
	if ti.visible:
		ti.offset.x = (left + st_w + dot_w - 20.0) / (ti.pixel_size / tag.pixel_size)   # 점 바로 오른쪽 (offset 은 자기 픽셀 단위)
	tag.offset.x = left + st_w + dot_w + gap + text_w / 2.0
	var bg_px := tag.pixel_size * 56.0 / 32.0   # 판 높이 = 글자 56px 상당
	bg.pixel_size = bg_px
	bg.scale = Vector3((total + 26.0) * tag.pixel_size / (128.0 * bg_px), 1.8 if two else 1.0, 1)


## 흰 둥근 카드 (128×32, 밝은 사무실 비교 O)
var _plate: ImageTexture
func _plate_texture() -> ImageTexture:
	if _plate:
		return _plate
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	var col := Color(0.99, 0.98, 0.96, 0.94)
	for x in 128:
		for y in 32:
			var cx := clampf(x + 0.5, 16.0, 112.0)
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, 16)) <= 15.5:
				img.set_pixel(x, y, col)
	_plate = ImageTexture.create_from_image(img)
	return _plate


## 프로젝트 색 줄 (8×30, 둥근 끝, 흰색 → modulate 로 색)
var _stripe: ImageTexture
func _stripe_texture() -> ImageTexture:
	if _stripe:
		return _stripe
	var img := Image.create(8, 30, false, Image.FORMAT_RGBA8)
	for x in 8:
		for y in 30:
			var cy := clampf(y + 0.5, 4.0, 26.0)
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(4, cy)) <= 4.0:
				img.set_pixel(x, y, Color.WHITE)
	_stripe = ImageTexture.create_from_image(img)
	return _stripe


var _font: Font
## 게임 안 글자 (말풍선 · 간판 · 이름판 · 아이콘) = 주아 (둥글둥글, M4 사용자 · OFL, assets/fonts) + 없는 기호는 시스템 글꼴로
func _glyph_font() -> Font:
	if _font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI Symbol", "Segoe UI"])
		sys.font_weight = 700
		_font = (JUA as FontFile).duplicate() as FontFile
		_font.fallbacks = [sys]
	return _font


## 받침판 (진한 테두리 + 흰 안쪽 → modulate 로 상태 색) — 하늘 배경과 겹쳐도 읽히게 (3-3)
var _disc: ImageTexture
func _disc_texture() -> ImageTexture:
	if _disc:
		return _disc
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 64:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(32, 32))
			if r <= 31.5:
				img.set_pixel(x, y, Color(0.18, 0.16, 0.15) if r > 26.5 else Color.WHITE)
	_disc = ImageTexture.create_from_image(img)
	return _disc


## 말풍선 판: 따뜻한 흰색 둥근 사각 + 진한 테 3px (128×36 — 화면에선 약 13px 높이라 테가 두꺼워야 보임)
var _bubble: ImageTexture
func _bubble_texture() -> ImageTexture:
	if _bubble:
		return _bubble
	var img := Image.create(128, 36, false, Image.FORMAT_RGBA8)
	var r := 13.0
	for x in 128:
		for y in 36:
			var q := Vector2(clampf(x + 0.5, r + 1, 127 - r), clampf(y + 0.5, r + 1, 35 - r))
			var d := Vector2(x + 0.5, y + 0.5).distance_to(q)
			if d <= r:
				img.set_pixel(x, y, Color("fffdf8") if d <= r - 3.0 else Color("4a433c"))
	_bubble = ImageTexture.create_from_image(img)
	return _bubble


## 말풍선 꼬리: 아래를 가리키는 작은 삼각형 (16×12, 판과 같은 색 + 양옆 테)
var _tail: ImageTexture
func _tail_texture() -> ImageTexture:
	if _tail:
		return _tail
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		var half := 8.0 * (1.0 - (y + 0.5) / 12.0)   # 위가 넓고 아래가 뾰족
		for x in 16:
			var dx := absf(x + 0.5 - 8.0)
			if dx <= half:
				img.set_pixel(x, y, Color("fffdf8") if (dx <= half - 2.5 or y < 3) else Color("4a433c"))
	_tail = ImageTexture.create_from_image(img)
	return _tail


## 땀방울: 위가 뾰족 · 아래가 둥근 연하늘 방울 + 진한 파랑 테 + 흰 반짝 (빨강 안 씀), 32px
var _drop: ImageTexture
func _drop_texture() -> ImageTexture:
	if _drop:
		return _drop
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c := Vector2(16, 21)
	var r := 8.0
	for x in 32:
		for y in 32:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c) - r   # 아래 원
			if p.y < c.y:   # 위 뾰족: 높이에 따라 반지름이 줄어드는 원뿔
				var t := clampf((c.y - p.y) / 15.0, 0.0, 1.0)
				d = minf(d, absf(p.x - c.x) - r * (1.0 - t) * 0.95)
				if t >= 1.0:
					d = maxf(d, 1.0)
			var alpha := clampf(2.5 - d, 0.0, 1.0)   # 테 2px
			if alpha <= 0.0:
				continue
			var col := Color("285a8c").lerp(Color("aadefa"), clampf(0.5 - d, 0.0, 1.0))
			if p.distance_to(c + Vector2(-3, -1)) < 2.2:
				col = Color.WHITE
			col.a = alpha
			img.set_pixel(x, y, col)
	_drop = ImageTexture.create_from_image(img)
	return _drop


## 내 차례 '!' (M3 4세션째 사용자 "배경 없이 · 좀 더 동글한"): 위가 통통하고 아래로 가늘어지는 둥근 막대 + 동그란 점,
##   진한 테 + 흰 안쪽 → modulate 로 노랑. 가장자리는 부드럽게 (반 픽셀 섞음)
var _bang: ImageTexture
var _quest: ImageTexture
func _bang_texture() -> ImageTexture:
	if _bang:
		return _bang
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var a := Vector2(32, 15)
	var b := Vector2(32, 37)
	var dark := Color(0.17, 0.15, 0.13)
	for x in 64:
		for y in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			var d := minf(p.distance_to(a.lerp(b, t)) - lerpf(8.5, 5.0, t), p.distance_to(Vector2(32, 51.5)) - 6.5)
			var alpha := clampf(4.5 - d, 0.0, 1.0)   # 테 바깥 4px
			if alpha <= 0.0:
				continue
			var c := dark.lerp(Color.WHITE, clampf(0.5 - d, 0.0, 1.0))
			c.a = alpha
			img.set_pixel(x, y, c)
	_bang = ImageTexture.create_from_image(img)
	return _bang



## 무소식 '?' — '!' 와 같은 식 (동글한 굵은 획 + 진한 테 4px, 배경 원 없음). 위 고리 + 짧은 줄기 + 점
func _quest_texture() -> ImageTexture:
	if _quest:
		return _quest
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var c := Vector2(32, 20)
	var r := 10.5
	var e := c + Vector2(cos(PI / 3.0), sin(PI / 3.0)) * r   # 고리 끝 (오른쪽 아래)
	var st := Vector2(32, 37)
	var dark := Color(0.17, 0.15, 0.13)
	for x in 64:
		for y in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var ang := atan2(p.y - c.y, p.x - c.x)
			var d_arc := absf(p.distance_to(c) - r) - 5.0 if ang <= PI / 3.0 else minf(p.distance_to(c - Vector2(r, 0)), p.distance_to(e)) - 5.0
			var t := clampf((p - e).dot(st - e) / (st - e).length_squared(), 0.0, 1.0)
			var d_stem := p.distance_to(e.lerp(st, t)) - lerpf(5.0, 4.5, t)
			var d := minf(minf(d_arc, d_stem), p.distance_to(Vector2(32, 51.5)) - 6.5)
			var alpha := clampf(4.5 - d, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var col := dark.lerp(Color.WHITE, clampf(0.5 - d, 0.0, 1.0))
			col.a = alpha
			img.set_pixel(x, y, col)
	_quest = ImageTexture.create_from_image(img)
	return _quest

# ------------------------------------------------------------------ 바닥 (건물 + 구역 색 + 부두)
func _floors() -> void:
	var b := layout.building_rect()
	var f := _block(b.get_center(), b.size, -0.02, 0.03, C_FLOOR.building)
	f.name = "Floor_building"
	island.add_occupied_rect(_mr(b.grow(0.2)))
	for z in ["workroom", "counter", "rest"]:   # 구역 = 바닥재 1개 + 대표 실루엣 1개 (UX 규칙)
		var r: Rect2 = layout.zone_rect(z)
		var fl := _block(r.get_center(), r.size - Vector2(0.1, 0.1), 0.03, 0.04, C_FLOOR[z])
		fl.name = "Floor_" + z
		if z == "counter":   # 창구 = 차가운 타일 (휴게 나무와 대비, v2.6)
			fl.material_override = _tile_mat(C_FLOOR[z], C_TILE_LINE, 0.5)
		elif z == "workroom":   # 작업실 = 카펫 타일 (줄눈 아주 옅게, M4)
			fl.material_override = _plank_mat(C_FLOOR[z])
		elif z == "rest":   # 휴게 = 나무 마루 (M4)
			fl.material_override = _plank_mat(C_FLOOR[z])
	island.add_walk_rect(_mr(b))
	var p: Rect2 = layout.zone_rect("pier")
	_block(p.get_center(), p.size, -0.25, 0.03, C_FLOOR.pier).name = "Floor_pier"
	island.add_walk_rect(_mr(Rect2(p.position, p.size + Vector2(0.2, 0)).grow_individual(-0.1, -0.1, 0, -0.1)))   # 문 (벽 두께) 까지 이어짐


# ------------------------------------------------------------------ 받침: 아래로 좁아지는 바위 (v2.4, 45° 시점에서 보이게 가파르게 · 크리스탈은 뺌 2026-10-16)
func _base() -> void:
	var bs: Dictionary = layout.data.building.base
	var b := layout.building_rect().grow(float(layout.data.building.wall_t))
	var slab := float(bs.slab)
	var h := float(bs.step_h)
	var bottom := -slab - int(bs.steps) * h
	var rock := _prop(ROCK_BASE, b.get_center(), -0.02, 0.0, Vector3(b.size.x, (-0.02 - bottom) / 3.3, b.size.y))   # 울퉁불퉁 바위 (M4, 색 = 모델)
	rock.name = "BaseRock"


# ------------------------------------------------------------------ 건물 벽: 보드 구간만 높게, 나머지 낮은 턱 (3-3)
func _walls() -> void:
	var bd: Dictionary = layout.data.building
	var b := layout.building_rect()
	var t := float(bd.wall_t)
	var lo := float(bd.wall_low)
	var hs := float(bd.high_span) / 2.0
	# 뒷벽 (M4 3세션째, 사용자 "문 · 현황판만 높고 나머지가 너무 낮다"): 가운데 높은 구간 (호출 보드) + 양옆 back_h
	#   back_windows = 양옆에 창 띠 · side_high = 옆벽도 뒤에서 그만큼 back_h (모서리가 방처럼 감쌈)
	var bh := float(bd.get("back_h", lo))
	var win := bool(bd.get("back_windows", false))
	var side := 99.0 if str(bd.get("side_high", 0.0)) == "full" else float(bd.get("side_high", 0.0))   # "full" = 앞줄까지
	for a in Game.dev_args():   # 개발용 (그림 비교): `--back-wall=2.1,win,1.0` (높이 · 창 · 옆벽 높은 길이)
		if a.begins_with("--back-wall="):
			var parts := a.get_slice("=", 1).split(",")
			bh = float(parts[0])
			win = "win" in parts
			side = float(parts[parts.size() - 1]) if parts.size() > 1 and parts[parts.size() - 1].is_valid_float() else 0.0
	_wall(Rect2(-hs, b.position.y - t, hs * 2, t), float(bd.wall_high), C_WALL)
	_back_side(Rect2(b.position.x - t, b.position.y - t, -hs - b.position.x + t, t), bh, win)
	_back_side(Rect2(hs, b.position.y - t, b.end.x - hs + t, t), bh, win)
	var c_side := C_WALL if side > 0.0 else C_WALL_LOW
	side = minf(side, b.size.y)
	if side > 0.0:
		_wall(Rect2(b.end.x, b.position.y, t, side), bh, C_WALL)
	if side < b.size.y:
		_wall(Rect2(b.end.x, b.position.y + side, t, b.size.y - side), lo, C_WALL_LOW)
	_wall(Rect2(b.position.x - t, b.end.y, b.size.x + t * 2, t), lo, C_WALL_LOW)
	# 왼벽: 부두로 나가는 문 자리만 비움
	#   높은 부분 = 뒤에서 side 까지 (문 구간이 그 안이면 문틀 위를 벽으로 채움)
	var zs := b.position.y + side
	var z0 := b.position.y
	var spans: Array = []   # 벽 구간 [z0, z1]
	for d in bd.doors_left:
		spans.append([z0, float(d[0])])
		z0 = float(d[1])
		if float(d[0]) < zs:
			var mid := (float(d[0]) + float(d[1])) / 2.0
			var top := _block(Vector2(b.position.x - t / 2, mid), Vector2(t, float(d[1]) - float(d[0])), 1.32, bh, c_side)   # 문 위 벽
			top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_block(Vector2(b.position.x - t / 2, mid), Vector2(t + 0.04, float(d[1]) - float(d[0]) + 0.04), bh, bh + 0.035, C_WALL_CAP)
	spans.append([z0, b.end.y])
	for sp in spans:
		var a0: float = sp[0]
		var a1: float = sp[1]
		if a0 < zs:
			_wall(Rect2(b.position.x - t, a0, t, minf(a1, zs) - a0), bh, c_side)
		if a1 > zs:
			_wall(Rect2(b.position.x - t, maxf(a0, zs), t, a1 - maxf(a0, zs)), lo, C_WALL_LOW)
	# 작업실 앞 낮은 유리 칸막이 (v2.5) — 가운데 · 오른쪽 끝은 통로
	var gz := float(layout.data.workroom.front_z) + 0.1
	for seg in [[b.position.x + 0.1, -0.7], [0.7, b.end.x - 0.9]]:
		_glass(Vector2((seg[0] + seg[1]) / 2.0, gz), Vector2(seg[1] - seg[0], 0.05), 0.0, 0.6, true)
	# 휴게 | 창구 사이 낮은 벽 + 화분 줄 (v2.6) — 복도 쪽은 열어 둠, 소파 등이 여기에 붙음
	var dx := float(layout.data.zones.divider_x)
	var dz0 := float(layout.data.workroom.front_z) + 0.75
	var dv := _block(Vector2(dx, (dz0 + b.end.y) / 2.0), Vector2(0.12, b.end.y - dz0), 0.0, 0.42, C_WALL_LOW, true)
	dv.name = "Divider"
	var nl := int((b.end.y - dz0) / 0.45)
	for k in nl:
		var leaf := _mesh(_sphere(0.1 * layout.unit_m), "6f8a55")
		leaf.position = layout.m3(Vector2(dx, dz0 + (k + 0.5) * (b.end.y - dz0) / nl), 0.5)
		add_child(leaf)
	# 부두 문틀 (v2.6): 문 양옆 기둥 + 위 가로대
	for d in bd.doors_left:
		for zz in [float(d[0]), float(d[1])]:
			_block(Vector2(b.position.x - t / 2, zz), Vector2(t + 0.06, 0.1), 0.0, 1.3, C_WALL, true)
		var mid := (float(d[0]) + float(d[1])) / 2.0
		_block(Vector2(b.position.x - t / 2, mid), Vector2(t + 0.06, float(d[1]) - float(d[0]) + 0.1), 1.2, 1.32, C_WALL).name = "DoorFrame"


# ------------------------------------------------------------------ 1. 작업실
func _workroom() -> void:
	var w: Dictionary = layout.data.workroom
	var ds := _v2(w.desk_size)
	for d in layout.desks():
		var set := Node3D.new()   # 기준 = 앞줄 (rot 0, 앉은 사람이 -z 를 봄). 책상 · 모니터 · 의자를 자리마다 다르게 조합 (개성, M4 사용자)
		var combo: String = DESK_COMBOS[d.id % DESK_COMBOS.size()]
		for k in 3:
			set.add_child(DESK_PARTS[k][combo[k]].instantiate())
		set.name = "Desk_%d" % d.id
		set.position = layout.m3(d.pos)
		set.rotation_degrees.y = d.rot
		set.scale = Vector3.ONE * layout.unit_m
		add_child(set)
		island.add_solid_rect(_mr(Rect2(d.pos - ds / 2.0, ds)))
		var pers := PERSONAL.instantiate() as Node3D   # 개인 소품 (책상 기준 좌표 = desk_set 과 같음)
		set.add_child(pers)
		for k in 6:
			var item := pers.find_child("Item%d" % k, true, false) as Node3D
			if item:
				item.visible = ((d.id * 5 + k * 3) % 7) < 4   # 책상마다 다른 조합 (서류 트레이 · 펜꽂이 · 달력 · 포스트잇 · 액자 · 다육)
		(set.find_child("ChairBack", true, false) as MeshInstance3D).material_override = _mat(SHIRTS[d.id % SHIRTS.size()])   # 등받이 색 = 직원 보조 구분
		var bulb := set.find_child("Bulb", true, false) as MeshInstance3D
		desk_parts.append({"screen": set.find_child("Screen", true, false), "bulb": bulb, "light": _night_light(bulb.global_position + Vector3(0, 0.1, 0), 0.7, 1.5),
				"chair_back": set.find_child("ChairBack", true, false)})
	# 팀 책상 섬 옆 칸막이 (마주 보는 줄 사이 칸막이는 책상 모델 desk_a · b 안에 있음) — 낮게, 뒷줄 얼굴이 가리지 않게
	var rows: Array = w.rows
	var mid_z := (float(rows[0].desk_z) + float(rows[1].desk_z)) / 2.0
	var n := int(w.pod_cols)
	for c0 in range(0, layout.desk_cols, n):
		var xs: Array = []
		for k in range(c0, mini(c0 + n, layout.desk_cols)):
			xs.append(layout.col_x(k))
		var lo_x: float = xs.min() - ds.x / 2
		var hi_x: float = xs.max() + ds.x / 2
		for k in range(1, xs.size()):
			var px: float = (float(xs[k - 1]) + float(xs[k])) / 2.0
			_block(Vector2(px, mid_z), Vector2(0.04, ds.y * 2 - 0.1), DESK_TOP, DESK_TOP + 0.2, "8e98a3")
	# 호출 보드 (12칸 틀, 안 쓰는 칸은 덮개) — 뒷벽 높은 구간
	var b: Dictionary = layout.fixed("board")
	var bp := _v2(b.pos)
	var bs := _v2(b.size)
	var cells: Array = b.cells
	var bh := float(b.height)
	var panel := _prop(CALL_BOARD, bp, bh, 0.0, Vector3(bs.x / 1.5, bs.y / 0.5, 1.0))   # 흰 틀 + 레일 · 종 (모델 원점 = 판 가운데)
	panel.name = "CallBoard"
	var cw := bs.x / float(cells[0])
	var ch := bs.y / float(cells[1])
	var at := board_index()   # 책상 id → 칸 번호 (책상 배치와 같은 자리, 사용자 2026-10-16)
	var all := {}
	for k in int(cells[0]) * int(cells[1]):
		var cx := bp.x - bs.x / 2 + cw * (k % int(cells[0]) + 0.5)
		var cy := bh + bs.y / 2 - ch * (k / int(cells[0]) + 0.5)
		all[k] = _block(Vector2(cx, bp.y + 0.04), Vector2(cw * 0.78, 0.04), cy - ch * 0.39, cy + ch * 0.39, C_DARK if k in at else "7a7066")
	for k in at:
		board_cells.append(all[k])
	# 깃대 (뒤-오른쪽, 건물 밖 — 간판과 자리 바꿈, 사용자 2026-10-16)
	var fp := layout.signal_pos("flagpole")
	var fh := float(layout.fixed("flagpole").height)
	var fy := float(layout.fixed("flagpole").get("base_y", 0.0))   # 깃대는 뒷벽 높은 구간 위 (v2.4)
	_prop(FLAGPOLE, fp, fy, 0.0, Vector3(1.0, fh / 1.5, 1.0)).name = "FlagPole"
	flag = _mesh(_box(Vector3(0.62, 0.4, 0.03) * layout.unit_m), "a9a49b")
	flag.position = layout.m3(fp + Vector2(0.33, 0), fy)
	add_child(flag)
	# 회사 간판 (뒷벽 위 왼쪽 = 시계 기준 깃대와 좌우 짝, M4 사용자 · 2026-10-16 깃대와 자리 바꿈). 글자 = 회사 이름 자리 (M5 창업 화면에서 정함, 지금은 임시)
	var sg: Dictionary = layout.fixed("sign")
	var sign := _prop(SIGN, _v2(sg.pos), float(sg.base_y), 0.0)
	sign.name = "Sign"
	sign.rotation_degrees.x = float(sg.get("tilt", 0.0))   # 카메라 쪽으로 기울임 (M4 실화면 사용자 "내 각도에서 잘 안 보임" → 비교 뒤 A)
	sign.scale *= float(sg.get("scale", 1.0))   # base_y = 벽 끝 − 다리 (0.18 × 1.35) → 다리는 벽 속에 숨고 판 아래가 벽 끝 (사용자 "간판 다리 없애")
	var new_sign := "--sign-new" in Game.dev_args()
	(sign.find_child("SignHand", true, false) as Node3D).visible = not new_sign
	(sign.find_child("SignNew", true, false) as Node3D).visible = new_sign
	var st := Label3D.new()
	st.name = "SignText"
	st.text = "하늘 오피스"
	st.font = _glyph_font()
	st.font_size = 64
	st.pixel_size = 0.16 / 64.0   # 간판 자식 = 모델 좌표 (칸). 판 폭 1.2 안에 여섯 글자 정도
	st.outline_size = 0
	st.modulate = Color("f1eee9")
	st.position = Vector3(0, 0.39, 0.05)   # 판 가운데 앞 (판 아래 0.18 + 높이 0.42 / 2)
	sign.add_child(st)
	sign_text = st
	# 전자시계 (뒷벽 정가운데, 아래 끝 = 벽 끝 — 호출 보드를 가리지 않게. 간판 · 깃대를 양옆에 맞춤, 사용자 2026-10-16): 검은 판 + 밝은 테두리 + 초록 LED "14:00", 간판처럼 기울임
	var tb: Dictionary = layout.fixed("time_board")
	var board := Node3D.new()
	board.name = "TimeBoard"
	board.position = layout.m3(_v2(tb.pos), float(tb.base_y))
	board.rotation_degrees.x = float(tb.get("tilt", 0.0))
	board.scale = Vector3.ONE * layout.unit_m   # 자식 = 칸 단위
	add_child(board)
	_clock_build(board, Vector3.ZERO)   # 판 가운데 = 기울기 중심. zones 의 base_y · z = 기울인 뒤 아래 끝이 벽 끝 (벽 두께 가운데) 에 오게
	# 복도 입간판 게시판 (문 들어오면 바로, 앞 = +z)
	var nb: Dictionary = layout.slots("notice_board")[0]
	_prop(NOTICE, nb.pos, 0.0, 0.0).name = "NoticeBoard"
	island.add_solid_rect(_mr(Rect2(nb.pos - nb.size / 2.0, nb.size)))
	# 서버 랙 · 책장 · 화이트보드 · 망원경 · 대기 의자 · 화분
	for it in [["rack", RACK], ["bookshelf", BOOKSHELF], ["whiteboard", WHITEBOARD], ["telescope", TELESCOPE]]:   # 모델 (M4 2세션째), 앞면 = +z
		var sl := layout.room_slot(it[0])
		_prop(it[1], sl.pos, 0.0, 0.0).name = (it[0] as String).capitalize()
		island.add_solid_rect(_mr(Rect2(sl.pos - sl.size / 2.0, sl.size)))
	for wc in layout.slots("wait_chairs"):   # 대기 의자 (책상 쪽 = +x 를 봄)
		_prop(WAIT_CHAIR, wc.pos, 0.0, 90.0).name = "WaitChair"
	var room := layout.room_rect()
	_plant(Vector2(room.position.x + 0.35, room.end.y - 0.35))
	_plant(Vector2(room.end.x - 0.35, room.end.y - 0.35))


func _plant(p: Vector2) -> void:
	var k := absi(int(p.x * 7.0)) % 2   # 자리마다 몬스테라 · 스킨답서스 번갈아
	_prop(KIT_PLANTS[k], p, 0.0, k * 120.0, Vector3.ONE * 0.7).name = "Plant"
	island.add_solid_rect(_mr(Rect2(p - Vector2(0.15, 0.15), Vector2(0.3, 0.3))))


# ------------------------------------------------------------------ 2. 결재 창구
func _counter() -> void:
	var c: Dictionary = layout.fixed("counter")
	var cp := layout.signal_pos("counter")   # 오른벽 기준 (v2.6)
	var cs := _v2(c.size)
	var counter := SERVICE.instantiate() as Node3D   # 높은 카운터 + 유리 틀 (v2.6 구역 표시 ①)
	counter.name = "Counter"
	counter.position = layout.m3(cp)
	counter.rotation_degrees.y = float(c.rot) + 90.0   # 모델 손님 쪽 = +x, zones rot = 사장이 보는 쪽
	counter.scale = Vector3.ONE * layout.unit_m
	add_child(counter)
	island.add_solid_rect(_mr(Rect2(cp - cs / 2.0, cs)))
	_glass(cp, Vector2(0.02, cs.y - 0.08), 0.86, 1.33)
	# 바닥 줄 선 (줄 양옆) + 카메라 쪽 차단봉 (지나다닐 수 있게 걸리지 않음)
	var q: Array = layout.slots("queue")
	var qx0: float = minf(q[0].pos.x, q[q.size() - 1].pos.x) - 0.25
	var qx1: float = maxf(q[0].pos.x, q[q.size() - 1].pos.x) + 0.25
	var qz: float = q[0].pos.y
	for side in [-1.0, 1.0]:
		_block(Vector2((qx0 + qx1) / 2.0, qz + side * 0.32), Vector2(qx1 - qx0, 0.05), 0.04, 0.05, C_QUEUE)
	var nposts := 3
	for k in nposts:
		var px := qx0 + (qx1 - qx0) * k / (nposts - 1.0)
		var post := _mesh(_cyl(0.035 * layout.unit_m, 0.5 * layout.unit_m), "6c7580")
		post.position = layout.m3(Vector2(px, qz + 0.4), 0.25)
		add_child(post)
		var foot := _mesh(_cyl(0.09 * layout.unit_m, 0.03 * layout.unit_m), "6c7580")
		foot.position = layout.m3(Vector2(px, qz + 0.4), 0.015)
		add_child(foot)
	_block(Vector2((qx0 + qx1) / 2.0, qz + 0.4), Vector2(qx1 - qx0, 0.03), 0.4, 0.44, C_QUEUE).name = "QueueRope"
	# 사장 자리 (창구 바로 뒤, v2.8 C15): 중역 책상 + 빈 의자 + 명패 · 결재함 · 전화기 · 스탠드 + 작은 진열장
	var bd: Dictionary = layout.slots("boss_desk")[0]
	var desk := _prop(BOSS_DESK, bd.pos, 0.0, float(bd.rot))
	desk.name = "BossDesk"
	island.add_solid_rect(_mr(Rect2(bd.pos - bd.size / 2.0, bd.size + Vector2(0.45, 0))))   # 책상 + 뒤 의자 자리 (벽까지)
	var bulb := desk.find_child("Bulb", true, false) as MeshInstance3D
	boss = {"chair": desk.find_child("BossChair", true, false), "bulb": bulb, "note": desk.find_child("Note", true, false),
			"light": _night_light(bulb.global_position + Vector3(0, 0.1, 0), 0.8, 1.6)}
	boss.chair_pos = (boss.chair as Node3D).position
	boss.handset = desk.find_child("Handset", true, false)
	boss.plight = desk.find_child("PhoneLight", true, false)
	boss.handset_xf = (boss.handset as Node3D).transform
	var pl := boss.plight as MeshInstance3D   # 상태 불 = 모델보다 크게 (작은 구슬이라 불빛이 안 보임)
	var plc := pl.mesh.get_aabb().get_center()
	pl.transform = pl.transform * Transform3D(Basis(), plc) * Transform3D(Basis().scaled(Vector3.ONE * PHONE_LIGHT_K), Vector3.ZERO) * Transform3D(Basis(), -plc)
	var px := Label3D.new()   # 불통 표시 'X' (전화기 위, 직원의 회색 '?' 와 다른 모양)
	px.name = "PhoneX"
	px.text = "X"
	px.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	px.font_size = 72
	px.outline_size = 14
	px.pixel_size = 0.0035
	px.modulate = Color("e9eef4")
	px.outline_modulate = Color("39414d")
	px.visible = false
	add_child(px)
	boss.phone_x = px
	boss.plane_from = layout.m3(bd.pos, 0.75)   # 종이비행기 출발점 = 사장 책상 위 (사장이 있으면 손에서)
	var fig := BOSS_MODEL.instantiate() as Node3D   # 사장 (M4 사용자: "사장 자리에 플레이어가 앉아 있게") — 책상 모델 좌표, 의자에 앉음
	fig.name = "Boss"
	fig.position = boss.chair_pos + Vector3(0, 0, 0.5)   # 의자 메시 원점 = 책상 가운데 → 의자 자리 (build_counter_kit boss_chair y -0.5 = Godot +z 0.5)
	fig.rotation_degrees.y = 180.0   # 모델 앞 +z → 사장은 -z (창구 쪽) 를 봄
	fig.scale = Vector3.ONE / layout.unit_m   # 모델 = 미터, 책상 = 칸 크기
	desk.add_child(fig)
	boss.fig = fig
	boss.anim = fig.find_child("AnimationPlayer", true, false)
	boss.report = fig.find_child("Report", true, false)
	(boss.report as Node3D).visible = false
	(boss.anim as AnimationPlayer).play("Sit")
	(boss.anim as AnimationPlayer).animation_finished.connect(func(_n: StringName) -> void:   # 던지기 · 읽기 뒤 다시 타자
		(boss.report as Node3D).visible = false
		(boss.anim as AnimationPlayer).play("Sit", 0.25))
	set_boss_away(false)
	set_phone("none")
	var cb: Dictionary = layout.slots("boss_cabinet")[0]
	_prop(BOSS_CABINET, cb.pos, 0.0, float(cb.rot)).name = "BossCabinet"
	island.add_solid_rect(_mr(Rect2(cb.pos - cb.size / 2.0, cb.size)))
	var pr: Dictionary = layout.slots("printer")[0]
	_prop(PRINTER, pr.pos, 0.0, 0.0).name = "Printer"   # 흰 복합기 (앞 = +z)
	island.add_solid_rect(_mr(Rect2(pr.pos - pr.size / 2.0, pr.size)))


## 사장의 흔적 (v2.8 C15): 내가 있으면 스탠드 흰빛 · 자리 비우면 의자가 뒤로 빠지고 쪽지 (presence.gd 자리 비움)
func set_boss_away(away: bool) -> void:
	if boss.is_empty():
		return
	_set_glow(boss.bulb, Color("7d7a76") if away else Color("fff6e8"), not away)   # 꺼지면 어둡게 (낮에도 차이가 보이게)
	(boss.light as OmniLight3D).visible = not away
	(boss.note as Node3D).visible = away
	var ch := boss.chair as Node3D
	ch.position = boss.chair_pos + (Vector3(-0.36, 0, 0.1) if away else Vector3.ZERO)   # 모델 좌표: 사장 쪽 = +z · 옆 (-x) = 화면 앞쪽
	ch.rotation_degrees.y = -45.0 if away else 0.0
	if boss.has("fig"):
		(boss.fig as Node3D).visible = not away   # 자리 비우면 사장은 없고 흔적만


## 사장 책상 전화기 = 연결 상태 (5-7 '전화 개통' · 8장, M5 4세션째): none 미개통 = 회색 불 · on 개통 = PHONE_ON 불빛 · broken 불통 = 수화기 내려감 + X
##   불빛 색은 '끝' 초록 · '내 차례' 노랑과 겹치지 않게 따로. 깜빡임 없음
const PHONE_ON := Color("5cc8f2")   ## 하늘색 (그림 O/X 후보, `--phone-col=`)
const PHONE_OFF := Color("8a9099")
const PHONE_LIGHT_K := 3.0          ## 상태 불 크기 배율
const HANDSET_DOWN := Vector3(-0.2, -0.055, -0.04)   ## 불통 때 수화기를 옮길 양 (책상 모델 좌표: -x = 책상 안쪽)
var phone_state := "none"


func set_phone(state: String) -> void:
	if boss.is_empty() or not boss.has("plight"):
		return
	phone_state = state
	var col := PHONE_ON
	for a in Game.dev_args():
		if a.begins_with("--phone-col="):
			col = Color(a.get_slice("=", 1))
	_set_glow(boss.plight, col if state == "on" else PHONE_OFF.darkened(0.35 if state == "broken" else 0.0), state == "on")
	var hs := boss.handset as MeshInstance3D
	var xf: Transform3D = boss.handset_xf
	if state == "broken":   # 수화기를 받침에서 내려 책상 위에 옆으로 눕힘 (자기 가운데를 축으로)
		var c := hs.mesh.get_aabb().get_center() if hs.mesh else Vector3.ZERO
		var lie := Transform3D(Basis(Vector3.UP, deg_to_rad(68.0)), Vector3.ZERO)
		xf = xf * Transform3D(Basis(), c) * lie * Transform3D(Basis(), -c)
		xf.origin += HANDSET_DOWN
	hs.transform = xf
	var px := boss.phone_x as Label3D
	px.visible = state == "broken"
	px.global_position = phone_point() + Vector3(0, 0.42, 0)


## 전화기 자리 (화면 클릭 · X 표시 기준) = 상태 불 위치
func phone_point() -> Vector3:
	return (boss.plight as Node3D).global_transform * ((boss.plight as MeshInstance3D).mesh.get_aabb().get_center()) if boss.has("plight") else Vector3.ZERO


## 사장 동작 (M4): 던지기 (일 줄 때) · 보고서 읽기 (직원 일이 끝날 때). 자리에 없으면 아무것도 안 함
func boss_present() -> bool:
	return boss.has("fig") and (boss.fig as Node3D).visible


func boss_read(secs := 3.0) -> void:
	if not boss_present():
		return
	var ap := boss.anim as AnimationPlayer
	if ap.current_animation == "SitThrow":
		return   # 던지는 중이면 그대로
	(boss.report as Node3D).visible = true
	ap.play("SitRead", 0.25)
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if ap.current_animation == "SitRead":
			(boss.report as Node3D).visible = false
			ap.play("Sit", 0.3))


# ------------------------------------------------------------------ 3. 휴게 코너 (탕비 카운터 · 소파 · 회의 탁자)
func _rest() -> void:
	var p: Dictionary = layout.slots("pantry")[0]
	var pantry := PANTRY.instantiate() as Node3D   # 탕비 카운터 (커피 머신 · 컵 · 주전자 · 사과 · 화분), 앞면 = +x
	pantry.name = "Pantry"
	pantry.position = layout.m3(p.pos)
	pantry.scale = Vector3.ONE * layout.unit_m
	add_child(pantry)
	island.add_solid_rect(_mr(Rect2(p.pos - p.size / 2.0, p.size)))
	var wt: Dictionary = layout.slots("water")[0]
	_block(wt.pos, wt.size, 0.0, 0.75, "d8dde2", true)   # 정수기
	_block(wt.pos, wt.size * 0.7, 0.75, 1.0, "a9c4d4")
	var cr := layout.slot("coat_rack")   # 문 옆 옷걸이
	_block(cr, Vector2(0.08, 0.08), 0.0, 1.1, C_DARK, true)
	_block(cr + Vector2(0, 0), Vector2(0.3, 0.06), 0.95, 1.0, C_DARK)
	var so: Dictionary = layout.slots("sofa")[0]   # 등받이 = 보는 쪽 반대 (rot 90 = 왼쪽을 봄 → 등은 경계 벽 쪽)
	var sr := deg_to_rad(so.rot)
	var back := Vector2(sin(sr), cos(sr)).round()
	var foot: Vector2 = so.size if back.x == 0 else Vector2(so.size.y, so.size.x)
	_prop(KIT_SOFA, so.pos, 0.0, -float(so.rot)).name = "Sofa"   # KayKit 쿠션 소파 (앞면 +z → 보는 쪽으로 돌림)
	island.add_solid_rect(_mr(Rect2(so.pos - foot / 2.0, foot)))
	var mt: Dictionary = layout.slots("meeting_table")[0]
	_night_light(layout.m3(mt.pos, 1.7), 1.6, 3.2)   # 휴게 코너 조명 (밤에 아늑하게)
	var rr: float = mt.size.x * 0.85
	_prop(KIT_RUG, mt.pos, 0.04, 0.0, Vector3(rr, 1.0, rr) * 1.65).name = "Rug"   # KayKit 타원 러그 (탁자 크기에 맞춤)
	_prop(KIT_TABLE, mt.pos, 0.03, 0.0, Vector3(0.72, 1.0, 0.72)).name = "MeetingTable"   # KayKit 원탁 (Restaurant)
	for s in layout.slots("meeting_seats"):
		_prop(KIT_CHAIR, s.pos, 0.03, float(s.rot) + 180.0)
	island.add_solid_rect(_mr(Rect2(mt.pos - mt.size * 0.4, mt.size * 0.8)))


# ------------------------------------------------------------------ 4. 승강장 = 버스 정류장 (M3 4세션째 사용자 결정: 회의 C 개선 + 안내 단말기)
## 1.2×1.0칸 승강장 (받침 계열 색) · 파랑 표지판 (노랑 = 내 차례 전용) + 기둥 아래 노선판 · 뒤쪽 띠에 유리 쉼터
##   (유리 지붕 → 벤치가 비쳐 보임 · 지붕 앞 도착 안내판 · 금속 벤치 = 휴게 나무와 구분) · 가장자리 흰 줄
##   · 안내 단말기 = 관리인 대신 (연결 상태 · 알림 켜기 안내, M5 에서 누르면 연결 상태 창). 걷는 길 = 앞쪽 → 문
func _pier() -> void:
	var p: Rect2 = layout.zone_rect("pier")
	var u := layout.unit_m
	var sp := layout.slot("stop_sign")
	_block(sp, Vector2(0.06, 0.06), 0.0, 1.45, C_DARK, true).name = "StopPole"
	for d in [[0.2, 0.04, "3a78c8", 0.03], [0.12, 0.045, "f4f1ea", 0.032]]:   # 파랑 판 + 가운데 흰 원
		var disc := _mesh(_cyl(float(d[0]) * u, float(d[1]) * u), d[2])
		disc.rotation_degrees.x = 90.0   # 판이 카메라 (+z) 를 봄
		disc.position = layout.m3(sp + Vector2(0, float(d[3])), 1.3)
		add_child(disc)
	_block(sp + Vector2(0, 0.035), Vector2(0.17, 0.015), 0.72, 1.02, "eeeae2").name = "StopTimetable"   # 노선판
	_block(sp + Vector2(0, 0.04), Vector2(0.17, 0.015), 0.96, 1.02, "3a78c8")
	var x0 := p.position.x + 0.32
	var x1 := p.end.x - 0.1
	var mid := (x0 + x1) / 2.0
	var zb := p.position.y + 0.08
	var zf := zb + 0.4
	for x in [x0, x1]:
		_block(Vector2(x, zb), Vector2(0.05, 0.05), 0.0, 1.15, C_DARK, true)
	_glass(Vector2(mid, zb), Vector2(x1 - x0, 0.03), 0.1, 1.1, true)
	_glass(Vector2(mid, (zb + zf) / 2.0), Vector2(x1 - x0 + 0.1, zf - zb + 0.06), 1.13, 1.16).name = "StopRoof"
	_block(Vector2(mid, zf + 0.02), Vector2(x1 - x0 + 0.1, 0.04), 1.1, 1.17, C_DARK)   # 지붕 앞 테
	_block(Vector2(mid, zf), Vector2(0.42, 0.03), 0.93, 1.09, "1f2a33").name = "StopBoard"   # 도착 안내판
	_set_glow(_block(Vector2(mid, zf + 0.018), Vector2(0.34, 0.01), 0.98, 1.04, "7fe3ff"), Color("7fe3ff"), true)
	_block(Vector2(mid, zb + 0.2), Vector2(x1 - x0 - 0.18, 0.16), 0.26, 0.3, "7d8b96", true).name = "StopBench"
	for x in [mid - 0.22, mid + 0.22]:
		_block(Vector2(x, zb + 0.2), Vector2(0.04, 0.14), 0.0, 0.26, C_DARK)
	_block(Vector2(p.position.x + 0.03, p.get_center().y), Vector2(0.04, p.size.y), 0.03, 0.04, "f1ece2")   # 가장자리 줄
	_block(Vector2(p.get_center().x, p.end.y - 0.03), Vector2(p.size.x, 0.04), 0.03, 0.04, "f1ece2")
	var kp := layout.slot("kiosk")
	kiosk = _block(kp, Vector2(0.16, 0.12), 0.0, 0.62, C_KEEPER, true)
	kiosk.name = "StopKiosk"
	_set_glow(_block(kp + Vector2(0, 0.062), Vector2(0.11, 0.01), 0.38, 0.55, "7fe3ff"), Color("7fe3ff"), true)


# ------------------------------------------------------------------ 떠오르는 지붕 (시험용, --roof)
func _roof() -> void:
	var rr := layout.building_rect().grow(0.25)
	var hi := float(layout.data.building.wall_high)
	roof = _block(rr.get_center(), rr.size, hi + 1.3, hi + 1.45, "e9dfcf")
	roof.name = "FloatingRoof"
	var mat: StandardMaterial3D = (roof as MeshInstance3D).material_override.duplicate()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	(roof as MeshInstance3D).material_override = mat
	(roof as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ 길찾기 (island_builder.find_path 위에)
## 칸 좌표 a → b 경로 (월드 미터 Vector2 목록). 길이 없으면 빈 배열
func path(a: Vector2, b: Vector2) -> Array:
	return island.find_path(layout.m(a), layout.m(b))


## 직원 i 를 칸 좌표 to 까지 걷게 함 (M3 office_routine 이 이 위에). 길이 없으면 null
##   max_s > 0: 길이 길면 빨리 걸어서 그 안에 도착 (이동 3초 이내, 5-3) · delay: 걷기 전 멈춤 (그 시간도 max_s 안)
func walk(i: int, to: Vector2, speed := 0.6, max_s := 0.0, delay := 0.0) -> Tween:
	var node: Node3D = staff[i].node
	var pts: Array = island.find_path(Vector2(node.position.x, node.position.z), layout.m(to))
	if pts.is_empty():
		return null
	var anim: AnimationPlayer = staff[i].anim
	var tw := node.create_tween()
	var prev := Vector2(node.position.x, node.position.z)
	if max_s > 0.0:
		speed = walk_speed(_path_len(prev, pts), speed, max_s - delay)
	if delay > 0.0:
		if anim.current_animation != "ThumbsUp":   # ⑨ 엄지척은 끝까지
			anim.play("Idle", 0.1)
		tw.tween_interval(delay)
	tw.tween_callback(anim.play.bind(_walk_anim(i), 0.2))
	for p in pts:
		var dir: Vector2 = p - prev
		var dur := maxf(prev.distance_to(p) / speed, 0.01)
		if dir.length() > 0.001:   # 가는 쪽을 봄 (직원 앞 = -z) — 걸으면서 돎 (구간 시간보다 길지 않게)
			tw.tween_property(node, "rotation:y", atan2(-dir.x, -dir.y), minf(0.15, dur))
			tw.parallel().tween_property(node, "position", Vector3(p.x, 0, p.y), dur)
		else:
			tw.tween_property(node, "position", Vector3(p.x, 0, p.y), dur)
		prev = p
	tw.tween_callback(anim.play.bind(_stand_anim(i), 0.2))
	return tw


## 걷는 속도: 기본 속도로 시간 안에 못 가면 빨리 (m/초)
static func walk_speed(length_m: float, speed: float, max_s: float) -> float:
	return maxf(speed, length_m / maxf(max_s - 0.15, 0.3))   # 0.15 = 방향 돌리기 몫


func _path_len(from: Vector2, pts: Array) -> float:
	var n := 0.0
	var prev := from
	for p in pts:
		n += prev.distance_to(p)
		prev = p
	return n


## 따뜻한 흰빛 조명 (노랑 · 주황 아님). 섬 안의 OmniLight3D 는 day_night 가 낮엔 약하게 · 밤엔 밝게 맞춤 (낮 밝게 · 밤 아늑, v2.5)
func _night_light(pos: Vector3, energy: float, range_cells: float) -> OmniLight3D:
	var lt := OmniLight3D.new()
	lt.light_color = Color("fff1e2")
	lt.light_energy = energy
	lt.omni_range = range_cells * layout.unit_m
	lt.shadow_enabled = false
	lt.position = pos
	add_child(lt)
	return lt


# ------------------------------------------------------------------ 회색 상자 도우미 (칸 단위)
## 바닥 위 상자: 중심 c · 크기 size (칸), 높이 y0~y1 (칸). solid = 지나갈 수 없음
func _block(c: Vector2, size: Vector2, y0: float, y1: float, col: String, solid := false) -> MeshInstance3D:
	var u := layout.unit_m
	var mi := _mesh(_box(Vector3(size.x, y1 - y0, size.y) * u), col)
	mi.position = Vector3(c.x * u, (y0 + y1) / 2.0 * u, c.y * u)
	add_child(mi)
	if solid:
		island.add_solid_rect(_mr(Rect2(c - size / 2.0, size)))
	return mi


## 모델 하나 놓기 (크기 단위 칸 → unit_m 배). y = 바닥 높이 (칸), rot = y 축 회전 (도), scale = 칸 단위 추가 배율
func _prop(scene: PackedScene, c: Vector2, y: float, rot: float, scale := Vector3.ONE) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.position = layout.m3(c, y)
	n.rotation_degrees.y = rot
	n.scale = scale * layout.unit_m
	add_child(n)
	return n


## 반투명 유리 (작업실 칸막이 · 창구 유리)
func _glass(c: Vector2, size: Vector2, y0: float, y1: float, solid := false) -> MeshInstance3D:
	var g := _block(c, size, y0, y1, "b9d3df", solid)
	var gm: StandardMaterial3D = g.material_override.duplicate()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color.a = 0.4
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


## 나무 마루 재질: 판 폭 0.25칸 · 길이 1칸, 판마다 밝기 조금씩 다르게 + 끝 이음 엇갈림 (위에서 본 면, 세계 좌표 triplanar)
func _plank_mat(col: String) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var base := Color(col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 4:
		var shade := base.darkened(rng.randf_range(-0.05, 0.06))
		var cut := (row * 23) % 64
		for yy in range(row * 16, row * 16 + 16):
			for xx in 64:
				var c := shade
				if yy == row * 16 or xx == cut:
					c = base.darkened(0.18)   # 판 사이 줄
				img.set_pixel(xx, yy, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / (1.0 * layout.unit_m)
	m.roughness = 0.7
	return m


## 타일 바닥 재질: 한 장 = cell 칸, 줄눈 색 line (위에서 본 면에만 — 세계 좌표 triplanar)
func _tile_mat(col: String, line: String, cell: float) -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(col))
	for k in 32:
		for e in [0, 31]:
			img.set_pixel(k, e, Color(line))
			img.set_pixel(e, k, Color(line))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / (cell * layout.unit_m)
	m.roughness = 0.6
	return m


## 뒷벽 양옆 한 구간: 높이 h (낮으면 낮은 턱 색). win = 가운데 창 띠 (아래 벽 0.55 · 창 · 위 띠, 기둥 약 1칸마다)
func _back_side(r: Rect2, h: float, win: bool) -> void:
	var col := C_WALL if h > float(layout.data.building.wall_low) + 0.01 else C_WALL_LOW
	if not win or h < 1.2:
		_wall(r, h, col)
		return
	var w0 := 0.55
	var w1 := minf(h - 0.3, 1.55)
	_wall(r, w0, col)
	var top := _block(r.get_center(), r.size, w1, h, col)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block(r.get_center(), r.size + Vector2(0.04, 0.04), h, h + 0.035, C_WALL_CAP).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := maxi(1, int(round(r.size.x / 1.0)))
	for k in n + 1:
		var px := r.position.x + r.size.x * k / n
		_block(Vector2(px, r.get_center().y), Vector2(0.08, r.size.y + 0.02), w0, w1, C_WALL_CAP).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pane := _block(r.get_center(), Vector2(r.size.x, 0.03), w0, w1, "bcd6e6")   # 창 = 옅은 하늘색 (1.1 창밖 연출 자리)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _wall(r: Rect2, h: float, col: String) -> void:
	var mi := _block(r.get_center(), r.size, 0.0, h, col, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 벽 그림자 끔 (3-3)
	mi.name = "Wall"
	var cap := _block(r.get_center(), r.size + Vector2(0.04, 0.04), h, h + 0.035, C_WALL_CAP)   # 위 덮개 (나무, M4 — 낮은 벽 윤곽이 또렷하게)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block(r.get_center(), r.size + Vector2(0.02, 0.02), 0.0, 0.05, C_WALL_BASE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 걸레받이


func _mesh(m: Mesh, col: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(col)
	return mi


func _mat(col: String) -> StandardMaterial3D:
	if not _mats.has(col):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col)
		mat.roughness = 0.9
		_mats[col] = mat
	return _mats[col]


## 빛나는 칸 (램프 · 화면 · 깃발): 칸마다 재질을 따로 가짐
func _set_glow(mi: MeshInstance3D, col: Color, on: bool, flat := false) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if flat:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.6
	mat.emission_enabled = on
	mat.emission = col
	mat.emission_energy_multiplier = 1.4 if on else 0.0
	mi.material_override = mat


## 7칸 숫자: 켜지는 칸 (a 위 · b 오른위 · c 오른아래 · d 아래 · e 왼아래 · f 왼위 · g 가운데)
const SEG_DIGITS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]


## 전자시계 LED (사용자 참고 그림: 3D LED 시계): 검은 판 + 밝은 테두리 + 두꺼운 초록 칸. 꺼진 칸은 숨김
## c = 숫자 가운데 (칸) = 판 가운데
func _clock_build(parent: Node3D, c: Vector3) -> void:
	_led_on = StandardMaterial3D.new()
	_led_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 낮에도 그늘 없이 빛남
	_led_on.albedo_color = Color("2ee86f")   # 선명한 초록 (노랑 = 알림 · 빨강 = 경고 느낌이라 뺌)
	var w := 0.28
	var h := 0.52
	var t := 0.085
	var xs := [-0.69, -0.25, 0.25, 0.69]   # 칸 간격 0.44 ≥ 폭 + 두께 + 틈 (붙으면 1 · 4 가 뭉침)
	var pw: float = 2.0 * (xs[3] + w / 2 + t / 2) + 0.16
	var ph := h + t + 0.16
	var rim := _mesh(_box(Vector3(pw + 0.12, ph + 0.12, 0.05)), "f1eee9")   # 밝은 테두리 (하늘 · 벽과 구분)
	rim.position = c + Vector3(0, 0, -0.035)
	parent.add_child(rim)
	var plate := _mesh(_box(Vector3(pw, ph, 0.06)), "111317")
	plate.position = c + Vector3(0, 0, -0.025)
	parent.add_child(plate)
	var segs := {"a": [Vector2(0, h / 2), true], "g": [Vector2(0, 0), true], "d": [Vector2(0, -h / 2), true],
			"f": [Vector2(-w / 2, h / 4), false], "b": [Vector2(w / 2, h / 4), false], "e": [Vector2(-w / 2, -h / 4), false], "c": [Vector2(w / 2, -h / 4), false]}
	for x in xs:
		var digit := {}
		for k in segs:
			var horiz: bool = segs[k][1]
			var size := Vector3(w - t * 1.1, t, 0.02) if horiz else Vector3(t, h / 2 - t * 1.1, 0.02)
			digit[k] = [_led_part(parent, size, c + Vector3(float(x) + segs[k][0].x, segs[k][0].y, 0.015))]
		_clock_segs.append(digit)
	for y in [0.11, -0.11]:
		_clock_colon.append(_led_part(parent, Vector3(0.075, 0.075, 0.02), c + Vector3(0, y, 0.015)))
	set_time_text("08:00")


## LED 칸 하나 (초록, 그늘 없음)
func _led_part(parent: Node3D, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var face := MeshInstance3D.new()
	face.mesh = _box(size)
	face.material_override = _led_on
	face.position = pos
	parent.add_child(face)
	return face


## 전자시계 글자 바꾸기 ("14:00"). colon = 가운데 두 점 켜짐
func set_time_text(text: String, colon := true) -> void:
	for d in _clock_colon:
		d.visible = colon
	if text == time_text:
		return
	time_text = text
	var digits := text.replace(":", "")
	for i in mini(digits.length(), _clock_segs.size()):
		var lit: String = SEG_DIGITS[int(digits[i])] if digits[i].is_valid_int() else ""
		for k in _clock_segs[i]:
			_clock_segs[i][k][0].visible = k in lit   # 꺼진 칸 = 숨김 (테두리도 자식이라 같이)


## 켜진 칸 수 (시험용)
func clock_lit() -> int:
	var n := 0
	for digit in _clock_segs:
		for k in digit:
			if digit[k][0].visible:
				n += 1
	return n


## 호출 보드 칸 번호 (책상 id 순서): 보드 칸 자리 = 책상 자리 — 윗줄 = 뒷줄 책상 (rows[0]) · 아랫줄 = 앞줄, 왼쪽 → 오른쪽 = 책상 x 순서.
## 책상 열이 보드 열 (6) 보다 적으면 가운데 열부터 씀 (지름 10 = 가운데 2열)
func board_index() -> Array:
	var cols := int(layout.fixed("board").cells[0])
	var xs: Array = []
	for c in layout.desk_cols:
		xs.append(layout.col_x(c))
	xs.sort()   # col_x 는 가운데 묶음 → 오른쪽 → 왼쪽 순이라 x 로 정렬
	var start := (cols - xs.size()) / 2
	var out: Array = []
	for d in layout.desks():
		out.append((0 if int(d.row) == 0 else cols) + start + xs.find(layout.col_x(int(d.col))))
	return out


# ------------------------------------------------------------------ M5 2세션째: 회사 단계 가구 · 모임 · 퇴근 · 짐 상자 (PLAN 6-1 · 6-3)
## 단계 가구 = data/stages.json 의 unlock (같은 모델 + 재질 교체가 원칙). 연출 순서 · 시각은 company_show.gd 가 정함
const BOX_Y := 0.27            ## 짐 상자: 몸 기준 높이 · 앞 (m)
const BOX_Z := 0.17
const GATHER_GAP := 0.42       ## 모임 자리 사이 (칸) — 직원끼리 안 겹치게
const C_POPUP := "2c3e66"      ## 단계 상승 팝업 테 = 새 간판 남색 (노랑 없음)

var stage := -1                ## 화면에 적용된 단계 번호 (apply_stage)
var off_duty := false          ## 하루 끝 (창 밖 · 일찍 퇴근): 쉬는 직원은 퇴근 · 일하는 직원만 남음 (야근)
var _stage_nodes := {}         ## unlock 이름 → [Node3D] (meta "until" = 그 unlock 전에만 보임: 선반 · 손글씨 간판)
var _look_mats: Array = []     ## 재질 교체 [{mi, surface, key, mat}] — unlock 전엔 looks 색
var _sign_forced := false      ## 개발 인자 `--sign-new` (단계와 상관없이 새 간판)
var notice_note: Label3D       ## '오늘 업무 끝' (일찍 퇴근): 게시판 귀퉁이 쪽지 (화이트보드 전)
var board_note: Label3D        ## '오늘 업무 끝' 화이트보드 글씨 (화이트보드가 생긴 뒤)
var popup: Label3D             ## 단계 상승 팝업


## 시작 단계: `--stage=N` (개발) · 개발 실행 (--demo · --offscreen) 은 마지막 단계 (예전 화면 그대로) · 실제 = 저장의 shown_stage
func start_stage() -> int:
	var last: int = Company.stage_data().stages.size() - 1
	for a in Game.dev_args():
		if a.begins_with("--stage="):
			return clampi(int(a.get_slice("=", 1)), 0, last)
	if "--demo" in Game.dev_args() or "--offscreen" in Game.dev_args():
		return last
	return clampi(int(Game.company.get("shown_stage", 0)), 0, last)


func _stage_setup() -> void:
	var add := func(key: String, n: Node3D, until := false) -> void:
		if n == null:
			return
		n.set_meta("until", until)
		n.set_meta("scale0", n.scale)
		if not _stage_nodes.has(key):
			_stage_nodes[key] = []
		_stage_nodes[key].append(n)
	add.call("bookshelf", get_node_or_null("Bookshelf"))
	add.call("whiteboard", get_node_or_null("Whiteboard"))
	add.call("telescope", get_node_or_null("Telescope"))
	var rack := get_node_or_null("Rack") as Node3D
	add.call("server_rack", rack)
	if rack:   # 초기 단계 = 서버 선반 (같은 자리, 랙과 교체)
		var sl := layout.room_slot("rack")
		var shelf := _prop(SERVER_SHELF, sl.pos, 0.0, 0.0)
		shelf.name = "ServerShelf"
		add.call("server_rack", shelf, true)
	var sign := get_node_or_null("Sign")
	if sign:
		add.call("sign_new", sign.find_child("SignNew", true, false))
		add.call("sign_new", sign.find_child("SignHand", true, false), true)
	_sign_forced = "--sign-new" in Game.dev_args()
	var looks: Dictionary = Company.stage_data().get("looks", {})
	for d in layout.desks():
		var set := get_node_or_null("Desk_%d" % d.id)
		if set == null:
			continue
		add.call("personal_shelf", set.find_child("PersonalShelf", true, false))
		for k in 3:   # 책상 · 모니터 · 의자만 (개인 소품의 나무는 그대로)
			for mi in set.get_child(k).find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				for sf in m.get_surface_count():
					var mat := m.surface_get_material(sf)
					if mat == null:
						continue
					for key in looks:
						if (looks[key] as Dictionary).has(mat.resource_name):
							_look_mats.append({"mi": mi, "surface": sf, "key": key, "mat": _mat(looks[key][mat.resource_name])})
	# '오늘 업무 끝' (일찍 퇴근 날만): 화이트보드가 있으면 거기에 남색 마커 글씨 (낙서는 지움) — 게시판은 사용량 · 성장 자리 (사용자 2026-10-16)
	#   화이트보드 전 (근무일 0~5) 엔 게시판 귀퉁이에 작은 쪽지
	board_note = _note_label("오늘 업무 끝", 0.2)
	var wb := get_node_or_null("Whiteboard") as Node3D
	if wb:
		wb.add_child(board_note)
		board_note.position = Vector3(0, 0.82, 0.05)   # 판 가운데 (모델 좌표 = 칸)
	notice_note = _note_label("오늘\n업무 끝", 0.12)
	var card := _mesh(_box(Vector3(0.34, 0.27, 0.012)), "fbf8f2")   # 흰 쪽지 (성장 막대는 안 가리게 아래 귀퉁이)
	card.name = "NoteCard"
	card.position = Vector3(0, 0, -0.012)
	notice_note.add_child(card)
	var nb := get_node_or_null("NoticeBoard") as Node3D
	if nb:
		nb.add_child(notice_note)
		notice_note.position = Vector3(0.13, 0.5, 0.13)   # 코르크 판 오른쪽 아래 귀퉁이
	popup = _label(56, 4)
	popup.name = "StagePopup"
	popup.pixel_size = 0.27 * layout.unit_m / 56.0
	popup.modulate = Color.WHITE
	popup.outline_size = 18
	popup.outline_modulate = Color(C_POPUP)
	popup.visible = false
	add_child(popup)


## 판에 붙이는 남색 글씨 (모델 좌표 = 칸, 부모 크기를 따라감)
func _note_label(text: String, h: float) -> Label3D:
	var l := Label3D.new()
	l.name = "EarlyNote"
	l.text = text
	l.font = _glyph_font()
	l.font_size = 48
	l.pixel_size = h / 48.0
	l.line_spacing = -6.0
	l.modulate = Color(C_POPUP)
	l.outline_size = 0
	l.visible = false
	return l


## 지금 보이는 '오늘 업무 끝' (없으면 null, 시험용)
func early_note() -> Label3D:
	if board_note.visible:
		return board_note
	return notice_note if notice_note.visible else null


## 단계 적용: 생긴 가구 보이기 · 재질 교체 · 간판. pop = 새로 생긴 것을 '뿅' 키워 보임 (단계 상승 연출). 새로 보인 노드 목록을 돌려줌
func apply_stage(n: int, pop := false) -> Array:
	var have := Company.unlocked(n)
	var shown: Array = []
	for key in _stage_nodes:
		for nd in _stage_nodes[key]:
			var on: bool = (key in have) != bool(nd.get_meta("until", false))
			if key == "sign_new" and _sign_forced:
				on = not bool(nd.get_meta("until", false))
			if on and not nd.visible:
				shown.append(nd)
				if pop and stage >= 0:
					var s0: Vector3 = nd.get_meta("scale0")
					nd.scale = s0 * 0.05
					var tw: Tween = nd.create_tween()
					tw.tween_property(nd, "scale", s0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			nd.visible = on
	for e in _look_mats:
		(e.mi as MeshInstance3D).set_surface_override_material(int(e.surface), null if e.key in have else e.mat)
	stage = n
	return shown


## 그 unlock 이 지금 화면에 있는지 (시험 · 모임 자리)
func has_unlock(key: String) -> bool:
	return key in Company.unlocked(stage)


## 모임 자리 (아침 조회 · 단계 상승): 화이트보드 코너가 있으면 그 앞, 없으면 게시판 앞 (근무일 0~5, 6-1). 둘 다 앞 = +z → 판을 봄 (rot 0)
func gather_spot() -> Dictionary:
	if has_unlock("whiteboard"):
		var wb := layout.room_slot("whiteboard")
		return {"pos": wb.pos + Vector2(0, 0.58), "board": wb.pos, "at": "whiteboard"}
	var nb: Dictionary = layout.slots("notice_board")[0]
	return {"pos": nb.pos + Vector2(0.2, 0.62), "board": nb.pos, "at": "notice_board"}


## 모임 자리 n 개: 판 앞 빈 바닥 (가구 · 탕비 카운터 · 회의 탁자 러그 피함, 서로 GATHER_GAP 이상) 중 판에 가까운 순.
##   사무실 칸 격자에서 고름 — 줄 1~3 (앞으로 0.6 · 1.0 · 1.4칸), 자리가 모자라면 가까운 자리를 겹쳐 씀
func gather_points(n: int) -> Array:
	var g := gather_spot()
	var mt: Dictionary = layout.slots("meeting_table")[0]
	var rug_r: float = float(mt.size.x) * 1.1   # 회의 탁자 러그 (장식) 반지름 + 여유
	var chairs: Array = layout.desks().map(func(d): return d.seat)   # 의자 (막힘 칸이 아님) 도 피함
	for k in ["meeting_seats", "wait_chairs"]:
		chairs.append_array(layout.slots(k).map(func(e): return e.pos))
	var cand: Array = []
	for row in 3:
		for c in range(-4, 6):
			var p: Vector2 = g.board + Vector2(0.42 * c, 0.5 + 0.4 * row)
			var ok: bool = p.distance_to(mt.pos) > rug_r and chairs.all(func(q: Vector2) -> bool: return p.distance_to(q) >= 0.38)
			for d in [Vector2.ZERO, Vector2(0.2, 0), Vector2(-0.2, 0), Vector2(0, 0.2), Vector2(0, -0.2)]:
				ok = ok and island.is_walkable(layout.m(p + d))
			if ok:
				cand.append([p.distance_to(g.board + Vector2(0, 0.5)) + 0.25 * row, p])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for e in cand:
		if out.size() < n and out.all(func(q: Vector2) -> bool: return q.distance_to(e[1]) >= GATHER_GAP):
			out.append(e[1])
	while out.size() < n:
		out.append(out[out.size() % maxi(1, out.size())] if not out.is_empty() else g.pos)
	return out


## 쉬는 책상 직원 (rest · done, 보이고 퇴근 걸음 아님) — 모임 · 점심 대상. 일하는 직원은 안 데려감 (6-1)
func resting() -> Array:
	var out: Array = []
	for i in desk_count:
		var s: Dictionary = staff[i]
		if s.state in ["rest", "done"] and (s.node as Node3D).visible and not bool(s.get("leaving", false)):
			out.append(i)
	return out


func any_turn() -> bool:
	return staff.any(func(s): return s.state in ["turn", "turn15"])


func any_working() -> bool:
	return staff.any(func(s): return s.state in ["work", "watch", "unknown", "done0"] and (s.node as Node3D).visible)


## 모임: 쉬는 직원들이 모임 자리로 걸어가 판을 봄. 하던 쉬는 행동은 그만둠 (act = gather 동안 새 행동 안 고름)
func gather(idxs: Array) -> void:
	var pts := gather_points(idxs.size())
	var board: Vector2 = gather_spot().board
	for n in idxs.size():
		var i: int = idxs[n]
		var s: Dictionary = staff[i]
		_stop_walk(i)
		_leave_act(i)
		s.act = "gather"
		s.act_until = _now() + 3600.0
		var d: Vector2 = board - pts[n]   # 판을 봄 (직원 앞 = -z)
		_act_go(i, pts[n], rad_to_deg(atan2(-d.x, -d.y)), (s.anim as AnimationPlayer).play.bind("Idle", 0.2))


## 걷던 쉬는 행동 (커피 · 수다로 가는 중) 을 멈춤 — 안 멈추면 그 도착 콜백이 나중에 방향 · 동작을 바꿈
func _stop_walk(i: int) -> void:
	var s: Dictionary = staff[i]
	if s.tween != null:
		(s.tween as Tween).kill()
		s.tween = null


## 모인 직원 (아직 모임 중이고 도착한) 에게 동작 하나 — Clap (박수) · bow (꾸벅)
func gather_play(idxs: Array, what: String) -> void:
	for i in idxs:
		var s: Dictionary = staff[i]
		if str(s.get("act", "")) != "gather" or s.tween != null:
			continue
		if what == "bow":
			bow(i)
		else:
			(s.anim as AnimationPlayer).play(what, 0.2)


## 모임 끝: 아직 모임 중인 직원은 다음 1초 안에 쉬는 행동을 새로 고름
func gather_end(idxs: Array) -> void:
	for i in idxs:
		var s: Dictionary = staff[i]
		if str(s.get("act", "")) == "gather":
			s.act = ""
			s.act_until = 0.0
			if s.tween == null:
				(s.anim as AnimationPlayer).play("Idle", 0.2)


## 모임 자리에 와 있는 직원 수 (시험용)
func gathered() -> int:
	var n := 0
	for s in staff:
		if str(s.get("act", "")) == "gather" and s.tween == null:
			n += 1
	return n


## 점심 (6-3, 33%): 쉬는 직원이 회의 탁자 의자에 앉아 쉼, 자리가 모자라면 소파
func lunch(idxs: Array) -> void:
	var seats := layout.slots("meeting_seats")
	var span: Array = idle_cfg.get("act_s", [30, 180])
	for n in idxs.size():
		var i: int = idxs[n]
		var s: Dictionary = staff[i]
		if n >= seats.size():
			rest_act(i, "sofa")
			continue
		_stop_walk(i)
		_leave_act(i)
		s.act = "lunch"
		s.act_until = _now() + float(span[1])
		var seat: Dictionary = seats[n]
		_act_go(i, seat.pos, float(seat.rot), (s.anim as AnimationPlayer).play.bind("SitRest", 0.25))


## 하루 끝 · 다시 출근 (6-3): on = 쉬는 책상 직원이 통근버스로 퇴근 (정류장에서 손 흔들기) · off = 버스에서 내려 출근 (꾸벅)
##   일하는 직원은 그대로 (야근). 일찍 퇴근이면 게시판에 '오늘 업무 끝'
func set_off_duty(on: bool, early := false) -> void:
	var wb_on := has_unlock("whiteboard")
	board_note.visible = on and early and wb_on
	notice_note.visible = on and early and not wb_on
	var wb := get_node_or_null("Whiteboard")
	var doodle := wb.find_child("Doodle", true, false) if wb else null
	if doodle:
		(doodle as Node3D).visible = not board_note.visible   # 낙서를 지우고 씀
	if off_duty == on:
		return
	off_duty = on
	for i in desk_count:
		if staff[i].state in ["rest", "done", "meet"]:
			_leave_act(i)   # 소파 · 모임 · 점심 중이었어도 그만두고
			set_state(i, staff[i].state, true)


## 입사 표시: 이 직원의 다음 출근 = 짐 상자를 들고 와서 책상에 풀어 놓음 (office_routine 이 새 직원을 보면 부름)
func mark_hire(i: int) -> void:
	staff[i].box_in = true


## 상자 든 출근이 도착하면: 상자를 책상 위에 내려놓고 → 2.5초 뒤 풀면 개인 소품이 나타남
func _unpack(i: int) -> void:
	var s: Dictionary = staff[i]
	s.box_in = false
	if str(s.get("held", "")) != "box" or s.desk.is_empty():
		return
	hold(i, "")
	(s.anim as AnimationPlayer).play(_pose_anim(s), 0.2)
	var set := get_node_or_null("Desk_%d" % int(s.desk.id)) as Node3D
	var items: Array = []
	if set:
		for k in 6:
			var it := set.find_child("Item%d" % k, true, false) as Node3D
			if it and it.visible:
				it.visible = false
				items.append(it)
	var bx := _desk_box(i)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		bx.queue_free()
		for it in items:
			var s0: Vector3 = it.scale
			it.scale = s0 * 0.05
			it.visible = true
			it.create_tween().tween_property(it, "scale", s0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## 책상 위 상자 하나 (모니터 옆 · 앉은 사람 쪽)
func _desk_box(i: int) -> Node3D:
	var s: Dictionary = staff[i]
	var bx := (PROPS.box as PackedScene).instantiate() as Node3D
	bx.name = "DeskBox"
	var r := deg_to_rad(float(s.desk.rot))
	var side := Vector2(cos(r), -sin(r))   # 책상 옆쪽 (앉은 사람 머리에 안 가리게 모니터 옆 빈자리)
	var face := Vector2(-sin(r), -cos(r))   # 앉은 사람이 보는 쪽
	bx.position = layout.m3(s.desk.pos + side * 0.38 - face * 0.1, DESK_TOP)
	bx.rotation_degrees.y = float(s.desk.rot)
	bx.scale = Vector3.ONE * layout.unit_m
	add_child(bx)
	return bx


## 송별 (휴직 = 2주 안 씀): 자리에 나타나 개인 소품을 상자에 담고 → 들고 정류장으로 → 손 흔들고 버스. 책상은 빈 채로
func farewell(i: int) -> void:
	var s: Dictionary = staff[i]
	if s.desk.is_empty() or s.state != "off" or (s.node as Node3D).visible:
		return
	var set := get_node_or_null("Desk_%d" % int(s.desk.id)) as Node3D
	var node: Node3D = s.node
	node.position = layout.m3(s.desk.seat)
	node.rotation_degrees.y = float(s.desk.rot)
	node.visible = true
	dress(i)
	var bx := _desk_box(i)
	(s.anim as AnimationPlayer).play("Idle", 0.2)
	var tw := node.create_tween()
	s.tween = tw
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:   # 소품을 담음
		if set:
			for k in 6:
				var it := set.find_child("Item%d" % k, true, false) as Node3D
				if it:
					it.visible = false
		bx.queue_free()
		hold(i, "box")
		s.tween = null
		s.leaving = true
		bus_call(4.5)
		s.tween = walk(i, layout.slot("dock"), 0.6, WALK_MAX_S)
		if s.tween != null:
			(s.tween as Tween).tween_callback((s.anim as AnimationPlayer).play.bind("Wave", 0.15))
			(s.tween as Tween).tween_interval(1.0)
			(s.tween as Tween).tween_callback(_settle.bind(i))
		else:
			_settle(i))


## 단계 상승 팝업 (사무실 가운데 위, 4초): 단계 이름과 새로 생긴 것만 (숫자 · 칭찬 문구 없음)
func show_popup(text: String, secs := 4.0) -> void:
	popup.text = text
	popup.position = layout.m3(Vector2(0.0, -0.4), 2.3)
	popup.visible = true
	popup.modulate.a = 1.0
	if popup.has_meta("tw"):
		(popup.get_meta("tw") as Tween).kill()
	var tw := popup.create_tween()
	popup.set_meta("tw", tw)
	tw.tween_interval(secs)
	tw.tween_property(popup, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: popup.visible = false)


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s


func _mr(r: Rect2) -> Rect2:
	return Rect2(r.position * layout.unit_m, r.size * layout.unit_m)


func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
