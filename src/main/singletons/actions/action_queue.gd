extends Node

var _queue: Array[Dictionary] = []

func enqueueAction(action: Dictionary) -> bool:
	if !ActionType.isValid(action):
		push_warning("ActionQueue: Rejected invalid action.")
		return false
	
	_queue.append(action)
	GlobalSignalBus.emitActionEnqueued(action)
	return true

func waitForActionToResolve(expectedAction: Dictionary) -> Variant:
	while true:
		var resolution: Array = await GlobalSignalBus.actionResolved
		if resolution.size() < 2:
			continue

		var resolvedAction = resolution[0]
		if is_same(resolvedAction, expectedAction):
			return resolution[1]

	return null

func popNextAction() -> Dictionary:
	if _queue.is_empty():
		return {}
	
	var action = _queue.pop_front()
	GlobalSignalBus.emitActionPopped(action)
	return action

func peekNextAction() -> Dictionary:
	if _queue.is_empty():
		return {}
	else:
		return _queue.front()

func queueHasActions() -> bool:
	return !_queue.is_empty()

func clearQueue() -> void:
	_queue.clear()
	GlobalSignalBus.emitQueueCleared()

func getActionQueueSize() -> int:
	return _queue.size()
