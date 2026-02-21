extends Node2D

@onready var card: Card = $Card

var dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	GlobalSignalBus.cardClicked.connect(_onCardClicked)
	GlobalSignalBus.cardFlipped.connect(_onCardFlipped)

	# TEMP: assign a CardData resource in inspector, or load one here
	# card.setCardData(preloaded_data)

func _onCardClicked(c: Card) -> void:
	# start dragging on click
	dragging = true
	drag_offset = c.global_position - get_global_mouse_position()
	c.shadow.setVisible(true, true, false)

func _unhandled_input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
		dragging = false
		card.shadow.setVisible(false)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		card.visuals.flip() # quick flip test

func _process(_delta: float) -> void:
	if dragging:
		card.global_position = get_global_mouse_position() + drag_offset

func _onCardFlipped(c: Card) -> void:
	# optional debug hook
	pass
