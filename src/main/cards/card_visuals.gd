extends Control
class_name CardVisuals

const STAT_COLOUR_NORMAL = Color.BLACK
const STAT_COLOUR_BUFFED = Color.DARK_GREEN
const STAT_COLOUR_DEBUFFED = Color.DARK_RED

@onready var face: TextureRect = %CardFace
@onready var back: TextureRect = %CardBack
@onready var nameLable: RichTextLabel = %CardName
@onready var healthLable: RichTextLabel = %CardHealth
@onready var attackLable: RichTextLabel = %CardAttack


var card: Card
var isHovered := false
var isDragging := false
var scaleTween: Tween

var defaultZIndex := 0
var dragZIndex := 1000

func init(cardReference: Card):
	card = cardReference
	defaultZIndex = z_index

func refresh() -> void:
	nameLable.text = str(card.data.name)
	healthLable.text = (
	str(card.health)
	if card.temporaryHealth <= 0 else "%s (+%s)" % [card.health, card.temporaryHealth]
		)#temp for testing show health lost #TODO REMOVE
	attackLable.text = str(card.attack)

	_loadCardImage()
	_updateStatColours()

func _loadCardImage() -> void:
	var imagePath := card.data.imagePath
	if imagePath.is_empty() or not ResourceLoader.exists(imagePath):
		push_warning("Card Visuals: Cannot load picture: " + imagePath)
		imagePath = "res://assets/images/cards/default_image.png"

	face.texture = load(imagePath)

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

func applyInteractionVisuals(hovered: bool, dragging: bool) -> void:
	isHovered = hovered
	isDragging = dragging

	if scaleTween:
		scaleTween.kill()
		scaleTween = null

	var targetScale := Vector2.ONE

	if isDragging:
		targetScale = Vector2(1.10, 1.10)
	elif isHovered:
		targetScale = Vector2(1.05, 1.05)

	scale = targetScale
	z_as_relative = !isDragging
	z_index = dragZIndex if isDragging else defaultZIndex

func beginFlip() -> Tween:
	var flipTween := card.create_tween()

	flipTween.tween_property(self, "scale:x", 0.0, 0.15)
	flipTween.tween_callback(func(): _toggleCardVisibility())
	flipTween.tween_property(self, "scale:x", 1.0, 0.15)

	GlobalSignalBus.emitCardFlipped(card)
	return flipTween

func flip() -> void:
	var flipTween := beginFlip()
	await flipTween.finished

func _toggleCardVisibility() -> void:
	var componenets = [face, back, nameLable, healthLable, attackLable]
	for component in componenets:
		component.visible = !component.visible

func handleHovered(hovered: bool) -> void:
	if isHovered == hovered:
		return
	
	applyInteractionVisuals(hovered, isDragging)

func handleDragging(dragging: bool) -> void:
	if isDragging == dragging:
		return
	
	applyInteractionVisuals(isHovered, dragging)

func isFaceUp() -> bool:
	return face.visible and !back.visible
