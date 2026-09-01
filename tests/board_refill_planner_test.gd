extends Node

const SLOT_GRID_SCENE = preload("res://src/main/board/slot_grid/slot_grid.tscn")

var _planner = BoardShiftPlanner.new()
var _passed = 0
var _failures = 0


func _ready() -> void:
	await _testRightUsesPrimaryRowRoute()
	await _testDownUsesPrimaryColumnRoute()
	await _testUpFromBottomRightUsesFallbackRowRoute()
	await _testLeftFromMiddleRightUsesFallbackColumnRoute()
	await _testBottomLeftUsesMirroredFallbackRowRoute()
	await _testPlanningDoesNotMutateBoard()
	await _testNoRouteRejectsDirectRefill()
	await _testRejectsInvalidMovement()
	await _testPlanNeverMovesPlayer()
	await _testIdenticalInputProducesIdenticalPlan()

	if _failures > 0:
		push_error("FAIL: Board refill planner tests (%s failures, %s passed)" % [_failures, _passed])
		get_tree().quit(1)
		return

	print("PASS: Board refill planner tests (%s passed)" % _passed)
	get_tree().quit(0)


func _testRightUsesPrimaryRowRoute() -> void:
	var fixture = await _createFixture(Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	var sourceCard = _placeCard(fixture, Vector2i(0, 1))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Moving right must produce a plan.")
	_expect(plan.steps.size() == 1, "Moving right from centre must shift one card.")
	_expectStep(plan, 0, sourceCard, Vector2i(0, 1), Vector2i(1, 1), "Moving right must pull the middle-left card right.")
	_expect(plan.refillSlot.coordinates == Vector2i(0, 1), "Moving right must refill at middle-left.")
	await _destroyFixture(fixture)


func _testDownUsesPrimaryColumnRoute() -> void:
	var fixture = await _createFixture(Vector2i(2, 1), Vector2i(2, 2), Vector2i.DOWN)
	var sourceCard = _placeCard(fixture, Vector2i(2, 0))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Moving down must produce a plan.")
	_expect(plan.steps.size() == 1, "Moving down from middle-right must shift one card.")
	_expectStep(plan, 0, sourceCard, Vector2i(2, 0), Vector2i(2, 1), "Moving down must pull the top-right card down.")
	_expect(plan.refillSlot.coordinates == Vector2i(2, 0), "Moving down must refill at top-right.")
	await _destroyFixture(fixture)


func _testUpFromBottomRightUsesFallbackRowRoute() -> void:
	var fixture = await _createFixture(Vector2i(2, 2), Vector2i(2, 1), Vector2i.UP)
	var middleCard = _placeCard(fixture, Vector2i(1, 2))
	var leftCard = _placeCard(fixture, Vector2i(0, 2))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Moving up from bottom-right must find a fallback plan.")
	_expect(plan.steps.size() == 2, "Bottom-right vacancy must shift the two-card bottom row.")
	_expectStep(plan, 0, middleCard, Vector2i(1, 2), Vector2i(2, 2), "Bottom-middle must shift into bottom-right.")
	_expectStep(plan, 1, leftCard, Vector2i(0, 2), Vector2i(1, 2), "Bottom-left must shift into bottom-middle.")
	_expect(plan.refillSlot.coordinates == Vector2i(0, 2), "Bottom-right vacancy must refill at bottom-left.")
	await _destroyFixture(fixture)


func _testLeftFromMiddleRightUsesFallbackColumnRoute() -> void:
	var fixture = await _createFixture(Vector2i(2, 1), Vector2i(1, 1), Vector2i.LEFT)
	var sourceCard = _placeCard(fixture, Vector2i(2, 0))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Moving left from middle-right must find a fallback plan.")
	_expect(plan.steps.size() == 1, "Middle-right vacancy must shift one top-right card down.")
	_expectStep(plan, 0, sourceCard, Vector2i(2, 0), Vector2i(2, 1), "Top-right must shift down into middle-right.")
	_expect(plan.refillSlot.coordinates == Vector2i(2, 0), "Middle-right vacancy must refill at top-right.")
	await _destroyFixture(fixture)


func _testBottomLeftUsesMirroredFallbackRowRoute() -> void:
	var fixture = await _createFixture(Vector2i(0, 2), Vector2i(0, 1), Vector2i.UP)
	var middleCard = _placeCard(fixture, Vector2i(1, 2))
	var rightCard = _placeCard(fixture, Vector2i(2, 2))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Moving up from bottom-left must find a mirrored fallback plan.")
	_expect(plan.steps.size() == 2, "Bottom-left vacancy must shift the two-card bottom row.")
	_expectStep(plan, 0, middleCard, Vector2i(1, 2), Vector2i(0, 2), "Bottom-middle must shift into bottom-left.")
	_expectStep(plan, 1, rightCard, Vector2i(2, 2), Vector2i(1, 2), "Bottom-right must shift into bottom-middle.")
	_expect(plan.refillSlot.coordinates == Vector2i(2, 2), "Bottom-left vacancy must refill at bottom-right.")
	await _destroyFixture(fixture)


func _testPlanningDoesNotMutateBoard() -> void:
	var fixture = await _createFixture(Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	var sourceCard = _placeCard(fixture, Vector2i(0, 1))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "The non-mutation fixture must produce a plan.")
	_expect(fixture.grid.getSlotAt(Vector2i(0, 1)).currentCard == sourceCard, "Planning must leave the source card in its original slot.")
	_expect(fixture.grid.getSlotAt(Vector2i(1, 1)).currentCard == null, "Planning must leave the original vacancy empty.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 1)).currentCard == fixture.player, "Planning must leave the player in the destination slot.")
	await _destroyFixture(fixture)


func _testNoRouteRejectsDirectRefill() -> void:
	var fixture = await _createFixture(Vector2i(2, 2), Vector2i(2, 1), Vector2i.UP)
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(!plan.succeeded, "A vacancy with no card route must fail planning.")
	_expect(plan.steps.is_empty(), "A failed plan must not contain partial steps.")
	_expect(plan.refillSlot == null, "A failed plan must not select direct-slot refill.")
	await _destroyFixture(fixture)


func _testRejectsInvalidMovement() -> void:
	var fixture = await _createFixture(Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	fixture.request.movementDirection = Vector2i(1, 1)
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(!plan.succeeded, "Diagonal movement must be rejected.")
	_expect(!plan.failureReason.is_empty(), "Rejected movement must include a failure reason.")
	await _destroyFixture(fixture)


func _testPlanNeverMovesPlayer() -> void:
	var fixture = await _createFixture(Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	_placeCard(fixture, Vector2i(0, 1))
	var plan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(plan.succeeded, "Player-safety fixture must produce a plan.")
	for step in plan.steps:
		_expect(step.card != fixture.player, "A shift plan must never move the player.")
		_expect(step.fromSlot != fixture.request.playerDestinationSlot, "A shift plan must never use the player slot as a source.")
	await _destroyFixture(fixture)


func _testIdenticalInputProducesIdenticalPlan() -> void:
	var fixture = await _createFixture(Vector2i(2, 2), Vector2i(2, 1), Vector2i.UP)
	_placeCard(fixture, Vector2i(1, 2))
	_placeCard(fixture, Vector2i(0, 2))
	var firstPlan = _planner.planBoardShift(fixture.grid, fixture.request)
	var secondPlan = _planner.planBoardShift(fixture.grid, fixture.request)

	_expect(firstPlan.succeeded and secondPlan.succeeded, "Identical planning input must succeed consistently.")
	_expect(firstPlan.steps.size() == secondPlan.steps.size(), "Identical planning input must produce the same number of steps.")
	_expect(firstPlan.refillSlot == secondPlan.refillSlot, "Identical planning input must produce the same refill slot.")
	for index in range(firstPlan.steps.size()):
		_expect(firstPlan.steps[index].fromSlot == secondPlan.steps[index].fromSlot and firstPlan.steps[index].toSlot == secondPlan.steps[index].toSlot, "Identical planning input must produce the same step order.")
	await _destroyFixture(fixture)


func _createFixture(vacatedCoordinates: Vector2i, destinationCoordinates: Vector2i, direction: Vector2i) -> Dictionary:
	var root = Node.new()
	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var board = BoardController.new()
	board.name = "BoardController"
	board.slotGridPath = NodePath("../SlotGrid")
	root.add_child(grid)
	root.add_child(board)
	add_child(root)
	await get_tree().process_frame

	var player = CreateCard.new().createCard("C_0000")
	var destinationSlot: CardSlot = grid.getSlotAt(destinationCoordinates)
	_expect(board.placeCard(player, destinationSlot), "Fixture player must be placed.")
	var vacatedSlot: CardSlot = grid.getSlotAt(vacatedCoordinates)
	var request = BoardRefillRequest.afterPlayerMove(vacatedSlot, destinationSlot, direction, 1)
	return {"root": root, "grid": grid, "board": board, "player": player, "request": request}


func _placeCard(fixture: Dictionary, coordinates: Vector2i) -> Card:
	var card = CreateCard.new().createCard("M_0001")
	var slot: CardSlot = fixture.grid.getSlotAt(coordinates)
	_expect(fixture.board.placeCard(card, slot), "Fixture card must be placed at %s." % coordinates)
	return card


func _expectStep(plan: BoardShiftPlan, index: int, card: Card, fromCoordinates: Vector2i, toCoordinates: Vector2i, message: String) -> void:
	if index >= plan.steps.size():
		_expect(false, message)
		return

	var step: BoardShiftStep = plan.steps[index]
	_expect(step.card == card and step.fromSlot.coordinates == fromCoordinates and step.toSlot.coordinates == toCoordinates, message)


func _destroyFixture(fixture: Dictionary) -> void:
	fixture.root.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
