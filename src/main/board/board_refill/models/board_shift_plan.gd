extends RefCounted
class_name BoardShiftPlan

var succeeded = false
var failureReason = ""
var vacatedPlayerSlot: CardSlot
var playerDestinationSlot: CardSlot
var movementDirection: Vector2i
var steps: Array[BoardShiftStep] = []
var refillSlot: CardSlot
var cycleNumber = 0
