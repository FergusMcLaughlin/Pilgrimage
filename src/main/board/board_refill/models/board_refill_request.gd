extends RefCounted
class_name BoardRefillRequest

var vacatedPlayerSlot: CardSlot
var playerDestinationSlot: CardSlot
var movementDirection: Vector2i
var cycleNumber: int
var cause: String

static func afterPlayerMove(vacatedSlot: CardSlot, destinationSlot: CardSlot, moveDirection: Vector2i, cycle: int, refillCause = "player_moved") -> BoardRefillRequest:
	var request = BoardRefillRequest.new()
	request.vacatedPlayerSlot = vacatedSlot
	request.playerDestinationSlot = destinationSlot
	request.movementDirection = moveDirection
	request.cycleNumber = cycle
	request.cause = refillCause
	return request
