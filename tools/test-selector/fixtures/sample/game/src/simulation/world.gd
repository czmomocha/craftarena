extends RefCounted

## 夹具：中间层，依赖 fixed.gd。

const Fixed := preload("res://src/shared/fixed.gd")


func cell() -> int:
	return Fixed.SCALE
