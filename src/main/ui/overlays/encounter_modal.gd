class_name EncounterModal
extends Control

@onready var artwork: TextureRect = %Artwork
@onready var titleLabel: Label = %Title
@onready var bodyText: RichTextLabel = %BodyText
@onready var continueButton: Button = %ContinueButton
@onready var leaveButton: Button = %LeaveButton

var definition: EncounterDefinition

func _ready() -> void:
	continueButton.pressed.connect(_onContinueButtonPressed)
	leaveButton.pressed.connect(_onLeaveButtonPressed)
	close()

func _onContinueButtonPressed() -> void:
	_submit(EncounterDefinition.Outcome.CONTINUE)

func _onLeaveButtonPressed() -> void:
	_submit(EncounterDefinition.Outcome.LEAVE)

func present(content: EncounterDefinition) -> bool:
	close()
	if content == null or content.encounterType not in [
		EncounterDefinition.Type.CONTINUE_ONLY,
		EncounterDefinition.Type.CONTINUE_OR_LEAVE
	]:
		push_error("EncounterModal: expected a valid encounter type.")
		return false
	
	definition = content
	titleLabel.text = content.title
	bodyText.text = content.body
	artwork.texture = content.artwork
	artwork.visible = content.artwork != null
	continueButton.text = _label(content.buttonLabel, "CONTINUE_BUTTON")
	leaveButton.text = _label(content.leaveButtonLabel, "LEAVE_BUTTON")
	leaveButton.visible = content.encounterType == EncounterDefinition.Type.CONTINUE_OR_LEAVE
	continueButton.size_flags_horizontal = Control.SIZE_EXPAND | (
		Control.SIZE_SHRINK_END if leaveButton.visible else Control.SIZE_SHRINK_CENTER
	)
	continueButton.disabled = false
	leaveButton.disabled = !leaveButton.visible
	show()
	if leaveButton.visible:
		leaveButton.grab_focus()
	else:
		continueButton.grab_focus()
	return true

func _submit(outcome: EncounterDefinition.Outcome) -> void:
	if definition == null or continueButton.disabled or not is_visible_in_tree() or get_tree().paused:
		return
	if outcome not in [EncounterDefinition.Outcome.CONTINUE, EncounterDefinition.Outcome.LEAVE]:
		return
	if outcome == EncounterDefinition.Outcome.LEAVE and not leaveButton.visible:
		return
	
	continueButton.disabled = true
	leaveButton.disabled = true
	GlobalSignalBus.emitEncounterOutcomeRequested(definition.id, outcome)

func close() -> void:
	definition = null
	continueButton.disabled = true
	leaveButton.disabled = true
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null && is_ancestor_of(focused):
		focused.release_focus()
	hide()

func _label(value: String, fallbackKey: String) -> String:
	return tr(fallbackKey if value.strip_edges().is_empty() else value)
