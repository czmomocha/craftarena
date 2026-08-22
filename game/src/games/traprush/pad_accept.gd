class_name TraprushPadAccept
extends RefCounted

## 检查点垫盒占用验收：只在胶囊与垫盒相交时推进有序进度。
## 依据 CD-21 §8：检查点完成由服务端从占用判定，客户端不得发送完成断言。
## 依据 CD-21 §4.2：玩家必须经过有序检查点。垫盒通常为 non-solid，以便站在体积内。
## 不调用 world.tick()；不 try_move / set_pose；不从客户端 Dictionary 读完成标志。

const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")


static func try_accept_on_pad(
	world: SimulationWorld,
	entity_id: int,
	track: TraprushCheckpointTrack,
	checkpoint_id: int,
	pad_box_id: int
) -> bool:
	if world == null:
		return false
	if track == null:
		return false
	if not world.overlaps_static_box(entity_id, pad_box_id):
		return false
	var checkpoint_track: CheckpointTrack = track
	return checkpoint_track.try_accept(checkpoint_id)
