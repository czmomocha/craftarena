extends GutTest

## C5 第 2 章：MatchJoinSession 拆成 codec / accept / 门面。
## 断言的是拆分性质与 E9 行数，不是匹配 JSON 字段。现有
## test_match_join_session.gd 仍覆盖公开 API。

const MatchJoinCodecGd := preload("res://src/client/match_join_codec.gd")
const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")

const E9_LINE_CAP: int = 400
const JOIN_PATHS: PackedStringArray = [
	"res://src/client/match_join_accept.gd",
	"res://src/client/match_join_codec.gd",
	"res://src/client/match_join_session.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_join_files_stay_under_e9_line_cap() -> void:
	for path: String in JOIN_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_create_owns_an_accept_collaborator() -> void:
	var session: MatchJoinSessionGd = MatchJoinSessionGd.create()
	assert_not_null(session.accept)
	assert_eq(session.state, MatchJoinSessionGd.STATE_IDLE)


func test_facade_statics_delegate_to_codec() -> void:
	assert_eq(
		MatchJoinSessionGd.normalize_room_code("abcd23"),
		MatchJoinCodecGd.normalize_room_code("abcd23")
	)
	assert_eq(
		MatchJoinSessionGd.http_url("http://127.0.0.1:8080/", "/matchmaking/quick"),
		MatchJoinCodecGd.http_url("http://127.0.0.1:8080/", "/matchmaking/quick")
	)
	var parsed: Dictionary = MatchJoinSessionGd.parse_json_object("{\"ok\":true}")
	var codec_parsed: Dictionary = MatchJoinCodecGd.parse_json_object("{\"ok\":true}")
	var parsed_ok: bool = parsed.get("ok", false)
	var codec_ok: bool = codec_parsed.get("ok", false)
	assert_eq(parsed_ok, codec_ok)
