extends Node
class_name BoardRefillController

@export var journeyDeck: JourneyDeck

func _ready() -> void:
	GlobalSignalBus.boardRefillRequested.connect(_onBoardRefillRequested)

func _onBoardRefillRequested(refillRequest: BoardRefillRequest) -> void:
	var result = BoardRefillResult.new()
	result.request = refillRequest
	
	if refillRequest.slot == null or refillRequest.slot.isOccupied():
		result.failureReason = "The target slot is invalid or occupied"
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	if journeyDeck == null or journeyDeck.isEmpty():
		result.succeeded = true
		result.skipped = true
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	var reveal = ActionType.make(
		ActionType.REVEAL_CARD,
		journeyDeck,
		refillRequest.slot,
		RevealCardPayload.create(refillRequest.cause)
		)
	
	if !ActionQueue.enqueueAction(reveal):
		result.failureReason = "The refil action has been rejected"
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	result.revealedCard = ( await ActionQueue.waitForActionToResolve(reveal) as Card)
	result.succeeded = result.revealedCard != null
	
	if !result.succeeded:
		result.failureReason = "the refill reveal action has failed"
	
	GlobalSignalBus.emitBoardRefillResult(result)
