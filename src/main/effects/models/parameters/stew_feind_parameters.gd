extends EffectParameters
class_name StewFeindParameters

var watchedCardId: String
var amount: int

static func fromDictionary(dictionary: Dictionary) -> StewFeindParameters:
	var rawCardId = dictionary.get("watched_card_id")
	if !(rawCardId is String) or rawCardId.strip_edges().is_empty():
		return null
	var rawAmount = dictionary.get("amount")
	if rawAmount is float and rawAmount == floorf(rawAmount):
		rawAmount = int(rawAmount)
	if !(rawAmount is int) or rawAmount <= 0:
		return null
	var parameters = StewFeindParameters.new()
	parameters.watchedCardId = rawCardId
	parameters.amount = rawAmount
	return parameters
