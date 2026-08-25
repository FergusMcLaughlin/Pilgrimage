extends Node
class_name GameController

enum GameState {
	SETUP,
	PLAYER_READY,
	RESOLVING_MOVE,
	COMBAT,
	AFTER_MOVE,
	GAME_OVER
}

@export var boardController: BoardController
@export var slotGrid: SlotGrid
@export var journeyDeck: JourneyDeck
@export var playerCardId: String = "C_0000"

var state: GameState = GameState.SETUP
var playerCard: Card
var playerCycleNumber: int = 0
var _createCard := CreateCard.new()

func _ready() -> void:
	GlobalSignalBus.combatEnded.connect(_onCombatCompleted)
	GlobalSignalBus.boardRefillCompleted.connect(_onBoardRefillCompleted)

func setState(newState: GameState) -> void:
	if state == newState:
		return
	var previousState: GameState = state
	state = newState
	GlobalSignalBus.emitGameStateChanged(previousState, state)

func _activatePlayerCard(card: Card) -> void:
	if card != null and !card.visuals.isFaceUp():
		await card.flipCard()

func startRun(shuffleDeck: bool = true) -> bool:
	setState(GameState.SETUP)
	InputManager.lockInput()
	
	if !_hasRequiredReferences():
		return _failSetup("missing board, grid or deck")
	
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	playerCycleNumber = 0
	
	journeyDeck.boardController = boardController
	journeyDeck.slotGrid = slotGrid
	journeyDeck.initialiseJourneyDeck(shuffleDeck)

	playerCard = _createCard.createCard(playerCardId)
	if playerCard == null:
		return _failSetup("could not create player")
	
	var centerSlot: CardSlot = slotGrid.getCenterSlot()
	if centerSlot == null or !boardController.placeCard(playerCard, centerSlot):
		playerCard.queue_free()
		playerCard = null
		return _failSetup("could not place player in center")
	
	await _activatePlayerCard(playerCard)
	
	await journeyDeck.fillEmptySlots(slotGrid)
	await _waitForActionSystemIdle()
	_enterPlayerReady()
	return true

func _hasRequiredReferences() -> bool:
	return boardController != null and slotGrid != null and journeyDeck != null

func _failSetup(message: String) -> bool:
	push_error("GameController: " + message)
	setState(GameState.SETUP)
	InputManager.lockInput()
	return false


func _waitForActionSystemIdle() -> void:
	while ActionQueue.queueHasActions() or ActionProcessor.isProcessingAction:
		await get_tree().process_frame

func _enterPlayerReady() -> void:
	playerCycleNumber += 1
	setState(GameState.PLAYER_READY)
	InputManager.unlockInput()
	GlobalSignalBus.emitPlayerCycleStarted(
		playerCard,
		playerCycleNumber,
	)

func beginPlayerAction() -> bool:
	if state != GameState.PLAYER_READY:
		return false
	InputManager.lockInput()
	setState(GameState.RESOLVING_MOVE)
	return true


func beginCombat() -> bool:
	if state != GameState.RESOLVING_MOVE:
		return false
	setState(GameState.COMBAT)
	return true

func _onCombatCompleted(combatResult: CombatResult) -> void:
	if combatResult.succeeded and combatResult.playerMoved:
		GlobalSignalBus.emitBoardRefillRequested(
			BoardRefillRequest.forEmptySlot(combatResult.context.playerSlot, combatResult.context.cycleNumber)
		)
		return
	
	_finishResolvedPlayerAction()

func _onBoardRefillCompleted(_result: BoardRefillResult) -> void:
	_finishResolvedPlayerAction()

func _finishResolvedPlayerAction() -> void:
	if beginAfterMovePhase():
		await  _waitForActionSystemIdle()
		completePlayerCycle()

func beginAfterMovePhase() -> bool:
	if state not in [GameState.RESOLVING_MOVE, GameState.COMBAT]:
		return false
	setState(GameState.AFTER_MOVE)
	GlobalSignalBus.emitAfterMoveStarted(
		playerCard,
		playerCycleNumber,
	)
	return true


func completePlayerCycle() -> bool:
	if state != GameState.AFTER_MOVE:
		return false
	if ActionQueue.queueHasActions() or ActionProcessor.isProcessingAction:
		return false

	GlobalSignalBus.emitPlayerCycleCompleted(
		playerCard,
		playerCycleNumber,
	)
	_enterPlayerReady()
	return true
