extends Node

var _queue: Array[GameAction] = []

func enqueueAction(action: GameAction) -> bool:
	if action == null or !action.isValid():
		push_warning("ActionQueue: Rejected invalid action.")
		return false
	
	_queue.append(action)
	GlobalSignalBus.emitActionEnqueued(action)
	return true

func waitForActionToResolve(expectedAction: GameAction) -> Variant:
	if expectedAction == null:
		return null
	while true:
		var resolution: Array = await GlobalSignalBus.actionResolved
		if resolution.size() < 2:
			continue
	
		var resolvedAction = resolution[0] as GameAction
		if is_same(resolvedAction, expectedAction):
			return resolution[1]
	
	return null

func popNextAction() -> GameAction:
	if _queue.is_empty():
		return null
	
	var action = _queue.pop_front()
	GlobalSignalBus.emitActionPopped(action)
	return action

func peekNextAction() -> GameAction:
	if _queue.is_empty():
		return null
	else:
		return _queue.front()

func queueHasActions() -> bool:
	return !_queue.is_empty()

func clearQueue() -> void:
	_queue.clear()
	GlobalSignalBus.emitQueueCleared()

func getActionQueueSize() -> int:
	return _queue.size()
