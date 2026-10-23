extends Node

const VALID_SCRIPT := "res://src/main/effects/handlers/gain_health_on_play.gd"
const INVALID_TYPE_SCRIPT := "res://tests/fixtures/not_card_effect.gd"
const REMOVAL_SCRIPT := "res://tests/fixtures/removal_recorder_effect.gd"
const RemovalRecorder := preload("res://tests/fixtures/removal_recorder_effect.gd")

var _createdCards: Array[Card] = []
var _originalEffectData: Dictionary
var _passed := 0
var _failures := 0


func _ready() -> void:
	_originalEffectData = EffectLibrary.effectDataById.duplicate()
	await _runTest(_testOnPlayHealthGainUsesModifyStats)
	await _runTest(_testOnlyPlayedCardReacts)
	await _runTest(_testCardWithoutEffectsDoesNothing)
	await _runTest(_testEmptyScriptPathIsSkipped)
	await _runTest(_testWrongScriptTypeIsSkipped)
	await _runTest(_testNonPositiveAmountQueuesNothing)
	await _runTest(_testNonRevealDoesNotActivateCard)
	await _runTest(_testRemoveDeactivatesEffects)
	await _runTest(_testRemovalEventArrivesBeforeDeactivation)
	await _runTest(_testReactivationDoesNotDuplicateEffects)
	await _runTest(_testBrokenEffectDoesNotBlockValidEffect)
	await _runTest(_testStewFeindParameters)
	await _runTest(_testStewFeindReactsToPlayAndRemoval)
	await _runTest(_testStewFeindIgnoresOwnRemoval)
	await _runTest(_testStewFeindWithRealRemoval)
	
	EffectLibrary.effectDataById = _originalEffectData
	if _failures > 0:
		push_error("FAIL: EffectProcessor tests (%s failures)" % _failures)
		get_tree().quit(1)
		return
	print("PASS: EffectProcessor tests (%s passed)" % _passed)
	get_tree().quit(0)
	

func _runTest(testMethod: Callable) -> void:
	await _beforeEach()
	await testMethod.call()
	_passed += 1
	await _afterEach()
	

func _beforeEach() -> void:
	await _waitForProcessor()
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	RemovalRecorder.reset()
	EffectLibrary.effectDataById = _originalEffectData.duplicate()
	

func _afterEach() -> void:
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	for card in _createdCards:
		if is_instance_valid(card):
			card.queue_free()
	_createdCards.clear()
	await get_tree().process_frame
	

func _testOnPlayHealthGainUsesModifyStats() -> void:
	var goatman := _createCard("M_0002")
	var startingHealth := goatman.health
	var queuedActions: Array[GameAction] = []
	var recordAction = func(action: GameAction) -> void:
		queuedActions.append(action)
	GlobalSignalBus.actionEnqueued.connect(recordAction)
	
	_emitPlayed(goatman)
	await _waitForProcessor()
	GlobalSignalBus.actionEnqueued.disconnect(recordAction)
	
	_expect(goatman.health == startingHealth + 2, "Goatman should gain exactly 2 health.")
	_expect(queuedActions.size() == 1, "The effect should queue exactly one action.")
	_expect(queuedActions[0].type == ActionType.MODIFY_STATS, "The effect must queue MODIFY_STATS.")
	_expect(queuedActions[0].target == goatman, "The queued action must target Goatman.")
	var payload = queuedActions[0].payload as ModifyStatsPayload
	_expect(payload.stat == "health", "The action must modify health.")
	_expect(payload.amount == 2, "The action amount must be 2.")
	

func _testOnlyPlayedCardReacts() -> void:
	var firstGoatman := _createCard("M_0002")
	var secondGoatman := _createCard("M_0002")
	_emitPlayed(secondGoatman)
	await _waitForProcessor()
	var secondHealthAfterPlay := secondGoatman.health
	
	_emitPlayed(firstGoatman)
	await _waitForProcessor()
	_expect(firstGoatman.health == firstGoatman.data.baseHealth + 2, "The played Goatman should react.")
	_expect(secondGoatman.health == secondHealthAfterPlay, "Another Goatman must not react.")
	

func _testCardWithoutEffectsDoesNothing() -> void:
	var knight := _createCard("M_0001")
	var startingHealth := knight.health
	_emitPlayed(knight)
	await _waitForProcessor()
	_expect(knight.health == startingHealth, "A card without effects must not gain health.")
	_expect(!EffectProcessor.activeEffectsByCard.has(knight), "A card without effects must not retain instances.")
	

func _testEmptyScriptPathIsSkipped() -> void:
	var card := _createCardWithEffects(["empty_script"])
	EffectLibrary.effectDataById = {"empty_script": _makeEffectData("empty_script", "", 2)}
	_emitPlayed(card)
	await _waitForProcessor()
	_expect(card.health == card.data.baseHealth, "An empty script path must do nothing.")
	_expect(!EffectProcessor.activeEffectsByCard.has(card), "An empty path must not retain an instance.")
	

func _testWrongScriptTypeIsSkipped() -> void:
	var card := _createCardWithEffects(["wrong_type"])
	EffectLibrary.effectDataById = {
		"wrong_type": _makeEffectData("wrong_type", INVALID_TYPE_SCRIPT, 2)
	}
	_emitPlayed(card)
	await _waitForProcessor()
	_expect(card.health == card.data.baseHealth, "A wrong script type must do nothing.")
	_expect(!EffectProcessor.activeEffectsByCard.has(card), "A wrong script type must not be retained.")
	

func _testNonPositiveAmountQueuesNothing() -> void:
	var card := _createCardWithEffects(["zero_gain"])
	EffectLibrary.effectDataById = {
		"zero_gain": _makeEffectData("zero_gain", VALID_SCRIPT, 0)
	}
	_emitPlayed(card)
	await _waitForProcessor()
	_expect(card.health == card.data.baseHealth, "A non-positive amount must do nothing.")
	_expect(!ActionQueue.queueHasActions(), "A non-positive amount must queue nothing.")
	

func _testNonRevealDoesNotActivateCard() -> void:
	var goatman := _createCard("M_0002")
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.MODIFY_STATS, goatman, goatman, ModifyStatsPayload.create("health", 1, "test")),
		null
	)
	await get_tree().process_frame
	_expect(goatman.health == goatman.data.baseHealth, "A non-reveal event must do nothing.")
	_expect(!EffectProcessor.activeEffectsByCard.has(goatman), "A non-reveal event must not activate effects.")
	

func _testRemoveDeactivatesEffects() -> void:
	var goatman := _createCard("M_0002")
	_emitPlayed(goatman)
	await _waitForProcessor()
	_expect(EffectProcessor.activeEffectsByCard.has(goatman), "Reveal should activate Goatman's effect.")
	
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.REMOVE_CARD, null, goatman, RemoveCardPayload.create(0, "test")),
		null
	)
	_expect(!EffectProcessor.activeEffectsByCard.has(goatman), "Remove must deactivate the card's effects.")
	

func _testRemovalEventArrivesBeforeDeactivation() -> void:
	var target := _createCardWithEffects(["record_removal"])
	var attacker := _createCard("M_0003")
	EffectLibrary.effectDataById = {
		"record_removal": _makeEffectData("record_removal", REMOVAL_SCRIPT, 1)
	}
	_emitPlayed(target)
	_expect(EffectProcessor.activeEffectsByCard.has(target), "The recorder effect should activate.")
	
	var entry := GraveyardEntry.new()
	entry.cardId = target.data.id
	GlobalSignalBus.emitActionResolved(
		ActionType.make(
			ActionType.REMOVE_CARD,
			attacker,
			target,
			RemoveCardPayload.create(0, "combat")
		),
		entry
	)
	
	_expect(
		RemovalRecorder.callOrder == ["event", "deactivated"],
		"The leaving card must receive its event before deactivation."
	)
	_expect(RemovalRecorder.observedSource == attacker, "The removal event should expose its source.")
	_expect(RemovalRecorder.observedCause == "combat", "The removal event should expose its cause.")
	_expect(RemovalRecorder.observedResult == entry, "The removal event should expose its graveyard entry.")
	_expect(!EffectProcessor.activeEffectsByCard.has(target), "The leaving card must be deactivated afterward.")
	

func _testReactivationDoesNotDuplicateEffects() -> void:
	var goatman := _createCard("M_0002")
	_emitPlayed(goatman)
	await _waitForProcessor()
	_emitPlayed(goatman)
	await _waitForProcessor()
	_expect(EffectProcessor.activeEffectsByCard[goatman].size() == 1, "Reactivation must not duplicate instances.")
	_expect(goatman.health == goatman.data.baseHealth + 4, "Two plays should trigger exactly twice.")
	

func _testBrokenEffectDoesNotBlockValidEffect() -> void:
	var card := _createCardWithEffects(["broken", "valid"])
	EffectLibrary.effectDataById = {
		"broken": _makeEffectData("broken", INVALID_TYPE_SCRIPT, 2),
		"valid": _makeEffectData("valid", VALID_SCRIPT, 2)
	}
	_emitPlayed(card)
	await _waitForProcessor()
	_expect(card.health == card.data.baseHealth + 2, "A broken effect must not block a valid effect.")
	_expect(EffectProcessor.activeEffectsByCard[card].size() == 1, "Only the valid instance should be retained.")
	

func _testStewFeindParameters() -> void:
	var definition = EffectLibrary.getEffectData("stew_feind")
	_expect(definition != null, "Production Stew Feind must load.")
	var parameters = definition.parameters as StewFeindParameters
	_expect(parameters != null, "Production parameters must parse.")
	if parameters != null:
		_expect(parameters.watchedCardId == "M_0007" and parameters.amount == 1,
			"Stew Feind must watch Stew with magnitude one.")
	for invalidAmount in [null, "1", 1.5, 0, -1]:
		_expect(StewFeindParameters.fromDictionary({
			"watched_card_id": "M_0007", "amount": invalidAmount
		}) == null, "Invalid amounts must be rejected.")
	for invalidId in [null, 7, "", "   "]:
		_expect(StewFeindParameters.fromDictionary({
			"watched_card_id": invalidId, "amount": 1
		}) == null, "Invalid watched IDs must be rejected.")
	_expect(StewFeindParameters.fromDictionary({
		"watched_card_id": "M_0007", "amount": 1.0
	}) != null, "Integral JSON floats must be accepted.")


func _testStewFeindReactsToPlayAndRemoval() -> void:
	var stew := _createCard("M_0007")
	_emitPlayed(stew)
	var first := _createCardWithEffects(["stew_feind"])
	var second := _createCardWithEffects(["stew_feind"])
	_emitPlayed(first)
	_emitPlayed(second)
	await _waitForProcessor()
	var startingHealth := first.health
	_expect(first.health == first.data.baseHealth, "Existing Stews must not award a bonus.")
	var notifications: Array[Card] = []
	var recordTrigger = func(source: Card, _effect: EffectData) -> void:
		notifications.append(source)
	GlobalSignalBus.cardEffectTriggered.connect(recordTrigger)

	# A failed removal, deletion and unrelated play must not execute the effect.
	var removeAction = ActionType.make(ActionType.REMOVE_CARD, null, stew,
		RemoveCardPayload.create(0, "test"))
	GlobalSignalBus.emitActionResolved(removeAction, null)
	var entry := GraveyardEntry.new()
	entry.cardId = "M_0007"
	entry.instanceId = stew.instanceId
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.DELETE_CARD, null, stew), true)
	_emitPlayed(_createCard("M_0003"))
	await _waitForProcessor()
	_expect(first.health == startingHealth and notifications.is_empty(),
		"Failed removal, deletion and unrelated cards must not trigger.")

	# Destruction counts even though the host never received an earlier play bonus.
	GlobalSignalBus.emitActionResolved(removeAction, entry)
	await _waitForProcessor()
	_expect(first.health == startingHealth - 1 and second.health == startingHealth - 1,
		"Successful Stew removal must subtract one from each host.")
	_expect(notifications.size() == 2, "Removal must report once per host.")

	var newStew := _createCard("M_0007")
	_emitPlayed(newStew)
	_emitPlayed(_createCard("M_0007"))
	await _waitForProcessor()
	_expect(first.health == startingHealth + 1 and second.health == startingHealth + 1,
		"Two Stew reveals must each add one without resolution recursion.")
	_expect(notifications.count(first) == 3 and notifications.count(second) == 3,
		"Every execution must report once, including rapid repeats.")

	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.REMOVE_CARD, null, first, RemoveCardPayload.create(0, "test")),
		null)
	_emitPlayed(_createCard("M_0007"))
	await _waitForProcessor()
	_expect(first.health == startingHealth + 1 and second.health == startingHealth + 2,
		"Deactivated hosts must stop reacting while other hosts continue.")
	GlobalSignalBus.cardEffectTriggered.disconnect(recordTrigger)


func _testStewFeindIgnoresOwnRemoval() -> void:
	var host := _createCardWithEffects(["stew_feind"])
	host.data.id = "M_0007"
	_emitPlayed(host)
	await _waitForProcessor()
	var startingHealth := host.health
	var entry := GraveyardEntry.new()
	entry.cardId = host.data.id
	entry.instanceId = host.instanceId
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.REMOVE_CARD, null, host, RemoveCardPayload.create(0, "test")),
		entry)
	_expect(!ActionQueue.queueHasActions(), "A host must not penalize its own removal.")
	_expect(host.health == startingHealth, "Self-removal must not change host health.")


func _testStewFeindWithRealRemoval() -> void:
	var fixture := Node.new()
	var grid: SlotGrid = preload("res://src/main/board/slot_grid/slot_grid.tscn").instantiate()
	grid.name = "SlotGrid"
	var board := BoardController.new()
	board.slotGridPath = NodePath("../SlotGrid")
	fixture.add_child(grid)
	fixture.add_child(board)
	add_child(fixture)
	await get_tree().process_frame
	var host := _createCardWithEffects(["stew_feind"])
	var stew := _createCard("M_0007")
	_expect(board.placeCard(host, grid.getSlotAt(Vector2i(0, 0))), "Place the effect host.")
	_expect(board.placeCard(stew, grid.getSlotAt(Vector2i(1, 0))), "Place Stew before destruction.")
	_emitPlayed(host)
	_emitPlayed(stew)
	await _waitForProcessor()
	_expect(host.health == host.data.baseHealth + 1, "Stew play must add one health.")
	var action = ActionType.make(ActionType.REMOVE_CARD, host, stew,
		RemoveCardPayload.create(host.instanceId, "test"))
	ActionQueue.enqueueAction(action)
	var result = await ActionQueue.waitForActionToResolve(action)
	await _waitForProcessor()
	_expect(result is GraveyardEntry, "Real Stew removal must succeed.")
	_expect(host.health == host.data.baseHealth, "Real destruction must subtract one health.")
	await get_tree().process_frame
	_expect(!is_instance_valid(stew), "Destroyed Stew must be freed safely.")
	Graveyard.reset()
	BoardHistory.reset()
	fixture.queue_free()
	await get_tree().process_frame


func _emitPlayed(card: Card) -> void:
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.REVEAL_CARD, null, null, RevealCardPayload.create("test")),
		card
	)
	

func _createCard(cardId: String) -> Card:
	var card := CreateCard.new().createCard(cardId)
	_expect(card != null, "Test setup could not create card %s." % cardId)
	add_child(card)
	_createdCards.append(card)
	return card
	

func _createCardWithEffects(effectIds: Array[String]) -> Card:
	var card := _createCard("M_0001")
	card.data = card.data.duplicate(true)
	card.data.effects = effectIds
	return card
	

func _makeEffectData(effectId: String, scriptPath: String, amount: int) -> EffectData:
	return EffectDataFactory.fromDictionary({
		"id": effectId,
		"name": effectId,
		"trigger": "on_play",
		"operation": "gain_health",
		"target": "self",
		"script_path": scriptPath,
		"parameters": {"amount": amount}
	})
	

func _waitForProcessor(maxFrames := 120) -> void:
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() && !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	_expect(false, "ActionProcessor did not become idle.")
	

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)
