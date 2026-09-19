extends Control
## S1 main lobby (spec 1). View only: fills designed chrome from UiCopy and
## emits intent. Channel membership, matchmaking and overlay windows stay on
## MatchLobbyShell — this file must not start a match.

signal channel_requested(gameplay: String)
signal plaza_requested()
signal settings_requested()
signal account_requested()
signal character_requested()

const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const UiCopyS1Gd := preload("res://src/shared/ui_copy_s1.gd")

## Placeholder identity / counts. Not product copy and not a data contract —
## deliberately absent from content/locale/craft_arena.csv.
const DEMO_NICKNAME: String = "Maker_042"
const DEMO_DRAFT_CHIP: String = "草稿 2"
const DEMO_PUBLISHED_CHIP: String = "已发布 1"
const DEMO_VERSION: String = "v0.2.1-dev · build 1042"

const _TRAPRUSH := "Layout/Main/Columns/Left/TraprushCard"
const _BASTION := "Layout/Main/Columns/Left/BastionCard"
const _NAV := "Layout/Main/Columns/NavColumn"

## Designed entries that this chapter must not open. 我的内容 is S5 / third
## batch. It stays visible because removing it would edit the design; it is
## disabled for the same reason S3 greys Sort / Search — an enabled control
## that silently does nothing is worse. Character select is wired this chapter.
const DEAD_NAV: Array[String] = ["NavMyContent"]

var _chrome_ready: bool = false


func _ready() -> void:
	_ensure_chrome()


func _ensure_chrome() -> void:
	if _chrome_ready:
		return
	_chrome_ready = true
	_apply_copy()
	_open_bastion_card()
	_wire_chrome()


func _apply_copy() -> void:
	_set_text("Layout/TopBar/Row/TitleBox/Subtitle", UiCopyS1Gd.BRAND_SUBTITLE)
	_set_text(_TRAPRUSH + "/Content/VBox/ChipRow/OpenChip/Label", UiCopyS1Gd.CHIP_OPEN)
	_set_text(_TRAPRUSH + "/Content/VBox/Title", UiCopyS1Gd.TRAPRUSH_TITLE)
	_set_text(_TRAPRUSH + "/Content/VBox/Desc", UiCopyS1Gd.TRAPRUSH_DESC)
	_set_text(_TRAPRUSH + "/Content/VBox/CTA", UiCopyS1Gd.ENTER)
	_set_text(_BASTION + "/Content/VBox/ChipRow/ComingChip/Label", UiCopyS1Gd.CHIP_OPEN)
	_set_text(_BASTION + "/Content/VBox/Title", UiCopyS1Gd.BASTION_TITLE)
	_set_text(_BASTION + "/Content/VBox/Desc", UiCopyS1Gd.BASTION_DESC)
	_set_text(_BASTION + "/Content/VBox/CTA", UiCopyS1Gd.ENTER)
	_set_text(_NAV + "/NavCharacter/Row/Texts/Zh", UiCopyS1Gd.NAV_CHARACTER)
	_set_text(_NAV + "/NavMyContent/Row/Texts/Zh", UiCopyS1Gd.NAV_MY_CONTENT)
	_set_text(_NAV + "/NavWorkshop/Row/Texts/Zh", UiCopyS1Gd.NAV_WORKSHOP)
	_set_text(_NAV + "/NavSettings/Row/Texts/Zh", UiCopyS1Gd.NAV_SETTINGS)
	_set_text("Layout/DevBar/Row/Online", UiCopyS1Gd.STATUS_ONLINE)
	_set_plain("Layout/TopBar/Row/IdentityBox/Nickname", DEMO_NICKNAME)
	_set_plain(_NAV + "/NavMyContent/Row/Chips/Draft/L", DEMO_DRAFT_CHIP)
	_set_plain(_NAV + "/NavMyContent/Row/Chips/Published/L", DEMO_PUBLISHED_CHIP)
	_set_plain("Layout/DevBar/Row/Version", DEMO_VERSION)
	_set_plain("Layout/DevBar/Row/HintBox/Label", "")


## BASTION is a shipped channel as of M6 E4. The mockup drew it locked; F1
## flips that without rewriting the scene tree (ComingChip keeps its name).
func _open_bastion_card() -> void:
	var card: Button = get_node_or_null(_BASTION) as Button
	if card != null:
		card.disabled = false
	var cta: Button = get_node_or_null(_BASTION + "/Content/VBox/CTA") as Button
	if cta != null:
		cta.disabled = false
	var overlay: CanvasItem = get_node_or_null(_BASTION + "/Overlay") as CanvasItem
	if overlay != null:
		overlay.visible = false


func _wire_chrome() -> void:
	_connect_button(_TRAPRUSH, func() -> void: channel_requested.emit(MatchGameplayGd.TRAPRUSH))
	_connect_button(_TRAPRUSH + "/Content/VBox/CTA", func() -> void: channel_requested.emit(MatchGameplayGd.TRAPRUSH))
	_connect_button(_BASTION, func() -> void: channel_requested.emit(MatchGameplayGd.BASTION))
	_connect_button(_BASTION + "/Content/VBox/CTA", func() -> void: channel_requested.emit(MatchGameplayGd.BASTION))
	_connect_button(_NAV + "/NavCharacter", func() -> void: character_requested.emit())
	_connect_button(_NAV + "/NavWorkshop", func() -> void: plaza_requested.emit())
	_connect_button(_NAV + "/NavSettings", func() -> void: settings_requested.emit())
	_connect_button("Layout/TopBar/Row/Gear", func() -> void: settings_requested.emit())
	for node_name: String in DEAD_NAV:
		var dead: Button = get_node_or_null("%s/%s" % [_NAV, node_name]) as Button
		if dead != null:
			dead.disabled = true
	_wire_identity()


func _wire_identity() -> void:
	var identity: Control = get_node_or_null("Layout/TopBar/Row/IdentityBox") as Control
	if identity == null:
		return
	identity.mouse_filter = Control.MOUSE_FILTER_STOP
	identity.gui_input.connect(_on_identity_gui_input)
	var avatar: Control = get_node_or_null("Layout/TopBar/Row/Avatar") as Control
	if avatar != null:
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		avatar.gui_input.connect(_on_identity_gui_input)


func _on_identity_gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	account_requested.emit()


func _connect_button(path: String, handler: Callable) -> void:
	var button: Button = get_node_or_null(path) as Button
	if button != null:
		button.pressed.connect(handler)


func _set_text(path: String, key: String) -> void:
	_set_plain(path, UiCopy.text(key))


func _set_plain(path: String, value: String) -> void:
	var node: Node = get_node_or_null(path)
	if node is Label:
		(node as Label).text = value
	elif node is Button:
		(node as Button).text = value
