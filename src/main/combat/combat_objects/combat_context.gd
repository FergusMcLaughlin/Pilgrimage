class_name CombatContext
extends RefCounted

var cycleNumber: int
var attacker: Card
var defender: Card
var playerSlot: CardSlot
var targetSlot: CardSlot

var attackerInstanceId: int
var attackerCardId: String
var defenderInstanceId: int
var defenderCardId: String

var attackerDamage: int
var retaliationDamage: int

static func create(cycle: int, player: Card, target: Card, fromSlot: CardSlot, toSlot: CardSlot) -> CombatContext:
	var context = CombatContext.new()
	
	context.cycleNumber = cycle
	context.attacker = player
	context.defender = target
	context.playerSlot = fromSlot
	context.targetSlot = toSlot
	context.attackerInstanceId = player.instanceId
	context.attackerCardId = player.data.id
	context.defenderInstanceId = target.instanceId
	context.defenderCardId = target.data.id
	context.attackerDamage = maxi(player.attack, 0)
	context.retaliationDamage = maxi(target.attack, 0)
	return context
