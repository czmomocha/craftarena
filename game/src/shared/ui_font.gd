class_name UiFont
extends RefCounted

## 入包字体的单一落点。
##
## 此前中文靠引擎回退字体渲染，所以"UI 用的是哪个字体"这个问题没有答案，
## 也就没有可断言的东西。字体入包之后路径会出现在三个地方——项目设置的
## `gui/theme/custom_font`、产品 UI 主题的 `default_font`、包内自检——散在
## 三处就迟早会漂移。这里是唯一的所有者。
##
## 字体本身是 Noto Sans SC 的常用 3500 字子集（SIL OFL 1.1）。OFL 的保留字体名
## 约束要求子集产物不得沿用原字体名，所以它叫 `FAMILY_NAME`，不叫 "Noto Sans SC"。
## 子集化与改名的可复现步骤在 `tools/font-subset/README.md`。

const FONT_PATH: String = "res://content/ui/fonts/craftarena_sans_sc_regular.otf"

## 重命名后的 family。测试拿它当"这份子集确实被改过名"的证据。
const FAMILY_NAME: String = "CraftArena Sans SC"

## 自检与测试用的探针汉字：一个必定落在子集里的常用字。
##
## 刻意写死，不从 `UiCopy` 取。`UiCopy.text()` 找不到键时返回键名本身，
## 首字符是 ASCII，于是「这份字体有没有汉字字形」会被悄悄换成
## 「有没有 `c` 的字形」——后者恒为真，探针就失效了。
## 本地化表自身是否可读由 `locale_table_loadable` 单独负责。
const PROBE_CHAR: String = "快"


## 加载失败返回 null，由调用方决定是回退还是报错；这里不静默换成系统字体，
## 否则"字体没进包"和"字体进包了"在窗口里长得一模一样。
static func default_font() -> Font:
	var resource: Resource = load(FONT_PATH)
	return resource as Font
