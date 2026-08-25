extends RefCounted
class_name BoardRefillRequest

var slot: CardSlot
var cycleNumber: int
var cause: String

static func forEmptySlot(emptySlot: CardSlot, cycle: int) -> BoardRefillRequest:
	var request = BoardRefillRequest.new()
	request.slot = emptySlot
	request.cycleNumber = cycle
	request.cause = "player_moved"
	return request
