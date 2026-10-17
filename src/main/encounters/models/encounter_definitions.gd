class_name EncounterDefinition
extends Resource

enum Type { CONTINUE_ONLY, CONTINUE_OR_LEAVE }
enum Outcome { CONTINUE, LEAVE }

@export var encounterType: Type = Type.CONTINUE_ONLY
@export var id: StringName = &""
@export var title: String = ""
@export_multiline var body: String = ""
@export var artwork: Texture2D
@export var buttonLabel: String = "CONTINUE_BUTTON"
@export var leaveButtonLabel: String = "LEAVE_BUTTON"
