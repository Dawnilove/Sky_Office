extends Node
## 직원 카드 (1.3): 직원을 누르면 이름 + 상태 + [프로젝트 완료] (확인 단계). 일하는 중에는 못 누름
##   프로젝트 완료 = 그 직원의 단골 표시만 뺌 (직원은 남음). 같은 프로젝트를 다시 열면 원래 직원이 돌아옴

const StaffRegistry := preload("res://scripts/world/staff_registry.gd")
const Company := preload("res://scripts/world/company.gd")

var firm_ui: Node
var office: Node3D
var routine: Node
var watch: Node
var show: Node   ## company_show (연출)
var card: PanelContainer


func setup(f: Node, o: Node3D, r: Node, w: Node, s: Node = null) -> void:
	show = s
	firm_ui = f
	office = o
	routine = r
	watch = w


## 끝낼 수 있는 상태: 일하는 중 · 내 차례 · 대기가 아닐 때 (일하는 중에 끝내도 바로 복귀해서 의미가 없음)
static func can_finish(state: String) -> bool:
	return state in ["rest", "done", "off"]


## 화면 클릭 → 직원이면 카드 (처리했으면 true)
func click(screen: Vector2) -> bool:
	if routine == null or watch == null:
		return false
	var i: int = routine.pick_at(screen)
	if i < 0:
		return false
	var id: int = routine.staff_id_at(i)
	if id < 0:
		return false
	show_card(id, i)
	return true


func show_card(id: int, i: int, confirm := false) -> void:
	_drop()
	var st := StaffRegistry.staff_by_id(watch.snap.staff, id)
	if st.is_empty():
		return
	var nm := str(routine.looks.get(id, {}).get("name", ""))
	var cv: Array = firm_ui._float_card(nm if nm != "" else "직원")
	card = cv[0]
	var v: VBoxContainer = cv[1]
	firm_ui._big_card(card, v)
	var state := str(office.staff[i].state)
	var ok := can_finish(state) and not bool(st.get("done", false))
	if confirm:
		v.add_child(firm_ui._big_note("이 프로젝트를 끝낼까요?
직원은 남고, 같은 프로젝트를 다시 열면 돌아와요.", 14))
		firm_ui._big_buttons(v, [["끝내기", func() -> void:
			var now := Time.get_unix_time_from_system()
			var honor: Array = Game.company.get("honor", [])
			honor.append(Company.honor_entry(st, routine.looks.get(id, {}).get("look", {}), now))   # 기념사진 (겉모습 · 날짜 · 기간만)
			Game.company.honor = honor
			Game.save_game()
			if show != null:
				show.honor_scene(i)
			else:
				office.refresh_honor(true)
			watch.finish_project(id)
			_drop()], ["취소", _drop]])
	else:
		v.add_child(firm_ui._big_note(routine.bubble_text(state, {}) if not bool(st.get("done", false)) else "끝낸 프로젝트예요", 14))
		var items := [["닫기", _drop]]
		if ok:
			items.push_front(["프로젝트 완료", show_card.bind(id, i, true)])
		else:
			v.add_child(firm_ui._big_note("일하는 중에는 끝낼 수 없어요" if not bool(st.get("done", false)) else "같은 프로젝트를 다시 열면 돌아와요", 13))
		firm_ui._big_buttons(v, items)
	firm_ui._place(card, 0.45)


func _drop() -> void:
	if card != null and is_instance_valid(card):
		firm_ui._close(card)
	card = null
