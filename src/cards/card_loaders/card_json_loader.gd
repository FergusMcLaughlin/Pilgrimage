class_name CardJsonLoader

static func loadDictionaryFromFile(filepath: String) -> Dictionary:
	if !FileAccess.file_exists(filepath):
		push_error("CardJasonLoader: file does not exist : " + filepath)
		return {}
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("CardJasonLoader: failed to open file : " + filepath)
		return {}
	
	var fileText = file.get_as_text()
	var parsedResults = JSON.parse_string(fileText)

	if parsedResults == null:
		push_error("CardJasonLoader: invalid JSON in file : " + filepath)
		return {}
	
	if !(parsedResults is Dictionary):
		push_error("CardJasonLoader: expected top-level dictionary in file : " + filepath)
		return {}
	
	return parsedResults
