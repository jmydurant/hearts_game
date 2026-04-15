extends Control

const HeartsMatch = preload("res://scripts/core/hearts_match.gd")
const HeartsUtil = preload("res://scripts/core/hearts_util.gd")

const BASE_SIZE := Vector2(640, 360)
const RENDER_SCALE := 3.0
const MIN_RENDER_SIZE := Vector2i(1920, 1080)
const LAYOUT_SCALE := 2.0
const FOCUS_HAND := 0
const FOCUS_ACTIONS := 1
const PANEL_BG := Color("0f1716")
const PANEL_ALT := Color("183028")
const PANEL_LINE := Color("8de0b8")
const GRID_COLOR := Color(0.32, 0.56, 0.43, 0.10)
const TEXT_COLOR := Color("d8f3dc")
const MUTED_COLOR := Color("7fb99c")
const RED_COLOR := Color("ff7b7b")
const HEART_COLOR := Color("e5526f")
const DIAMOND_COLOR := Color("ff9a62")
const SPADE_COLOR := Color("355c9a")
const CLUB_COLOR := Color("2d8a63")
const GOLD_COLOR := Color("f6d06f")
const BLUE_COLOR := Color("74c0fc")
const CARD_BG := Color("f1ead7")
const CARD_BORDER := Color("2f3e46")
const CARD_BACK := Color("1e3a5f")
const CARD_BACK_ALT := Color("3f6b97")

var game_match: HeartsMatch
var mono_font: Font
var title_font: Font
var ascii_mode := false
var seed_override := -1

var focus_zone := FOCUS_HAND
var hand_cursor := 0
var action_index := 0
var pass_selected_keys: Array[String] = []
var toast_text := ""
var show_pause_dialog := false
var pause_choice := 0
var _automation_running := false
var resolution_supported := true


func _ready() -> void:
	_parse_runtime_flags()
	_load_fonts()
	_configure_window()
	_refresh_canvas_transform()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resolution_supported:
		queue_redraw()
		return
	game_match = HeartsMatch.new(ascii_mode)
	game_match.state_changed.connect(_on_state_changed)
	game_match.trick_resolved.connect(_on_trick_resolved)
	game_match.round_resolved.connect(_on_round_resolved)
	game_match.match_finished.connect(_on_match_finished)
	game_match.start_match(seed_override)


func _parse_runtime_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--ascii":
			ascii_mode = true
		elif arg.begins_with("--seed="):
			seed_override = int(arg.get_slice("=", 1))


func _load_fonts() -> void:
	var body_pixel_font := _load_pixel_font("res://assets/fonts/fusion/fusion-pixel-8px-monospaced-zh_hans.ttf")
	var title_pixel_font := _load_pixel_font("res://assets/fonts/fusion/fusion-pixel-12px-monospaced-zh_hans.ttf")
	if body_pixel_font != null and title_pixel_font != null:
		mono_font = body_pixel_font
		title_font = title_pixel_font
		return
	mono_font = _build_system_font([
		"DejaVu Sans Mono",
		"Noto Sans Mono",
		"Liberation Mono",
		"Courier New",
		"Menlo",
		"Monospace",
	])
	title_font = _build_system_font([
		"DejaVu Sans",
		"Noto Sans",
		"Liberation Sans",
		"Arial",
		"Helvetica",
		"Sans",
	])


func _load_pixel_font(resource_path: String) -> FontFile:
	var pixel_font := load(resource_path) as FontFile
	if pixel_font != null:
		pixel_font = pixel_font.duplicate()
	else:
		pixel_font = FontFile.new()
		var load_error := pixel_font.load_dynamic_font(ProjectSettings.globalize_path(resource_path))
		if load_error != OK:
			return null
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.hinting = TextServer.HINTING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel_font.multichannel_signed_distance_field = false
	pixel_font.oversampling = 1.0
	return pixel_font


func _build_system_font(font_names: Array[String]) -> Font:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(font_names)
	mono.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	mono.hinting = TextServer.HINTING_NONE
	mono.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	mono.multichannel_signed_distance_field = false
	mono.oversampling = 1.0
	return mono


func _configure_window() -> void:
	var screen_size := DisplayServer.screen_get_size()
	resolution_supported = screen_size.x >= MIN_RENDER_SIZE.x and screen_size.y >= MIN_RENDER_SIZE.y
	if resolution_supported:
		get_window().size = MIN_RENDER_SIZE
		get_window().min_size = MIN_RENDER_SIZE
		DisplayServer.window_set_title("终端红心大战")
		return
	get_window().size = screen_size
	get_window().min_size = screen_size
	DisplayServer.window_set_title("终端红心大战 - 需要至少 1920x1080")


func _refresh_canvas_transform() -> void:
	scale = Vector2(RENDER_SCALE, RENDER_SCALE)
	var canvas_size := BASE_SIZE * RENDER_SCALE
	position = (Vector2(MIN_RENDER_SIZE) - canvas_size) * 0.5


func _on_state_changed() -> void:
	_sync_selection()
	queue_redraw()
	_maybe_advance_automation()


func _on_trick_resolved(_summary: Dictionary) -> void:
	queue_redraw()


func _on_round_resolved(_summary: Dictionary) -> void:
	queue_redraw()


func _on_match_finished(_summary: Dictionary) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event
	if _handle_key_input(key_event.keycode):
		get_viewport().set_input_as_handled()


func _handle_key_input(keycode: int) -> bool:
	if not resolution_supported:
		if keycode == KEY_ESCAPE or keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
			get_tree().quit()
			return true
		return false
	if keycode == KEY_F11:
		_toggle_fullscreen()
		return true
	if keycode == KEY_ESCAPE:
		show_pause_dialog = not show_pause_dialog
		pause_choice = 0
		queue_redraw()
		return true
	if show_pause_dialog:
		_handle_pause_input(keycode)
		return true
	var state := game_match.get_state()
	if state["phase"] == HeartsMatch.Phase.ROUND_END:
		if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
			game_match.resolve_round()
			return true
		return false
	if state["phase"] == HeartsMatch.Phase.MATCH_END:
		if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
			game_match.start_match(seed_override)
			return true
		return false
	if state["phase"] == HeartsMatch.Phase.PASSING:
		return _handle_passing_input(keycode, state)
	if state["phase"] == HeartsMatch.Phase.TRICK_PLAY and int(state["current_player"]) == 0:
		return _handle_play_input(keycode, state)
	return false


func _handle_pause_input(keycode: int) -> void:
	if keycode == KEY_LEFT or keycode == KEY_RIGHT:
		pause_choice = 1 - pause_choice
		queue_redraw()
		return
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		if pause_choice == 0:
			show_pause_dialog = false
			queue_redraw()
		else:
			get_tree().quit()


func _handle_passing_input(keycode: int, state: Dictionary) -> bool:
	match keycode:
		KEY_LEFT:
			if focus_zone == FOCUS_HAND:
				hand_cursor = max(0, hand_cursor - 1)
			else:
				action_index = max(0, action_index - 1)
		KEY_RIGHT:
			if focus_zone == FOCUS_HAND:
				hand_cursor = min(_human_hand(state).size() - 1, hand_cursor + 1)
			else:
				action_index = min(_action_labels(state).size() - 1, action_index + 1)
		KEY_UP, KEY_DOWN:
			focus_zone = 1 - focus_zone
		KEY_ENTER, KEY_KP_ENTER:
			if focus_zone == FOCUS_HAND or action_index == 0:
				_toggle_pass_card(state)
			else:
				_confirm_pass(state)
		_:
			return false
	queue_redraw()
	return true


func _handle_play_input(keycode: int, state: Dictionary) -> bool:
	match keycode:
		KEY_LEFT:
			if focus_zone == FOCUS_HAND:
				hand_cursor = max(0, hand_cursor - 1)
		KEY_RIGHT:
			if focus_zone == FOCUS_HAND:
				hand_cursor = min(_human_hand(state).size() - 1, hand_cursor + 1)
		KEY_UP, KEY_DOWN:
			focus_zone = 1 - focus_zone
		KEY_ENTER, KEY_KP_ENTER:
			_play_selected_card(state)
		_:
			return false
	queue_redraw()
	return true


func _toggle_pass_card(state: Dictionary) -> void:
	var hand := _human_hand(state)
	if hand.is_empty():
		return
	var card: Dictionary = hand[hand_cursor]
	var key := HeartsUtil.card_key(card)
	var existing := pass_selected_keys.find(key)
	if existing >= 0:
		pass_selected_keys.remove_at(existing)
		toast_text = "取消选择 %s。" % HeartsUtil.card_label(card, ascii_mode)
		return
	if pass_selected_keys.size() >= 3:
		toast_text = "已经选满 3 张，先取消一张。"
		return
	pass_selected_keys.append(key)
	toast_text = "选中 %s。" % HeartsUtil.card_label(card, ascii_mode)


func _confirm_pass(state: Dictionary) -> void:
	if pass_selected_keys.size() != 3:
		toast_text = "请先选够 3 张牌。"
		return
	var selected_cards: Array = []
	for card in _human_hand(state):
		if pass_selected_keys.has(HeartsUtil.card_key(card)):
			selected_cards.append(HeartsUtil.clone_card(card))
	if selected_cards.size() != 3:
		toast_text = "选牌无效，请重新选择。"
		pass_selected_keys.clear()
		return
	if game_match.submit_pass(selected_cards):
		toast_text = "完成传牌。"
		pass_selected_keys.clear()


func _play_selected_card(state: Dictionary) -> void:
	var hand := _human_hand(state)
	if hand.is_empty():
		return
	var card: Dictionary = hand[hand_cursor]
	if not HeartsUtil.contains_card(state.get("legal_moves", []), card):
		toast_text = "%s 现在不能出。" % HeartsUtil.card_label(card, ascii_mode)
		return
	if game_match.submit_play(card):
		toast_text = ""


func _maybe_advance_automation() -> void:
	if _automation_running:
		return
	var state := game_match.get_state()
	if state["phase"] == HeartsMatch.Phase.TRICK_PLAY and int(state["current_player"]) != 0:
		_automation_running = true
		call_deferred("_run_automation_loop")
	elif state["phase"] == HeartsMatch.Phase.TRICK_RESOLVE:
		_automation_running = true
		call_deferred("_run_automation_loop")


func _run_automation_loop() -> void:
	while true:
		var state := game_match.get_state()
		if state["phase"] == HeartsMatch.Phase.TRICK_RESOLVE:
			await get_tree().create_timer(0.45).timeout
			game_match.resolve_trick()
			continue
		if state["phase"] != HeartsMatch.Phase.TRICK_PLAY or int(state["current_player"]) == 0:
			break
		await get_tree().create_timer(0.45).timeout
		game_match.advance_ai_turn()
	_automation_running = false
	queue_redraw()


func _sync_selection() -> void:
	var state := game_match.get_state()
	var hand := _human_hand(state)
	if hand.is_empty():
		hand_cursor = 0
	else:
		hand_cursor = clamp(hand_cursor, 0, hand.size() - 1)
	if state["phase"] != HeartsMatch.Phase.PASSING:
		pass_selected_keys.clear()
		action_index = 0
		focus_zone = FOCUS_HAND
	else:
		var valid_keys: Array[String] = []
		for card in hand:
			valid_keys.append(HeartsUtil.card_key(card))
		pass_selected_keys = pass_selected_keys.filter(func(key: String) -> bool:
			return valid_keys.has(key)
		)
	if state["phase"] == HeartsMatch.Phase.TRICK_PLAY and int(state["current_player"]) != 0:
		focus_zone = FOCUS_HAND


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_configure_window()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _draw() -> void:
	_draw_background()
	if not resolution_supported:
		_draw_unsupported_overlay()
		return
	var state := game_match.get_state()
	var table_rect := _r(8, 8, 228, 116)
	var sidebar_rect := _r(244, 8, 68, 164)
	var hand_rect := _r(8, 128, 228, 44)
	_draw_panel(table_rect, "牌桌")
	_draw_panel(sidebar_rect, "终端面板")
	_draw_panel(hand_rect, "你的手牌")
	_draw_table(state, table_rect)
	_draw_sidebar(state, sidebar_rect)
	_draw_hand(state, hand_rect)
	_draw_status_line(state)
	if show_pause_dialog:
		_draw_pause_dialog()
	elif state["phase"] == HeartsMatch.Phase.ROUND_END:
		_draw_round_overlay(state)
	elif state["phase"] == HeartsMatch.Phase.MATCH_END:
		_draw_match_overlay(state)


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), PANEL_BG, true)
	for x in range(0, int(BASE_SIZE.x), int(_s(4))):
		draw_line(Vector2(x, 0), Vector2(x, BASE_SIZE.y), GRID_COLOR, 1.0)
	for y in range(0, int(BASE_SIZE.y), int(_s(6))):
		draw_line(Vector2(0, y), Vector2(BASE_SIZE.x, y), GRID_COLOR, 1.0)
	for y in range(0, int(BASE_SIZE.y), int(_s(2))):
		draw_rect(Rect2(0, y, BASE_SIZE.x, 1), Color(0, 0, 0, 0.03), true)


func _draw_panel(rect: Rect2, title: String) -> void:
	draw_rect(rect, PANEL_ALT, true)
	draw_rect(rect, PANEL_LINE, false, 1.0)
	_draw_text(title, rect.position + _v(6, 10), GOLD_COLOR, 12, true)


func _draw_table(state: Dictionary, rect: Rect2) -> void:
	var inner := rect.grow(-_s(8))
	var center := inner.get_center()
	var table_color := Color("123d32")
	var felt_rect := Rect2(inner.position + _v(20, 14), inner.size - _v(40, 28))
	draw_rect(felt_rect, table_color, true)
	draw_rect(felt_rect, PANEL_LINE, false, 1.0)
	_draw_player_badge(state, 2, _r(center.x / LAYOUT_SCALE - 28, inner.position.y / LAYOUT_SCALE, 56, 18))
	_draw_player_badge(state, 1, _r(inner.position.x / LAYOUT_SCALE - 2, center.y / LAYOUT_SCALE - 9, 52, 18))
	_draw_player_badge(state, 3, _r((inner.end.x - _s(50)) / LAYOUT_SCALE, center.y / LAYOUT_SCALE - 9, 52, 18))
	_draw_player_badge(state, 0, _r(center.x / LAYOUT_SCALE - 28, (inner.end.y - _s(18)) / LAYOUT_SCALE, 56, 18))
	_draw_trick_cards(state, center)


func _draw_player_badge(state: Dictionary, player_index: int, rect: Rect2) -> void:
	var player: Dictionary = state["players"][player_index]
	var highlight: bool = int(state["current_player"]) == player_index and state["phase"] == HeartsMatch.Phase.TRICK_PLAY
	draw_rect(rect, Color("193227"), true)
	draw_rect(rect, GOLD_COLOR if highlight else PANEL_LINE, false, 1.0)
	_draw_text(state["player_labels"][player_index], rect.position + _v(4, 8), TEXT_COLOR, 8, true)
	_draw_text("%02d 分" % int(player["total_points"]), rect.position + _v(4, 15), MUTED_COLOR, 8, true)
	if player_index != 0:
		_draw_text("%02d 张" % int(player["hand_count"]), rect.position + Vector2(rect.size.x - _s(26), _s(8)), TEXT_COLOR, 8, true)


func _draw_trick_cards(state: Dictionary, center: Vector2) -> void:
	var trick: Dictionary = state["current_trick"]
	var plays: Array = trick.get("plays", [])
	var positions := {
		0: Rect2(center + _v(-8, 14), _v(16, 22)),
		1: Rect2(center + _v(-32, -6), _v(16, 22)),
		2: Rect2(center + _v(-8, -28), _v(16, 22)),
		3: Rect2(center + _v(16, -6), _v(16, 22)),
	}
	_draw_text("当前墩", center + _v(-15, -40), GOLD_COLOR, 12, true)
	var winner: int = int(state.get("pending_trick_result", {}).get("winner", -1))
	for play in plays:
		var player_index := int(play.get("player", 0))
		var rect: Rect2 = positions[player_index]
		_draw_card(rect, play.get("card", {}), false, winner == player_index and state["phase"] == HeartsMatch.Phase.TRICK_RESOLVE)
		_draw_text(state["player_labels"][player_index], rect.position + Vector2(-_s(2), rect.size.y + _s(7)), MUTED_COLOR, 8, true)
	if plays.is_empty():
		_draw_text("等待首牌", center + _v(-18, 0), MUTED_COLOR, 8, true)


func _draw_sidebar(state: Dictionary, rect: Rect2) -> void:
	var x := rect.position.x + _s(6)
	var y := rect.position.y + _s(12)
	_draw_text("第 %d 局" % int(state["round_number"]), Vector2(x, y), TEXT_COLOR, 12, true)
	y += _s(12)
	_draw_text(state["pass_label"], Vector2(x, y), GOLD_COLOR, 8, true)
	y += _s(10)
	_draw_text("已破心" if state["hearts_broken"] else "未破心", Vector2(x, y), RED_COLOR if state["hearts_broken"] else MUTED_COLOR, 8, true)
	y += _s(12)
	_draw_text("比分", Vector2(x, y), GOLD_COLOR, 12, true)
	y += _s(8)
	for index in range(4):
		var player: Dictionary = state["players"][index]
		var label: String = "%s %02d/%02d" % [state["player_labels"][index], int(player["round_points"]), int(player["total_points"])]
		_draw_text(_clip_text(label, 14), Vector2(x, y), TEXT_COLOR, 8, true)
		y += _s(8)
	y += _s(4)
	_draw_text("日志", Vector2(x, y), GOLD_COLOR, 12, true)
	y += _s(8)
	var logs: Array = state.get("log_lines", [])
	for index in range(max(0, logs.size() - 6), logs.size()):
		_draw_text(_clip_text(logs[index], 15), Vector2(x, y), MUTED_COLOR, 8, true)
		y += _s(8)


func _draw_hand(state: Dictionary, rect: Rect2) -> void:
	var hand := _human_hand(state)
	if hand.is_empty():
		_draw_text("当前没有手牌。", rect.position + _v(8, 22), MUTED_COLOR, 12, true)
		return
	var player_turn := int(state["phase"]) == HeartsMatch.Phase.TRICK_PLAY and int(state["current_player"]) == 0
	var controls_enabled := int(state["phase"]) == HeartsMatch.Phase.PASSING or player_turn
	var card_width := _s(14)
	var card_height := _s(22)
	var usable_width := rect.size.x - _s(22) - card_width
	var step := 0.0
	if hand.size() > 1:
		step = min(_s(16), usable_width / float(hand.size() - 1))
	var start_x := rect.position.x + _s(10)
	for index in range(hand.size()):
		var card: Dictionary = hand[index]
		var selected := pass_selected_keys.has(HeartsUtil.card_key(card))
		var hovered := index == hand_cursor and controls_enabled
		var lift := 0.0
		if selected:
			lift += _s(4)
		if hovered:
			lift += _s(6)
		var card_rect := Rect2(start_x + step * index, rect.position.y + _s(16) - lift, card_width, card_height)
		var legal := true
		if int(state["phase"]) == HeartsMatch.Phase.PASSING:
			legal = true
		elif player_turn:
			legal = HeartsUtil.contains_card(state.get("legal_moves", []), card)
		_draw_card(card_rect, card, hovered, false, selected, legal)
	var action_rect := _r(rect.position.x / LAYOUT_SCALE + 158, rect.position.y / LAYOUT_SCALE + 4, 66, 10)
	var labels := _action_labels(state)
	for index in range(labels.size()):
		var label_rect := Rect2(action_rect.position.x + index * _s(28), action_rect.position.y, _s(26), action_rect.size.y)
		var active := focus_zone == FOCUS_ACTIONS and action_index == index and controls_enabled
		draw_rect(label_rect, GOLD_COLOR if active else PANEL_ALT, true)
		draw_rect(label_rect, TEXT_COLOR if active else PANEL_LINE, false, 1.0)
		_draw_text(labels[index], label_rect.position + _v(3, 7), PANEL_BG if active else TEXT_COLOR, 8, true)


func _draw_card(rect: Rect2, card: Dictionary, cursor := false, winning := false, selected := false, legal := true) -> void:
	draw_rect(Rect2(rect.position + _v(1, 1), rect.size), Color(0, 0, 0, 0.25), true)
	draw_rect(rect, CARD_BG, true)
	var accent := _card_suit_color(card)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, _s(2))), accent if legal else MUTED_COLOR, true)
	var outline := CARD_BORDER
	if selected:
		outline = BLUE_COLOR
	elif winning:
		outline = GOLD_COLOR
	elif cursor:
		outline = TEXT_COLOR
	elif not legal:
		outline = MUTED_COLOR
	draw_rect(rect, outline, false, 1.0)
	var label := HeartsUtil.card_label(card, ascii_mode)
	var color := _card_suit_color(card)
	if not legal:
		color = MUTED_COLOR
	_draw_text(label, rect.position + _v(2, 8), color, 8, true)
	_draw_text(HeartsUtil.RANK_LABELS.get(int(card.get("rank", 2)), "?"), rect.position + _v(2, 19), color, 8, true)


func _draw_status_line(state: Dictionary) -> void:
	var hint := ""
	match int(state["phase"]):
		HeartsMatch.Phase.PASSING:
			hint = "左右移动，回车选牌，上下切换到确认。"
		HeartsMatch.Phase.TRICK_PLAY:
			if int(state["current_player"]) == 0:
				hint = "选择要出的牌并按回车。"
			else:
				hint = "%s 思考中..." % state["player_labels"][state["current_player"]]
		HeartsMatch.Phase.TRICK_RESOLVE:
			hint = "结算这一墩..."
		HeartsMatch.Phase.ROUND_END:
			hint = "回车进入下一局。"
		HeartsMatch.Phase.MATCH_END:
			hint = "回车重新开局。"
	var bar_rect := _r(0, 174, 320, 6)
	draw_rect(bar_rect, PANEL_LINE, true)
	_draw_text(toast_text if toast_text != "" else hint, _v(6, 179), PANEL_BG, 8, true)


func _draw_round_overlay(state: Dictionary) -> void:
	var summary: Dictionary = state.get("pending_round_summary", {})
	var rect := _r(56, 42, 208, 96)
	_draw_modal(rect, "本局结算")
	var y := rect.position.y + _s(18)
	if int(summary.get("shoot_the_moon", -1)) >= 0:
		_draw_text("%s 收全罚分。" % state["player_labels"][summary["shoot_the_moon"]], rect.position + Vector2(_s(10), y - rect.position.y), GOLD_COLOR, 12, true)
		y += _s(12)
	var applied: Array = summary.get("applied_scores", [])
	var totals: Array = summary.get("totals", [])
	for index in range(min(applied.size(), 4)):
		var line := "%s  本局 %+d  总分 %02d" % [state["player_labels"][index], int(applied[index]), int(totals[index])]
		_draw_text(line, Vector2(rect.position.x + _s(10), y), TEXT_COLOR, 8, true)
		y += _s(11)
	_draw_text("按 Enter 继续", rect.position + Vector2(_s(10), rect.size.y - _s(12)), MUTED_COLOR, 8, true)


func _draw_match_overlay(state: Dictionary) -> void:
	var summary: Dictionary = state.get("pending_round_summary", {})
	var rect := _r(52, 34, 216, 110)
	_draw_modal(rect, "比赛结束")
	var winners: Array = summary.get("winner_ids", [])
	var y := rect.position.y + _s(18)
	_draw_text("胜者：%s" % _winner_names(state, winners), Vector2(rect.position.x + _s(10), y), GOLD_COLOR, 12, true)
	y += _s(14)
	var totals: Array = summary.get("totals", [])
	for index in range(min(totals.size(), 4)):
		var line := "%s  总分 %02d" % [state["player_labels"][index], int(totals[index])]
		_draw_text(line, Vector2(rect.position.x + _s(10), y), TEXT_COLOR, 8, true)
		y += _s(11)
	_draw_text("按 Enter 再来一局", rect.position + Vector2(_s(10), rect.size.y - _s(12)), MUTED_COLOR, 8, true)


func _draw_pause_dialog() -> void:
	var rect := _r(84, 58, 152, 64)
	_draw_modal(rect, "暂停")
	_draw_text("继续还是退出？", rect.position + _v(10, 26), TEXT_COLOR, 12, true)
	var labels := ["继续", "退出"]
	for index in range(labels.size()):
		var button := Rect2(rect.position.x + _s(16) + index * _s(60), rect.position.y + _s(38), _s(44), _s(14))
		var active := pause_choice == index
		draw_rect(button, GOLD_COLOR if active else PANEL_ALT, true)
		draw_rect(button, TEXT_COLOR if active else PANEL_LINE, false, 1.0)
		_draw_text(labels[index], button.position + _v(10, 9), PANEL_BG if active else TEXT_COLOR, 8, true)


func _draw_unsupported_overlay() -> void:
	var rect := _r(48, 52, 224, 76)
	_draw_modal(rect, "分辨率不支持")
	_draw_text("当前显示器低于 1920x1080。", rect.position + _v(10, 26), TEXT_COLOR, 12, true)
	_draw_text("本版本不再提供低分屏回退。", rect.position + _v(10, 38), TEXT_COLOR, 8, true)
	_draw_text("请在 1080p 或更高分辨率运行。", rect.position + _v(10, 49), GOLD_COLOR, 8, true)
	_draw_text("按 Enter 或 Esc 退出", rect.position + _v(10, 64), MUTED_COLOR, 8, true)


func _draw_modal(rect: Rect2, title: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color(0, 0, 0, 0.45), true)
	draw_rect(rect, PANEL_ALT, true)
	draw_rect(rect, GOLD_COLOR, false, 1.0)
	_draw_text(title, rect.position + _v(10, 10), GOLD_COLOR, 12, true)


func _action_labels(state: Dictionary) -> Array[String]:
	if int(state["phase"]) == HeartsMatch.Phase.PASSING:
		return ["选牌", "确认"]
	if int(state["phase"]) == HeartsMatch.Phase.TRICK_PLAY and int(state["current_player"]) == 0:
		return ["出牌"]
	return []


func _human_hand(state: Dictionary) -> Array:
	return state["players"][0]["hand"]


func _winner_names(state: Dictionary, winners: Array) -> String:
	if winners.is_empty():
		return "-"
	var names: Array[String] = []
	for winner in winners:
		names.append(state["player_labels"][int(winner)])
	return "、".join(names)


func _clip_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars - 1) + "…"


func _card_suit_color(card: Dictionary) -> Color:
	var suit := int(card.get("suit", 0))
	match suit:
		HeartsUtil.Suit.HEARTS:
			return HEART_COLOR
		HeartsUtil.Suit.DIAMONDS:
			return DIAMOND_COLOR
		HeartsUtil.Suit.SPADES:
			return SPADE_COLOR
		HeartsUtil.Suit.CLUBS:
			return CLUB_COLOR
		_:
			return TEXT_COLOR


func _s(value: float) -> float:
	return value * LAYOUT_SCALE


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * LAYOUT_SCALE


func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(Vector2(x, y) * LAYOUT_SCALE, Vector2(w, h) * LAYOUT_SCALE)


func _draw_text(text: String, position: Vector2, color: Color, size := 8, mono := true) -> void:
	var use_title_font := (not mono) or int(size) >= 10
	var font := title_font if use_title_font else mono_font
	if font == null:
		return
	var pixel_size := 12 if use_title_font else 8
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, pixel_size, color)
