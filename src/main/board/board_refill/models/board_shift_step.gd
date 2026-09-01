extends RefCounted
class_name BoardShiftStep

var card: Card
var fromSlot: CardSlot
var toSlot: CardSlot

static func create(cardToBeShifted: Card, sourceSlot: CardSlot, destinationSlot: CardSlot) -> BoardShiftStep:
	var step = BoardShiftStep.new()
	step.card = cardToBeShifted
	step.fromSlot = sourceSlot
	step.toSlot = destinationSlot
	return step
