extends GameplayEvent
class_name ActionResolvedEvent

var action: GameAction
var result: Variant

static func create(resolvedAction: GameAction, actionResult: Variant) -> ActionResolvedEvent:
	var event = ActionResolvedEvent.new()
	event.type = "action_resolved"
	event.action = resolvedAction
	event.result = actionResult
	return event
