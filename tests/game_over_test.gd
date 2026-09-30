extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE := preload("res://src/main/decks/deck_types/journey_deck.tscn")
const GAME_OVER_OVERLAY_SCENE := preload("res://src/main/ui/overlays/game_over_overlay.tscn")

var _fixture_root: Node
var _grid: SlotGrid
var _board: BoardController
var _deck: JourneyDeck
var _controller: GameController
var _game_over_count := 0
var _completed_cycle_count := 0
var _game_over_saw_idle_queue := false
var _resolved_action_before_game_over := false
var _overlay_continue_count := 0
var _passed := 0
var _failures := 0


func _ready() -> void:
	GlobalSignalBus.gameOverRequested.connect(_on_game_over_requested)
	GlobalSignalBus.gameOverContinueRequested.connect(_on_game_over_continue_requested)
	GlobalSignalBus.playerCycleCompleted.connect(_on_player_cycle_completed)
	GlobalSignalBus.actionResolved.connect(_on_action_resolved)

	await _create_fixture()
	await _test_defeat_waits_for_queued_work_and_locks_input()
	_test_duplicate_game_over_request_is_ignored()
	await _destroy_fixture()

	await _create_fixture()
	await _test_removed_player_triggers_game_over()
	await _destroy_fixture()

	await _create_fixture()
	await _test_queued_healing_prevents_game_over()
	await _destroy_fixture()

	await _test_overlay_contract()

	GlobalSignalBus.gameOverRequested.disconnect(_on_game_over_requested)
	GlobalSignalBus.gameOverContinueRequested.disconnect(_on_game_over_continue_requested)
	GlobalSignalBus.playerCycleCompleted.disconnect(_on_player_cycle_completed)
	GlobalSignalBus.actionResolved.disconnect(_on_action_resolved)

	if _failures > 0:
		push_error("FAIL: Game-over tests (%s failures, %s checks passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: Game-over tests (%s checks passed)" % _passed)
	get_tree().quit(0)


func _create_fixture() -> void:
	await _reset_shared_systems()
	_game_over_count = 0
	_completed_cycle_count = 0
	_game_over_saw_idle_queue = false
	_resolved_action_before_game_over = false

	_fixture_root = Node.new()
	_fixture_root.name = "GameOverFixture"
	_grid = SLOT_GRID_SCENE.instantiate()
	_grid.name = "SlotGrid"
	_board = BoardController.new()
	_board.name = "BoardController"
	_board.slotGridPath = NodePath("../SlotGrid")
	_deck = JOURNEY_DECK_SCENE.instantiate()
	_deck.name = "JourneyDeck"
	_controller = GameController.new()
	_controller.name = "GameController"

	_fixture_root.add_child(_grid)
	_fixture_root.add_child(_board)
	_fixture_root.add_child(_deck)
	_fixture_root.add_child(_controller)
	add_child(_fixture_root)
	await get_tree().process_frame

	_controller.boardController = _board
	_controller.slotGrid = _grid
	_controller.journeyDeck = _deck
	_expect(await _controller.startRun(false), "The game-over fixture must start a valid run.")


func _test_defeat_waits_for_queued_work_and_locks_input() -> void:
	var player := _controller.playerCard
	var cycles_before := _completed_cycle_count
	player.health = 0
	_expect(_controller.beginPlayerAction(), "A settled run must accept a player action before game-over testing.")

	var queued_action := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		player,
		ModifyStatsPayload.create("attack", 1, "game_over_test")
	)
	_expect(ActionQueue.enqueueAction(queued_action), "The settling action must enter the queue.")
	await _controller._finishResolvedPlayerAction()

	_expect(_resolved_action_before_game_over, "Queued work must resolve before Game Over is requested.")
	_expect(_game_over_saw_idle_queue, "Game Over must be requested only after the action system is idle.")
	_expect(_controller.state == GameController.GameState.GAME_OVER, "A player still at zero health must enter GAME_OVER.")
	_expect(InputManager.inputLocked, "GAME_OVER must keep gameplay input locked.")
	_expect(_game_over_count == 1, "A defeated run must emit exactly one game-over request.")
	_expect(_completed_cycle_count == cycles_before, "A defeated action must not complete a player cycle or return to PLAYER_READY.")


func _test_duplicate_game_over_request_is_ignored() -> void:
	_controller._enterGameOver()
	_controller._enterGameOver()
	_expect(_game_over_count == 1, "Repeated game-over attempts must not emit duplicate requests.")
	_expect(_controller.state == GameController.GameState.GAME_OVER, "Repeated game-over attempts must keep the terminal state.")
	_expect(InputManager.inputLocked, "Repeated game-over attempts must never unlock input.")


func _test_removed_player_triggers_game_over() -> void:
	var player := _controller.playerCard
	var entry := Graveyard.buryCard(player, null, "game_over_test", _board)
	_expect(entry != null, "The removal-path test must remove the player through the Graveyard.")
	await get_tree().process_frame
	_expect(_controller.beginPlayerAction(), "A settled run must accept the removal-path test action.")
	await _controller._finishResolvedPlayerAction()

	_expect(_controller.state == GameController.GameState.GAME_OVER, "A player removed from active play must enter GAME_OVER.")
	_expect(_game_over_count == 1, "A removed player must emit one game-over request.")
	_expect(InputManager.inputLocked, "A removed player must leave gameplay input locked.")


func _test_queued_healing_prevents_game_over() -> void:
	var player := _controller.playerCard
	player.health = 0
	_expect(_controller.beginPlayerAction(), "A fresh run must accept the prevention test action.")

	var healing_action := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		player,
		ModifyStatsPayload.create("health", 1, "game_over_prevention_test")
	)
	_expect(ActionQueue.enqueueAction(healing_action), "The prevention action must enter the queue.")
	await _controller._finishResolvedPlayerAction()

	_expect(player.health == 1, "Queued healing must resolve before the final defeat check.")
	_expect(_game_over_count == 0, "A player restored above zero before settlement must not trigger Game Over.")
	_expect(_controller.state == GameController.GameState.PLAYER_READY, "A saved player must continue into the next ready state.")
	_expect(!InputManager.inputLocked, "A saved player must regain input at PLAYER_READY.")


func _test_overlay_contract() -> void:
	var overlay: Control = GAME_OVER_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame

	var dimmer := overlay.get_node_or_null("BackGround") as ColorRect
	var continue_button := overlay.get_node_or_null("BackGround/MarginContainer/VBoxContainer/ButtonHolder/ContinueButton") as Button
	_expect(dimmer != null, "The Game Over overlay must contain a dimmer.")
	_expect(continue_button != null, "The Game Over overlay must contain a Continue button.")
	if dimmer != null:
		_expect(dimmer.mouse_filter == Control.MOUSE_FILTER_STOP, "The dimmer must block clicks from reaching the frozen board.")
		_expect(dimmer.anchor_top == 0.5 and dimmer.anchor_bottom == 0.5, "The backdrop must keep the intended centred message band layout.")
	if continue_button != null:
		_expect(!continue_button.disabled, "The Continue button must remain usable after game over.")
	_expect(
		GlobalSignalBus.has_signal("gameOverContinueRequested"),
		"The GlobalSignalBus must expose a Continue handoff signal for the post-run screen flow."
	)
	if continue_button != null and GlobalSignalBus.has_signal("gameOverContinueRequested"):
		_overlay_continue_count = 0
		continue_button.pressed.emit()
		_expect(_overlay_continue_count == 1, "Continue must emit exactly one handoff request.")
		_expect(continue_button.disabled, "Continue must disable itself to prevent repeated scene transitions.")
		continue_button.pressed.emit()
		_expect(_overlay_continue_count == 1, "A disabled Continue button must not emit a second handoff request.")

	overlay.queue_free()
	await get_tree().process_frame


func _on_game_over_requested() -> void:
	_game_over_count += 1
	_game_over_saw_idle_queue = !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction


func _on_player_cycle_completed(_player: Card, _cycle_number: int) -> void:
	_completed_cycle_count += 1


func _on_action_resolved(_action: GameAction, _result: Variant) -> void:
	_resolved_action_before_game_over = true


func _on_game_over_continue_requested() -> void:
	_overlay_continue_count += 1


func _destroy_fixture() -> void:
	await _reset_shared_systems()
	if is_instance_valid(_fixture_root):
		_fixture_root.queue_free()
	await get_tree().process_frame


func _reset_shared_systems() -> void:
	for _frame in range(240):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			break
		await get_tree().process_frame
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	InputManager.lockInput()


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
