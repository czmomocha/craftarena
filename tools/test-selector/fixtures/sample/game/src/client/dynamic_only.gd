extends RefCounted

## 夹具：实参不是字面量的 load，静态图看不出它到底依赖谁。


func fetch(path: String) -> Resource:
	return load(path)
