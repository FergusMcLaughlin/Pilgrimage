extends Area2D
class_name CardArea

var card: Card

func init(cardReference: Card):
	card = cardReference

func _ready() -> void:
	collision_layer = GameConstants.LAYER_CARD
	collision_mask = 0

	mouse_entered.connect(onMouseEntered)
	mouse_exited.connect(onMouseExited)
	input_event.connect(onInputEvent)

func onMouseEntered() -> void:
	if card == null:
		return
	
	GlobalSignalBus.emitCardHovered(card)

func onMouseExited() -> void:
	if card == null:
		return

	GlobalSignalBus.emitCardUnhovered(card)

func onInputEvent(_viewport,event, _shape_idx):
	if card == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		GlobalSignalBus.emitCardClicked(card)
