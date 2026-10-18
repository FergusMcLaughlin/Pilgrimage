class_name EncounterJsonLoader

static func loadDictionaryFromFile(filepath: String) -> Dictionary:
	if !FileAccess.file_exists(filepath):
		push_error("EncounterJasonLoader: file does not exist : " + filepath)
		return {}
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("EncounterJasonLoader: failed to open file : " + filepath)
		return {}
	
	var fileText = file.get_as_text()
	var parsedResults = JSON.parse_string(fileText)

	if parsedResults == null:
		push_error("EncounterJasonLoader: invalid JSON in file : " + filepath)
		return {}
	
	if !(parsedResults is Dictionary):
		push_error("EncounterJasonLoader: expected top-level dictionary in file : " + filepath)
		return {}
	
	return parsedResults
