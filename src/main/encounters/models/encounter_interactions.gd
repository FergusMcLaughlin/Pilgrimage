class_name EncounterInteraction
extends RefCounted

var runId: int
var cycleNumber: int
var source: Card
var sourceInstanceId: int
var player: Card
var playerInstanceId: int
var playerSlot: CardSlot
var targetSlot: CardSlot
var definition: EncounterDefinition
var sourceRemoved = false
var playerMoved = false

var waitingAction: GameAction

static func create (
	id: int,
	cycle: int,
	sourceCard: Card,
	playerCard: Card,
	fromSlot: CardSlot,
	toSlot: CardSlot
	) -> EncounterInteraction:
	var request = EncounterInteraction.new()
	request.runId = id
	request.cycleNumber = cycle
	request.source = sourceCard
	request.sourceInstanceId = sourceCard.instanceId
	request.player = playerCard
	request.playerInstanceId = playerCard.instanceId
	request.playerSlot = fromSlot
	request.targetSlot = toSlot
	request.definition = sourceCard.data.encounter
	return request
