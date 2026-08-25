extends Node

var _passed := 0
var _failures := 0


func _ready() -> void:
	_testActionTypeAndDirectDamage()
	await _testRejectedActions()
	await _testTypedAttribution()
	await _testVisualRefresh()
	await _testModifyStatsRemainsIndependent()
	await get_tree().process_frame
	if _failures > 0:
		push_error("FAIL: Story 13 damage action tests (%s failures, %s passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: Story 13 damage action tests (%s passed)" % _passed)
	get_tree().quit(0)


func _makeCard(cardId: String, health: int, attack: int = 1) -> Card:
	var card := Card.new()
	var data := CardData.new()
	data.id = cardId
	data.baseHealth = health
	data.baseAttack = attack
	card.data = data
	card.health = health
	card.attack = attack
	card.instanceId = randi_range(1, 1000000)
	return card


func _testActionTypeAndDirectDamage() -> void:
	_expect(ActionType.DEAL_DAMAGE in ActionType.VALID_TYPES, "DEAL_DAMAGE must remain registered.")
	_testDamage(5, 0, 0, 0, 0, 5, 0, false)
	_testDamage(5, 3, 2, 2, 0, 5, 1, false)
	_testDamage(5, 3, 5, 3, 2, 3, 0, false)
	_testDamage(5, 0, 5, 0, 5, 0, 0, true)
	_testDamage(5, 0, 99, 0, 5, 0, 0, true)

	var target := _makeCard("target", 5)
	var rejected := target.applyDamage(-1)
	_expect(rejected is DamageResult and !rejected.succeeded, "Negative direct damage must return a rejected DamageResult.")
	_expect(target.health == 5, "Rejected damage must not change health.")
	target.free()


func _testDamage(startingHealth: int, temporaryHealth: int, amount: int, expectedTempLost: int, expectedBaseLost: int, expectedHealth: int, expectedTemp: int, lethal: bool) -> void:
	var target := _makeCard("target", startingHealth)
	target.temporaryHealth = temporaryHealth
	var result := target.applyDamage(amount)
	_expect(result is DamageResult and result.succeeded, "Valid damage must return a successful DamageResult.")
	_expect(result.damageRequested == amount, "DamageResult must retain the requested amount.")
	_expect(result.temporaryHealthLost == expectedTempLost, "Temporary-health loss must be exact.")
	_expect(result.baseHealthLost == expectedBaseLost, "Base-health loss must be exact.")
	_expect(result.damageDealt == expectedTempLost + expectedBaseLost, "Damage must not be double-counted.")
	_expect(result.remainingHealth == expectedHealth and target.health == expectedHealth, "Remaining base health must be exact.")
	_expect(result.remainingTemporaryHealth == expectedTemp and target.temporaryHealth == expectedTemp, "Remaining temporary health must be exact.")
	_expect(result.wasLethal == lethal, "Lethal state must reflect remaining base health.")
	_expect(result.target == target and result.targetInstanceId == target.instanceId, "Direct damage must identify its target.")
	target.free()


func _testRejectedActions() -> void:
	var source := _makeCard("source", 5)
	var target := _makeCard("target", 5)
	for action in [
		ActionType.make(ActionType.DEAL_DAMAGE, null, target, {"amount": 1}),
		ActionType.make(ActionType.DEAL_DAMAGE, Node.new(), target, {"amount": 1}),
		ActionType.make(ActionType.DEAL_DAMAGE, source, null, {"amount": 1}),
		ActionType.make(ActionType.DEAL_DAMAGE, source, Node.new(), {"amount": 1}),
		ActionType.make(ActionType.DEAL_DAMAGE, source, target, {}),
		ActionType.make(ActionType.DEAL_DAMAGE, source, target, {"amount": "1"}),
		ActionType.make(ActionType.DEAL_DAMAGE, source, target, {"amount": -1}),
	]:
		var startingHealth := target.health
		var result = await _enqueueAndWait(action)
		_expect(result is DamageResult and !result.succeeded, "Invalid DEAL_DAMAGE input must return a rejected DamageResult.")
		_expect(target.health == startingHealth, "Rejected action damage must change nothing.")


func _testTypedAttribution() -> void:
	var source := _makeCard("source", 5)
	var target := _makeCard("target", 5)
	var action := ActionType.make(ActionType.DEAL_DAMAGE, source, target, {
		"amount": 2,
		"cause": "combat",
		"cycle_number": 7,
	})
	var result = await _enqueueAndWait(action)
	_expect(result is DamageResult and result.succeeded, "Valid queued damage must return a successful DamageResult.")
	_expect(result.source == source and result.target == target, "DamageResult must retain source and target references.")
	_expect(result.sourceInstanceId == source.instanceId and result.targetInstanceId == target.instanceId, "DamageResult must retain stable instance IDs.")
	_expect(result.sourceCardId == source.data.id and result.targetCardId == target.data.id, "DamageResult must retain definition IDs.")
	_expect(result.cause == "combat" and result.cycleNumber == 7, "Cause and cycle must survive the action boundary.")
	source.free()
	target.free()


func _testVisualRefresh() -> void:
	var target := CreateCard.new().createCard("M_0001")
	add_child(target)
	await get_tree().process_frame
	target.temporaryHealth = 2
	target.applyDamage(1)
	_expect(target.visuals.healthLable.text == "%s (+1)" % target.health, "Damage must refresh the visible temporary-health value.")
	target.applyDamage(2)
	_expect(target.visuals.healthLable.text == str(target.health), "Damage overflow must refresh the visible base-health value.")
	target.queue_free()


func _testModifyStatsRemainsIndependent() -> void:
	var target := CreateCard.new().createCard("M_0001")
	add_child(target)
	target.health = 2
	var result = await _enqueueAndWait(ActionType.make(
		ActionType.MODIFY_STATS, null, target, {"stat": "health", "amount": 2}
	))
	_expect(result == null and target.health == 4, "MODIFY_STATS healing must remain independent of DEAL_DAMAGE.")
	target.queue_free()


func _enqueueAndWait(action: Dictionary) -> Variant:
	if !ActionQueue.enqueueAction(action):
		_expect(false, "A structurally valid test action must enter ActionQueue.")
		return null
	return await ActionQueue.waitForActionToResolve(action)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
