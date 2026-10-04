extends Node

const GRID := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const DECK := preload("res://src/main/decks/deck_types/journey_deck.tscn")
const HARNESS := preload("res://src/tests scenes/card_test_scene.gd")

var _failures := 0
var _passed := 0
var _boardChanges := 0


func _ready() -> void:
	await _testProductionDeckIgnoresClicks()
	await _testDebugDeckGuards()
	await _testDebugRevealSettlesWhileLocked()
	await _testDragRequiresOptInAndBoardOwner()
	await _testLockCancelsDrag()
	await _testHarnessCleanupAndReentry()
	if _failures > 0:
		push_error("FAIL: Gameplay input tests (%s failures, %s checks passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: Gameplay input tests (%s checks passed)" % _passed)
	get_tree().quit(0)


func _fixture() -> Dictionary:
	var root := Node.new()
	var grid: SlotGrid = GRID.instantiate()
	grid.name = "Grid"
	var board := BoardController.new()
	board.slotGridPath = NodePath("../Grid")
	var deck: JourneyDeck = DECK.instantiate()
	var game := GameController.new()
	root.add_child(grid)
	root.add_child(board)
	root.add_child(deck)
	root.add_child(game)
	add_child(root)
	deck.boardController = board
	deck.slotGrid = grid
	deck.journeyDeckCardBag.initialiseDeck(["M_0002", "M_0001"], false)
	game.state = GameController.GameState.PLAYER_READY
	# Exercise the manual scene's real handlers without starting its whole run.
	var harness = HARNESS.new()
	harness.boardController = board
	harness.journeyDeck = deck
	harness.gameController = game
	InputManager.debugDraggingEnabled = false
	InputManager.debugBoardController = null
	InputManager.unlockInput()
	return {"root": root, "grid": grid, "board": board, "deck": deck, "game": game, "harness": harness}


func _click(button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _testProductionDeckIgnoresClicks() -> void:
	var f := _fixture()
	f.deck.deckImage.gui_input.emit(_click())
	InputManager.lockInput()
	f.deck.deckImage.gui_input.emit(_click())
	await get_tree().process_frame
	_expect(f.deck.getDeckSize() == 2, "An ordinary deck must not consume cards on clicks, locked or unlocked.")
	_expect(f.grid.getOccupiedSlots().is_empty(), "An ordinary deck click must not place a card.")
	_expect(!ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction, "An ordinary deck click must not schedule gameplay work.")
	await _cleanup(f)


func _testDebugDeckGuards() -> void:
	var f := _fixture()
	f.harness._configureDebugInput()
	InputManager.lockInput()
	f.deck.deckImage.gui_input.emit(_click())
	InputManager.unlockInput()
	for phase in [GameController.GameState.SETUP, GameController.GameState.RESOLVING_MOVE, GameController.GameState.COMBAT, GameController.GameState.AFTER_MOVE, GameController.GameState.GAME_OVER]:
		f.game.state = phase
		f.deck.deckImage.gui_input.emit(_click())
	f.game.state = GameController.GameState.PLAYER_READY
	f.deck.deckImage.gui_input.emit(_click(MOUSE_BUTTON_RIGHT))
	f.deck.deckImage.gui_input.emit(_click(MOUSE_BUTTON_LEFT, false))
	f.deck.deckImage.gui_input.emit(InputEventMouseMotion.new())
	await get_tree().process_frame
	_expect(f.deck.getDeckSize() == 2 and f.grid.getOccupiedSlots().is_empty(), "Debug deck input must reject locked clicks, other phases and non-left-press events.")
	_expect(!ActionQueue.queueHasActions() and !f.deck.isProcessingRevealQueue, "Rejected debug clicks must leave no queued reveal work.")
	await _cleanup(f)


func _testDebugRevealSettlesWhileLocked() -> void:
	var f := _fixture()
	f.harness._configureDebugInput()
	f.deck.deckImage.gui_input.emit(_click())
	InputManager.lockInput()
	await _settle(f.deck)
	var slots: Array[CardSlot] = f.grid.getOccupiedSlots()
	_expect(slots.size() == 1 and f.deck.getDeckSize() == 1, "An accepted debug click must complete exactly one reveal after input locks.")
	if slots.size() == 1:
		_expect(slots[0].currentCard.health == 5, "Queued on-play effects must settle while input is locked.")
		_expect(slots[0].currentCard.visuals.isFaceUp(), "The queued reveal animation must finish while input is locked.")
	_expect(InputManager.inputLocked, "Action completion must not override the caller's input lock.")
	await _cleanup(f)


func _looseCard(root: Node) -> Card:
	var card := CreateCard.new().createCard("M_0001")
	root.add_child(card)
	card.setCardState(CardState.State.ON_BOARD)
	return card


func _testDragRequiresOptInAndBoardOwner() -> void:
	var f := _fixture()
	var card := _looseCard(f.root)
	GlobalSignalBus.emitCardPressed(card)
	_expect(InputManager.cardBeingDragged == null, "Loose cards must not drag without the debug override.")
	f.harness._configureDebugInput()
	InputManager.lockInput()
	GlobalSignalBus.emitCardPressed(card)
	_expect(InputManager.cardBeingDragged == null, "Debug dragging must still respect the input lock.")
	InputManager.unlockInput()
	GlobalSignalBus.emitCardPressed(card)
	_expect(InputManager.cardBeingDragged == card, "The debug harness must enable dragging of loose cards.")
	_boardChanges = 0
	GlobalSignalBus.boardStateChanged.connect(_recordBoardChange)
	InputManager.hoveredSlot = f.grid.getSlotAt(Vector2i(0, 0))
	InputManager._finishDragging(Vector2.ZERO)
	GlobalSignalBus.boardStateChanged.disconnect(_recordBoardChange)
	_expect(f.board.getSlotCardIsIn(card) == f.grid.getSlotAt(Vector2i(0, 0)), "A debug drop must update board occupancy.")
	_expect(_boardChanges == 1, "A successful debug drop must publish exactly one board change.")
	_expect(card.currentState == CardState.State.IN_SLOT and InputManager.cardBeingDragged == null, "A successful drop must complete the drag state.")
	var spare := _looseCard(f.root)
	GlobalSignalBus.emitCardPressed(spare)
	InputManager.debugBoardController = null
	InputManager.hoveredSlot = f.grid.getSlotAt(Vector2i(1, 0))
	InputManager._finishDragging(Vector2.ZERO)
	_expect(!f.grid.getSlotAt(Vector2i(1, 0)).isOccupied(), "A missing debug board owner must reject placement.")
	_expect(spare.currentState == CardState.State.ON_BOARD, "A rejected drop must cancel drag visuals.")
	InputManager.debugBoardController = f.board
	await _cleanup(f)


func _testLockCancelsDrag() -> void:
	var f := _fixture()
	f.harness._configureDebugInput()
	var card := _looseCard(f.root)
	card.rotation = 0.3
	var originalFilter := card.mouse_filter
	GlobalSignalBus.emitCardPressed(card)
	InputManager.hoveredSlot = f.grid.getSlotAt(Vector2i(0, 0))
	card.rotation = 0.0
	InputManager.lockInput()
	_expect(InputManager.cardBeingDragged == null and InputManager.hoveredSlot == null, "Locking must clear active drag references.")
	_expect(card.currentState == CardState.State.ON_BOARD and !card.visuals.isDragging and !card.shadow.visible, "Locking must cancel dragging visuals and card state.")
	_expect(is_equal_approx(card.rotation, 0.3) and card.mouse_filter == originalFilter, "Locking must restore rotation and mouse filtering.")
	_expect(InputManager.draggingOffset == Vector2.ZERO, "Locking must clear the drag offset.")
	InputManager.unlockInput()
	GlobalSignalBus.emitCardPressed(card)
	_expect(InputManager.cardBeingDragged == card, "The cancelled card must remain draggable after unlocking.")
	await _cleanup(f)


func _testHarnessCleanupAndReentry() -> void:
	var f := _fixture()
	f.harness._configureDebugInput()
	var card := _looseCard(f.root)
	GlobalSignalBus.emitCardPressed(card)
	f.harness._exit_tree()
	_expect(!InputManager.debugDraggingEnabled and InputManager.debugBoardController == null, "Leaving the harness must clear its debug permission and board reference.")
	_expect(InputManager.cardBeingDragged == null, "Leaving the harness must cancel its active drag.")
	InputManager.unlockInput()
	f.deck.deckImage.gui_input.emit(_click())
	_expect(!f.deck.isProcessingRevealQueue, "Leaving the harness must disconnect its debug deck handler.")
	f.harness._configureDebugInput()
	f.deck.deckImage.gui_input.emit(_click())
	await _settle(f.deck)
	_expect(f.deck.getDeckSize() == 1 and f.grid.getOccupiedSlots().size() == 1, "Re-entering the debug setup must connect exactly one deck handler.")
	await _cleanup(f)


func _settle(deck: JourneyDeck) -> void:
	for frame in range(360):
		if !deck.isProcessingRevealQueue and !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	_expect(false, "Queued input work must settle within 360 frames.")


func _cleanup(f: Dictionary) -> void:
	await _settle(f.deck)
	f.harness._clearDebugInput()
	f.harness.free()
	InputManager.lockInput()
	InputManager.debugDraggingEnabled = false
	InputManager.debugBoardController = null
	EffectProcessor.clearEffects()
	f.root.queue_free()
	await get_tree().process_frame


func _recordBoardChange() -> void:
	_boardChanges += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
