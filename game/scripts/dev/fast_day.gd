extends Node
## 하루 빨리 보기 (M5 5세션째, PLAN 5-7 C42 + C47) — 녹화 재생 → 장면 로그 + 요약, 상한을 넘으면 종료 코드 1
##   화면 없이 순수 함수만 돌림: agent_state (판단) → staff_registry (직원) → office_routine.targets · step (보이는 것)
##   → 쉬는 행동은 office.pick_act + 연출 감독 (director.gd) 을 같은 규칙으로 흉내. 난수 = scenes.json seed, 시각 = 녹화 시각
##   실행 (SkyOffice 폴더에서): bash tools/offscreen_test.sh --fast-day          (기본 = fixtures/replay_m0.jsonl)
##                            bash tools/offscreen_test.sh --fast-day=C:/경로/녹화.jsonl  (replay_fixture.py 로 바꾼 것)
##   출력: [DAY] 줄 (장면 로그는 `--fast-day-log` 일 때만 전부) · 끝 보고 기준 시간 후보별 긴 보고 수 · 상한 확인

const AgentState := preload("res://scripts/world/agent_state.gd")
const StaffRegistry := preload("res://scripts/world/staff_registry.gd")
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")
const Office := preload("res://scripts/world/office.gd")
const Director := preload("res://scripts/world/director.gd")
const SCENES := "res://data/scenes.json"
const IDLE := "res://data/idle_weights.json"
const DEFAULT := "res://scripts/dev/fixtures/replay_m0.jsonl"

var main: Node3D


static func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func read_lines(path: String) -> Array:
	var out: Array = []
	for raw in FileAccess.get_file_as_string(path).split("\n", false):
		var e = JSON.parse_string(raw)
		if e is Dictionary:
			out.append(e)
	out.sort_custom(func(a, b) -> bool: return float(a.t) < float(b.t))
	return out


## 재생 (순수): lines = 녹화 줄 (시각 순) · sc = scenes.json · cfg = idle_weights.json
##   → {log: [[t, 직원 키, 장면]], summary: {...}, fails: [글]}
##   opts = {quiet: 조용히 모드, desks: 책상 수}
static func run(lines: Array, sc: Dictionary, cfg: Dictionary, opts := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sc.get("seed", 7))
	var step_s := float(sc.get("step_s", 5))
	var desks := int(opts.get("desks", sc.get("desks", 4)))
	var quiet := bool(opts.get("quiet", false))
	var names: Dictionary = sc.get("scenes", {})
	var lim: Dictionary = sc.get("limits", {})
	var span: Array = cfg.get("act_s", [30, 180])
	var wspan: Array = cfg.get("work_quirk_s", [90, 240])
	var long_s := float(AgentState.timings().get("long_work_s", 60))
	var rows: Array = []
	var fails: Array = []
	if lines.is_empty():
		return {"log": rows, "summary": {}, "fails": ["녹화 줄 없음"]}
	var t0 := float(lines[0].t)
	var t1 := float(lines[-1].t)
	var agent := AgentState.empty()
	var reg := StaffRegistry.empty()
	var shown := {}
	var life := {}      ## 직원 키 → {act, until, big_at, quirk_at, person}
	var works := {}     ## 세션 → 일 시작 시각 (끝 보고 길이 재기)
	var durs: Array = []
	var ei := 0
	var now := t0
	var big_peak := 0
	var big_in_turn := 0
	var gap_bad := 0
	var count := {}
	while now <= t1 + step_s:
		while ei < lines.size() and float(lines[ei].t) <= now:
			var e: Dictionary = lines[ei]
			ei += 1
			var sid := str(e.get("sess", ""))
			var ev := str(e.get("event", ""))
			if ev == "UserPromptSubmit":
				rows.append([float(e.t), sid, names.get("plane", "plane")])
				works[sid] = float(e.t)
			elif ev == "PostToolUse" and not works.has(sid):
				works[sid] = float(e.t)
			elif ev in ["Stop", "StopFailure"] and works.has(sid):
				durs.append(float(e.t) - float(works[sid]))
				works.erase(sid)
			agent = AgentState.reduce(agent, e)
			if str(e.get("proj", "")) != "":
				reg = StaffRegistry.touch(reg, "claude", str(e.proj), float(e.t), now)
		reg = StaffRegistry.sync(reg, desks, now)
		var want := OfficeRoutine.targets(agent, reg, now)
		var before := shown
		shown = OfficeRoutine.step(shown, want, now)
		var turn := false
		for k in shown:
			if str(shown[k].look) in OfficeRoutine.TURN_LOOKS:
				turn = true
		for k in shown:
			var look := str(shown[k].look)
			var prev := str(before.get(k, {}).get("look", "off"))
			if look != prev:
				var nm := "staff" if prev in ["off", "hide"] and not (look in ["off", "hide"]) else look
				if names.has(nm):
					rows.append([now, k, names[nm]])
					count[nm] = int(count.get(nm, 0)) + 1
		# 쉬는 행동 · 버릇 (책상 직원만, office.life_tick 과 같은 규칙)
		var movers := 0
		for k in life:
			if not shown.has(k):
				life[k].act = ""
			if str(life[k].act) in Director.BIG_ACTS:
				movers += 1
		for k in shown:
			var w: Dictionary = want.get(k, {})
			if not str(k).begins_with("s:") or bool(w.get("guest", true)):
				continue
			var look := str(shown[k].look)
			if not life.has(k):
				life[k] = {"act": "", "until": 0.0, "big_at": -1.0e18, "quirk_at": 0.0, "person": Office.personality_of(int(w.staff), cfg)}
			var L: Dictionary = life[k]
			if not (look in ["rest", "done"]):
				if str(L.act) in Director.BIG_ACTS:
					movers -= 1
				L.act = ""
				L.until = 0.0
				if look == "work":
					if float(L.quirk_at) <= 0.0:
						L.quirk_at = now + long_s + rng.randf_range(0.0, float(wspan[0]))
					elif now >= float(L.quirk_at):
						L.quirk_at = now + rng.randf_range(float(wspan[0]), float(wspan[1]))
						if Director.work_quirk({"turn": turn, "quiet": quiet}):
							rows.append([now, k, names.get("quirk", "quirk")])
							count.quirk = int(count.get("quirk", 0)) + 1
				else:
					L.quirk_at = 0.0
				continue
			if now < float(L.until):
				continue
			if str(L.act) in Director.BIG_ACTS:
				movers -= 1
			var ctx := {"turn": turn, "quiet": quiet, "big_now": movers, "last_big": float(L.big_at), "now": now}
			var act := Director.rest_act(Office.pick_act(str(L.person), cfg, rng.randf()), ctx, cfg)
			if act == "chat":
				act = "coffee"   # 상대 고르기는 화면 쪽 — 여기선 1명 몫으로
			L.act = act
			L.until = now + rng.randf_range(float(span[0]), float(span[1]))
			if act in Director.BIG_ACTS:
				if turn:
					big_in_turn += 1
				if now - float(L.big_at) < float(lim.get("big_gap_s", 600)):
					gap_bad += 1
				L.big_at = now
				movers += 1
				rows.append([now, k, "%s:%s" % [names.get("big", "big"), act]])
				count.big = int(count.get("big", 0)) + 1
		big_peak = maxi(big_peak, movers)
		now += step_s
	var hours := maxf((t1 - t0) / 3600.0, 1.0 / 60.0)
	var tries := {}
	for b in sc.get("report_long_try_s", [60, 180, 300]):
		tries[str(int(b))] = durs.filter(func(d): return d > float(b)).size()
	var summary := {"hours": snappedf(hours, 0.01), "events": lines.size(), "staff": reg.staff.size(), "counts": count,
			"big_peak": big_peak, "big_in_turn": big_in_turn, "big_gap_bad": gap_bad,
			"big_per_hour": snappedf(float(count.get("big", 0)) / hours, 0.1), "reports": durs.size(), "long_by_base": tries}
	if big_peak > int(lim.get("big_max", 3)):
		fails.append("큰 움직임 동시 %d명 > %d" % [big_peak, int(lim.big_max)])
	if big_in_turn > int(lim.get("big_during_turn", 0)):
		fails.append("내 차례 중 큰 움직임 %d번" % big_in_turn)
	if gap_bad > 0:
		fails.append("같은 직원 큰 연출 %d초 안에 다시 %d번" % [int(lim.get("big_gap_s", 600)), gap_bad])
	if float(summary.big_per_hour) > float(lim.get("big_per_hour", 30)):
		fails.append("큰 움직임 시간당 %s번 > %s" % [summary.big_per_hour, lim.big_per_hour])
	var base := str(int(sc.get("report_long_s", long_s)))
	if tries.has(base) and float(tries[base]) / hours > float(lim.get("long_reports_per_hour", 8)):
		fails.append("긴 끝 보고 시간당 %.1f번 > %s (기준 %s초)" % [float(tries[base]) / hours, lim.long_reports_per_hour, base])
	return {"log": rows, "summary": summary, "fails": fails}


func _ready() -> void:
	var path := DEFAULT
	for a in Game.dev_args():
		if a.begins_with("--fast-day="):
			path = a.get_slice("=", 1)
	var t := Time.get_ticks_msec()
	var r := run(read_lines(path), load_json(SCENES), load_json(IDLE), {"quiet": "--quiet" in Game.dev_args()})
	if "--fast-day-log" in Game.dev_args():
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		for row in r.log:
			print("[DAY] %s %s %s" % [OfficeRoutine.clock(float(row[0]), bias), row[1], row[2]])
	print("[DAY] 녹화 %s · %s시간 · 줄 %d · 직원 %d · 재생 %dms" % [path.get_file(), r.summary.hours, r.summary.events, r.summary.staff, Time.get_ticks_msec() - t])
	print("[DAY] 장면 수 %s" % JSON.stringify(r.summary.counts))
	print("[DAY] 큰 움직임: 동시 최대 %d명 · 시간당 %s번 · 내 차례 중 %d번 · 10분 안 다시 %d번" % [r.summary.big_peak, r.summary.big_per_hour, r.summary.big_in_turn, r.summary.big_gap_bad])
	print("[DAY] 끝 보고 %d번 · 기준 시간별 긴 보고 수 %s" % [r.summary.reports, JSON.stringify(r.summary.long_by_base)])
	for f in r.fails:
		print("[DAY] ✘ " + str(f))
	print("[DAY] 결과: %s" % ("통과" if r.fails.is_empty() else "실패 %d" % r.fails.size()))
	get_tree().quit(0 if r.fails.is_empty() else 1)
