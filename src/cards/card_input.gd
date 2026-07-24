extends Control
class_name CardInput

var card: Card

func init(cardReference: Card):
	card = cardReference

func _ready() -> void:
	mouse_entered.connect(onMouseEntered)
	mouse_exited.connect(onMouseExited)

func onMouseEntered() -> void:
	card.onCardHovered()

func onMouseExited() -> void:
	card.onCardUnhovered()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			card.onCardPressed()
		else:
			card.onCardReasled()
