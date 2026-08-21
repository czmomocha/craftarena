class_name TraprushPortalLink
extends RefCounted

## 单向传送边：稳定出口 ID、Q48.16 安全落点、BAM 朝向。
## 依据 CD-21 §4.2：每个出口具有稳定 ID、朝向和安全落点；传送由调用方在权威侧确认。
## 落点是定点整数，不把米写成 float。本类型只计算落点，不做客户端预测。

var source_id: int = 0
var dest_id: int = 0
var x: int = 0
var y: int = 0
var z: int = 0
var dest_yaw_bam: int = 0


func _init(
	p_source_id: int = 0,
	p_dest_id: int = 0,
	p_x: int = 0,
	p_y: int = 0,
	p_z: int = 0,
	p_dest_yaw_bam: int = 0
) -> void:
	source_id = p_source_id
	dest_id = p_dest_id
	x = p_x
	y = p_y
	z = p_z
	dest_yaw_bam = p_dest_yaw_bam


func apply() -> Dictionary:
	return {
		"dest_id": dest_id,
		"x": x,
		"y": y,
		"z": z,
		"dest_yaw_bam": dest_yaw_bam,
	}
