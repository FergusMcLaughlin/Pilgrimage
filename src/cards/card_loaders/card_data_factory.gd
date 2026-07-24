class_name CardDataFactory

static func fromDictionary(dictionary: Dictionary) -> CardData:
	var data := CardData.new()

	data.id = dictionary.get("id", "")
	data.name = dictionary.get("name", "")
	data.type = dictionary.get("type", "")
	data.baseHealth = dictionary.get("health", 0)
	data.baseAttack = dictionary.get("attack", 0)
	data.isPlayer = dictionary.get("isPlayer", false)
	data.isUnlocked = dictionary.get("isUnlocked", false)
	data.imagePath = dictionary.get("image_path", "")
	data.effects = _parseEffects(dictionary)

	return data

static func _parseEffects(dictionary: Dictionary) -> Array[String]:
	var rawEffects = dictionary.get("effects", [])
	var effects: Array[String] = []

	if rawEffects is Array:
		for effect in rawEffects:
			effects.append(str(effect))

	return effects
