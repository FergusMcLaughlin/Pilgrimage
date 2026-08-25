extends Node
class_name PlayerMovementController

@export var gameController: GameController
@export var boardController: BoardController
@export var slotGrid: SlotGrid

var isResolvingSelection = false

func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)

func _hasRequiredRefs() -> bool:
	return(gameController != null and boardController != null and slotGrid != null)

func _getPlayerSlot() -> CardSlot:
	if gameController == null or gameController.playerCard == null:
		return null
	return boardController.getSlotCardIsIn(gameController.playerCard)

func _getTargetSlot(card: Card) -> CardSlot:
	if card == null or boardController == null:
		return null
	return boardController.getSlotCardIsIn(card)

func isValidTarget(card: Card) -> bool:
	if !_hasRequiredRefs():
		return false
	if gameController.state != GameController.GameState.PLAYER_READY:
		return false
	if card == null or card == gameController.playerCard:
		return false
	
	var playerSlot = _getPlayerSlot()
	var targetSlot = _getTargetSlot(card)
	
	if playerSlot == null or targetSlot == null:
		return false
	if !targetSlot.isOccupied():
		return false
	
	return targetSlot in slotGrid.getCardinalNeighbours(playerSlot)

func _onCardPressed(card: Card) -> void:
	if !isValidTarget(card):
		return
	_requestCombat(card)

func _requestCombat(defender: Card) -> bool:
	var player = gameController.playerCard
	var playerSlot = _getPlayerSlot()
	var targetSlot = _getTargetSlot(defender)
	
	if playerSlot == null or targetSlot == null:
		return false
	if !gameController.beginPlayerAction():
		return false
	if !gameController.beginCombat():
		return false
	
	GlobalSignalBus.emitPlayerCombatRequested(player, defender, playerSlot, targetSlot, gameController.playerCycleNumber)
	
	return true
