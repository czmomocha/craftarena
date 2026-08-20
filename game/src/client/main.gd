extends Node

## 客户端启动场景。M0 阶段只负责证明工程能起来，并打印一行结构化启动日志，
## 供 Headless 烟测与 CI 直接断言。真正的大厅与玩法入口在后续里程碑接入。

const BOOT_EVENT: String = "client_boot"


func _ready() -> void:
	print(_format_log_line(BOOT_EVENT, {
		"project": ProjectSettings.get_setting("application/config/name", ""),
		"engine": Engine.get_version_info().get("string", ""),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"headless": DisplayServer.get_name() == "headless",
		"debug_build": OS.is_debug_build(),
	}))


static func _format_log_line(event: String, fields: Dictionary) -> String:
	var payload: Dictionary = fields.duplicate()
	payload["event"] = event
	return JSON.stringify(payload)
