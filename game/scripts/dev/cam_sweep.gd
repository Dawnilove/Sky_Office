extends "res://scripts/dev/scenario.gd"
## 개발용 카메라 각도 훑기 (`-- --offscreen --fresh --cam-sweep=<폴더>`, M2 3세션째): 게임을 한 번 켜고 좌우 · 내려다봄 각도를 바꿔 가며
## 가림 (scenario 와 같은 규칙) · 이름판 겹침 · 사무실 바닥이 화면에서 차지하는 넓이 · 화면 밖으로 나간 모서리를 재고, 각도마다 작은 그림을 저장
## 결과: <폴더>/sweep_<크기>.csv + <폴더>/<크기>/y<좌우>_p<내려다봄>.png (270×250). 카메라 거리 · 대상 · 시야는 main.gd 값 그대로
## `--sweep-step=5` (기본 5°) · `--sweep-yaw=0,90` · `--sweep-pitch=0,90` (범위, 기본 0~90) · `--sweep-thumbs=0` (그림 안 찍음)

const THUMB := Vector2i(270, 250)


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var out := ""
	var step := 5
	var yr := Vector2i(0, 90)
	var pr_ := Vector2i(0, 90)
	var thumbs := true
	for a in Game.dev_args():
		if a.begins_with("--cam-sweep="):
			out = a.get_slice("=", 1)
		if a.begins_with("--sweep-step="):
			step = int(a.get_slice("=", 1))
		if a.begins_with("--sweep-yaw="):
			yr = Vector2i(int(a.get_slice("=", 1).get_slice(",", 0)), int(a.get_slice("=", 1).get_slice(",", 1)))
		if a.begins_with("--sweep-pitch="):
			pr_ = Vector2i(int(a.get_slice("=", 1).get_slice(",", 0)), int(a.get_slice("=", 1).get_slice(",", 1)))
		if a == "--sweep-thumbs=0":
			thumbs = false
	var lay: Layout = main.layout
	var office: Node3D = main.office
	var cam: Camera3D = main.camera
	var k: Dictionary = main.get_script().get_script_constant_map()
	var target: Vector3 = k.CAM_TARGET
	var dist: float = k.BASE_SIZE.y / (2.0 * k.PX_PER_M * tan(deg_to_rad(k.CAM_FOV / 2.0))) * main.diameter_k
	var dir_out := "%s/%d" % [out, lay.diameter]
	DirAccess.make_dir_recursive_absolute(dir_out)
	var csv := FileAccess.open("%s/sweep_%d_s%d.csv" % [out, lay.diameter, step], FileAccess.WRITE)
	csv.store_line("yaw,pitch,occlusion,tag_overlap,tag_board,floor_pct,outside")
	var desks := lay.desks()
	var angles: Array = []
	for p in range(pr_.x, pr_.y + 1, step):
		for y in range(yr.x, yr.y + 1, step):
			angles.append(Vector2i(y, p))

	# 1) 재기: 모두 일함 + 이름판 모두 보임 (scenario 가림 · 이름판 시험과 같은 조건)
	for i in office.staff.size():
		office.set_state(i, "work")
		office.set_hover(i, true)
	await get_tree().process_frame
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var b := lay.building_rect()
	var corners: Array = []   # 바닥 네 모서리 (넓이) + 벽 위 · 부두 (화면 밖 검사)
	for c in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
		corners.append(lay.m3(c, 0.0))
	var probes: Array = corners.duplicate()
	var hw := float(lay.data.building.high_span) / 2.0
	for x in [-hw, hw]:
		probes.append(lay.m3(Vector2(x, b.position.y), float(lay.data.building.wall_high)))
	var pr := lay.zone_rect("pier")
	probes.append(lay.m3(pr.position, 0.0))
	probes.append(lay.m3(Vector2(pr.position.x, pr.end.y), 0.0))
	for ang in angles:
		_aim(cam, target, dist, ang)
		var occ := _occlusion(cam, office, desks)
		var tags: Array = []
		for d in desks:
			tags.append(_sprite_rect(cam, office.staff[d.id].tag_bg))
		var tag_hits := 0
		for i in tags.size():
			for j in range(i + 1, tags.size()):
				if tags[i].intersects(tags[j]):
					tag_hits += 1
		var board_hits := 0
		for c in office.board_cells.size():
			var cr := _screen_rect(cam, [office.board_cells[c]])
			for t in tags:
				if t.intersects(cr):
					board_hits += 1
		var pts: Array = []
		for p3 in corners:
			pts.append(cam.unproject_position(p3) if not cam.is_position_behind(p3) else Vector2.INF)
		var area := 0.0
		if not pts.has(Vector2.INF):
			for i in 4:
				area += pts[i].x * pts[(i + 1) % 4].y - pts[(i + 1) % 4].x * pts[i].y
		var outside := 0
		for p3 in probes:
			if cam.is_position_behind(p3) or not Rect2(Vector2.ZERO, vp_size).has_point(cam.unproject_position(p3)):
				outside += 1
		csv.store_line("%d,%d,%d,%d,%d,%.1f,%d" % [ang.x, ang.y, occ, tag_hits, board_hits, absf(area) / 2.0 / (vp_size.x * vp_size.y) * 100.0, outside])
	csv.close()
	print("[SWEEP] 재기 끝 %d개" % angles.size())
	if not thumbs:
		main.quit_game()
		return

	# 2) 그림: 상태 4종 (일함 · 내 차례 15초 · 끝 · 회의) + 나머지 일함, 이름판은 평소대로
	var states := ["work", "turn15", "done", "meet"]
	for i in office.staff.size():
		office.set_hover(i, false)
		office.set_state(i, states[i] if i < states.size() else "work")
	main.ui.visible = false
	for ang in angles:
		_aim(cam, target, dist, ang)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = main._capture()
		img.convert(Image.FORMAT_RGBA8)
		var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color("9db8d6"))
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		bg.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		bg.save_png("%s/y%02d_p%02d.png" % [dir_out, ang.x, ang.y])
	print("[SWEEP] 그림 끝 → %s" % out)
	main.quit_game()


## 좌우 yaw · 내려다봄 pitch 로 카메라 위치 (main.gd 와 같은 식). 90° 바로 위는 위쪽 방향을 뒤 (-z, 좌우만큼 돌림) 로
func _aim(cam: Camera3D, target: Vector3, dist: float, ang: Vector2i) -> void:
	var y := deg_to_rad(ang.x)
	var p := deg_to_rad(ang.y)
	cam.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
	var up := Vector3.UP if ang.y < 89 else -Vector3(sin(y), 0, cos(y))
	cam.look_at(target, up)


## scenario 의 가림 규칙과 같음: 뒷줄 얼굴 ↔ 모니터 · 앞줄 직원, 앞줄 직원 ↔ 자기 모니터, 보드칸 ↔ 직원 · 모니터 (겹친 쌍 수)
func _occlusion(cam: Camera3D, office: Node3D, desks: Array) -> int:
	var n := 0
	var head := func(id: int) -> Rect2: return _screen_rect(cam, [office.staff[id].head])
	var body := func(id: int) -> Rect2: return _screen_rect(cam, [office.staff[id].body, office.staff[id].head])
	var screen := func(id: int) -> Rect2: return _screen_rect(cam, [office.desk_parts[id].screen])
	for a in desks:
		if a.row == 0:
			for d in desks:
				if head.call(a.id).intersects(screen.call(d.id)):
					n += 1
				if d.row == 1 and head.call(a.id).intersects(body.call(d.id)):
					n += 1
		elif screen.call(a.id).intersects(body.call(a.id)):
			n += 1
	for c in office.board_cells.size():
		var cr := _screen_rect(cam, [office.board_cells[c]])
		for d in desks:
			if cr.intersects(body.call(d.id)) or cr.intersects(screen.call(d.id)):
				n += 1
	return n
