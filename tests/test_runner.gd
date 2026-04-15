extends SceneTree

const GameScene = preload("res://scenes/Game.tscn")
const HeartsMatch = preload("res://scripts/core/hearts_match.gd")
const HeartsUtil = preload("res://scripts/core/hearts_util.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run_all()
	if failures.is_empty():
		print("All tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_all() -> void:
	_test_deal_is_unique()
	_test_pass_cycle()
	_test_first_trick_opens_with_two_of_clubs()
	_test_main_scene_loads()
	_test_hearts_cannot_lead_before_break()
	_test_follow_suit_is_forced()
	_test_first_trick_discards_avoid_points()
	_test_shoot_the_moon_scoring()
	_test_match_finish_detection()
	_test_full_round_simulation()
	_test_full_match_simulation()


func _test_deal_is_unique() -> void:
	var game_match := HeartsMatch.new()
	game_match.start_match(7)
	var state := game_match.get_state()
	var seen := {}
	for player in state["players"]:
		_expect(int(player["hand_count"]) == 13, "Each player should have 13 cards after dealing.")
		for card in player["hand"]:
			seen[HeartsUtil.card_key(card)] = true
	_expect(seen.size() == 52, "Dealt deck should contain 52 unique cards.")


func _test_pass_cycle() -> void:
	var game_match := HeartsMatch.new()
	game_match.start_match(12)
	var expected := [
		HeartsMatch.PassDirection.LEFT,
		HeartsMatch.PassDirection.RIGHT,
		HeartsMatch.PassDirection.ACROSS,
		HeartsMatch.PassDirection.HOLD,
	]
	for index in range(expected.size()):
		var state := game_match.get_state()
		_expect(int(state["pass_direction"]) == expected[index], "Pass cycle did not match the expected rotation.")
		if index < expected.size() - 1:
			game_match.start_round()


func _test_first_trick_opens_with_two_of_clubs() -> void:
	var game_match := HeartsMatch.new()
	game_match.start_match(22)
	_complete_pass_if_needed(game_match)
	var state := game_match.get_state()
	var legal := game_match.get_legal_moves(int(state["current_player"]))
	_expect(legal.size() == 1, "The opening leader should have exactly one legal move.")
	_expect(HeartsUtil.same_card(legal[0], HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 2)), "The opening lead must be the two of clubs.")


func _test_main_scene_loads() -> void:
	var game_node := GameScene.instantiate()
	_expect(game_node != null, "The main Game scene should instantiate successfully.")
	if game_node != null:
		game_node.free()


func _test_hearts_cannot_lead_before_break() -> void:
	var game_match := HeartsMatch.new()
	game_match.phase = HeartsMatch.Phase.TRICK_PLAY
	game_match.current_player = 0
	game_match.trick_index = 3
	game_match.hearts_broken = false
	game_match.current_trick = {"leader": 0, "lead_suit": -1, "plays": []}
	game_match.players = [
		_make_player([
			HeartsUtil.make_card(HeartsUtil.Suit.HEARTS, 2),
			HeartsUtil.make_card(HeartsUtil.Suit.HEARTS, 7),
			HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 10),
		]),
		_make_player([]),
		_make_player([]),
		_make_player([]),
	]
	var legal := game_match.get_legal_moves(0)
	_expect(legal.size() == 1 and HeartsUtil.same_card(legal[0], HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 10)), "Hearts should not be a legal lead before hearts are broken.")


func _test_follow_suit_is_forced() -> void:
	var game_match := HeartsMatch.new()
	game_match.phase = HeartsMatch.Phase.TRICK_PLAY
	game_match.current_player = 0
	game_match.trick_index = 4
	game_match.current_trick = {
		"leader": 1,
		"lead_suit": HeartsUtil.Suit.CLUBS,
		"plays": [{"player": 1, "card": HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 5)}],
	}
	game_match.players = [
		_make_player([
			HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 9),
			HeartsUtil.make_card(HeartsUtil.Suit.HEARTS, 2),
		]),
		_make_player([]),
		_make_player([]),
		_make_player([]),
	]
	var legal := game_match.get_legal_moves(0)
	_expect(legal.size() == 1 and HeartsUtil.same_card(legal[0], HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 9)), "A player with the lead suit should be forced to follow suit.")


func _test_first_trick_discards_avoid_points() -> void:
	var game_match := HeartsMatch.new()
	game_match.phase = HeartsMatch.Phase.TRICK_PLAY
	game_match.current_player = 0
	game_match.trick_index = 0
	game_match.current_trick = {
		"leader": 1,
		"lead_suit": HeartsUtil.Suit.CLUBS,
		"plays": [{"player": 1, "card": HeartsUtil.make_card(HeartsUtil.Suit.CLUBS, 6)}],
	}
	game_match.players = [
		_make_player([
			HeartsUtil.make_card(HeartsUtil.Suit.HEARTS, 2),
			HeartsUtil.make_card(HeartsUtil.Suit.SPADES, 12),
			HeartsUtil.make_card(HeartsUtil.Suit.DIAMONDS, 3),
		]),
		_make_player([]),
		_make_player([]),
		_make_player([]),
	]
	var legal := game_match.get_legal_moves(0)
	_expect(legal.size() == 1 and HeartsUtil.same_card(legal[0], HeartsUtil.make_card(HeartsUtil.Suit.DIAMONDS, 3)), "On the first trick, point cards should be blocked if a safe discard exists.")


func _test_shoot_the_moon_scoring() -> void:
	var game_match := HeartsMatch.new()
	game_match.players = [
		_make_player([], 26, 0),
		_make_player([], 0, 0),
		_make_player([], 0, 0),
		_make_player([], 0, 0),
	]
	var summary := game_match._build_round_summary()
	_expect(int(summary["shoot_the_moon"]) == 0, "Shoot the moon should identify the collecting player.")
	_expect(summary["applied_scores"] == [0, 26, 26, 26], "Shoot the moon should add 26 points to the other three players.")


func _test_match_finish_detection() -> void:
	var game_match := HeartsMatch.new()
	game_match.players = [
		_make_player([], 10, 95),
		_make_player([], 0, 42),
		_make_player([], 0, 37),
		_make_player([], 0, 68),
	]
	game_match.phase = HeartsMatch.Phase.ROUND_END
	game_match.pending_round_summary = game_match._build_round_summary()
	var summary := game_match.resolve_round()
	_expect(game_match.phase == HeartsMatch.Phase.MATCH_END, "The match should end when a player reaches 100 points.")
	_expect(summary.has("winner_ids"), "Match resolution should include winner ids.")


func _test_full_round_simulation() -> void:
	var game_match := HeartsMatch.new()
	game_match.start_match(99)
	_drive_until_round_end(game_match, 200)
	var state := game_match.get_state()
	_expect(int(state["phase"]) == HeartsMatch.Phase.ROUND_END, "A driven round should reach round-end state.")


func _test_full_match_simulation() -> void:
	var game_match := HeartsMatch.new()
	game_match.start_match(11)
	var guard := 0
	while game_match.phase != HeartsMatch.Phase.MATCH_END and guard < 4000:
		guard += 1
		if game_match.phase == HeartsMatch.Phase.PASSING:
			_complete_pass_if_needed(game_match)
		elif game_match.phase == HeartsMatch.Phase.TRICK_PLAY:
			if game_match.current_player == 0:
				var legal := game_match.get_legal_moves(0)
				_expect(not legal.is_empty(), "Human player should always have a legal move during full match simulation.")
				game_match.submit_play(legal[0])
			else:
				game_match.advance_ai_turn()
		elif game_match.phase == HeartsMatch.Phase.TRICK_RESOLVE:
			game_match.resolve_trick()
		elif game_match.phase == HeartsMatch.Phase.ROUND_END:
			game_match.resolve_round()
	_expect(game_match.phase == HeartsMatch.Phase.MATCH_END, "A full match simulation should eventually finish.")
	_expect(guard < 4000, "Full match simulation exceeded the guard limit.")


func _drive_until_round_end(game_match: HeartsMatch, guard_limit: int) -> void:
	var guard := 0
	while game_match.phase != HeartsMatch.Phase.ROUND_END and guard < guard_limit:
		guard += 1
		if game_match.phase == HeartsMatch.Phase.PASSING:
			_complete_pass_if_needed(game_match)
		elif game_match.phase == HeartsMatch.Phase.TRICK_PLAY:
			if game_match.current_player == 0:
				var legal := game_match.get_legal_moves(0)
				_expect(not legal.is_empty(), "Human player should always have a legal move.")
				game_match.submit_play(legal[0])
			else:
				game_match.advance_ai_turn()
		elif game_match.phase == HeartsMatch.Phase.TRICK_RESOLVE:
			game_match.resolve_trick()
	_expect(game_match.phase == HeartsMatch.Phase.ROUND_END, "Round simulation exceeded the guard limit.")


func _complete_pass_if_needed(game_match: HeartsMatch) -> void:
	if game_match.phase != HeartsMatch.Phase.PASSING:
		return
	var state := game_match.get_state()
	var selected: Array = state["players"][0]["hand"].slice(0, 3)
	_expect(game_match.submit_pass(selected), "Passing three legal cards should succeed.")


func _make_player(hand: Array, round_points := 0, total_points := 0) -> Dictionary:
	return {
		"hand": HeartsUtil.clone_cards(hand),
		"captured_tricks": [],
		"round_points": round_points,
		"total_points": total_points,
		"passed_cards": [],
		"received_cards": [],
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
