class_name FixedResult
extends RefCounted

## 定点或 int64 运算的结果。ok = false 表示溢出或除零，value 必须忽略。

var ok: bool = false
var value: int = 0


static func success(value: int) -> FixedResult:
	var result: FixedResult = FixedResult.new()
	result.ok = true
	result.value = value
	return result


static func fail() -> FixedResult:
	var result: FixedResult = FixedResult.new()
	result.ok = false
	result.value = 0
	return result
