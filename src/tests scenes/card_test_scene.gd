extends Control

const GAME_OVER_OVERLAY_SCENE := preload("res://src/main/ui/overlays/game_over_overlay.tscn")

@export_file("*.tscn") var postRunScenePath: String

#added for testing: F6 opens this encounter without requiring a card landing.
@export var encounterPreviewId: String = "roadside_corpse"

@onready var encounterModal: EncounterModal = $CanvasLayerEncounter/EncounterModal
@onready var cardsRoot: Control = $CanvasLayer/CardsRoot
@onready var canvasLayer: CanvasLayer = $CanvasLayer
@onready var journeyDeck: JourneyDeck = $JourneyDeck
@onready var slotGrid: SlotGrid = $SlotGrid
@onready var boardController: BoardController = $BoardController
@onready var gameController: GameController = $GameController
@onready var playerMovementController: PlayerMovementController = $PlayerMovementController

@onready var addPlayerButton: Button = $CanvasLayer/Controls/AddPlayerButton
@onready var addKnightButton: Button = $CanvasLayer/Controls/AddKnightButton
@onready var addGoatmanButton: Button = $CanvasLayer/Controls/AddGoatmanButton
@onready var addStewButton: Button = $CanvasLayer/Controls/AddStewButton
@onready var addRemainsButton: Button = $CanvasLayer/Controls/AddRemainsButton
@onready var clearCardsButton: Button = $CanvasLayer/Controls/ClearCardsButton
@onready var removeBoardCardButton: Button = $CanvasLayer/Controls/RemoveBoardCardButton
@onready var deleteGraveyardCardButton: Button = $CanvasLayer/Controls/DeleteGraveyardCardButton
@onready var reviveGraveyardCardButton: Button = $CanvasLayer/Controls/ReviveGraveyardCardButton
@onready var graveyardList: RichTextLabel = %GraveyardList
@onready var boardHistoryList: RichTextLabel = %BoardHistoryList
@onready var playerCycleStatus: RichTextLabel = %PlayerCycleStatus
@onready var advancePlayerCycleButton: Button = %AdvancePlayerCycleButton
@onready var movementStatus: RichTextLabel = %MovementStatus

var createCard := CreateCard.new()
var gameOverOverlay

var cards: Array[Card] = []
var activeCardIndex := -1

@export var debug_stat_cycle := true
@export var debug_interval_seconds := 1.0
@export var debug_delta := 2

var debugTimer: Timer
var debugPhase := 0

@export var debug_state_cycle := false
@export var debug_state_interval_seconds := 2.0

var debugStateTimer: Timer
var debugStatePhase := 0

const CARD_START_POS := Vector2(200, 320)
const CARD_SPACING_X := 180


func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
	GlobalSignalBus.cardFlipped.connect(_onCardFlipped)
	GlobalSignalBus.cardStateChanged.connect(_onCardStateChanged)
	GlobalSignalBus.actionResolved.connect(_onLifecycleActionResolved)
	GlobalSignalBus.gameOverRequested.connect(_onGameOverRequested)
	GlobalSignalBus.gameOverContinueRequested.connect(_onGameOverContinueRequested)
	GlobalSignalBus.encounterOutcomeRequested.connect(_onEncounterOutcomeRequested)
	
	journeyDeck.boardController = boardController
	journeyDeck.slotGrid = slotGrid
	gameController.boardController = boardController
	gameController.slotGrid = slotGrid
	gameController.journeyDeck = journeyDeck
	playerMovementController.gameController = gameController
	playerMovementController.boardController = boardController
	playerMovementController.slotGrid = slotGrid
	_configureDebugInput()
	_connectButtons()
	GlobalSignalBus.gameStateChanged.connect(_onGameStateChanged)
	GlobalSignalBus.playerCombatRequested.connect(_onPlayerCombatRequested)
	_refreshLifecycleDebugPanel()
	_refreshPlayerCyclePanel()
	_setEncounterPreviewControlsEnabled(false)
	await gameController.startRun()
	_refreshPlayerCyclePanel()
	
	if debug_stat_cycle:
		_startDebugStatCycle()
	
	if debug_state_cycle:
		_startDebugStateCycle()
	

func _exit_tree() -> void:
	_clearDebugInput()
	if GlobalSignalBus.gameOverRequested.is_connected(_onGameOverRequested):
		GlobalSignalBus.gameOverRequested.disconnect(_onGameOverRequested)
	if GlobalSignalBus.gameOverContinueRequested.is_connected(_onGameOverContinueRequested):
		GlobalSignalBus.gameOverContinueRequested.disconnect(_onGameOverContinueRequested)


func _configureDebugInput() -> void:
	InputManager.debugDraggingEnabled = true
	InputManager.debugBoardController = boardController
	journeyDeck.deckImage.gui_input.connect(_onDebugDeckInput)


func _clearDebugInput() -> void:
	if InputManager.debugBoardController == boardController:
		InputManager.lockInput()
		InputManager.debugDraggingEnabled = false
		InputManager.debugBoardController = null
	if is_instance_valid(journeyDeck) and journeyDeck.deckImage.gui_input.is_connected(_onDebugDeckInput):
		journeyDeck.deckImage.gui_input.disconnect(_onDebugDeckInput)


func _onDebugDeckInput(event: InputEvent) -> void:
	if !(event is InputEventMouseButton):
		return
	if !event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if !InputManager.isGameplayInputAllowed():
		return
	if gameController.state != GameController.GameState.PLAYER_READY:
		return
	journeyDeck.queueRevealToNextEmptySlot()


func _onGameOverRequested() -> void:
	encounterModal.close()
	if is_instance_valid(gameOverOverlay):
		return

	gameOverOverlay = GAME_OVER_OVERLAY_SCENE.instantiate()
	canvasLayer.add_child(gameOverOverlay)


#added for testing: preview only between turns; this does not implement landing encounters.
func _openEncounterPreview() -> void:
	if encounterModal.visible or gameController.state != GameController.GameState.PLAYER_READY:
		return
	if !InputManager.isGameplayInputAllowed() or ScreenLoader.isCurrentlyLoadingScene():
		return
	if !encounterModal.present(EncounterLibrary.getEncounterData(encounterPreviewId)):
		return
	InputManager.lockInput()
	_setEncounterPreviewControlsEnabled(false)
	_refreshPlayerCyclePanel()


func _onEncounterOutcomeRequested(encounterId: StringName, outcome: EncounterDefinition.Outcome) -> void:
	if gameController.state != GameController.GameState.PLAYER_READY:
		return
	if !encounterModal.visible or encounterModal.definition == null or get_tree().paused:
		return
	if encounterId != encounterModal.definition.id:
		return
	if outcome not in [EncounterDefinition.Outcome.CONTINUE, EncounterDefinition.Outcome.LEAVE]:
		return
	if outcome == EncounterDefinition.Outcome.LEAVE and encounterModal.definition.encounterType != EncounterDefinition.Type.CONTINUE_OR_LEAVE:
		return
	print("Encounter preview: ", encounterId, " outcome: ", EncounterDefinition.Outcome.keys()[outcome])
	encounterModal.close()
	_setEncounterPreviewControlsEnabled(true)
	if gameController.state == GameController.GameState.PLAYER_READY:
		InputManager.unlockInput()
	_refreshPlayerCyclePanel()


func _setEncounterPreviewControlsEnabled(enabled: bool) -> void:
	for button: Button in $CanvasLayer/Controls.get_children():
		button.disabled = !enabled
	advancePlayerCycleButton.disabled = !enabled


func _onGameOverContinueRequested() -> void:
	if !is_instance_valid(gameOverOverlay) or ScreenLoader.isCurrentlyLoadingScene():
		return

	await ScreenLoader.loadScene(postRunScenePath)


func _onLifecycleActionResolved(action: GameAction, _result: Variant) -> void:
	if action.type not in [
		ActionType.REMOVE_CARD,
		ActionType.DELETE_CARD,
		ActionType.REVIVE_CARD
	]:
		return
	
	_refreshLifecycleDebugPanel()
	

func _refreshLifecycleDebugPanel() -> void:
	var graveyardLines: Array[String] = []
	for entry in Graveyard.getEntries():
		graveyardLines.append(
			"- #%s %s [%s] cause=%s" % [
				entry.entryId,
				_getCardDisplayName(entry.cardId),
				entry.cardId,
				entry.cause
			]
		)
	graveyardList.text = (
		"(empty)" if graveyardLines.is_empty() else "\n".join(graveyardLines)
	)
	
	var historyLines: Array[String] = []
	for event in BoardHistory.getEvents():
		var cardId: String = event.cardId if !event.cardId.is_empty() else "unknown"
		var eventDictionary = event.toDictionary()
		var details: Array[String] = []
		if eventDictionary.has("cause") and !str(eventDictionary["cause"]).is_empty():
			details.append("cause=%s" % eventDictionary["cause"])
		if eventDictionary.has("from"):
			details.append("from=%s" % eventDictionary["from"])
	
		var line := "%s. %s — %s [%s]" % [
			event.sequence,
			event.type.to_upper(),
			_getCardDisplayName(cardId),
			cardId
		]
		if !details.is_empty():
			line += " (%s)" % ", ".join(details)
		historyLines.append(line)
	
	boardHistoryList.text = (
		"(no events)" if historyLines.is_empty() else "\n".join(historyLines)
	)
	

func _getCardDisplayName(cardId: String) -> String:
	if !CardLibrary.hasCardData(cardId):
		return "Unknown card"
	return CardLibrary.getCardData(cardId).name
	

func debug_card_size(label: String, card: Control) -> void:
	print("")
	print("========== ", label, " ==========")
	
	print("parent: ",
		card.get_parent().name if card.get_parent() else "NONE"
	)
	
	print("size: ", card.size)
	print("custom_minimum_size: ", card.custom_minimum_size)
	
	print("position: ", card.position)
	print("global_position: ", card.global_position)
	
	print("scale: ", card.scale)
	print("global_scale: ", card.get_global_transform().get_scale())
	
	print("anchors: ",
		card.anchor_left, ", ",
		card.anchor_top, ", ",
		card.anchor_right, ", ",
		card.anchor_bottom
	)
	
	print("offsets: ",
		card.offset_left, ", ",
		card.offset_top, ", ",
		card.offset_right, ", ",
		card.offset_bottom
	)
	
	print("==================================")
	

func _connectButtons() -> void:
	addPlayerButton.pressed.connect(_onAddPlayerPressed)
	addKnightButton.pressed.connect(_onAddKnightPressed)
	addGoatmanButton.pressed.connect(_onAddGoatmanPressed)
	addStewButton.pressed.connect(_onAddStewPressed)
	addRemainsButton.pressed.connect(_onAddRemainsPressed)
	clearCardsButton.pressed.connect(_onClearCardsPressed)
	removeBoardCardButton.pressed.connect(_onRemoveBoardCardPressed)
	deleteGraveyardCardButton.pressed.connect(_onDeleteGraveyardCardPressed)
	reviveGraveyardCardButton.pressed.connect(_onReviveGraveyardCardPressed)
	advancePlayerCycleButton.pressed.connect(_onAdvancePlayerCyclePressed)
	

func _onGameStateChanged(_previousState: int, newState: int) -> void:
	_setEncounterPreviewControlsEnabled(
		newState == GameController.GameState.PLAYER_READY
	)
	_refreshPlayerCyclePanel()
	

func _onPlayerCombatRequested(
	player: Card,
	defender: Card,
	playerSlot: CardSlot,
	targetSlot: CardSlot,
	cycleNumber: int
) -> void:
	movementStatus.text = "Combat requested: %s -> %s\nSlots: %s -> %s | Cycle: %s" % [
		player.data.name,
		defender.data.name,
		playerSlot.coordinates,
		targetSlot.coordinates,
		cycleNumber
	]
	_refreshPlayerCyclePanel()


func _refreshPlayerCyclePanel() -> void:
	var stateName: String = GameController.GameState.keys()[gameController.state]
	playerCycleStatus.text = "State: %s\nPlayer cycle: %s\nInput: %s" % [
		stateName,
		gameController.playerCycleNumber,
		"LOCKED" if InputManager.inputLocked else "READY"
	]
	advancePlayerCycleButton.text = (
		"Start Run" if gameController.state == GameController.GameState.SETUP
		else "Advance Player Cycle"
	)
	

func _onAdvancePlayerCyclePressed() -> void:
	advancePlayerCycleButton.disabled = true
	match gameController.state:
		GameController.GameState.SETUP:
			await gameController.startRun()
		GameController.GameState.PLAYER_READY:
			gameController.beginPlayerAction()
		GameController.GameState.RESOLVING_MOVE:
			gameController.beginCombat()
		GameController.GameState.COMBAT:
			gameController.beginAfterMovePhase()
		GameController.GameState.AFTER_MOVE:
			gameController.completePlayerCycle()
	_refreshPlayerCyclePanel()
	advancePlayerCycleButton.disabled = false
	

func _onAddPlayerPressed() -> void:
	_addCardById("C_0000")
	

func _onAddKnightPressed() -> void:
	_addCardById("M_0010")
	

func _onAddGoatmanPressed() -> void:
	_addCardById("M_0011")
	

func _onAddStewPressed() -> void:
	_addCardById("M_0007")


func _onAddRemainsPressed() -> void:
	_addCardById("M_0012")
	

func _onClearCardsPressed() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	
	cards.clear()
	activeCardIndex = -1
	
	print("Cleared all test cards")
	

func _onRemoveBoardCardPressed() -> void:
	var occupiedSlots := slotGrid.getOccupiedSlots()
	if occupiedSlots.is_empty():
		print("Manual graveyard test: no board card to remove.")
		return
	
	var card := occupiedSlots[0].currentCard
	var removeAction := ActionType.make(
		ActionType.REMOVE_CARD,
		null,
		card,
		RemoveCardPayload.create(0, "manual_test")
	)
	if !ActionQueue.enqueueAction(removeAction):
		push_warning("Manual graveyard test: REMOVE_CARD was rejected.")
	

func _onDeleteGraveyardCardPressed() -> void:
	var entries := Graveyard.getEntries()
	if entries.is_empty():
		print("Manual graveyard test: the graveyard is empty.")
		return
	
	var deleteAction := ActionType.make(
		ActionType.DELETE_CARD,
		null,
		entries[0]
	)
	if !ActionQueue.enqueueAction(deleteAction):
		push_warning("Manual graveyard test: DELETE_CARD was rejected.")
	

func _onReviveGraveyardCardPressed() -> void:
	var entries := Graveyard.getEntries()
	if entries.is_empty():
		print("Manual graveyard test: the graveyard is empty.")
		return
	
	var emptySlots := slotGrid.getEmptySlots()
	if emptySlots.is_empty():
		print("Manual graveyard test: there is no empty revival slot.")
		return
	
	var reviveAction := ActionType.make(
		ActionType.REVIVE_CARD,
		entries[0],
		emptySlots[0]
	)
	if !ActionQueue.enqueueAction(reviveAction):
		push_warning("Manual graveyard test: REVIVE_CARD was rejected.")
	

func _addCardById(cardId: String) -> void:
	var newCard: Card = createCard.createCard(cardId)
	
	if newCard == null:
		push_error("Failed to create test card for id %s" % cardId)
		return
	
	cardsRoot.add_child(newCard)
	cards.append(newCard)
	
	debug_card_size("AFTER ADD CHILD", newCard)
	
	_layoutCards()
	
	debug_card_size("AFTER LAYOUT", newCard)
	
	activeCardIndex = cards.size() - 1
	_printActiveCard()
	
	if newCard.data != null:
		print(
			"Created card %s | name=%s type=%s hp=%s atk=%s image=%s" %
			[
				newCard.data.id,
				newCard.data.name,
				newCard.data.type,
				str(newCard.health),
				str(newCard.attack),
				newCard.data.imagePath
			]
		)
	
	_applyTestState(CardState.State.ON_BOARD)
	
	await get_tree().process_frame
	
	debug_card_size("AFTER ON_BOARD + 1 FRAME", newCard)
	

func _layoutCards() -> void:
	for i in range(cards.size()):
		var card := cards[i]
	
		if card == null:
			continue
	
		if card.currentState == CardState.State.IN_SLOT:
			continue
	
		card.global_position = CARD_START_POS + Vector2(i * CARD_SPACING_X, 0)
	

func _getActiveCard() -> Card:
	if cards.is_empty():
		return null
	
	if activeCardIndex < 0 or activeCardIndex >= cards.size():
		return null
	
	return cards[activeCardIndex]
	

func _setActiveCard(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	
	activeCardIndex = index
	_printActiveCard()
	

func _printActiveCard() -> void:
	var card := _getActiveCard()
	
	if card == null:
		return
	
	print(
		"Active card -> index=%s id=%s name=%s type=%s" %
		[
			str(activeCardIndex),
			card.data.id,
			card.data.name,
			card.data.type
		]
	)
	

func _startDebugStatCycle() -> void:
	debugTimer = Timer.new()
	debugTimer.wait_time = debug_interval_seconds
	debugTimer.one_shot = false
	debugTimer.autostart = true
	
	add_child(debugTimer)
	
	debugTimer.timeout.connect(_onDebugStatTimeout)
	

func _startDebugStateCycle() -> void:
	debugStateTimer = Timer.new()
	debugStateTimer.wait_time = debug_state_interval_seconds
	debugStateTimer.one_shot = false
	debugStateTimer.autostart = true
	
	add_child(debugStateTimer)
	
	debugStateTimer.timeout.connect(_onDebugStateTimeout)
	

func _onDebugStatTimeout() -> void:
	if !InputManager.isGameplayInputAllowed():
		return
	var card := _getActiveCard()
	
	if card == null or card.data == null:
		return
	
	if card.data.type == "player":
		return
	
	var baseHp := card.data.baseHealth
	var baseAp := card.data.baseAttack
	
	match debugPhase % 3:
		0:
			card.health = baseHp
			card.attack = baseAp
	
		1:
			card.health = baseHp + debug_delta
			card.attack = baseAp + debug_delta
	
		2:
			card.health = max(0, baseHp - debug_delta)
			card.attack = max(0, baseAp - debug_delta)
	
	debugPhase += 1
	
	if card.visuals:
		card.visuals.refresh()
	

func _onDebugStateTimeout() -> void:
	if !InputManager.isGameplayInputAllowed():
		return
	var stateOrder := [
		CardState.State.IN_DECK,
		CardState.State.ON_BOARD,
		CardState.State.BEING_DRAGGED,
		CardState.State.IN_SLOT
	]
	
	var nextState: int = stateOrder[debugStatePhase % stateOrder.size()]
	
	debugStatePhase += 1
	
	_applyTestState(nextState)
	

func _applyTestState(newState: int) -> void:
	var card := _getActiveCard()
	
	if card == null:
		return
	
	card.setCardState(newState)
	
	print("Card test state set to: %s" % _getStateName(newState))
	

func _onCardPressed(card: Card) -> void:
	var index := cards.find(card)
	
	if index != -1:
		_setActiveCard(index)
	

func _input(event: InputEvent) -> void:
	#added for testing: F6 in the running game opens the encounter preview.
	if event is InputEventKey and event.pressed and !event.echo and event.keycode == KEY_F6:
		get_viewport().set_input_as_handled()
		_openEncounterPreview()
		return
	if !InputManager.isGameplayInputAllowed():
		return
	if encounterModal.visible:
		return
	var card := _getActiveCard()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and card != null:
			card.flipCard()
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_setActiveCard(0)
	
			KEY_2:
				_setActiveCard(1)
	
			KEY_3:
				_setActiveCard(2)
	
			KEY_4:
				_setActiveCard(3)
	
			KEY_Q:
				_applyTestState(CardState.State.IN_DECK)
	
			KEY_W:
				_applyTestState(CardState.State.ON_BOARD)
	
			KEY_E:
				_applyTestState(CardState.State.BEING_DRAGGED)
	
			KEY_R:
				_applyTestState(CardState.State.IN_SLOT)
	
			KEY_SPACE:
				_cycleToNextState()
	

func _cycleToNextState() -> void:
	var card := _getActiveCard()
	
	if card == null:
		return
	
	var nextState := CardState.State.IN_DECK
	
	match card.currentState:
		CardState.State.IN_DECK:
			nextState = CardState.State.ON_BOARD
	
		CardState.State.ON_BOARD:
			nextState = CardState.State.BEING_DRAGGED
	
		CardState.State.BEING_DRAGGED:
			nextState = CardState.State.IN_SLOT
	
		CardState.State.IN_SLOT:
			nextState = CardState.State.IN_DECK
	
	_applyTestState(nextState)
	

func _onCardFlipped(card: Card) -> void:
	if card != _getActiveCard():
		return
	
	print("Card flipped")
	

func _onCardStateChanged(changedCard: Card, oldState: int, newState: int) -> void:
	if changedCard != _getActiveCard():
		return
	
	print(
		"Card state changed: %s -> %s" %
		[
			_getStateName(oldState),
			_getStateName(newState)
		]
	)
	

func _getStateName(state: int) -> String:
	match state:
		CardState.State.IN_DECK:
			return "IN_DECK"
	
		CardState.State.ON_BOARD:
			return "ON_BOARD"
	
		CardState.State.BEING_DRAGGED:
			return "BEING_DRAGGED"
	
		CardState.State.IN_SLOT:
			return "IN_SLOT"
	
		_:
			return "UNKNOWN"
