extends GameActionPayload
class_name DealDamagePayload

var amount: int
var cycleNumber: int

static func create(dealDamageAmount: int, dealDamageCause: String, dealDamageCycleNumber: int) -> DealDamagePayload:
	var dealDamageActionPayload = DealDamagePayload.new()
	dealDamageActionPayload.amount = dealDamageAmount
	dealDamageActionPayload.cause = dealDamageCause
	dealDamageActionPayload.cycleNumber = dealDamageCycleNumber
	return dealDamageActionPayload
