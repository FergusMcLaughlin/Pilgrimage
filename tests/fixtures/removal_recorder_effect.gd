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
	

func onEvent(event: GameplayEvent) -> void:
	var resolvedEvent = event as ActionResolvedEvent
	if resolvedEvent == null:
		return
	var action = resolvedEvent.action
	if action == null or action.type != ActionType.REMOVE_CARD:
		return
	if action.target != hostCard:
		return
	
	callOrder.append("event")
	observedSource = action.source
	var payload = action.payload as RemoveCardPayload
	observedCause = payload.cause if payload != null else ""
	observedResult = resolvedEvent.result
	

func onDeactivated() -> void:
	callOrder.append("deactivated")
