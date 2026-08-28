extends GameplayEvent
class_name CardPlayedEvent

var card: Card

static func create(playedCard: Card) -> CardPlayedEvent:
	var event = CardPlayedEvent.new()
	event.type = "on_play"
	event.card = playedCard
	return event
