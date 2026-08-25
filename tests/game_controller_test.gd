extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE := preload("res://src/main/decks/deck_types/journey_deck.tscn")

var _fixtureRoot: Node
var _grid: SlotGrid
var _board: BoardController
var _deck: JourneyDeck
var _controller: GameController
var _passed := 0
var _failures := 0
var _startedPlayers: Array = []
var _afterMovePlayers: Array = []
var _completedPlayers: Array = []
var _readyObservedIdle := false
var _readyObservedPlayerFaceUp := false


func _ready() -> void:
	await _testMissingReferencesFailLocked()
	await _createFixture()
	await _testRunSetup()
	_testRejectedTransitionsDoNotAdvance()
	_testMovementAfterMoveBoundary()
	await _testCombatAndGuardedCompletion()
	_testOnlyPlayerReceivesCycleEvents()
	await _cleanup()

	if _failures > 0:
		push_error("FAIL: GameController tests (%s failures, %s checks passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: GameController tests (%s checks passed)" % _passed)
	get_tree().quit(0)


func _testMissingReferencesFailLocked() -> void:
	var controller := GameController.new()
	add_child(controller)
	InputManager.unlockInput()
	_expect(!await controller.startRun(false), "A run without required references must fail.")
	_expect(InputManager.inputLocked, "Failed setup must leave input locked.")
	controller.queue_free()
	await get_tree().process_frame


func _createFixture() -> void:
	_fixtureRoot = Node.new()
	_fixtureRoot.name = "GameControllerFixture"

	_grid = SLOT_GRID_SCENE.instantiate()
	_grid.name = "SlotGrid"
	_board = BoardController.new()
	_board.name = "BoardController"
	_board.slotGridPath = NodePath("../SlotGrid")
	_deck = JOURNEY_DECK_SCENE.instantiate()
	_deck.name = "JourneyDeck"
	_controller = GameController.new()
	_controller.name = "GameController"

	_fixtureRoot.add_child(_grid)
	_fixtureRoot.add_child(_board)
	_fixtureRoot.add_child(_deck)
	_fixtureRoot.add_child(_controller)
	add_child(_fixtureRoot)
	await get_tree().process_frame

	_controller.boardController = _board
	_controller.slotGrid = _grid
	_controller.journeyDeck = _deck
	GlobalSignalBus.playerCycleStarted.connect(_onPlayerCycleStarted)
	GlobalSignalBus.afterMoveStarted.connect(_onAfterMoveStarted)
	GlobalSignalBus.playerCycleCompleted.connect(_onPlayerCycleCompleted)
	GlobalSignalBus.gameStateChanged.connect(_onGameStateChanged)


func _testRunSetup() -> void:
	var placeholder := GraveyardEntry.new()
	Graveyard.entries.append(placeholder)
	BoardHistory.recordEvent("test_event")

	var started := await _controller.startRun(false)
	_expect(started, "A run with valid references must start.")
	_expect(Graveyard.getEntries().is_empty(), "Starting a run must reset Graveyard.")
	_expect(BoardHistory.getEvents().is_empty(), "Starting a run must reset BoardHistory.")
	_expect(_controller.playerCard != null, "Setup must create the player.")
	_expect(
		_grid.getCenterSlot().currentCard == _controller.playerCard,
		"Setup must place the player in the center slot.",
	)
	_expect(_controller.playerCard.visuals.isFaceUp(), "Setup must leave the player face-up.")
	_expect(_grid.getOccupiedSlots().size() == 9, "Queued reveals must fill the eight surrounding slots.")
	for slot in _grid.getOccupiedSlots():
		if slot == _grid.getCenterSlot():
			continue
		_expect(slot.currentCard.visuals.isFaceUp(), "Every initial Journey card must finish face-up.")
	_expect(!ActionQueue.queueHasActions(), "Setup must wait for the action queue to empty.")
	_expect(!ActionProcessor.isProcessingAction, "Setup must wait for the action processor to become idle.")
	_expect(_readyObservedIdle, "PLAYER_READY must wait until the action system is idle.")
	_expect(
		_readyObservedPlayerFaceUp,
		"PLAYER_READY must wait until the player is face-up.",
	)
	_expect(
		_controller.state == GameController.GameState.PLAYER_READY,
		"Successful setup must enter PLAYER_READY.",
	)
	_expect(!InputManager.inputLocked, "Input must unlock in PLAYER_READY.")
	_expect(_controller.playerCycleNumber == 1, "The first player cycle must be numbered 1.")


func _testRejectedTransitionsDoNotAdvance() -> void:
	var cycle: int = _controller.playerCycleNumber
	var completedCount: int = _completedPlayers.size()
	_expect(!_controller.beginCombat(), "Combat must be rejected outside RESOLVING_MOVE.")
	_expect(!_controller.beginAfterMovePhase(), "AFTER_MOVE must reject an invalid source state.")
	_expect(!_controller.completePlayerCycle(), "Completion must be rejected outside AFTER_MOVE.")
	_expect(_controller.playerCycleNumber == cycle, "Rejected input must not advance the cycle number.")
	_expect(_completedPlayers.size() == completedCount, "Rejected input must not emit cycle completion.")


func _testMovementAfterMoveBoundary() -> void:
	_expect(_controller.beginPlayerAction(), "A valid player action must begin from PLAYER_READY.")
	_expect(InputManager.inputLocked, "Beginning an action must lock input.")
	_expect(
		_controller.state == GameController.GameState.RESOLVING_MOVE,
		"A valid action must enter RESOLVING_MOVE.",
	)
	_expect(
		_controller.beginAfterMovePhase(),
		"Movement resolution must be able to enter AFTER_MOVE.",
	)
	_expect(_afterMovePlayers.size() == 1, "AFTER_MOVE must emit even when no maintenance is required.")
	_expect(_controller.completePlayerCycle(), "An idle AFTER_MOVE phase must complete.")
	_expect(_completedPlayers.size() == 1, "A completed action must emit completion exactly once.")
	_expect(
		_controller.state == GameController.GameState.PLAYER_READY,
		"Completion must return to PLAYER_READY.",
	)
	_expect(_controller.playerCycleNumber == 2, "Completion must begin the next numbered cycle.")
	_expect(!InputManager.inputLocked, "Input must unlock again only at PLAYER_READY.")


func _testCombatAndGuardedCompletion() -> void:
	_expect(_controller.beginPlayerAction(), "The second valid action must begin.")
	_expect(_controller.beginCombat(), "Combat must be enterable from RESOLVING_MOVE.")
	_expect(
		_controller.state == GameController.GameState.COMBAT,
		"The combat transition must enter COMBAT.",
	)
	_expect(_controller.beginAfterMovePhase(), "Combat resolution must be able to enter AFTER_MOVE.")

	var queuedAction := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		_controller.playerCard,
		{"stat": "attack", "amount": 1},
	)
	_expect(ActionQueue.enqueueAction(queuedAction), "The guard test action must enqueue.")
	_expect(!_controller.completePlayerCycle(), "A cycle must not complete while actions are queued.")
	_expect(InputManager.inputLocked, "Input must remain locked while AFTER_MOVE is unsettled.")
	await _waitForProcessor()
	_expect(_controller.completePlayerCycle(), "The cycle must complete after actions settle.")
	_expect(_completedPlayers.size() == 2, "The second cycle must emit completion once.")
	_expect(_controller.playerCycleNumber == 3, "The next ready boundary must increment the cycle.")


func _testOnlyPlayerReceivesCycleEvents() -> void:
	var player := _controller.playerCard
	_expect(_startedPlayers.size() == 3, "Each ready boundary must emit one start event.")
	for emittedPlayer in _startedPlayers + _afterMovePlayers + _completedPlayers:
		_expect(emittedPlayer == player, "Board cards must never receive player-cycle events.")


func _onPlayerCycleStarted(player: Card, _cycleNumber: int) -> void:
	_startedPlayers.append(player)


func _onAfterMoveStarted(player: Card, _cycleNumber: int) -> void:
	_afterMovePlayers.append(player)


func _onPlayerCycleCompleted(player: Card, _cycleNumber: int) -> void:
	_completedPlayers.append(player)


func _onGameStateChanged(_previousState: int, newState: int) -> void:
	if newState != GameController.GameState.PLAYER_READY:
		return
	_readyObservedIdle = !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction
	_readyObservedPlayerFaceUp = (
		_controller.playerCard != null
		and _controller.playerCard.visuals.isFaceUp()
	)


func _waitForProcessor(maxFrames := 240) -> void:
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	_expect(false, "ActionProcessor did not become idle after %s frames." % maxFrames)


func _cleanup() -> void:
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	if is_instance_valid(_fixtureRoot):
		_fixtureRoot.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
