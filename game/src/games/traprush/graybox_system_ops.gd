class_name TraprushGrayboxSystemOps
extends RefCounted

## 灰盒权威 SYSTEM payload.op 名。不是 PLAYER Intent，客户端不得提交。
## 依据 CD-21 §8：检查点完成、传送落地和冲线由服务端占用判定；出界复位是服务端环境失败（CD-21 §6）。
## 本名单只给命令日志与回放夹具用。break_crate 是灰盒测试入口，不是客户端破坏断言。
## commit_tick 是服务端推进 tick（先重力积分再切换 hazard），客户端不得提交。
## apply_fall 是独立位移、不推进 tick、不改 vy；try_commit_tick 内部积分不另记 apply_fall。

const PLACE_POSE: String = "place_pose"
const ACCEPT_CHECKPOINT: String = "accept_checkpoint"
const LAND_PORTAL: String = "land_portal"
const CROSS_FINISH: String = "cross_finish"
const RESET_IF_OUT_OF_RANGE: String = "reset_if_out_of_range"
const BREAK_CRATE: String = "break_crate"
const COMMIT_TICK: String = "commit_tick"
const APPLY_FALL: String = "apply_fall"
