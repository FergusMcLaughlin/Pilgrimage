extends Node
class_name BoardRefillController

@export var journeyDeck: JourneyDeck
@export var slotGrid: SlotGrid
@export var gameController: GameController

var boardShiftPlanner = BoardShiftPlanner.new()

func _ready() -> void:
	GlobalSignalBus.boardRefillRequested.connect(_onBoardRefillRequested)

func _onBoardRefillRequested(refillRequest: BoardRefillRequest) -> void:
	var result = BoardRefillResult.new()
	result.request = refillRequest
	
	var plan = boardShiftPlanner.planBoardShift(slotGrid, refillRequest)
	result.plan = plan
	
	if !_isRefillRequestCurrent(refillRequest):
		result.failureReason = "The board refill request is stale"
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	if !plan.succeeded:
		result.failureReason = plan.failureReason
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	var shiftSucceeded = await _processShiftPlan(plan, result)
	
	if !shiftSucceeded:
		GlobalSignalBus.emitBoardRefillResult(result)
		return
	
	if !_isRefillRequestCurrent(refillRequest):
		result.failureReason = "The board refill request became stale"
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
		plan.refillSlot,
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

func _processShiftPlan(shiftPlan: BoardShiftPlan, result: BoardRefillResult) -> bool:
	for step in shiftPlan.steps:
		if !_isShiftStepValid(step,result.request):
			result.failureReason = "The planned shift is no longer valid"
			return false
		
		var moveAction = ActionType.make(
			ActionType.MOVE_CARD,
			step.card,
			step.toSlot,
			MoveCardPayload.create("board_refill_shift")
			)
		
		if not ActionQueue.enqueueAction(moveAction):
			result.failureReason = "A board shift action was rejected"
			return false
		
		var moved = await ActionQueue.waitForActionToResolve(moveAction) as bool
		
		if not moved:
			result.failureReason = "A board shift action failed"
			return false
		
		result.completedSteps.append(step)
		
	
	return true

func _isRefillRequestCurrent(refillRequest: BoardRefillRequest) -> bool:
	if refillRequest == null:
		return false
	
	if gameController == null:
		return false
	
	if refillRequest.cycleNumber != gameController.playerCycleNumber:
		return false
	
	return gameController.state == gameController.GameState.COMBAT

func _isShiftStepValid(step: BoardShiftStep, refillRequest: BoardRefillRequest) -> bool:
	if step == null:
		return false
	
	if !_isRefillRequestCurrent(refillRequest):
		return false
	
	if step.card == null:
		return false
	
	if step.fromSlot == null or step.toSlot == null:
		return false
	
	if step.fromSlot.currentCard != step.card:
		return false
	
	if step.toSlot.isOccupied():
		return false
	
	if step.card == refillRequest.playerDestinationSlot.currentCard:
		return false
	
	return true
