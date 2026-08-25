class_name DamageResult
extends RefCounted

var succeeded = false
var failureReason = ""

var source: Card
var target: Card
var sourceInstanceId = 0
var sourceCardId = ""
var targetInstanceId = 0
var targetCardId = ""

var cause = ""
var cycleNumber = 0
var damageRequested = 0
var damageDealt = 0
var temporaryHealthLost = 0
var baseHealthLost = 0
var remainingTemporaryHealth = 0
var remainingHealth = 0
var wasLethal = false

static func rejected(reason: String) -> DamageResult:
	var result = DamageResult.new()
	result.failureReason = reason
	return result
