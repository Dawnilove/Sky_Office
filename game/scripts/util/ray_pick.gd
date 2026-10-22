extends RefCounted
## 클릭 광선이 물건의 "실제 모양(삼각형)"에 닿았는지 — 상자(AABB) 판정은 실제보다 커서 옆 칸·뒤 칸 클릭까지 가로챔
## (예: 우체통·자라는 작물 때문에 빈 밭 칸이 안 눌리던 문제)

static var _tris := {}   ## Mesh → TriangleMesh (한 번 만들면 계속 씀)


## 광선이 노드 안 메시의 실제 면에 닿으면 카메라에서의 거리, 아니면 INF
static func distance(n: Node3D, origin: Vector3, dir: Vector3) -> float:
	var best := INF
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if (mi.global_transform * mi.get_aabb()).grow(0.01).intersects_ray(origin, dir) == null:
			continue   # 상자에도 안 닿으면 볼 필요 없음 (빠른 거르기)
		var tm: TriangleMesh = _tris.get(mi.mesh)
		if tm == null:
			tm = mi.mesh.generate_triangle_mesh()
			_tris[mi.mesh] = tm
		if tm == null:
			continue
		var inv := mi.global_transform.affine_inverse()
		var hit: Dictionary = tm.intersect_ray(inv * origin, (inv.basis * dir).normalized())
		if not hit.is_empty():
			best = minf(best, origin.distance_to(mi.global_transform * (hit.position as Vector3)))
	return best
