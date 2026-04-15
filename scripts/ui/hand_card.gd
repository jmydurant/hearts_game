extends Control

const HeartsUtil = preload("res://scripts/core/hearts_util.gd")

const TEXT_COLOR := Color("d8f3dc")
const MUTED_COLOR := Color("7fb99c")
const GOLD_COLOR := Color("f6d06f")
const BLUE_COLOR := Color("74c0fc")
const CARD_BG := Color("f1ead7")
const CARD_BORDER := Color("2f3e46")

signal hovered(card_index: int)
signal clicked(card_index: int)

var card_index := -1
var card: Dictionary = {}
var ascii_mode := false
var cursor := false
var selected := false
var legal := true
var suit_color := TEXT_COLOR
var mono_font: Font


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE


func configure(config: Dictionary) -> void:
	card_index = int(config.get("card_index", -1))
	card = config.get("card", {})
	ascii_mode = bool(config.get("ascii_mode", false))
	cursor = bool(config.get("cursor", false))
	selected = bool(config.get("selected", false))
	legal = bool(config.get("legal", true))
	suit_color = config.get("suit_color", TEXT_COLOR)
	mono_font = config.get("mono_font", null)
	position = config.get("position", Vector2.ZERO)
	size = config.get("size", Vector2.ZERO)
	z_index = int(config.get("z_index", card_index))
	visible = bool(config.get("visible", true))
	mouse_filter = Control.MOUSE_FILTER_STOP if bool(config.get("interactable", false)) else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if mouse_filter == Control.MOUSE_FILTER_STOP else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			clicked.emit(card_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(card_index)


func _draw() -> void:
	if not visible or mono_font == null or card.is_empty():
		return
	var unit := size.x / 14.0
	draw_rect(Rect2(Vector2(unit, unit), size), Color(0, 0, 0, 0.25), true)
	draw_rect(Rect2(Vector2.ZERO, size), CARD_BG, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, _s(2, unit))), suit_color if legal else MUTED_COLOR, true)
	var outline := CARD_BORDER
	if selected:
		outline = BLUE_COLOR
	elif cursor:
		outline = TEXT_COLOR
	elif not legal:
		outline = MUTED_COLOR
	draw_rect(Rect2(Vector2.ZERO, size), outline, false, 1.0)
	var color := suit_color if legal else MUTED_COLOR
	var label := HeartsUtil.card_label(card, ascii_mode)
	_draw_text(label, _v(2, 8, unit), color)
	_draw_text(HeartsUtil.RANK_LABELS.get(int(card.get("rank", 2)), "?"), _v(2, 19, unit), color)


func _draw_text(text: String, text_position: Vector2, color: Color) -> void:
	draw_string(mono_font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)


func _s(value: float, unit: float) -> float:
	return value * unit


func _v(x: float, y: float, unit: float) -> Vector2:
	return Vector2(_s(x, unit), _s(y, unit))
