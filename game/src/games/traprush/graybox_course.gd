class_name TraprushGrayboxCourse
extends RefCounted

## TRAPRUSH 单人灰盒跑道夹具：组装检查点、上下/侧向传送、墙盒、可破坏箱、周期 hazard。
## 依据 CD-21 §4.2 / §5.2 / §8 与 CD-61 M1 灰盒：有序检查点、传送不得跳点、破坏后开路、1 个周期障碍 stub。
## 灰盒检查点垫走 PadAccept / CD-21 §8：完成由占用判定，客户端不得断言。
## 终点垫走 FinishAccept：冲线由占用 + 全部强制检查点完成判定；无 FinishIntent（CD-21 §6 / §8）。
## finish_tick 是权威 world.tick_index，未冲线哨兵为 -1；不写入 SimulationWorld.hash_state。
## 位移、jump_dy、support_dy、fall_dy、范围边界、max_hops、max_health、period、snapshot capacity 均由调用方传入，不锁定 Tick/快照 Hz、重力或掉出次数 N（CD-63）。
## 成功 PLAYER 意图写入 SimReplayBuffer（CD-43 命令日志 + 种子）。成功的 place_pose / 检查点 / 落地传送 / 冲线 / 出界复位 / try_break_crate / try_commit_tick / try_apply_fall 写入 SYSTEM 记录（actor_id = 0），不是 FinishIntent。
## assemble 记录 tick 0 关键快照；layout 可选 shove_target 时在盒之后再生成第二胶囊，缺省 shove_target_id = 0。try_commit_tick(fall_dy) 先 TraprushGravity.integrate（fall_dy 是加速度）再推进 tick、按调用方周期切换 hazard 阻挡、再 record，成功入 SYSTEM 带。
## try_step_intent(payload, jump_dy, support_dy) 把 support_dy 传给 apply；Jump 走 apply_jump；成功 PLAYER 意图入带。Shove 不经 IntentStepper。
## try_shove(payload, cooldown_ticks, dx, dz) 委托 ShoveApply；dx/dz/冷却由调用方传入，不从 payload 读 impulse。ok 则 PLAYER 入带；shoved 才更新 last_shove_tick。无目标、解码失败不入带。不 tick。
## try_apply_fall(fall_dy) 只调用 world.try_move_y_until_blocked，不改 vy；成功入 SYSTEM 带，不 tick、不 record。
## try_reset_if_out_of_range 用已合入的只读范围查询；出界则 set_pose 到最近检查点复活落点（CD-21 §6），成功复位入 SYSTEM 带，不 tick，不计数 N。
## try_interact / try_use_item / 成功 try_shove 入 PLAYER 带；try_place_pose / 成功检查点 / 成功落地传送 / 首次冲线 / 成功出界复位 / 成功 try_break_crate / 成功 try_commit_tick / 成功 try_apply_fall 入 SYSTEM 带。world.set_pose 仍不入带。
## try_interact 仅在 overlapping_static_boxes 含 crate 时按调用方 damage 走 Destructible；摧毁则关闭 crate 盒阻挡。
## try_use_item 用当前姿态加调用方 reach 得到候选坐标，overlapping_static_boxes_at 含 crate 时才伤害；伤害与 reach 不从 payload 读取。
## try_break_crate 保持测试入口：不要求重叠；成功伤害入 SYSTEM 带。
## 整段 M1 切片（检查点、传送、周期窗口、爆破开路、冲线）由 TraprushGrayboxAcceptance.try_run 编排；本夹具不发明寻路。Acceptance 仍不含推击。
## 不从客户端 Dictionary 读最终位置、障碍死亡、道具命中、冲线结果或完成标志；不实现道具栏、2p、名次或 Headless。
## Collaborators are TraprushGrayboxLayout / Assemble / Play so this file stays under E9.
## Public API stays on this type.

const AssembleGd := preload("res://src/games/traprush/graybox_course_assemble.gd")
const PlayGd := preload("res://src/games/traprush/graybox_course_play.gd")

var world: SimulationWorld = null
var entity_id: int = 0
var track: TraprushCheckpointTrack = null
var wall_box_id: int = 0
var crate_box_id: int = 0
var hazard_box_id: int = 0
var finish_box_id: int = 0
var finish_tick: int = -1
var shove_target_id: int = 0
var crate: TraprushDestructible = null
var pad_box_ids: Array[int] = []
var tape: SimReplayBuffer = null
var snapshots: SimSnapshotRing = null

var _spawn: TraprushCheckpointSpawn = null
var _graph: TraprushPortalGraph = null
var _checkpoint_ids: Array[int] = []
var _actor_id: int = 0
var _content_version: String = ""
var _trace_id: String = ""
var _next_command_seq: int = 1
var _hazard_period_ticks: int = 0
var _last_shove_tick: int = -1


static func assemble(layout: Dictionary) -> TraprushGrayboxCourse:
	return AssembleGd.try_assemble(layout)

func try_step_intent(payload: Dictionary, jump_dy: int, support_dy: int) -> Dictionary:
	return PlayGd.try_step_intent(self, payload, jump_dy, support_dy)

func try_shove(payload: Dictionary, cooldown_ticks: int, dx: int, dz: int) -> Dictionary:
	return PlayGd.try_shove(self, payload, cooldown_ticks, dx, dz)

func try_apply_fall(fall_dy: int) -> bool:
	return PlayGd.try_apply_fall(self, fall_dy)

func try_reset_if_out_of_range(
	min_y: int,
	max_y: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> Dictionary:
	return PlayGd.try_reset_if_out_of_range(self, min_y, max_y, min_x, max_x, min_z, max_z)

func try_interact(payload: Dictionary, damage: int) -> Dictionary:
	return PlayGd.try_interact(self, payload, damage)

func try_use_item(
	payload: Dictionary,
	damage: int,
	reach_dx: int,
	reach_dy: int,
	reach_dz: int
) -> Dictionary:
	return PlayGd.try_use_item(self, payload, damage, reach_dx, reach_dy, reach_dz)

func try_commit_tick(fall_dy: int) -> bool:
	return PlayGd.try_commit_tick(self, fall_dy)

func try_break_crate(damage: int) -> Dictionary:
	return PlayGd.try_break_crate(self, damage)

func try_place_pose(x: int, y: int, z: int, yaw_bam: int) -> bool:
	return PlayGd.try_place_pose(self, x, y, z, yaw_bam)

func try_land_portal(start_id: int, dest_checkpoint_id: int, max_hops: int) -> Dictionary:
	return PlayGd.try_land_portal(self, start_id, dest_checkpoint_id, max_hops)

func try_accept_checkpoint(checkpoint_id: int) -> bool:
	return PlayGd.try_accept_checkpoint(self, checkpoint_id)

func try_cross_finish() -> Dictionary:
	return PlayGd.try_cross_finish(self)

func _append_command(payload: Dictionary, kind: int) -> bool:
	if tape == null or world == null:
		push_error("TraprushGrayboxCourse: tape append missing world or tape")
		return false
	var actor_id: int = _actor_id
	if kind == SharedCommand.Kind.SYSTEM:
		actor_id = SharedIds.NULL_ID
	var command: SharedCommand = SharedCommand.create(
		_next_command_seq,
		actor_id,
		_next_command_seq,
		world.tick_index,
		0,
		_content_version,
		payload.duplicate(true),
		_trace_id,
		kind
	)
	if command == null:
		push_error("TraprushGrayboxCourse: SharedCommand.create failed after accepted command")
		return false
	if not tape.append(command):
		push_error("TraprushGrayboxCourse: SimReplayBuffer.append failed after accepted command")
		return false
	_next_command_seq += 1
	return true

