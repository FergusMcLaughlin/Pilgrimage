extends Node

var passed := 0
var failures := 0
var refills: Array[BoardRefillRequest] = []
var completed := 0

func _ready() -> void:
	GlobalSignalBus.boardRefillRequested.connect(func(request): refills.append(request))
	GlobalSignalBus.playerCycleCompleted.connect(func(_player, _cycle): completed += 1)
	await _testRetainedResult()
	await _testMovedResult()
	await _testFailure(false)
	await _testFailure(true)
	await _testRunInvalidation()
	print("GameController encounters: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _fixture() -> Dictionary:
	refills.clear()
	completed = 0
	var game := GameController.new()
	add_child(game)
	var player := Card.new()
	player.health = 10
	player.instanceId = 101
	var source := Card.new()
	source.data = CardLibrary.getCardData("M_0012")
	source.instanceId = 102
	var fromSlot := CardSlot.new()
	var toSlot := CardSlot.new()
	fromSlot.coordinates = Vector2i(1, 1)
	toSlot.coordinates = Vector2i(2, 1)
	game.runId = 4
	game.playerCycleNumber = 7
	game.playerCard = player
	game.state = GameController.GameState.PLAYER_READY
	InputManager.unlockInput()
	_expect(game.beginEncounter(), "Ready game begins encounter.")
	_expect(game.state == GameController.GameState.ENCOUNTER and InputManager.inputLocked, "Encounter starts locked.")
	var request := EncounterInteraction.create(4, 7, source, player, fromSlot, toSlot)
	return {"game":game, "request":request, "player":player, "source":source, "from":fromSlot, "to":toSlot}

func _testRetainedResult() -> void:
	var f := _fixture()
	var result := EncounterResult.create(f.request, true)
	GlobalSignalBus.emitEncounterCompleted(result)
	GlobalSignalBus.emitEncounterCompleted(result)
	_expect(completed == 1 and f.game.playerCycleNumber == 8, "Retained result completes one cycle despite duplicate notification.")
	_expect(refills.is_empty() and !InputManager.inputLocked, "No-move result requires no refill and unlocks input.")
	await _cleanup(f)

func _testMovedResult() -> void:
	var f := _fixture()
	f.request.sourceRemoved = true
	f.request.playerMoved = true
	var result := EncounterResult.create(f.request, true)
	GlobalSignalBus.emitEncounterCompleted(result)
	GlobalSignalBus.emitEncounterCompleted(result)
	_expect(refills.size() == 1 and completed == 0, "Move requests one refill and waits for it.")
	_expect(refills[0].cause == "encounter_advance" and refills[0].movementDirection == Vector2i.RIGHT, "Refill captures cause and direction.")
	var unrelated := BoardRefillResult.new()
	unrelated.request = BoardRefillRequest.new()
	GlobalSignalBus.emitBoardRefillResult(unrelated)
	_expect(completed == 0 and InputManager.inputLocked, "Unrelated refill cannot finish the turn.")
	var matching := BoardRefillResult.new()
	matching.request = refills[0]
	matching.succeeded = true
	GlobalSignalBus.emitBoardRefillResult(matching)
	GlobalSignalBus.emitBoardRefillResult(matching)
	_expect(completed == 1 and f.game.playerCycleNumber == 8, "Matching refill completes the cycle once.")
	_expect(f.game.pendingRefillRequest == null and !InputManager.inputLocked, "Refill ownership is cleared and input restored.")
	await _cleanup(f)

func _testFailure(partial: bool) -> void:
	var f := _fixture()
	f.request.sourceRemoved = partial
	GlobalSignalBus.emitEncounterCompleted(EncounterResult.create(f.request, false, "Expected test failure"))
	_expect(f.game.state == GameController.GameState.PLAYER_READY and !InputManager.inputLocked, "Failure returns to usable input.")
	_expect(completed == (1 if partial else 0), "Only partially applied consequences finish a cycle.")
	_expect(f.game.playerCycleNumber == (8 if partial else 7) and refills.is_empty(), "Failure preserves or finishes the correct cycle without refill.")
	await _cleanup(f)

func _testRunInvalidation() -> void:
	var f := _fixture()
	var oldId: int = f.game.runId
	f.game.pendingRefillRequest = BoardRefillRequest.new()
	_expect(!await f.game.startRun(false), "Incomplete setup intentionally fails.")
	_expect(f.game.runId == oldId + 1 and f.game.pendingRefillRequest == null, "Starting a new run changes identity and clears old refill ownership.")
	f.game.state = GameController.GameState.ENCOUNTER
	GlobalSignalBus.emitEncounterCompleted(EncounterResult.create(f.request, true))
	_expect(completed == 0 and refills.is_empty(), "An old-run result cannot continue the new run.")
	f.game.pendingRefillRequest = BoardRefillRequest.new()
	f.game._enterGameOver()
	_expect(f.game.pendingRefillRequest == null and InputManager.inputLocked, "Game over clears refill ownership and keeps input locked.")
	await _cleanup(f)

func _cleanup(f: Dictionary) -> void:
	f.game.queue_free()
	await get_tree().process_frame
	f.player.free()
	f.source.free()
	f.from.free()
	f.to.free()
	InputManager.unlockInput()

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
