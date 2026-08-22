class_name TraprushFinishAccept
extends RefCounted

## 终点垫盒占用验收：全部强制检查点完成后，只在胶囊与终点盒相交时冲线。
## 依据 CD-21 §6：默认结束规则是到达终点；冲线 Tick 由服务端占用判定。
## 依据 CD-21 §8：客户端不得发送冲线结果。无 FinishIntent。
## 几何查询用 overlaps_static_box（与 PadAccept 相同）；终点垫通常为 non-solid。
## 不调用 world.tick()；不 try_move / set_pose；不从客户端 Dictionary 读冲线标志。
## 本函数只回答可否冲线，不写入 finish_tick。

const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")


static func try_cross(
	world: SimulationWorld,
	entity_id: int,
	track: TraprushCheckpointTrack,
	finish_box_id: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	if track == null:
		return failed
	var checkpoint_track: CheckpointTrack = track
	if not checkpoint_track.is_finished():
		return failed
	if not world.overlaps_static_box(entity_id, finish_box_id):
		return failed
	return {"ok": true}
