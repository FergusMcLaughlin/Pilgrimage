extends CardEffect

static var callOrder: Array[String] = []
static var observedSource = null
static var observedCause := ""
static var observedResult = null


static func reset() -> void:
	callOrder.clear()
	observedSource = null
	observedCause = ""
	observedResult = null


func onEvent(event: Dictionary) -> void:
	if event.get("type") != "action_resolved":
		return
	var action: Dictionary = event.get("action", {})
	if action.get("type") != ActionType.REMOVE_CARD:
		return
	if action.get("target") != hostCard:
		return

	callOrder.append("event")
	observedSource = action.get("source")
	observedCause = action.get("data", {}).get("cause", "")
	observedResult = event.get("result")


func onDeactivated() -> void:
	callOrder.append("deactivated")
