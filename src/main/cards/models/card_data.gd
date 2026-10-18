extends Resource
class_name CardData

@export var id: String
@export var name: String
@export var type: String
@export var baseHealth: int
@export var baseAttack: int
@export var isPlayer: bool
@export var isUnlocked: bool
@export var imagePath: String
@export var effects: Array[String] = []
@export var hasEncounter: bool = false
@export var encounterId: StringName = &""
@export var encounter: EncounterDefinition
