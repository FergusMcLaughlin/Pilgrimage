extends Node

const MODAL := preload("res://src/main/ui/overlays/encounter_modal.tscn")
@onready var CORPSE: EncounterDefinition = EncounterLibrary.getEncounterData("roadside_corpse")
@onready var QUIET_ROAD: EncounterDefinition = EncounterLibrary.getEncounterData("quiet_road")
@onready var CART: EncounterDefinition = EncounterLibrary.getEncounterData("abandoned_cart")

var failures := 0
var passed := 0

func _ready() -> void:
	var host := Control.new()
	add_child(host)
	var modal: EncounterModal = MODAL.instantiate()
	host.add_child(modal)
	for viewportSize: Vector2 in [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080)]:
		host.size = viewportSize
		for definition: EncounterDefinition in [CORPSE, QUIET_ROAD, CART]:
			modal.present(definition)
			await _settleLayout()
			var frame: Control = modal.get_node("ModalFrame")
			var panel: PanelContainer = frame.get_node("Panel")
			var row: HBoxContainer = panel.get_node("Margin/HBoxContainer")
			var textMargin: MarginContainer = row.get_node("TextMargin")
			var content: VBoxContainer = textMargin.get_node("Content")
			var buttons: HBoxContainer = modal.continueButton.get_parent()
			_expect((frame.position + frame.size * 0.5).is_equal_approx(viewportSize * 0.5), "Modal remains centred.")
			_expect(panel.size.is_equal_approx(frame.size), "Panel fits its frame.")
			var areaRatio: float = panel.size.x * panel.size.y / (viewportSize.x * viewportSize.y)
			_expect(areaRatio >= 0.2 and areaRatio <= 0.3, "Panel occupies 20–30 percent of the viewport.")
			_expect(modal.get_node("DimBackground").size.is_equal_approx(viewportSize), "Backdrop covers the viewport.")
			_expect(is_equal_approx(textMargin.position.x + textMargin.size.x, row.size.x), "Text column fills the remaining width.")
			if definition.artwork != null:
				var textShare: float = textMargin.size.x / row.size.x
				_expect(textShare >= 0.30 and textShare <= 0.38, "Illustrated fixture preserves the approved text-column share.")
				_expect(absf(modal.artwork.size.y - panel.size.y) < 1.0, "Artwork covers the full panel height.")
				_expect(modal.artwork.get_global_rect().position.is_equal_approx(panel.get_global_rect().position), "Artwork is flush with the panel edge.")
			else:
				_expect(!modal.artwork.visible and textMargin.size.is_equal_approx(row.size), "Text-only fixture has no artwork gap.")
			_expect(modal.bodyText.size.x == content.size.x, "Body fills the text column.")
			_expect(!modal.bodyText.scroll_active, "Descriptions do not scroll.")
			_expect(modal.bodyText.get_content_height() <= modal.bodyText.size.y + 1, "Authored description fits without clipping: %s at %s" % [definition.id, viewportSize])
			_expect(content.get_global_rect().encloses(modal.titleLabel.get_global_rect()), "Wrapped title stays within the text column.")
			_expect(content.get_global_rect().encloses(modal.continueButton.get_global_rect()), "Continue stays within the text column.")
			if modal.leaveButton.visible:
				_expect(content.get_global_rect().encloses(modal.leaveButton.get_global_rect()), "Leave stays within the text column.")
				_expect(is_zero_approx(modal.leaveButton.position.x), "Leave aligns left.")
				_expect(is_equal_approx(modal.continueButton.position.x + modal.continueButton.size.x, buttons.size.x), "Continue aligns right with Leave present.")
			else:
				_expect(absf(modal.continueButton.position.x + modal.continueButton.size.x * 0.5 - buttons.size.x * 0.5) < 1.0, "Continue alone is centred.")
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			_expect(style != null and style.bg_color == Color.BLACK, "Text panel is opaque black.")
			_expect(!modal.get_node("DeadBody").visible and !modal.get_node("DeadBodyOL").visible, "No fixture-specific corpse layers leak into other encounters.")
	host.queue_free()
	await get_tree().process_frame
	print("Encounter modal layout: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _settleLayout() -> void:
	for i in range(3):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
