extends GameActionPayload
class_name ModifyStatsPayload

var stat: String
var amount: int

static func create(modifyStat: String, modifyAmount: int, modifyCause: String) -> ModifyStatsPayload:
	var modifyStatActionPayload = ModifyStatsPayload.new()
	modifyStatActionPayload.stat = modifyStat
	modifyStatActionPayload.amount = modifyAmount
	modifyStatActionPayload.cause = modifyCause
	return modifyStatActionPayload
