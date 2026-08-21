class_name TraprushPortalGraph
extends RefCounted

## 若干 portal_link 组成的传送图。
## 依据 CD-21 §4.2：传送链长度有上限，禁止无限循环。max_hops 必须由调用方传入，本文件不写死产品上限。

var _by_source: Dictionary[int, TraprushPortalLink] = {}


func add_link(link: TraprushPortalLink) -> bool:
	if link == null:
		return false
	if _by_source.has(link.source_id):
		return false
	_by_source[link.source_id] = link
	return true


func follow(start_id: int, max_hops: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if max_hops < 1:
		return failed
	var visited: Dictionary[int, bool] = {}
	var current_id: int = start_id
	var hops: int = 0
	var last: TraprushPortalLink = null
	while hops < max_hops:
		if visited.has(current_id):
			return failed
		visited[current_id] = true
		if not _by_source.has(current_id):
			if last == null:
				return failed
			return _success(last)
		last = _by_source[current_id]
		current_id = last.dest_id
		hops += 1
	if last == null:
		return failed
	if visited.has(current_id):
		return failed
	if _by_source.has(current_id):
		return failed
	return _success(last)


func _success(link: TraprushPortalLink) -> Dictionary:
	var pose: Dictionary = link.apply()
	pose["ok"] = true
	return pose
