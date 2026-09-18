extends GutTest

## 全景天空贴图的预算判定（CD-11 §8.1「独立运行时贴图」那一档，2026-09-17 拍板）。
##
## **这一档没有 CI 门禁。** `npm run asset-budget` 的 `ASSET_EXTENSION` 是 `.glb`
## （`tools/asset-budget/src/discover.ts`），直接入库的 `.png` 根本不在它的遍历里，
## 所以 CD-11 §8.1 点名两处替代保障：`--package-check` 的 `sky_textures_loadable`
## 判尺寸与 2:1 比例，本文件判字节数。既然是替代保障，这里就必须是**真断言**，
## 不是烟测——`.gd` 里此刻没有任何别的东西会因为一张超预算的天空而红。
##
## 反例喂的是 `Image.create_empty` 现构的 `ImageTexture`，不是仓库里的文件。理由
## 有两条：往 LFS 里塞一张 2048 的图只为证明门禁会咬，代价是一份永久垃圾；而改
## `sky_catalog.gd` 的常量做故障注入在 Windows 上会毁掉那份中文注释的编码
## （2026-09-17 实测把一个 headless 进程挂死）。判定被抽成纯函数就是为了这个。
##
## 与 `test_traprush_sky_contract.gd` 的分工：那边判契约（三级门禁、wire、编译），
## 本文件判**这两张图本身**。「图在不在」在那边，「图对不对」在这里。

const SharedSkyCatalog := preload("res://src/shared/sky_catalog.gd")

## CD-11 §8.1 第二行「单张独立贴图文件体积 2 MB」，按 1024 进制，与
## `tools/asset-budget/src/budget.ts` 的 `MAX_FILE_BYTES` 同一个数。
## 所有者是 CD-11，本常量只是它在测试里的那一份，冲突以 CD-11 为准。
const MAX_TEXTURE_FILE_BYTES: int = 2 * 1024 * 1024


# 1. 判定本身：正例与反例。

func test_budget_accepts_the_shipped_shape_and_anything_smaller_at_two_to_one() -> void:
	# 上限不是等式：比 1024 小的 2:1 全景照样合法，换一张更省的图不该被判失败。
	assert_true(SharedSkyCatalog.texture_meets_budget(_texture(1024, 512)))
	assert_true(SharedSkyCatalog.texture_meets_budget(_texture(512, 256)))
	assert_true(SharedSkyCatalog.texture_meets_budget(_texture(2, 1)))


func test_budget_rejects_oversize_and_non_panoramic_shapes() -> void:
	# 超宽度上限。1024 这个数的所有者是 CD-11 §8.1，这里同时钉住它，
	# 免得有人把常量调大之后本表还是绿的。
	assert_eq(SharedSkyCatalog.MAX_TEXTURE_WIDTH, 1024)
	assert_false(SharedSkyCatalog.texture_meets_budget(_texture(2048, 1024)))
	# 不是 2:1。这类图**能加载、能渲染**，贴到球面上只是歪的——典型的「存在但错」，
	# 没有这条断言就只能靠人眼在 A2 接上渲染之后发现。
	assert_false(SharedSkyCatalog.texture_meets_budget(_texture(1024, 1024)))
	assert_false(SharedSkyCatalog.texture_meets_budget(_texture(512, 1024)))
	# 差一格也不行：比例是硬条件，不是「大致」。
	assert_false(SharedSkyCatalog.texture_meets_budget(_texture(1024, 511)))
	assert_false(SharedSkyCatalog.texture_meets_budget(_texture(1024, 513)))
	# 加载失败走同一个 false，调用方因此只需要判一个东西。
	assert_false(SharedSkyCatalog.texture_meets_budget(null))


# 2. 仓库里那两张图。

func test_every_registered_sky_loads_as_a_texture_and_fits_the_budget() -> void:
	for sky_id: int in range(SharedSkyCatalog.SKY_ID_MAX + 1):
		var path: String = SharedSkyCatalog.texture_path(sky_id)
		assert_false(path.is_empty(), "天空 %d 没有路径" % sky_id)
		# `load` 而不是 `ResourceLoader.exists`：`.png` 进包是导入产物，
		# 少一次 reimport 或者错一条导出过滤，只有加载这一步能看出来。
		var texture: Texture2D = ResourceLoader.load(path) as Texture2D
		assert_not_null(texture, "%s 加载不成 Texture2D" % path)
		assert_true(
			SharedSkyCatalog.texture_meets_budget(texture),
			"%s 不满足 CD-11 §8.1：%d×%d" % [path, texture.get_width(), texture.get_height()]
		)


func test_shipped_panoramas_stay_under_the_file_size_budget() -> void:
	# CD-11 §8.1 那一档的第二行。这是它**唯一**的机械落点：`asset-budget` 不扫
	# `.png`，`--package-check` 只量尺寸。本条红 = 包体预算被突破了。
	for sky_id: int in range(SharedSkyCatalog.SKY_ID_MAX + 1):
		var path: String = SharedSkyCatalog.texture_path(sky_id)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		assert_gt(bytes.size(), 0, "%s 读不到字节（LFS 指针？）" % path)
		# `<=`，与 `asset-budget` 对 `.glb` 的判法一致（`fileBytes > MAX` 才算超）。
		assert_true(
			bytes.size() <= MAX_TEXTURE_FILE_BYTES,
			"%s 是 %d B，超过 %d B 的预算" % [path, bytes.size(), MAX_TEXTURE_FILE_BYTES]
		)


func _texture(width: int, height: int) -> ImageTexture:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	assert_not_null(texture, "构不出 %d×%d 的反例贴图" % [width, height])
	return texture
