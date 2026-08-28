
class_name CombatResult
extends RefCounted

var succeeded = false
var failureReason = ""
var context: CombatContext

var defenderDamage: DamageResult
var playerDamage: DamageResult

var defenderDefeated = false
var playerDefeated = false
var defenderGraveyardEntry: GraveyardEntry
var playerGraveyardEntry: GraveyardEntry

var playerMoved = false

func resultedInAKill() -> bool:
	return defenderGraveyardEntry != null

func attackerSurvived() -> bool:
	return !playerDefeated

static func failed(combatContext: CombatContext, reason: String) -> CombatResult:
	var result = CombatResult.new()
	result.context = combatContext
	result.failureReason = reason
	return result
