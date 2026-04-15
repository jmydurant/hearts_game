class_name HeartsMatch
extends RefCounted

signal state_changed
signal trick_resolved(summary)
signal round_resolved(summary)
signal match_finished(summary)

const HeartsAI = preload("res://scripts/ai/hearts_ai.gd")
const HeartsUtil = preload("res://scripts/core/hearts_util.gd")

const PLAYER_COUNT := 4
const CARDS_PER_PLAYER := 13
const MAX_SCORE := 100
const PLAYER_LABELS := ["你", "左家", "对家", "右家"]

enum Phase {
	PASSING,
	TRICK_PLAY,
	TRICK_RESOLVE,
	ROUND_END,
	MATCH_END,
}

enum PassDirection {
	LEFT,
	RIGHT,
	ACROSS,
	HOLD,
}

const PASS_LABELS := {
	PassDirection.LEFT: "传左",
	PassDirection.RIGHT: "传右",
	PassDirection.ACROSS: "传对家",
	PassDirection.HOLD: "不传",
}

var _ascii_mode := false
var _seed_value := 0
var _rng := RandomNumberGenerator.new()
var _ai := HeartsAI.new()

var players: Array = []
var round_index := -1
var pass_direction := PassDirection.LEFT
var hearts_broken := false
var current_player := 0
var current_trick: Dictionary = {"leader": 0, "lead_suit": -1, "plays": []}
var trick_index := 0
var phase := Phase.PASSING
var pending_trick_result: Dictionary = {}
var pending_round_summary: Dictionary = {}
var last_pass_summary: Dictionary = {}
var event_feed: Array[String] = []


func _init(ascii_mode := false) -> void:
	_ascii_mode = ascii_mode
	_reset_players()


func start_match(seed_value := -1) -> void:
	if seed_value >= 0:
		_seed_value = seed_value
	else:
		_seed_value = int(Time.get_unix_time_from_system())
	_rng.seed = _seed_value
	round_index = -1
	_reset_players()
	event_feed.clear()
	_append_log("种子 %d，比赛开始。" % _seed_value)
	start_round()


func start_round() -> void:
	round_index += 1
	pass_direction = round_index % 4
	hearts_broken = false
	current_player = 0
	current_trick = {"leader": 0, "lead_suit": -1, "plays": []}
	trick_index = 0
	pending_trick_result = {}
	pending_round_summary = {}
	last_pass_summary = {}
	event_feed.clear()
	_append_log("第 %d 局开始。" % (round_index + 1))
	_append_log("本局规则：%s。" % PASS_LABELS[pass_direction])
	_deal_round()
	current_player = _find_two_of_clubs_holder()
	current_trick["leader"] = current_player
	if pass_direction == PassDirection.HOLD:
		phase = Phase.TRICK_PLAY
		_append_log("%s 持有 2♣，由其先手。" % PLAYER_LABELS[current_player])
	else:
		phase = Phase.PASSING
	_emit_state()


func submit_pass(cards: Array) -> bool:
	if phase != Phase.PASSING or pass_direction == PassDirection.HOLD:
		return false
	if cards.size() != 3:
		return false
	var unique: Dictionary = {}
	for card in cards:
		if not HeartsUtil.contains_card(players[0]["hand"], card):
			return false
		unique[HeartsUtil.card_key(card)] = true
	if unique.size() != 3:
		return false

	var pending_passes: Array = []
	for player_index in range(PLAYER_COUNT):
		pending_passes.append([])
	pending_passes[0] = HeartsUtil.sort_cards(cards)
	for player_index in range(1, PLAYER_COUNT):
		pending_passes[player_index] = _ai.choose_pass_cards(players[player_index]["hand"], get_state())

	for player_index in range(PLAYER_COUNT):
		players[player_index]["passed_cards"] = HeartsUtil.clone_cards(pending_passes[player_index])
		for card in pending_passes[player_index]:
			HeartsUtil.remove_card(players[player_index]["hand"], card)

	for player_index in range(PLAYER_COUNT):
		var target: int = _get_pass_target(player_index, pass_direction)
		var incoming: Array = HeartsUtil.clone_cards(pending_passes[player_index])
		players[target]["hand"].append_array(incoming)
		players[target]["received_cards"] = incoming

	for player in players:
		player["hand"] = HeartsUtil.sort_cards(player["hand"])

	last_pass_summary = {
		"direction": pass_direction,
		"sent": HeartsUtil.clone_cards(players[0]["passed_cards"]),
		"received": HeartsUtil.clone_cards(players[0]["received_cards"]),
	}
	_append_log("你传出了 %s。" % HeartsUtil.cards_to_text(last_pass_summary["sent"], _ascii_mode))
	_append_log("你收到了 %s。" % HeartsUtil.cards_to_text(last_pass_summary["received"], _ascii_mode))
	current_player = _find_two_of_clubs_holder()
	current_trick = {"leader": current_player, "lead_suit": -1, "plays": []}
	phase = Phase.TRICK_PLAY
	_append_log("%s 持有 2♣，由其先手。" % PLAYER_LABELS[current_player])
	_emit_state()
	return true


func get_legal_moves(player_index: int) -> Array:
	if phase != Phase.TRICK_PLAY or player_index != current_player:
		return []
	if player_index < 0 or player_index >= players.size():
		return []
	var hand: Array = players[player_index]["hand"]
	if current_trick["plays"].is_empty():
		if trick_index == 0:
			return [HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 2)]
		if hearts_broken or HeartsUtil.has_only_hearts(hand):
			return HeartsUtil.sort_cards(hand)
		var non_hearts: Array = []
		for card in hand:
			if int(card["suit"]) != HeartsUtil.Suit.HEARTS:
				non_hearts.append(HeartsUtil.clone_card(card))
		return HeartsUtil.sort_cards(non_hearts)

	var lead_suit := int(current_trick["lead_suit"])
	var follow_cards: Array = []
	for card in hand:
		if int(card["suit"]) == lead_suit:
			follow_cards.append(HeartsUtil.clone_card(card))
	if not follow_cards.is_empty():
		return HeartsUtil.sort_cards(follow_cards)

	if trick_index == 0:
		var safe_cards: Array = []
		for card in hand:
			if not HeartsUtil.is_point_card(card):
				safe_cards.append(HeartsUtil.clone_card(card))
		if not safe_cards.is_empty():
			return HeartsUtil.sort_cards(safe_cards)

	return HeartsUtil.sort_cards(hand)


func submit_play(card: Dictionary) -> bool:
	return _submit_play_for_player(current_player, card)


func advance_ai_turn() -> Dictionary:
	if phase != Phase.TRICK_PLAY or current_player == 0:
		return {}
	var state: Dictionary = get_state()
	var legal_moves: Array = state.get("legal_moves", [])
	if legal_moves.is_empty():
		legal_moves = get_legal_moves(current_player)
	if legal_moves.is_empty():
		return {}
	var player_id: int = current_player
	var chosen_card: Dictionary = _ai.choose_play_card(player_id, legal_moves, state)
	if chosen_card.is_empty():
		chosen_card = HeartsUtil.clone_card(legal_moves[0])
	_submit_play_for_player(player_id, chosen_card)
	return {"player": player_id, "card": HeartsUtil.clone_card(chosen_card)}


func resolve_trick() -> Dictionary:
	if phase != Phase.TRICK_RESOLVE or pending_trick_result.is_empty():
		return {}
	var summary: Dictionary = pending_trick_result.duplicate(true)
	var winner: int = int(summary.get("winner", 0))
	players[winner]["captured_tricks"].append(summary.get("plays", []).duplicate(true))
	players[winner]["round_points"] += int(summary.get("points", 0))
	_append_log("%s 收下这一墩（%d 分）。" % [PLAYER_LABELS[winner], int(summary.get("points", 0))])
	pending_trick_result = {}
	trick_index += 1
	if trick_index >= CARDS_PER_PLAYER:
		phase = Phase.ROUND_END
		pending_round_summary = _build_round_summary()
	else:
		current_player = winner
		current_trick = {"leader": winner, "lead_suit": -1, "plays": []}
		phase = Phase.TRICK_PLAY
	emit_signal("trick_resolved", summary)
	_emit_state()
	return summary


func resolve_round() -> Dictionary:
	if phase != Phase.ROUND_END or pending_round_summary.is_empty():
		return {}
	var summary: Dictionary = pending_round_summary.duplicate(true)
	emit_signal("round_resolved", summary)
	if _is_match_finished():
		phase = Phase.MATCH_END
		summary["winner_ids"] = _get_low_score_winners()
		_append_log("比赛结束。胜者：%s。" % _winner_names(summary["winner_ids"]))
		pending_round_summary = summary.duplicate(true)
		emit_signal("match_finished", summary)
		_emit_state()
		return summary
	pending_round_summary = {}
	start_round()
	return summary


func get_state() -> Dictionary:
	var player_views: Array = []
	for player in players:
		player_views.append({
			"hand": HeartsUtil.clone_cards(player["hand"]),
			"hand_count": player["hand"].size(),
			"captured_tricks": player["captured_tricks"].duplicate(true),
			"captured_count": player["captured_tricks"].size(),
			"round_points": int(player["round_points"]),
			"total_points": int(player["total_points"]),
			"passed_cards": HeartsUtil.clone_cards(player["passed_cards"]),
			"received_cards": HeartsUtil.clone_cards(player["received_cards"]),
		})
	var legal_moves: Array = []
	if phase == Phase.TRICK_PLAY:
		legal_moves = get_legal_moves(current_player)
	return {
		"seed": _seed_value,
		"phase": phase,
		"round_number": round_index + 1,
		"pass_direction": pass_direction,
		"pass_label": PASS_LABELS[pass_direction],
		"hearts_broken": hearts_broken,
		"current_player": current_player,
		"current_trick": {
			"leader": int(current_trick.get("leader", 0)),
			"lead_suit": int(current_trick.get("lead_suit", -1)),
			"plays": current_trick.get("plays", []).duplicate(true),
		},
		"trick_number": min(trick_index + 1, CARDS_PER_PLAYER),
		"legal_moves": HeartsUtil.clone_cards(legal_moves),
		"players": player_views,
		"log_lines": event_feed.duplicate(),
		"pending_trick_result": pending_trick_result.duplicate(true),
		"pending_round_summary": pending_round_summary.duplicate(true),
		"last_pass_summary": last_pass_summary.duplicate(true),
		"player_labels": PLAYER_LABELS.duplicate(),
		"max_score": MAX_SCORE,
	}


func _submit_play_for_player(player_index: int, card: Dictionary) -> bool:
	if phase != Phase.TRICK_PLAY:
		return false
	if player_index != current_player:
		return false
	var legal_moves: Array = get_legal_moves(player_index)
	if not HeartsUtil.contains_card(legal_moves, card):
		return false
	if not HeartsUtil.remove_card(players[player_index]["hand"], card):
		return false
	current_trick["plays"].append({"player": player_index, "card": HeartsUtil.clone_card(card)})
	if current_trick["plays"].size() == 1:
		current_trick["lead_suit"] = int(card["suit"])
	if int(card["suit"]) == HeartsUtil.Suit.HEARTS:
		hearts_broken = true
	_append_log("%s 打出 %s。" % [PLAYER_LABELS[player_index], HeartsUtil.card_label(card, _ascii_mode)])
	if current_trick["plays"].size() >= PLAYER_COUNT:
		pending_trick_result = _compute_trick_result(current_trick)
		phase = Phase.TRICK_RESOLVE
	else:
		current_player = (current_player + 1) % PLAYER_COUNT
	_emit_state()
	return true


func _build_round_summary() -> Dictionary:
	var raw_scores: Array = []
	for player in players:
		raw_scores.append(int(player["round_points"]))
	var applied_scores: Array = raw_scores.duplicate()
	var moon_player: int = -1
	for index in range(raw_scores.size()):
		if int(raw_scores[index]) == 26:
			moon_player = index
			applied_scores = [26, 26, 26, 26]
			applied_scores[index] = 0
			break
	for index in range(players.size()):
		players[index]["total_points"] += int(applied_scores[index])
	var totals: Array = []
	for player in players:
		totals.append(int(player["total_points"]))
	if moon_player >= 0:
		_append_log("%s 收全了罚分，其余三家各记 26 分。" % PLAYER_LABELS[moon_player])
	else:
		_append_log("本局结算：%s。" % _score_line(applied_scores))
	return {
		"round_number": round_index + 1,
		"raw_scores": raw_scores.duplicate(),
		"applied_scores": applied_scores.duplicate(),
		"totals": totals.duplicate(),
		"shoot_the_moon": moon_player,
	}


func _compute_trick_result(trick: Dictionary) -> Dictionary:
	var plays: Array = trick.get("plays", [])
	var lead_suit: int = int(trick.get("lead_suit", -1))
	var winner: int = int(plays[0].get("player", 0))
	var winning_card: Dictionary = plays[0].get("card", {})
	var points: int = 0
	for play in plays:
		var card: Dictionary = play.get("card", {})
		points += HeartsUtil.card_points(card)
		if int(card.get("suit", -1)) == lead_suit and int(card.get("rank", 0)) > int(winning_card.get("rank", 0)):
			winner = int(play.get("player", 0))
			winning_card = card
	return {
		"winner": winner,
		"winning_card": HeartsUtil.clone_card(winning_card),
		"lead_suit": lead_suit,
		"points": points,
		"plays": plays.duplicate(true),
		"trick_number": trick_index + 1,
	}


func _deal_round() -> void:
	for player in players:
		player["hand"].clear()
		player["captured_tricks"].clear()
		player["round_points"] = 0
		player["passed_cards"] = []
		player["received_cards"] = []
	var deck: Array = []
	for suit in range(4):
		for rank in range(2, 15):
			deck.append(HeartsUtil.make_card(suit, rank))
	for index in range(deck.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp = deck[index]
		deck[index] = deck[swap_index]
		deck[swap_index] = temp
	for index in range(deck.size()):
		players[index % PLAYER_COUNT]["hand"].append(deck[index])
	for player in players:
		player["hand"] = HeartsUtil.sort_cards(player["hand"])


func _find_two_of_clubs_holder() -> int:
	var target := HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 2)
	for player_index in range(players.size()):
		if HeartsUtil.contains_card(players[player_index]["hand"], target):
			return player_index
	return 0


func _get_pass_target(player_index: int, direction: int) -> int:
	match direction:
		PassDirection.LEFT:
			return (player_index + 1) % PLAYER_COUNT
		PassDirection.RIGHT:
			return (player_index + PLAYER_COUNT - 1) % PLAYER_COUNT
		PassDirection.ACROSS:
			return (player_index + 2) % PLAYER_COUNT
		_:
			return player_index


func _reset_players() -> void:
	players.clear()
	for _index in range(PLAYER_COUNT):
		players.append({
			"hand": [],
			"captured_tricks": [],
			"round_points": 0,
			"total_points": 0,
			"passed_cards": [],
			"received_cards": [],
		})


func _append_log(text: String) -> void:
	event_feed.append(text)
	while event_feed.size() > 8:
		event_feed.remove_at(0)


func _is_match_finished() -> bool:
	for player in players:
		if int(player["total_points"]) >= MAX_SCORE:
			return true
	return false


func _get_low_score_winners() -> Array:
	var best_score: int = 1_000_000
	var winner_ids: Array = []
	for index in range(players.size()):
		var total := int(players[index]["total_points"])
		if total < best_score:
			best_score = total
			winner_ids = [index]
		elif total == best_score:
			winner_ids.append(index)
	return winner_ids


func _winner_names(winner_ids: Array) -> String:
	var names: Array[String] = []
	for winner_id in winner_ids:
		names.append(PLAYER_LABELS[int(winner_id)])
	return "、".join(names)


func _score_line(scores: Array) -> String:
	var parts: Array[String] = []
	for index in range(scores.size()):
		parts.append("%s %+d" % [PLAYER_LABELS[index], int(scores[index])])
	return " / ".join(parts)


func _emit_state() -> void:
	emit_signal("state_changed")
