extends RefCounted
class_name EffectParameters

static func parsePositiveInt(dictionary: Dictionary, key: String) -> int:
	var raw = dictionary.get(key)
	if raw is float and raw == floorf(raw):
		raw = int(raw)
	if !(raw is int) or raw <= 0:
		return 0
	return raw
