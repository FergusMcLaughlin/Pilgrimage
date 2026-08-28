extends GameActionPayload
class_name MoveCardPayload

static func create(moveCardCause: String) -> MoveCardPayload:
	var moveCardActionPayload = MoveCardPayload.new()
	moveCardActionPayload.cause = moveCardCause
	return moveCardActionPayload
