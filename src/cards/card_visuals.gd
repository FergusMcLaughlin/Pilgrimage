extends Node2D # possible mistake
class_name CardVisuals

const STAT_COLOUR_NORMAL = Color.BLACK
const STAT_COLOUR_BUFFED = Color.DARK_GREEN
const STAT_COLOUR_DEBUFFED = Color.DARK_RED

@onready var face: TextureRect = $CardFace
@onready var back: TextureRect = $CardBack
@onready var nameLable: RichTextLabel = $CardName
@onready var healthLable: RichTextLabel = $CardHealth
@onready var attackLable: RichTextLabel = $CardAttack
@onready var shape: Polygon2D = $Polygon2D

var card: Card

func init(cardReference: Card):
	card = cardReference

func refresh() -> void:
	nameLable.text = str(card.data.name)
	healthLable.text = str(card.health)
	attackLable.text = str(card.attack)

	_loadCardImage()
	_updateStatColours()

func _loadCardImage() -> void:
	var imagePath := "res://assets/images/cards/%s.png" % card.data.name
	var texture := load(imagePath)

	if texture:
		face.texture = texture
		face.scale = Vector2(0.1, 0.1)
	else:
		push_error("Card Visuals: Cant load picture: " + imagePath)

func _updateStatColours() -> void:
	if card.data.type == "player":
		return
	
	attackLable.modulate = _getStatColour(card.attack, card.data.baseAttack)
	healthLable.modulate = _getStatColour(card.health, card.data.baseHealth)

func _getStatColour(current: int, base: int) -> Color:
	if current > base:
		return STAT_COLOUR_BUFFED
	elif current < base:
		return STAT_COLOUR_DEBUFFED
	return STAT_COLOUR_NORMAL

func flip() -> void: # shadow functionality is gone currently
	var flipTween = card.create_tween()

	flipTween.tween_property(self, "scale:x", 0.0, 0.15)
	flipTween.tween_callback(func(): _toggleCardVisibility())
	flipTween.tween_property(self, "scale:x", 1.0, 0.15)

	GlobalSignalBus.emitCardFlipped(card)

func _toggleCardVisibility() -> void:
	var componenets = [face, back, nameLable, healthLable, attackLable]
	for component in componenets:
		component.visible = !component.visible
	
