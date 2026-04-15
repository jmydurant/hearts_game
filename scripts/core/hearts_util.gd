class_name HeartsUtil
extends RefCounted

enum Suit {
	CLUBS,
	DIAMONDS,
	SPADES,
	HEARTS,
}

const SUIT_SYMBOLS := ["♣", "♦", "♠", "♥"]
const SUIT_SYMBOLS_ASCII := ["C", "D", "S", "H"]
const SUIT_NAMES := ["梅花", "方块", "黑桃", "红心"]
const RANK_LABELS := {
	2: "2",
	3: "3",
	4: "4",
	5: "5",
	6: "6",
	7: "7",
	8: "8",
	9: "9",
	10: "10",
	11: "J",
	12: "Q",
	13: "K",
	14: "A",
}


static func make_card(suit: int, rank: int) -> Dictionary:
	return {"suit": suit, "rank": rank}


static func clone_card(card: Dictionary) -> Dictionary:
	return {"suit": int(card.get("suit", 0)), "rank": int(card.get("rank", 2))}


static func clone_cards(cards: Array) -> Array:
	var copy: Array = []
	for card in cards:
		copy.append(clone_card(card))
	return copy


static func card_key(card: Dictionary) -> String:
	return "%d_%d" % [int(card.get("suit", 0)), int(card.get("rank", 2))]


static func same_card(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("suit", -1)) == int(b.get("suit", -2)) and int(a.get("rank", -1)) == int(b.get("rank", -2))


static func sort_cards(cards: Array) -> Array:
	var sorted_cards: Array = clone_cards(cards)
	sorted_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_suit := int(a.get("suit", 0))
		var b_suit := int(b.get("suit", 0))
		if a_suit == b_suit:
			return int(a.get("rank", 2)) < int(b.get("rank", 2))
		return a_suit < b_suit
	)
	return sorted_cards


static func remove_card(cards: Array, target: Dictionary) -> bool:
	for index in range(cards.size()):
		if same_card(cards[index], target):
			cards.remove_at(index)
			return true
	return false


static func contains_card(cards: Array, target: Dictionary) -> bool:
	for card in cards:
		if same_card(card, target):
			return true
	return false


static func count_suit(cards: Array, suit: int) -> int:
	var total := 0
	for card in cards:
		if int(card.get("suit", -1)) == suit:
			total += 1
	return total


static func has_only_hearts(cards: Array) -> bool:
	if cards.is_empty():
		return false
	for card in cards:
		if int(card.get("suit", -1)) != Suit.HEARTS:
			return false
	return true


static func is_point_card(card: Dictionary) -> bool:
	return int(card.get("suit", -1)) == Suit.HEARTS or is_queen_of_spades(card)


static func is_queen_of_spades(card: Dictionary) -> bool:
	return int(card.get("suit", -1)) == Suit.SPADES and int(card.get("rank", 0)) == 12


static func card_points(card: Dictionary) -> int:
	if int(card.get("suit", -1)) == Suit.HEARTS:
		return 1
	if is_queen_of_spades(card):
		return 13
	return 0


static func card_label(card: Dictionary, ascii_mode := false) -> String:
	var symbols := SUIT_SYMBOLS
	if ascii_mode:
		symbols = SUIT_SYMBOLS_ASCII
	return "%s%s" % [RANK_LABELS.get(int(card.get("rank", 2)), "?"), symbols[int(card.get("suit", 0))]]


static func cards_to_text(cards: Array, ascii_mode := false) -> String:
	var parts: Array[String] = []
	for card in sort_cards(cards):
		parts.append(card_label(card, ascii_mode))
	return " ".join(parts)
