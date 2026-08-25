extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")

var _results: Array[CombatResult] = []
var _enqueuedTypes: Array[String] = []
var _passed := 0
var _failures := 0


func _ready() -> void:
	GlobalSignalBus.combatEnded.connect(_onCombatEnded)
	GlobalSignalBus.actionEnqueued.connect(_onActionEnqueued)
	_testContextSnapshotsAndResultContract()
	await _testRequestValidation()
	await _testBothSurvive()
	await _testCleanVictory()
	await _testPlayerOnlyDeath()
	await _testMutualDeathAndDuplicateGuard()
	await _testRemovalFailureReturnsTypedFailure()
	if _failures > 0:
		push_error("FAIL: Story 13 combat resolver tests (%s failures, %s passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: Story 13 combat resolver tests (%s passed)" % _passed)
	get_tree().quit(0)


func _testContextSnapshotsAndResultContract() -> void:
	var player := _makeBareCard("player", 5, 4)
	var defender := _makeBareCard("defender", 5, 3)
	var fromSlot := CardSlot.new()
	var toSlot := CardSlot.new()
	var context := CombatContext.create(9, player, defender, fromSlot, toSlot)
	player.attack = 99
	defender.attack = 99
	_expect(context.attackerDamage == 4 and context.retaliationDamage == 3, "CombatContext must snapshot both attack values.")
	_expect(context.attackerInstanceId == player.instanceId and context.defenderInstanceId == defender.instanceId, "CombatContext must snapshot stable identities.")
	var failed := CombatResult.failed(context, "rejected")
	_expect(failed is CombatResult and !failed.succeeded and failed.context == context, "Failed combat must use the typed failure contract.")
	_expect(!("revealedCard" in failed) and !("journeyDeck" in failed), "CombatResult must not own refill or Journey Deck outcomes.")
	player.free()
	defender.free()
	fromSlot.free()
	toSlot.free()


func _testRequestValidation() -> void:
	var missing := CombatResolver.new()
	_expect(!missing._isValidRequest(null, null, null, null, 0), "Missing resolver references must reject combat safely.")
	missing.free()

	var fixture := await _createFixture(5, 1, 5, 1)
	var resolver: CombatResolver = fixture.resolver
	var game: GameController = fixture.game
	var player: Card = fixture.player
	var defender: Card = fixture.defender
	var playerSlot: CardSlot = fixture.player_slot
	var targetSlot: CardSlot = fixture.target_slot
	game.state = GameController.GameState.PLAYER_READY
	_expect(!resolver._isValidRequest(player, defender, playerSlot, targetSlot, 7), "Requests outside COMBAT must be rejected.")
	game.state = GameController.GameState.COMBAT
	_expect(!resolver._isValidRequest(player, defender, playerSlot, targetSlot, 6), "Stale cycle numbers must be rejected.")
	_expect(!resolver._isValidRequest(defender, player, targetSlot, playerSlot, 7), "A stale player identity must be rejected.")
	_expect(!resolver._isValidRequest(player, defender, targetSlot, playerSlot, 7), "Stale slot/card pairings must be rejected.")
	var diagonal: CardSlot = fixture.grid.getSlotAt(Vector2i(0, 0))
	_expect(!resolver._isValidRequest(player, diagonal.currentCard, playerSlot, diagonal, 7), "Non-cardinal requests must be rejected.")
	await _destroyFixture(fixture)


func _testBothSurvive() -> void:
	var fixture := await _createFixture(5, 2, 5, 2)
	var result := await _resolveFixture(fixture)
	_expect(result != null and result.succeeded, "Valid non-lethal combat must succeed.")
	_expect(result.defenderDamage is DamageResult and result.playerDamage is DamageResult, "Both attacks must return DamageResult objects.")
	_expect(fixture.defender.health == 3 and fixture.player.health == 3, "Both snapshotted attacks must resolve.")
	_expect(!result.defenderDefeated and !result.playerDefeated, "Survivors must not be marked defeated.")
	_expect(!result.playerMoved and fixture.player_slot.currentCard == fixture.player, "The player must not move when the defender survives.")
	_expect(_enqueuedTypes == [ActionType.DEAL_DAMAGE, ActionType.DEAL_DAMAGE], "Non-lethal combat must enqueue only its two damage actions.")
	await _destroyFixture(fixture)


func _testCleanVictory() -> void:
	var fixture := await _createFixture(5, 5, 5, 1)
	var attackerId: int = fixture.player.instanceId
	var result := await _resolveFixture(fixture)
	_expect(result != null and result.succeeded and result.defenderDefeated, "Equal attack and health must defeat the defender.")
	_expect(result.defenderGraveyardEntry != null, "A defeated defender must be removed through Graveyard.")
	_expect(result.defenderGraveyardEntry.sourceInstanceId == attackerId, "Defender removal must retain player attribution.")
	_expect(result.playerMoved and fixture.target_slot.currentCard == fixture.player, "A clean victory must move the surviving player.")
	_expect(fixture.player_slot.currentCard == null, "Combat movement must vacate the previous player slot.")
	_expect(ActionType.REVEAL_CARD not in _enqueuedTypes, "Combat must never enqueue REVEAL_CARD.")
	await _destroyFixture(fixture)


func _testPlayerOnlyDeath() -> void:
	var fixture := await _createFixture(3, 1, 5, 3)
	var defenderId: int = fixture.defender.instanceId
	var result := await _resolveFixture(fixture)
	_expect(result != null and result.succeeded and result.playerDefeated and !result.defenderDefeated, "Player-only lethal retaliation must be represented.")
	_expect(result.playerGraveyardEntry != null and result.playerGraveyardEntry.sourceInstanceId == defenderId, "Player removal must retain defender attribution.")
	_expect(!result.playerMoved and fixture.target_slot.currentCard == fixture.defender, "Player death must cause no combat movement.")
	await _destroyFixture(fixture)


func _testMutualDeathAndDuplicateGuard() -> void:
	var fixture := await _createFixture(3, 3, 3, 3)
	var attackerId: int = fixture.player.instanceId
	var defenderId: int = fixture.defender.instanceId
	_results.clear()
	_enqueuedTypes.clear()
	fixture.resolver._onPlayerCombatRequested(fixture.player, fixture.defender, fixture.player_slot, fixture.target_slot, 7)
	fixture.resolver._onPlayerCombatRequested(fixture.player, fixture.defender, fixture.player_slot, fixture.target_slot, 7)
	await _waitForCombat(fixture.resolver)
	var result: CombatResult = _results[0] if !_results.is_empty() else null
	_expect(_results.size() == 1, "Duplicate requests while resolving must emit exactly one CombatResult.")
	_expect(result != null and result.succeeded and result.playerDefeated and result.defenderDefeated, "Mutual lethal damage must defeat both cards.")
	_expect(result.defenderGraveyardEntry != null and result.defenderGraveyardEntry.sourceInstanceId == attackerId, "Mutual death must preserve defender-removal attribution.")
	_expect(result.playerGraveyardEntry != null and result.playerGraveyardEntry.sourceInstanceId == defenderId, "Mutual death must preserve player-removal attribution after the defender is freed.")
	_expect(!result.playerMoved, "Mutual death must never move the player.")
	await _destroyFixture(fixture)


func _testRemovalFailureReturnsTypedFailure() -> void:
	var fixture := await _createFixture(5, 5, 5, 1)
	fixture.board.remove_from_group("boardController")
	var result := await _resolveFixture(fixture)
	_expect(result != null and !result.succeeded and !result.failureReason.is_empty(), "A failed lethal removal must emit a typed failed CombatResult.")
	_expect(_results.size() == 1, "Failed combat must emit exactly one result.")
	await _destroyFixture(fixture)


func _createFixture(playerHealth: int, playerAttack: int, defenderHealth: int, defenderAttack: int) -> Dictionary:
	await _resetSystems()
	var root := Node.new()
	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var board := BoardController.new()
	board.name = "BoardController"
	board.slotGridPath = NodePath("../SlotGrid")
	var resolver := CombatResolver.new()
	var game := GameController.new()
	root.add_child(grid)
	root.add_child(board)
	root.add_child(resolver)
	add_child(root)
	await get_tree().process_frame
	resolver.gameController = game
	resolver.boardController = board
	resolver.slotGrid = grid
	var player := CreateCard.new().createCard("C_0000")
	var defender := CreateCard.new().createCard("M_0001")
	player.health = playerHealth
	player.attack = playerAttack
	defender.health = defenderHealth
	defender.attack = defenderAttack
	var playerSlot: CardSlot = grid.getSlotAt(Vector2i(1, 1))
	var targetSlot: CardSlot = grid.getSlotAt(Vector2i(1, 0))
	_expect(board.placeCard(player, playerSlot), "Fixture player must be placed.")
	_expect(board.placeCard(defender, targetSlot), "Fixture defender must be placed.")
	var diagonal: CardSlot = grid.getSlotAt(Vector2i(0, 0))
	_expect(board.placeCard(CreateCard.new().createCard("M_0002"), diagonal), "Fixture diagonal card must be placed.")
	game.playerCard = player
	game.playerCycleNumber = 7
	game.state = GameController.GameState.COMBAT
	return {
		"root": root, "grid": grid, "board": board, "resolver": resolver, "game": game,
		"player": player, "defender": defender, "player_slot": playerSlot, "target_slot": targetSlot,
	}


func _resolveFixture(fixture: Dictionary) -> CombatResult:
	_results.clear()
	_enqueuedTypes.clear()
	fixture.resolver._onPlayerCombatRequested(fixture.player, fixture.defender, fixture.player_slot, fixture.target_slot, 7)
	await _waitForCombat(fixture.resolver)
	return _results[0] if !_results.is_empty() else null


func _waitForCombat(resolver: CombatResolver, maxFrames := 240) -> void:
	for _frame in range(maxFrames):
		if !_results.is_empty() and !resolver.isResolving:
			return
		await get_tree().process_frame
	_expect(false, "Combat did not settle within %s frames." % maxFrames)


func _destroyFixture(fixture: Dictionary) -> void:
	await _resetSystems()
	fixture.root.queue_free()
	fixture.game.free()
	await get_tree().process_frame


func _resetSystems() -> void:
	for _frame in range(240):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			break
		await get_tree().process_frame
	ActionQueue.clearQueue()
	Graveyard.reset()
	BoardHistory.reset()
	_results.clear()
	_enqueuedTypes.clear()


func _makeBareCard(cardId: String, health: int, attack: int) -> Card:
	var card := Card.new()
	var data := CardData.new()
	data.id = cardId
	data.baseHealth = health
	data.baseAttack = attack
	card.data = data
	card.health = health
	card.attack = attack
	card.instanceId = randi_range(1, 1000000)
	return card


func _onCombatEnded(result: CombatResult) -> void:
	_results.append(result)


func _onActionEnqueued(action: Dictionary) -> void:
	_enqueuedTypes.append(action.type)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
