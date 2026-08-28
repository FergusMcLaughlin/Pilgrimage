extends GameActionPayload
class_name RemoveCardPayload

var sourceInstanceId: int

static func create(removeCardSourceInstanceId: int, removeCardCause: String) -> RemoveCardPayload:
	var removeCardActionPayload = RemoveCardPayload.new()
	removeCardActionPayload.sourceInstanceId = removeCardSourceInstanceId
	removeCardActionPayload.cause = removeCardCause
	return removeCardActionPayload
