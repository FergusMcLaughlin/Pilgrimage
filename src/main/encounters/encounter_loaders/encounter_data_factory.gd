class_name EncounterDataFactory

static func fromDictionary(dictionary: Dictionary) -> EncounterDefinition:
	var data := EncounterDefinition.new()
	
	data.id = dictionary.get("id", "")
	data.title = dictionary.get("title", "")
	data.body = dictionary.get("body", "")
	data.encounterType = _parseType(dictionary)
	data.artwork = _parseArtwork(dictionary)
	data.buttonLabel = dictionary.get("button_label", "CONTINUE_BUTTON")
	data.leaveButtonLabel = dictionary.get("leave_button_label", "LEAVE_BUTTON")
	
	return data

static func _parseType(dictionary: Dictionary) -> EncounterDefinition.Type:
	var types = {
		"continue_only": EncounterDefinition.Type.CONTINUE_ONLY,
		"continue_or_leave": EncounterDefinition.Type.CONTINUE_OR_LEAVE
	}
	
	return types.get(dictionary.get("type", "continue_only"), EncounterDefinition.Type.CONTINUE_ONLY)

static func _parseArtwork(dictionary: Dictionary) -> Texture2D:
	var artworkPath: String = dictionary.get("artwork_path", "")
	
	if !artworkPath.is_empty():
		return load(artworkPath) as Texture2D
	
	return null
