extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")

var _fixtureRoot: Node
var _grid: SlotGrid
var _board: BoardController
var _game: GameController
var _movement: PlayerMovementController
var _player: Card
var _cards: Dictionary[Vector2i, Card] = {}
var _combatRequests: Array[Array] = []
var _passed := 0
var _failures := 0
var _createCard := CreateCard.new()


func _ready() -> void:
	GlobalSignalBus.playerCombatRequested.connect(_onPlayerCombatRequested)
	await _testMissingReferencesFailClosed()
	await _createFixture()
	_testTargetValidation()
	_testInvalidClicksDoNothing()
	_testValidClickCreatesOneImmutableRequest()
	await _cleanup()

	if _failures > 0:
		push_error("FAIL: PlayerMovementController tests (%s failures, %s checks passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: PlayerMovementController tests (%s checks passed)" % _passed)
	get_tree().quit(0)


func _testMissingReferencesFailClosed() -> void:
	var movement := PlayerMovementController.new()
	add_child(movement)
	_expect(!movement.isValidTarget(null), "Missing references must make target validation fail closed.")
	movement.queue_free()
	await get_tree().process_frame


func _createFixture() -> void:
	_fixtureRoot = Node.new()
	_fixtureRoot.name = "PlayerMovementFixture"
	_grid = SLOT_GRID_SCENE.instantiate()
	_grid.name = "SlotGrid"
	_board = BoardController.new()
	_board.name = "BoardController"
	_board.slotGridPath = NodePath("../SlotGrid")
	_game = GameController.new()
	_game.name = "GameController"
	_movement = PlayerMovementController.new()
	_movement.name = "PlayerMovementController"

	_fixtureRoot.add_child(_grid)
	_fixtureRoot.add_child(_board)
	_fixtureRoot.add_child(_game)
	_fixtureRoot.add_child(_movement)
	add_child(_fixtureRoot)
	await get_tree().process_frame

	_game.boardController = _board
	_game.slotGrid = _grid
	_movement.gameController = _game
	_movement.boardController = _board
	_movement.slotGrid = _grid

	_player = _placeCard("C_0000", Vector2i(1, 1))
	_game.playerCard = _player
	_game.playerCycleNumber = 7
	for coordinate in [
		Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1),
		Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2),
	]:
		_placeCard("M_0001", coordinate)
	_game.setState(GameController.GameState.PLAYER_READY)
	InputManager.unlockInput()


func _placeCard(cardId: String, coordinate: Vector2i) -> Card:
	var card := _createCard.createCard(cardId)
	_expect(card != null, "Fixture card %s must be created." % cardId)
	if card == null:
		return null
	_expect(_board.placeCard(card, _grid.getSlotAt(coordinate)), "Fixture card must be placed at %s." % coordinate)
	_cards[coordinate] = card
	return card


func _testTargetValidation() -> void:
	for coordinate in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)]:
		_expect(_movement.isValidTarget(_cards[coordinate]), "Cardinal card at %s must be valid." % coordinate)
	for coordinate in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		_expect(!_movement.isValidTarget(_cards[coordinate]), "Diagonal card at %s must be invalid." % coordinate)
	_expect(!_movement.isValidTarget(null), "A null target must be invalid.")
	_expect(!_movement.isValidTarget(_player), "The player card must not target itself.")

	var unplacedCard := _createCard.createCard("M_0002")
	_fixtureRoot.add_child(unplacedCard)
	unplacedCard.setCardState(CardState.State.IN_SLOT)
	_expect(!_movement.isValidTarget(unplacedCard), "A card outside the slot grid must be invalid.")

	_game.setState(GameController.GameState.COMBAT)
	_expect(!_movement.isValidTarget(_cards[Vector2i(1, 0)]), "Targets must be invalid outside PLAYER_READY.")
	_game.setState(GameController.GameState.PLAYER_READY)


func _testInvalidClicksDoNothing() -> void:
	var initialCycle := _game.playerCycleNumber
	var initialRequestCount := _combatRequests.size()
	GlobalSignalBus.emitCardPressed(_cards[Vector2i(0, 0)])
	_expect(_combatRequests.size() == initialRequestCount, "A diagonal click must not request combat.")
	_expect(_game.state == GameController.GameState.PLAYER_READY, "An invalid click must leave the game ready.")
	_expect(!InputManager.inputLocked, "An invalid click must leave input unlocked.")
	_expect(_game.playerCycleNumber == initialCycle, "An invalid click must not change the cycle number.")


func _testValidClickCreatesOneImmutableRequest() -> void:
	var defender: Card = _cards[Vector2i(1, 0)]
	var playerSlot := _grid.getSlotAt(Vector2i(1, 1))
	var targetSlot := _grid.getSlotAt(Vector2i(1, 0))
	var playerHealth := _player.health
	var defenderHealth := defender.health
	var cycle := _game.playerCycleNumber

	GlobalSignalBus.emitCardPressed(defender)
	_expect(_combatRequests.size() == 1, "A valid click must emit exactly one combat request.")
	_expect(_game.state == GameController.GameState.COMBAT, "A valid click must finish the handoff in COMBAT.")
	_expect(InputManager.inputLocked, "A valid click must lock input.")
	_expect(_game.playerCycleNumber == cycle, "Requesting combat must not advance the player cycle.")
	_expect(playerSlot.currentCard == _player, "Story 12 must not move the player card.")
	_expect(targetSlot.currentCard == defender, "Story 12 must not move or remove the defender.")
	_expect(_player.health == playerHealth, "Story 12 must not change player health.")
	_expect(defender.health == defenderHealth, "Story 12 must not change defender health.")

	if _combatRequests.size() == 1:
		var request := _combatRequests[0]
		_expect(request[0] == _player, "The request must identify the player as attacker.")
		_expect(request[1] == defender, "The request must identify the clicked defender.")
		_expect(request[2] == playerSlot, "The request must include the original player slot.")
		_expect(request[3] == targetSlot, "The request must include the target slot.")
		_expect(request[4] == cycle, "The request must include the current cycle number.")

	GlobalSignalBus.emitCardPressed(_cards[Vector2i(2, 1)])
	_expect(_combatRequests.size() == 1, "Further clicks while in COMBAT must not emit duplicate requests.")


func _onPlayerCombatRequested(player, defender, playerSlot, targetSlot, cycleNumber) -> void:
	_combatRequests.append([player, defender, playerSlot, targetSlot, cycleNumber])


func _cleanup() -> void:
	InputManager.lockInput()
	if is_instance_valid(_fixtureRoot):
		_fixtureRoot.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
