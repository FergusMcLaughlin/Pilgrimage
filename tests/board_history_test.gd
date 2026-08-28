extends Node

var _passed := 0
var _failures := 0


func _ready() -> void:
	_runTest(_testSequenceAndFiltering)
	_runTest(_testReturnedEventsCannotMutateHistory)
	_runTest(_testLifecycleEventsRemainAppendOnly)
	_runTest(_testRemovalCounting)
	_runTest(_testResetRestartsSequence)
	
	if _failures > 0:
		push_error("FAIL: BoardHistory tests (%s failures)" % _failures)
		get_tree().quit(1)
		return
	print("PASS: BoardHistory tests (%s passed)" % _passed)
	get_tree().quit(0)
	

func _runTest(testMethod: Callable) -> void:
	BoardHistory.reset()
	testMethod.call()
	_passed += 1
	

func _testSequenceAndFiltering() -> void:
	var removed = BoardHistory.recordEvent(_makeEvent("removed", "M_0001"))
	var revived = BoardHistory.recordEvent(_makeEvent("revived", "M_0001"))
	_expect(removed.sequence == 1, "The first event should use sequence 1.")
	_expect(revived.sequence == 2, "Sequence numbers should increase.")
	_expect(BoardHistory.getEvents("removed").size() == 1, "Filtering should return one removal.")
	_expect(BoardHistory.getEvents().size() == 2, "An empty filter should return all events.")
	

func _testReturnedEventsCannotMutateHistory() -> void:
	BoardHistory.recordEvent(_makeEvent("removed", "M_0001"))
	var returned = BoardHistory.getEvents()
	returned[0].cardId = "changed"
	var stored = BoardHistory.getEvents()[0]
	_expect(stored.cardId == "M_0001", "Returned events should be copies.")
	

func _testLifecycleEventsRemainAppendOnly() -> void:
	BoardHistory.recordEvent(_makeEvent("removed"))
	BoardHistory.recordEvent(_makeEvent("revived"))
	BoardHistory.recordEvent(_makeEvent("deleted"))
	_expect(BoardHistory.getEvents().size() == 3, "Every lifecycle event should remain recorded.")
	_expect(BoardHistory.getEvents("removed").size() == 1, "Later events must not erase removal.")
	

func _testRemovalCounting() -> void:
	BoardHistory.recordEvent(_makeEvent("removed", "M_0001"))
	BoardHistory.recordEvent(_makeEvent("removed", "M_0002"))
	BoardHistory.recordEvent(_makeEvent("removed", "M_0001"))
	BoardHistory.recordEvent(_makeEvent("revived", "M_0001"))
	_expect(BoardHistory.countRemovedCards() == 3, "Total removal count should ignore revival.")
	_expect(BoardHistory.countRemovedCards("M_0001") == 2, "Card ID filtering should count matches.")
	

func _testResetRestartsSequence() -> void:
	BoardHistory.recordEvent(_makeEvent("removed"))
	BoardHistory.reset()
	var event = BoardHistory.recordEvent(_makeEvent("removed"))
	_expect(BoardHistory.getEvents().size() == 1, "Reset should clear old history.")
	_expect(event.sequence == 1, "Reset should restart sequence numbering.")
	

func _makeEvent(eventType: String, cardId: String = "") -> BoardHistoryEvent:
	var event: BoardHistoryEvent
	if eventType == "removed":
		event = CardRemovedHistoryEvent.new()
	else:
		event = BoardHistoryEvent.new()
	event.type = eventType
	event.cardId = cardId
	return event
	

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)
