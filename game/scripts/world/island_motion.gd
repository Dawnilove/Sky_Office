extends Node
## 섬의 움직임: 평소엔 둥실둥실 떠 있고, 창을 끌어 옮기면 반대 방향으로 살짝 기울었다가 출렁이며 돌아옴
## (스프링-감쇠 운동: 기울기'' = -강성 × (기울기 - 목표) - 감쇠 × 기울기')

const STIFFNESS := 40.0
const DAMPING := 7.0
const MAX_TILT := 0.08       ## 최대 기울기(라디안, 약 4.6도) — 창 표시 영역을 넘지 않게 작게
const BOB_HEIGHT := 0.04     ## 둥실둥실 높이(m)

var island: Node3D
var _last_pos := Vector2i.ZERO
var _tilt := Vector2.ZERO    ## x = 앞뒤(rotation.x), y = 좌우(rotation.z)
var _vel := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_last_pos = DisplayServer.window_get_position()


func _process(delta: float) -> void:
	if island == null or delta <= 0.0:
		return
	_t += delta
	var pos := DisplayServer.window_get_position()
	var win_vel := Vector2(pos - _last_pos) / delta
	_last_pos = pos
	var target := Vector2.ZERO
	if Game.settings.sway:
		# 오른쪽으로 끌면 섬은 관성 때문에 왼쪽으로 기울어 보이게 (z축 회전), 아래로 끌면 앞으로
		target = Vector2(clamp(win_vel.y * 0.00012, -MAX_TILT, MAX_TILT), clamp(win_vel.x * 0.00012, -MAX_TILT, MAX_TILT))
	var acc := -STIFFNESS * (_tilt - target) - DAMPING * _vel
	_vel += acc * delta
	_tilt += _vel * delta
	_tilt = _tilt.clamp(Vector2(-MAX_TILT, -MAX_TILT), Vector2(MAX_TILT, MAX_TILT))
	island.rotation.x = _tilt.x
	island.rotation.z = _tilt.y
	island.position.y = BOB_HEIGHT * sin(_t * 0.9)   # 항상 은은하게 둥실
