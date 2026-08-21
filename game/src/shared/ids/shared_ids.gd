class_name SharedIds
extends RefCounted

## L0 稳定 ID。权威仿真、命令、事件共用同一套规则：0 表示空，正整数才有效。
## 定点数合同见 CD-42 §1.1，不在本文件复述。

const CONTRACT_VERSION: int = 1
const NULL_ID: int = 0


static func is_valid(id: int) -> bool:
	return id > NULL_ID
