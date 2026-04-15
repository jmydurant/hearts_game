extends Control

const PANEL_BG := Color("0f1716")
const PANEL_ALT := Color("183028")
const PANEL_LINE := Color("8de0b8")
const TEXT_COLOR := Color("d8f3dc")
const GOLD_COLOR := Color("f6d06f")

signal hovered(button_index: int)
signal clicked(button_index: int)

var button_index := -1
var label := ""
var active := false
var interactable := false
var mono_font: Font


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE


func configure(config: Dictionary) -> void:
	button_index = int(config.get("button_index", -1))
	label = str(config.get("label", ""))
	active = bool(config.get("active", false))
	interactable = bool(config.get("interactable", false))
	mono_font = config.get("mono_font", null)
	position = config.get("position", Vector2.ZERO)
	size = config.get("size", Vector2.ZERO)
	z_index = int(config.get("z_index", 100 + button_index))
	visible = bool(config.get("visible", true))
	mouse_filter = Control.MOUSE_FILTER_STOP if interactable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactable else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			clicked.emit(button_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(button_index)


func _draw() -> void:
	if not visible or mono_font == null or label == "":
		return
	draw_rect(Rect2(Vector2.ZERO, size), GOLD_COLOR if active else PANEL_ALT, true)
	draw_rect(Rect2(Vector2.ZERO, size), TEXT_COLOR if active else PANEL_LINE, false, 1.0)
	draw_string(mono_font, Vector2(_u(3), _u(7)), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, PANEL_BG if active else TEXT_COLOR)


func _u(value: float) -> float:
	return value * (size.y / 10.0)
