extends Button
## One entry in the S3 public workshop grid (spec 3).
##
## Data-driven on purpose: the workshop scene instantiates this component once
## per entry and assigns the exported properties, so the card itself stays a
## single reusable scene instead of eight copy-pasted subtrees.
##
## Unverified content (spec 3, third state) dims the thumbnail, shows the
## "completability unverified" badge and disables the edit/reuse action.
##
## Copy lives in `UiCopy` (`craft_arena.card.*`), not in the scene: the labels in
## content_card.tscn are empty and filled here. `plays` carries the *number*
## ("1.2k") and the unit comes from the key, because baking "1.2k 次游玩" into the
## data would make the Chinese unreachable to the locale table.

@export var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		_apply()

@export var card_title := "":
	set(value):
		card_title = value
		_apply()

@export var tags: PackedStringArray = []:
	set(value):
		tags = value
		_apply()

@export var author := "":
	set(value):
		author = value
		_apply()

@export var author_color := Color(0.55, 0.57, 0.63):
	set(value):
		author_color = value
		_apply()

@export var score := 0.0:
	set(value):
		score = value
		_apply()

@export var plays := "":
	set(value):
		plays = value
		_apply()

@export var verified := true:
	set(value):
		verified = value
		_apply()

const STAR_FULL := "★"
const STAR_EMPTY := "☆"
const MAX_STARS := 5

var _content_margin: Control

# Resolved lazily rather than with `@onready`, because the exported setters run
# whenever the owner assigns them — which for a freshly instantiated card is
# *before* it enters the tree. With `@onready` those assignments hit null fields
# and `_apply()` bailed out on `is_node_ready()`, so the card rendered blank and
# nothing reported an error. The GUT suite never saw it: there `add_child`
# happens inside a running tree, so `_ready` fires before the setters do.
var _thumb: TextureRect = null
var _dim: ColorRect = null
var _badge: PanelContainer = null
var _badge_label: Label = null
var _title: Label = null
var _tags: HBoxContainer = null
var _dot: Panel = null
var _author: Label = null
var _action: Button = null
var _stars: Label = null
var _score: Label = null
var _plays: Label = null
var _resolved: bool = false


## Idempotent. `PackedScene.instantiate()` has already built the subtree, so
## every path here resolves as soon as the card object exists.
func _resolve() -> bool:
	if _resolved:
		return true
	_thumb = get_node_or_null(^"Margin/VBox/ThumbWrap/Thumb") as TextureRect
	if _thumb == null:
		return false
	_dim = get_node_or_null(^"Margin/VBox/ThumbWrap/Dim") as ColorRect
	_badge = get_node_or_null(^"Margin/VBox/ThumbWrap/Badge") as PanelContainer
	_badge_label = get_node_or_null(^"Margin/VBox/ThumbWrap/Badge/L") as Label
	_title = get_node_or_null(^"Margin/VBox/Title") as Label
	_tags = get_node_or_null(^"Margin/VBox/Tags") as HBoxContainer
	_dot = get_node_or_null(^"Margin/VBox/Footer/Dot") as Panel
	_author = get_node_or_null(^"Margin/VBox/Footer/Author") as Label
	_action = get_node_or_null(^"Margin/VBox/Footer/Action") as Button
	_stars = get_node_or_null(^"Margin/VBox/Stats/Stars") as Label
	_score = get_node_or_null(^"Margin/VBox/Stats/Score") as Label
	_plays = get_node_or_null(^"Margin/VBox/Stats/Plays") as Label
	_resolved = true
	return true


func _ready() -> void:
	_apply()
	_sync_minimum_size()
	if _content_margin:
		_content_margin.minimum_size_changed.connect(_sync_minimum_size)


func _sync_minimum_size() -> void:
	# A Button is not a Container, so its children do NOT contribute to its
	# minimum size. Mirror the content's minimum explicitly, otherwise the card
	# collapses inside the GridContainer and the anchored content overflows.
	if _content_margin == null:
		_content_margin = get_node_or_null(^"Margin") as Control
	if _content_margin:
		# Only the height is mirrored: the width must come from the GridContainer
		# column, otherwise the card grows wider than its column and the anchored
		# content overflows sideways.
		custom_minimum_size = Vector2(0, _content_margin.get_combined_minimum_size().y)


func _apply() -> void:
	if not _resolve():
		return

	_thumb.texture = thumbnail
	_title.text = card_title
	# No author, no dot. Real plaza rows carry no author field (see
	# s3_workshop.gd set_listing), and falling back to the content id would read
	# as an attribution the server never made. Hiding both keeps the footer from
	# showing a bare colour dot next to nothing.
	_author.text = author
	_author.visible = author != ""
	_dot.visible = author != ""
	_score.text = "%.1f" % score
	# Empty stays empty: "%s plays" with nothing in front reads as a broken card,
	# which is worse than showing no stat at all.
	_plays.text = "" if plays == "" else UiCopy.text(UiCopy.CARD_PLAYS_COUNT) % plays
	_badge_label.text = UiCopy.text(UiCopy.CARD_UNVERIFIED_BADGE)
	_action.text = UiCopy.text(UiCopy.CARD_ACTION_EDIT_REUSE)
	_dot.modulate = author_color

	var full := clampi(roundi(score), 0, MAX_STARS)
	_stars.text = STAR_FULL.repeat(full) + STAR_EMPTY.repeat(MAX_STARS - full)

	# Tag chips are whitelisted structured values, so they are built here rather
	# than authored per card in the scene.
	for child: Node in _tags.get_children():
		child.queue_free()
	for tag in tags:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"TagChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.theme_type_variation = &"ChipLabel"
		label.text = tag
		chip.add_child(label)
		_tags.add_child(chip)

	_dim.visible = not verified
	_badge.visible = not verified
	_action.disabled = not verified
