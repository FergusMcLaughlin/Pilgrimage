extends GameActionPayload
class_name RevealCardPayload

static func create(revealCardCause: String) -> RevealCardPayload:
	var revealCardActionPayload = RevealCardPayload.new()
	revealCardActionPayload.cause = revealCardCause
	return revealCardActionPayload
