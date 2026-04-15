class_name HeartsAI
extends RefCounted

const HeartsUtil = preload("res://scripts/core/hearts_util.gd")


func choose_pass_cards(hand: Array, _state: Dictionary) -> Array:
	var weighted: Array = []
	for card in hand:
		weighted.append({
			"card": HeartsUtil.clone_card(card),
			"weight": _pass_weight(card, hand),
		})
	weighted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["weight"]) == int(b["weight"]):
			return int(a["card"]["rank"]) > int(b["card"]["rank"])
		return int(a["weight"]) > int(b["weight"])
	)
	var selection: Array = []
	for index in range(min(3, weighted.size())):
		selection.append(HeartsUtil.clone_card(weighted[index]["card"]))
	return HeartsUtil.sort_cards(selection)


func choose_play_card(_player_index: int, legal_moves: Array, state: Dictionary) -> Dictionary:
	if legal_moves.is_empty():
		return {}
	var trick: Dictionary = state.get("current_trick", {})
	var plays: Array = trick.get("plays", [])
	if plays.is_empty():
		return _choose_lead_card(legal_moves)
	return _choose_follow_card(legal_moves, state)


func _pass_weight(card: Dictionary, hand: Array) -> int:
	var suit := int(card.get("suit", 0))
	var rank := int(card.get("rank", 2))
	var count := HeartsUtil.count_suit(hand, suit)
	var weight := rank
	if HeartsUtil.is_queen_of_spades(card):
		weight += 240
	elif suit == HeartsUtil.Suit.SPADES and rank >= 13:
		weight += 180
	elif suit == HeartsUtil.Suit.SPADES and rank >= 11:
		weight += 120
	if suit == HeartsUtil.Suit.HEARTS:
		weight += 60 + rank
	if count == 1:
		weight += 35
	elif count == 2:
		weight += 15
	if rank >= 12:
		weight += 18
	return weight


func _choose_lead_card(legal_moves: Array) -> Dictionary:
	var weighted: Array = []
	for card in legal_moves:
		var suit := int(card.get("suit", 0))
		var rank := int(card.get("rank", 2))
		var weight := rank
		if suit == HeartsUtil.Suit.SPADES:
			weight += 24
			if rank >= 12:
				weight += 36
		elif suit == HeartsUtil.Suit.HEARTS:
			weight += 12
		elif suit == HeartsUtil.Suit.CLUBS:
			weight -= 4
		weighted.append({"card": HeartsUtil.clone_card(card), "weight": weight})
	weighted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["weight"]) == int(b["weight"]):
			return int(a["card"]["rank"]) < int(b["card"]["rank"])
		return int(a["weight"]) < int(b["weight"])
	)
	return HeartsUtil.clone_card(weighted[0]["card"])


func _choose_follow_card(legal_moves: Array, state: Dictionary) -> Dictionary:
	var trick: Dictionary = state.get("current_trick", {})
	var plays: Array = trick.get("plays", [])
	var lead_suit := int(trick.get("lead_suit", -1))
	var current_winning_rank := -1
	var trick_points := 0
	for play in plays:
		var card: Dictionary = play.get("card", {})
		trick_points += HeartsUtil.card_points(card)
		if int(card.get("suit", -1)) == lead_suit:
			current_winning_rank = max(current_winning_rank, int(card.get("rank", 0)))

	var must_follow := true
	for card in legal_moves:
		if int(card.get("suit", -1)) != lead_suit:
			must_follow = false
			break

	if must_follow:
		var below: Array = []
		for card in legal_moves:
			if int(card.get("rank", 0)) < current_winning_rank:
				below.append(HeartsUtil.clone_card(card))
		if not below.is_empty():
			below.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["rank"]) > int(b["rank"])
			)
			return below[0]
		var sorted_legal := HeartsUtil.sort_cards(legal_moves)
		if trick_points > 0 or lead_suit == HeartsUtil.Suit.HEARTS:
			return HeartsUtil.clone_card(sorted_legal[0])
		return HeartsUtil.clone_card(sorted_legal[-1])

	var weighted: Array = []
	for card in legal_moves:
		var suit := int(card.get("suit", 0))
		var rank := int(card.get("rank", 2))
		var weight := rank
		if HeartsUtil.is_queen_of_spades(card):
			weight += 300
		elif suit == HeartsUtil.Suit.HEARTS:
			weight += 120 + rank
		elif suit == HeartsUtil.Suit.SPADES:
			weight += 70 + rank
		if rank >= 12:
			weight += 18
		weighted.append({"card": HeartsUtil.clone_card(card), "weight": weight})
	weighted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["weight"]) == int(b["weight"]):
			return int(a["card"]["rank"]) > int(b["card"]["rank"])
		return int(a["weight"]) > int(b["weight"])
	)
	return HeartsUtil.clone_card(weighted[0]["card"])
