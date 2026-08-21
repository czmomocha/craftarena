class_name TraprushPortalLanding
extends RefCounted

## 把 portal.follow 的落点接到 SimulationWorld.try_set_pose。
## 依据 CD-21 §4.2：出口被占用时等待确定性安全落点，不赋予自动相位穿透。
## max_hops 由调用方传入，本文件不写死产品上限。不调用 world.tick()。

const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")


static func try_land(
	world: SimulationWorld,
	entity_id: int,
	graph: TraprushPortalGraph,
	start_id: int,
	max_hops: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	if graph == null:
		return failed
	var current: Dictionary = world.get_pose(entity_id)
	if current.is_empty():
		return failed
	var portal_graph: PortalGraph = graph
	var followed: Dictionary = portal_graph.follow(start_id, max_hops)
	var follow_ok: bool = followed.get("ok", false)
	if not follow_ok:
		return failed
	var dest_x: int = followed.get("x", 0)
	var dest_y: int = followed.get("y", 0)
	var dest_z: int = followed.get("z", 0)
	var dest_yaw: int = followed.get("dest_yaw_bam", 0)
	if world.try_set_pose(entity_id, dest_x, dest_y, dest_z, dest_yaw):
		return {"ok": true, "landed": true}
	return {"ok": true, "landed": false}
