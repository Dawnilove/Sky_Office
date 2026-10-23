extends RefCounted
## 연출 감독 (M5 5세션째, PLAN 5-7 C44 · C36 '잔잔 예산') — 순수 함수만, 화면과 상관없음 → 시나리오 · 하루 빨리 보기가 그대로 씀
##   ① 말 걸기 (내 차례) 가 늘 먼저: 누가 내 차례면 큰 움직임 · 버릇 · 모임 · 점심을 새로 시작하지 않음 ('!' 가 안 묻히게).
##      내 차례 직원은 연출 대상이 아님 (모임 · 점심은 쉬는 직원만 — office.resting)
##   ② 크게 움직이는 직원 = 동시에 big_max 명 (3) 까지
##   ③ 같은 직원 큰 연출 = big_gap_s (10분) 에 1번
##   ④ 조용히 모드 (C36): 큰 움직임 · 버릇 · 아침 조회 · 점심 · 단계 모임을 끔. 말 거는 장면 (내 차례 · 딩 · 일 받기 · 보고 · 출퇴근) 은 그대로
## 값은 data/idle_weights.json (big_max · big_gap_s) — '하루 빨리 보기' (scripts/dev/fast_day.gd) 재생으로 조정

const BIG_ACTS := ["coffee", "sofa", "chat", "pier", "quirk", "read", "doodle", "pet"]


## 쉬는 행동 하나 허락: 바라는 act → 실제 act ("stand" = 그 자리에서 쉼)
##   ctx = {turn: 누가 내 차례, quiet: 조용히 모드, big_now: 지금 크게 움직이는 다른 직원 수, last_big: 이 직원 마지막 큰 연출 시각, now}
static func rest_act(act: String, ctx: Dictionary, cfg: Dictionary) -> String:
	if not (act in BIG_ACTS):
		return act
	if bool(ctx.get("turn", false)) or bool(ctx.get("quiet", false)):
		return "stand"
	if int(ctx.get("big_now", 0)) + (2 if act == "chat" else 1) > int(cfg.get("big_max", 3)):
		return "stand"
	var last := float(ctx.get("last_big", -1.0e18))
	if float(ctx.get("now", 0.0)) - last < float(cfg.get("big_gap_s", 600)):
		return "stand"
	return act


## 일하는 중 버릇 (5-3 긴 일 버릇): 내 차례가 있거나 조용히 모드면 안 함
static func work_quirk(ctx: Dictionary) -> bool:
	return not bool(ctx.get("turn", false)) and not bool(ctx.get("quiet", false))


## 회사 장면 (company_show): "play" 지금 · "wait" 미룸 · "lite" 모임 없이 (가구 · 팝업만) · "skip" 오늘은 안 함
##   kind = assembly · lunch · stage · end · early · day
static func scene(kind: String, ctx: Dictionary) -> String:
	var turn := bool(ctx.get("turn", false))
	var quiet := bool(ctx.get("quiet", false))
	match kind:
		"assembly", "lunch":
			return "skip" if turn or quiet else "play"
		"stage":
			if turn:
				return "wait"
			return "lite" if quiet else "play"
	return "play"   # 출퇴근 · 일찍 퇴근 · 새 하루 = 상태를 보여 주는 장면이라 늘
