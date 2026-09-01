extends RefCounted
class_name BoardShiftPlanner

func planBoardShift(slotGrid: SlotGrid, request: BoardRefillRequest) -> BoardShiftPlan:
	if !_isRequestValid(slotGrid, request):
		return _failedShiftPlan(request, "Invalid refill request")
	
	var priorityDirections = _getShiftPriorities(request.movementDirection)
	
	for shiftDirection in priorityDirections:
		var plan = _tryDirectionalPlan(slotGrid, request, shiftDirection)
		
		if plan.succeeded:
			return plan
			
	return _failedShiftPlan(request, "Invalid refill request")

func _isRequestValid(slotGrid: SlotGrid, request: BoardRefillRequest) -> bool:
	if slotGrid == null or request == null:
		return false
	
	if request.vacatedPlayerSlot == null or request.playerDestinationSlot == null:
		return false
	
	if request.movementDirection not in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		return false
	
	if request.vacatedPlayerSlot.isOccupied():
		return false
	
	if not request.playerDestinationSlot.isOccupied():
		return false
	
	return true

func _getNextSourceSlot(slotGrid: SlotGrid, vacancy: CardSlot, shiftDirection: Vector2i) -> CardSlot:
	if slotGrid == null or vacancy == null:
		return null
	
	return slotGrid.getSlotAt(vacancy.coordinates - shiftDirection)

func _getShiftPriorities(playerDirection: Vector2i) -> Array[Vector2i]:
	match playerDirection:
		Vector2i.LEFT:
			return[Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT]
		Vector2i.RIGHT:
			return[Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]
		Vector2i.UP:
			return[Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN]
		Vector2i.DOWN:
			return[Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	
	return[]

func _tryDirectionalPlan(slotGrid: SlotGrid, request: BoardRefillRequest, shiftDirection: Vector2i) -> BoardShiftPlan:
	if !_isRequestValid(slotGrid, request):
		return _failedShiftPlan(request, "Invalid refill request")
	
	var plan = BoardShiftPlan.new()
	plan.vacatedPlayerSlot = request.vacatedPlayerSlot
	plan.playerDestinationSlot = request.playerDestinationSlot
	plan.movementDirection = request.movementDirection
	plan.cycleNumber = request.cycleNumber
	
	var vacancy = request.vacatedPlayerSlot
	
	while !_isBorderSlot(slotGrid, vacancy, shiftDirection):
		var sourceSlot = _getNextSourceSlot(slotGrid, vacancy, shiftDirection)
		
		if sourceSlot == null or !sourceSlot.isOccupied():
			return _failedShiftPlan(request, "could not reach the edge of the grid")
		
		if sourceSlot == request.playerDestinationSlot:
			return _failedShiftPlan(request, "this shift interfers with the player")
		
		var step = BoardShiftStep.create(sourceSlot.currentCard, sourceSlot, vacancy)
		
		plan.steps.append(step)
		vacancy = sourceSlot
	
	if plan.steps.is_empty():
		return _failedShiftPlan(request, "The route did not shift any cards")
	
	plan.refillSlot = vacancy
	plan.succeeded = true
	return plan

func _isBorderSlot(slotGrid: SlotGrid, slot: CardSlot, shiftDirection: Vector2i) -> bool:
	if slotGrid == null or slot == null:
		return false
	
	var previousCoordinates = slot.coordinates - shiftDirection
	return slotGrid.getSlotAt(previousCoordinates) == null

func _failedShiftPlan(request: BoardRefillRequest, reason: String) -> BoardShiftPlan:
	var plan = BoardShiftPlan.new()
	plan.failureReason = reason
	
	if request != null:
		plan.vacatedPlayerSlot = request.vacatedPlayerSlot
		plan.playerDestinationSlot = request.playerDestinationSlot
		plan.movementDirection = request.movementDirection
		plan.cycleNumber = request.cycleNumber
	
	return plan
