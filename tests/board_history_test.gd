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
	var removed := BoardHistory.recordEvent("removed", {"card_id": "M_0001"})
	var revived := BoardHistory.recordEvent("revived", {"card_id": "M_0001"})
	_expect(removed.get("sequence") == 1, "The first event should use sequence 1.")
	_expect(revived.get("sequence") == 2, "Sequence numbers should increase.")
	_expect(BoardHistory.getEvents("removed").size() == 1, "Filtering should return one removal.")
	_expect(BoardHistory.getEvents().size() == 2, "An empty filter should return all events.")


func _testReturnedEventsCannotMutateHistory() -> void:
	BoardHistory.recordEvent("removed", {
		"card_id": "M_0001",
		"nested": {"cause": "combat"},
	})
	var returned := BoardHistory.getEvents()
	returned[0]["card_id"] = "changed"
	returned[0]["nested"]["cause"] = "changed"
	var stored := BoardHistory.getEvents()[0]
	_expect(stored.get("card_id") == "M_0001", "Returned events should be copies.")
	_expect(stored.get("nested", {}).get("cause") == "combat", "Nested details should be copied.")


func _testLifecycleEventsRemainAppendOnly() -> void:
	BoardHistory.recordEvent("removed", {"instance_id": 4})
	BoardHistory.recordEvent("revived", {"instance_id": 4})
	BoardHistory.recordEvent("deleted", {"instance_id": 4})
	_expect(BoardHistory.getEvents().size() == 3, "Every lifecycle event should remain recorded.")
	_expect(BoardHistory.getEvents("removed").size() == 1, "Later events must not erase removal.")


func _testRemovalCounting() -> void:
	BoardHistory.recordEvent("removed", {"card_id": "M_0001"})
	BoardHistory.recordEvent("removed", {"card_id": "M_0002"})
	BoardHistory.recordEvent("removed", {"card_id": "M_0001"})
	BoardHistory.recordEvent("revived", {"card_id": "M_0001"})
	_expect(BoardHistory.countRemovedCards() == 3, "Total removal count should ignore revival.")
	_expect(BoardHistory.countRemovedCards("M_0001") == 2, "Card ID filtering should count matches.")


func _testResetRestartsSequence() -> void:
	BoardHistory.recordEvent("removed")
	BoardHistory.reset()
	var event := BoardHistory.recordEvent("removed")
	_expect(BoardHistory.getEvents().size() == 1, "Reset should clear old history.")
	_expect(event.get("sequence") == 1, "Reset should restart sequence numbering.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)
