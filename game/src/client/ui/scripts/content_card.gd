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

@onready var _thumb: TextureRect = $Margin/VBox/ThumbWrap/Thumb
@onready var _dim: ColorRect = $Margin/VBox/ThumbWrap/Dim
@onready var _badge: PanelContainer = $Margin/VBox/ThumbWrap/Badge
@onready var _badge_label: Label = $Margin/VBox/ThumbWrap/Badge/L
@onready var _title: Label = $Margin/VBox/Title
@onready var _tags: HBoxContainer = $Margin/VBox/Tags
@onready var _dot: Panel = $Margin/VBox/Footer/Dot
@onready var _author: Label = $Margin/VBox/Footer/Author
@onready var _action: Button = $Margin/VBox/Footer/Action
@onready var _stars: Label = $Margin/VBox/Stats/Stars
@onready var _score: Label = $Margin/VBox/Stats/Score
@onready var _plays: Label = $Margin/VBox/Stats/Plays


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
	if not is_node_ready():
		return

	_thumb.texture = thumbnail
	_title.text = card_title
	_author.text = author
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
