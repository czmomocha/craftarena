class_name UiCopyTable
extends RefCounted

## CSV 读表。必须走 `FileAccess.get_csv_line`：手写按字符拆行在导出后的
## `.gdc` 里会拆出 0 行（2026-09-02 真导出）。从 `ui_copy.gd` 拆出以守 E9。

static func parse(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var header: PackedStringArray = file.get_csv_line(",")
	if header.size() > 0:
		header[0] = header[0].replace("\uFEFF", "").strip_edges()
	var tables: Dictionary = {}
	if header.size() < 2 or header[0] != "keys":
		file.close()
		return tables
	for col: int in range(1, header.size()):
		tables[String(header[col])] = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line(",")
		if _row_is_blank(row):
			continue
		var key: String = String(row[0]).strip_edges()
		if key == "" or key.begins_with("#"):
			continue
		for locale_col: int in range(1, mini(row.size(), header.size())):
			var locale: String = String(header[locale_col])
			var existing: Variant = tables.get(locale, null)
			if typeof(existing) != TYPE_DICTIONARY:
				continue
			var bag: Dictionary = existing
			bag[key] = String(row[locale_col])
			tables[locale] = bag
	file.close()
	return tables


static func _row_is_blank(fields: PackedStringArray) -> bool:
	if fields.is_empty():
		return true
	if fields.size() == 1 and fields[0] == "":
		return true
	return false
