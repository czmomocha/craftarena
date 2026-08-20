extends Node

## 对局服务端进程入口（M0 占位）。
##
## CD-44 §3 要求一场对局一个 Godot Headless 进程，由 MatchHost 分配内网端口、
## 处理租约并回收。本脚本目前只做三件事：解析 MatchHost 传入的参数、打印一行可被
## 父进程断言的结构化启动日志、保持进程存活直到被回收。
##
## 权威仿真、命令处理与复制属于 M3，尚未实现。**不要**因为它能起来就把它当作
## 可用的对局服务对接（宪法第二条：服务器是唯一权威，而这里还没有任何权威逻辑）。

const BOOT_EVENT: String = "match_server_boot"


func _ready() -> void:
	var options: Dictionary = _parse_user_args(OS.get_cmdline_user_args())

	print(JSON.stringify({
		"event": BOOT_EVENT,
		"match_id": options.get("match-id", ""),
		"port": options.get("port", ""),
		"pid": OS.get_process_id(),
		"headless": DisplayServer.get_name() == "headless",
	}))


## 只接受 `--key=value` 形式。裸开关与位置参数一律忽略，避免 MatchHost 传参出错时
## 被静默地解释成别的东西。
static func _parse_user_args(user_args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}

	for argument: String in user_args:
		if not argument.begins_with("--"):
			continue

		var separator_index: int = argument.find("=")
		if separator_index <= 2:
			continue

		var key: String = argument.substr(2, separator_index - 2)
		var value: String = argument.substr(separator_index + 1)
		options[key] = value

	return options
