extends Node

const MODAL := preload("res://src/main/ui/overlays/encounter_modal.tscn")
@onready var CORPSE: EncounterDefinition = EncounterLibrary.getEncounterData("roadside_corpse")
@onready var QUIET_ROAD: EncounterDefinition = EncounterLibrary.getEncounterData("quiet_road")
@onready var CART: EncounterDefinition = EncounterLibrary.getEncounterData("abandoned_cart")

var failures := 0
var passed := 0
var requests: Array[Dictionary] = []
var backgroundPresses := 0
var replaceOnSubmit := false
var modal: EncounterModal

func _ready() -> void:
	GlobalSignalBus.encounterOutcomeRequested.connect(_onEncounterOutcomeRequested)
	var host := Control.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := Button.new()
	background.position = Vector2(10, 10)
	background.size = Vector2(160, 50)
	background.pressed.connect(func(): backgroundPresses += 1)
	host.add_child(background)
	modal = MODAL.instantiate()
	host.add_child(modal)
	await _settle()
	_expect(!modal.visible and modal.definition == null, "Modal starts closed.")
	modal.continueButton.pressed.emit()
	_expect(requests.is_empty(), "Closed modal cannot submit.")
	_expect(modal.present(CORPSE), "Continue-only fixture opens.")
	await _settle()
	_expect(modal.titleLabel.text == CORPSE.title and modal.bodyText.text == CORPSE.body, "Authored title and description populate.")
	_expect(modal.artwork.texture == CORPSE.artwork and modal.artwork.visible, "Authored artwork populates.")
	_expect(modal.continueButton.text == tr("CONTINUE_BUTTON") and tr("CONTINUE_BUTTON") != "CONTINUE_BUTTON", "Continue label is localised.")
	_expect(modal.continueButton.has_focus(), "Continue-only initially focuses Continue.")
	modal.leaveButton.pressed.emit()
	_expect(requests.is_empty(), "Hidden Leave cannot submit.")
	modal._submit(99 as EncounterDefinition.Outcome)
	_expect(requests.is_empty(), "Unsupported outcomes cannot submit.")
	await _click(Vector2(40, 30))
	_expect(backgroundPresses == 0, "Backdrop blocks actual pointer clicks to controls behind it.")
	await _click(modal.continueButton.get_global_rect().get_center())
	_expect(requests == [{"id": CORPSE.id, "outcome": EncounterDefinition.Outcome.CONTINUE}], "Pointer click emits the typed bus request once.")
	_expect(modal.visible and modal.continueButton.disabled and modal.leaveButton.disabled, "Submission disables both buttons and leaves closing to the host.")
	modal.continueButton.pressed.emit()
	_expect(requests.size() == 1, "Repeated submission is ignored.")
	modal.close()
	_expect(!modal.visible and modal.definition == null and !modal.continueButton.has_focus(), "Closing clears content reference and focus.")
	modal.present(QUIET_ROAD)
	await _settle()
	_expect(modal.leaveButton.visible and !modal.leaveButton.disabled and modal.leaveButton.has_focus(), "Choice encounter focuses enabled Leave.")
	_expect(modal.leaveButton.text == tr("LEAVE_BUTTON") and tr("LEAVE_BUTTON") != "LEAVE_BUTTON", "Leave label is localised.")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	get_viewport().push_input(accept)
	accept = InputEventAction.new()
	accept.action = "ui_accept"
	get_viewport().push_input(accept)
	await _settle()
	_expect(requests.size() == 2 and requests.back().outcome == EncounterDefinition.Outcome.LEAVE, "Focused Leave supports accept input.")
	modal.present(CART)
	await _settle()
	_expect(modal.definition == CART and modal.titleLabel.text == CART.title and modal.bodyText.text == CART.body, "Third data-only resource uses the same modal.")
	_expect(!modal.artwork.visible and modal.artwork.texture == null, "Text-only resource clears previous artwork.")
	_expect(modal.continueButton.text == "Search", "Custom button wording preserves the typed outcome.")
	modal.continueButton.pressed.emit()
	_expect(requests.size() == 3 and requests.back().outcome == EncounterDefinition.Outcome.CONTINUE, "Search still requests CONTINUE.")
	var fallback := CORPSE.duplicate() as EncounterDefinition
	fallback.buttonLabel = " "
	fallback.leaveButtonLabel = ""
	modal.present(fallback)
	_expect(modal.continueButton.text == tr("CONTINUE_BUTTON") and modal.leaveButton.text == tr("LEAVE_BUTTON"), "Empty labels fall back to localised defaults.")
	_expect(!modal.leaveButton.visible and modal.continueButton.has_focus(), "Switching back clears choice-mode focus and visibility.")
	get_tree().paused = true
	modal.continueButton.pressed.emit()
	_expect(requests.size() == 3, "Even programmatic submission is rejected while paused.")
	get_tree().paused = false
	replaceOnSubmit = true
	modal.continueButton.pressed.emit()
	_expect(requests.size() == 4 and modal.definition == CART and !modal.continueButton.disabled, "Synchronous bus handler may open the next definition safely.")
	replaceOnSubmit = false
	modal.close()
	print("Expected validation errors follow for null and unsupported encounter types.")
	_expect(!modal.present(null) and !modal.visible, "Null content is rejected without leaving the modal open.")
	var invalid := CORPSE.duplicate() as EncounterDefinition
	invalid.set("encounterType", 99)
	_expect(!modal.present(invalid) and !modal.visible, "Unsupported encounter type is rejected.")
	_expect(requests.size() == 4, "Invalid content emits no outcome requests.")
	_expect(CORPSE.buttonLabel == "CONTINUE_BUTTON" and CORPSE.artwork != null, "Shared authored resource remains unchanged.")
	GlobalSignalBus.encounterOutcomeRequested.disconnect(_onEncounterOutcomeRequested)
	host.queue_free()
	await get_tree().process_frame
	print("Encounter modal behaviour: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _onEncounterOutcomeRequested(encounterId: StringName, outcome: EncounterDefinition.Outcome) -> void:
	requests.append({"id": encounterId, "outcome": outcome})
	if replaceOnSubmit:
		modal.present(CART)

func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await _settle()

func _settle() -> void:
	for i in range(3):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
