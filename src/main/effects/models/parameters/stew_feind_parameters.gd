extends EffectParameters
class_name StewFeindParameters

var watchedCardId: String
var amount: int

static func fromDictionary(dictionary: Dictionary) -> StewFeindParameters:
	var rawCardId = dictionary.get("watched_card_id")
	if !(rawCardId is String) or rawCardId.strip_edges().is_empty():
		return null
	var amount = parsePositiveInt(dictionary, "amount")
	if amount == 0:
		return null
	var parameters = StewFeindParameters.new()
	parameters.watchedCardId = rawCardId
	parameters.amount = amount
	return parameters
