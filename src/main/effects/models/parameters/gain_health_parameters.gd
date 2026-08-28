extends EffectParameters
class_name GainHealthParameters

var amount: int

static func fromDictionary(dictionary: Dictionary) -> GainHealthParameters:
	var rawAmount = dictionary.get("amount")
	if rawAmount is float and rawAmount == floorf(rawAmount):
		rawAmount = int(rawAmount)
	if !(rawAmount is int) or rawAmount <= 0:
		return null
	var parameters = GainHealthParameters.new()
	parameters.amount = rawAmount
	return parameters
