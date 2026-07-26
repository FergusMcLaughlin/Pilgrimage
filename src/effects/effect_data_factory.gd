class_name EffectDataFactory

static func fromDictionary(dictionary: Dictionary) -> EffectData:
	var data := EffectData.new()

	data.id = dictionary.get("id", "")
	data.name = dictionary.get("name", "")
	data.trigger = dictionary.get("trigger", "")
	data.operation = dictionary.get("operation", "")
	data.target = dictionary.get("target", "")
	data.parameters = dictionary.get("parameters", {}).duplicate(true)

	return data
