extends EffectParameters
class_name GainHealthParameters

var amount: int

static func fromDictionary(dictionary: Dictionary) -> GainHealthParameters:
	var amount = parsePositiveInt(dictionary, "amount")
	if amount == 0:
		return null
	var parameters = GainHealthParameters.new()
	parameters.amount = amount
	return parameters
