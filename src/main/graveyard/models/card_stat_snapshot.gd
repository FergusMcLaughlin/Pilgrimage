extends RefCounted
class_name CardStatSnapshot

var health: int
var temporaryHealth: int
var attack: int

static func fromCard(card: Card) -> CardStatSnapshot:
	if card == null:
		return null
	var snapshot = CardStatSnapshot.new()
	snapshot.health = card.health
	snapshot.temporaryHealth = card.temporaryHealth
	snapshot.attack = card.attack
	return snapshot

func copy() -> CardStatSnapshot:
	var snapshot = CardStatSnapshot.new()
	snapshot.health = health
	snapshot.temporaryHealth = temporaryHealth
	snapshot.attack = attack
	return snapshot

func toDictionary() -> Dictionary:
	return {
		"health": health,
		"temporary_health": temporaryHealth,
		"attack": attack
	}
