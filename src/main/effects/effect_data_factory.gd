class_name EffectDataFactory

static func fromDictionary(dictionary: Dictionary) -> EffectData:
	var data = EffectData.new()
	
	data.id = dictionary.get("id", "")
	data.name = dictionary.get("name", "")
	data.trigger = dictionary.get("trigger", "")
	data.operation = dictionary.get("operation", "")
	data.target = dictionary.get("target", "")
	data.scriptPath = dictionary.get("script_path", "")
	data.parameters = _parseParameters(data.operation, dictionary.get("parameters", {}))
	
	return data

static func _parseParameters(operation: String, rawParameters: Variant) -> EffectParameters:
	if !(rawParameters is Dictionary):
		return null
	match operation:
		"gain_health":
			return GainHealthParameters.fromDictionary(rawParameters)
		_:
			return null
