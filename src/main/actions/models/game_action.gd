extends RefCounted
class_name GameAction

var type: String
var source: Variant
var target: Variant
var payload: GameActionPayload

static func create(actionType: String, actionSource: Variant, actionTarget: Variant, actionPayload: GameActionPayload = null) -> GameAction:
	var action = GameAction.new()
	action.type = actionType
	action.source = actionSource
	action.target = actionTarget
	action.payload = actionPayload
	return action

func isValid() -> bool:
	return type in ActionType.VALID_TYPES
