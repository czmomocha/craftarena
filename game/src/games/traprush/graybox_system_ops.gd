class_name TraprushGrayboxSystemOps
extends RefCounted

## 灰盒权威占用记录的 SYSTEM payload.op 名。不是 PLAYER Intent，客户端不得提交。
## 依据 CD-21 §8：检查点完成、传送落地和冲线由服务端占用判定；本名单只给命令日志与回放夹具用。

const PLACE_POSE: String = "place_pose"
const ACCEPT_CHECKPOINT: String = "accept_checkpoint"
const LAND_PORTAL: String = "land_portal"
const CROSS_FINISH: String = "cross_finish"
